
#define _CRT_SECURE_NO_WARNINGS
#define _USE_MATH_DEFINES

#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#include <curand.h>
#include <curand_kernel.h>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <vector> 
#include <algorithm>
#include <random>
#include <cassert>
#include <tuple>
#include <omp.h>
#include <time.h>
#include <math.h>

#define UNREACHABLE() assert(0)
#define Pi 3.14159265358979323846
#define MAX_Sphere 10
int tonemap(double v) {
	return std::min(
		std::max(int(std::pow(v, 1 / 2.2) * 255), 0), 255);

};

//構造体

struct Ray {
	double3 o;
	double3 d;
};

struct Sphere;

struct Hit {
	double t;
	double3 p;
	double3 n;
	const Sphere* sphere;
	bool F;
};

enum class SurfaceType {
	Diffuse,
	Mirror,
	Fresnel,
};

struct Sphere {
	double3 p;
	double r;
	SurfaceType type;
	double3 R;//反射率　　色
	double3 Le;
	double ior = 1.5168;
};

struct Scene {
	Sphere spheres[MAX_Sphere]
	{
		{ double3{1e5 + 1,   40.8,		  81.6}, 1e5 , SurfaceType::Diffuse, double3{.99,0.,0.} },//左の壁
		{ double3{-1e5 + 99, 40.8,		  81.6}, 1e5 , SurfaceType::Diffuse, double3{0.,.99,0.} },//右の壁
		{ double3{50,        40.8,		  1e5},  1e5 , SurfaceType::Diffuse, double3{.75,.75,.75} },//奥の壁
		{ double3{50,        1e5,		  81.6}, 1e5 , SurfaceType::Diffuse, double3{.75,.75,.75} },//天井
		{ double3{50,		 -1e5 + 81.6, 81.6}, 1e5 , SurfaceType::Diffuse, double3{.75,.75,.75} },//床
		{ double3{37,		 16.5,		  47},   16.5, SurfaceType::Mirror, double3{.999,.999,.999}  },//左下の球
		{ double3{37,		 49.5,		  47},   16.5, SurfaceType::Mirror, double3{.999,.999,.999}  },//左上の球
		{ double3{73,		 16.5,		  78},   16.5, SurfaceType::Fresnel,double3{.999,.999,.999}  },//右下の球
		{ double3{73,		 49.5,		  78},   16.5, SurfaceType::Fresnel,double3{.999,.999,.999}  },//右上の球
		{ double3{50,		 681.6 - .27, 81.6}, 600 , SurfaceType::Diffuse, double3{0,0,0}, double3{12,12,12} },//ライト
	};
};


//グローバル変数
const int width = 1200;		//画像幅
const int height = 800;		//画像高さ



const int spp = 10;			//ピクセルごとのサンプル数
const int depth = 10;		//レイの反射数


//ホスト
double3 h_Result[width*height];

//デバイス
double3 *d_Result;


