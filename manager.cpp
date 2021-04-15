
#include "main.h"
#include "manager.h"
#include "renderer.h"
#include "polygon.h"
#include "cudaMain.cuh"
#include <mutex>

CPolygon* g_Polygon;
int cnt = 0;
void CManager::Init()
{

	CRenderer::Init();
	g_Polygon = new CPolygon();
	g_Polygon->Init(cnt);

}

void CManager::Uninit()
{
	CRenderer::Uninit();
	g_Polygon->Uninit();
	delete g_Polygon;
}

void CManager::Update()
{
	if (cnt ==1) {
		int time = cudafunction();
		g_Polygon = new CPolygon();
		g_Polygon->Init(cnt);
		char s[50];
		sprintf(s, "%d\n", time);
		LPCTSTR a = s;
		OutputDebugString(a);
	}
	cnt++;
}

void CManager::Draw()
{

	CRenderer::Begin();
	g_Polygon->Draw();

	CRenderer::End();

}