//デバイス関数
__device__ double dot(double3 a, double3 b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

__device__ double3 Normalize(double3 v) {
	return double3{ v.x / sqrt(dot(v, v)), v.y / sqrt(dot(v, v)), v.z / sqrt(dot(v, v)) };
}


__device__ double3 cross(double3 a, double3 b) {
	return double3{ a.y * b.z - a.z * b.y,
					a.z * b.x - a.x * b.z,
					a.x * b.y - a.y * b.x };
}

//カーネル関数
// GPUで計算する際の関数
__global__ void gpu_function(double3 *d_Result)
{
	int k_x = blockIdx.x * blockDim.x + threadIdx.x;//カーネルのX座標
	int k_y = blockIdx.y*blockDim.y + threadIdx.y;//カーネルのY座標
	int xsize = gridDim.x*blockDim.x;
	int id = k_x + k_y * xsize;

	d_Result[id] = { 0,0,0 };//{r,g,b}

	curandStateXORWOW_t rands;
	curand_init(1234, id, 0, &rands);

	/*camera parameter*/

	//位置
	const double3 eye{ 50, 52, 295.6 };
	//注視点
	const double3 center = double3{ eye.x + 0, eye.y - 0.042612, eye.z - 1 };
	//カメラの上を表すベクトル
	const double3 up{ 0, 1, 0 };
	//視野角
	const double fov = 30 * Pi / 180;
	//画面のアスペクト比
	const double aspect = double(width) / height;


	// Basis vectors for camera coordinates
	//カメラ座標系の基底ベクトル
	const auto wE = Normalize({ eye.x - center.x, eye.y - center.y, eye.z - center.z });
	const auto uE = Normalize(cross(up, wE));
	const auto vE = cross(wE, uE);


	for (int j = 0; j < spp; j++) {
		const int x = id % width;
		const int y = height - id / width;
		Ray ray;
		
		ray.o = eye;

		ray.d = [&]() {
			const double tf = tan(fov * .5);
			const double rpx = 2. * (x + curand_uniform_double(&rands)) / width - 1;
			const double rpy = 2. * (y + curand_uniform_double(&rands)) / height - 1;
			const double3 w = Normalize(double3{ aspect * tf * rpx, tf * rpy, -1 });
			return double3{ uE.x * w.x + vE.x * w.y + wE.x * w.z,
							uE.y * w.x + vE.y * w.y + wE.y * w.z,
							uE.z * w.x + vE.z * w.y + wE.z * w.z };// uE*w.x + vE * w.y + wE * w.z;
		}();

		double3 L{ 0,0,0 };
		double3 th{ 1.,1.,1. };

		for (int k = 0; k < depth; k++) {//反射回数？　　反射回数が１だとここがレイの数で２
			
			// 視点・カメラの設定
			Scene scene;

			Hit minh;
			int num;
			double tmin = 1e-4;
			double tmax = 1e+10;

			for (int i = 0; i < MAX_Sphere; i++) {
				Hit hit;

				const double3 op = { scene.spheres[i].p.x - ray.o.x , scene.spheres[i].p.y - ray.o.y , scene.spheres[i].p.z - ray.o.z };
				
				const double b = op.x*ray.d.x + op.y*ray.d.y + op.z*ray.d.z;

				const double det = b * b - (op.x*op.x + op.y*op.y + op.z*op.z) + scene.spheres[i].r * scene.spheres[i].r;

				if (det < 0) {
					hit = Hit{ 0,{0,0,0},{0,0,0},nullptr,false };
			
				}
				else {
					const double t1 = b - sqrt(det);
					if (tmin < t1 && t1 < tmax) {
					    hit = Hit{ t1, {}, {}, &scene.spheres[i] ,true };
						
					}
					else {
						const double t2 = b + sqrt(det);
						
						if (tmin < t2 && t2 < tmax) {
							num = 11;
							

							hit = Hit{ t2, {}, {}, &scene.spheres[i] ,true };
						}
						else {
						
							hit = Hit{ 0,{0,0,0},{0,0,0},nullptr,false };//適当なHITの値を返す
						}
					}
				}
													
				if (!hit.F) { continue; };

				//num = i;
				minh = hit;
				minh.F = true;//追加
				tmax = minh.t;
			}
			
			if (minh.F) {
				const Sphere* s = minh.sphere;
				minh.p = double3{ ray.o.x + ray.d.x * minh.t, ray.o.y + ray.d.y * minh.t, ray.o.z + ray.d.z * minh.t };
				minh.n = double3{ (minh.p.x - s->p.x) / s->r ,(minh.p.y - s->p.y) / s->r ,(minh.p.z - s->p.z) / s->r };
			}
				//return minh;
			


			// Intersection
			const Hit h = minh;
	
			
			if (!h.F) {
				break;
			}

			// Add contribution
			L = double3{ L.x + th.x * h.sphere->Le.x, L.y + th.y * h.sphere->Le.y, L.z + th.z * h.sphere->Le.z };
			
			
			// Update next direction
			ray.o = h.p;
			ray.d = [&]() {
				if (h.sphere->type == SurfaceType::Diffuse) {
					// Sample direction in local coordinates
					const double3 n = dot(h.n, double3{ -ray.d.x,-ray.d.y ,-ray.d.z }) > 0 ? double3{ h.n.x,h.n.y,h.n.z } : double3{ -h.n.x,-h.n.y,-h.n.z };

					double3 u{ 0,0,0 }, v{ 0,0,0 };
					const double s = n.z >= 0 ? 1 : -1;


					const double a = -1 / (s + n.z);
					const double b = n.x * n.y * a;

					u = double3{ 1 + s * n.x * n.x * a, s * b, -s * n.x };
					v = double3{ b, s + n.y * n.y * a, -n.y };


					const double3 d = [&]() {
						const double r = sqrt(curand_uniform_double(&rands));
						const double t = 2 * Pi * curand_uniform_double(&rands);
						const double x = r * cos(t);
						const double y = r * sin(t);

						if (0.0 > 1 - x * x - y * y) {
							return double3{ x, y,
								sqrt(0.0) };
						}
						else {
							return double3{ x, y,
							sqrt(1 - x * x - y * y) };
						}

					}();

					// Convert to world coordinates
					return  double3{ u.x * d.x + v.x * d.y + n.x * d.z,
									 u.y * d.x + v.y * d.y + n.y * d.z,
									 u.z * d.x + v.z * d.y + n.z * d.z };

				}
				else if (h.sphere->type == SurfaceType::Mirror) {
					
					const double3 wi = double3{ -ray.d.x, -ray.d.y, -ray.d.z };//-ray.d
					return  double3{ 2 * dot(wi,h.n) * h.n.x - wi.x,
									 2 * dot(wi,h.n) * h.n.y - wi.y,
									 2 * dot(wi,h.n) * h.n.z - wi.z };
					
				}
				else if (h.sphere->type == SurfaceType::Fresnel) {

					const double3 wi = double3{ -ray.d.x, -ray.d.y, -ray.d.z };//-ray.d;
					const bool into = dot(wi, h.n) > 0;
					const double3 n = into ? h.n : double3{ -h.n.x,-h.n.y,-h.n.z };
					const double ior = h.sphere->ior;
					const double eta = into ? 1 / ior : ior;

					bool F;
					const double3 wt = [&]() -> double3 {
						// Snell's law (vector form)
						const double t = dot(wi, n);
						const double t2 = 1 - eta * eta * (1 - t * t);

						if (t2 < 0) {
							F = false;
							return double3{ 0,0,0 };
						}

						F = true;
						return double3{ eta * (n.x * t - wi.x) - n.x * sqrt(t2),
										eta * (n.y * t - wi.y) - n.y * sqrt(t2),
										eta * (n.z * t - wi.z) - n.z * sqrt(t2) }; //eta * (n * t - wi) - n * sqrt(t2);

					}();

					if (!F) {
						// Total internal reflection
						return double3{ 2 * dot(wi,h.n) * h.n.x - wi.x,
									    2 * dot(wi,h.n) * h.n.y - wi.y,
									    2 * dot(wi,h.n) * h.n.z - wi.z };// 2 * dot(wi, h.n) * h.n - wi;
					}

					const double Fr = [&]() {
						// Schlick's approximation
						const double cos = into
							? dot(wi, h.n)
							: dot(wt, h.n);
						const double r = (1 - ior) / (1 + ior);
						return r * r + (1 - r * r) * pow(1 - cos, 5);
					}();

					// Select reflection or refraction
					// according to the fresnel term
					return  curand_uniform_double(&rands) < Fr
						? double3{ 2 * dot(wi, h.n) * h.n.x - wi.x,
								   2 * dot(wi, h.n) * h.n.y - wi.y,
								   2 * dot(wi, h.n) * h.n.z - wi.z }
					: wt;
				}

				//UNREACHABLE();
				return double3{ 0,0,0 }; 
			}();


			// Update throughput
			th = double3{ th.x*h.sphere->R.x, th.y*h.sphere->R.y ,th.z*h.sphere->R.z };
			if (th.x > th.y&&th.x > th.z&&th.x == 0) {

				break;
			}
			if (th.y > th.x&&th.y > th.z&&th.y == 0) {

				break;
			}
			if (th.z > th.x&&th.z > th.y&&th.z == 0) {

				break;
			}
		}

		d_Result[id] = double3{ (d_Result[id].x + L.x / spp), (d_Result[id].y + L.y / spp), (d_Result[id].z + L.z / spp) };
	}

}

// main function
int cudafunction(void)
{

	int start = clock();

	// デバイス(GPU)側の領域確保
	cudaMalloc(&d_Result, width*height * sizeof(double3));
	

	// CPU⇒GPUのデータコピー
	cudaMemcpy(d_Result, h_Result, width*height * sizeof(double3), cudaMemcpyHostToDevice);
	

	dim3 grid(75, 50);//グリッド
	dim3 block(16, 16, 1);//ブロック 16の倍数がいいらしい



	// GPUで計算
	gpu_function << <grid, block >> > (d_Result);

	// GPU⇒CPUのデータコピー
	cudaMemcpy(h_Result, d_Result, width*height * sizeof(double3), cudaMemcpyDeviceToHost);

	int end = clock();

	cudaFree(d_Result);

	std::ofstream ofs("result.ppm");
	ofs << "P3\n" << width << " " << height << "\n255\n";
	for (const auto& i : h_Result) {
		ofs << tonemap(i.x) << " "
			<< tonemap(i.y) << " "
			<< tonemap(i.z) << "\n";
	}

	return end-start;
}

