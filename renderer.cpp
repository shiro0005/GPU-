
#include "main.h"
#include "renderer.h"
#include <io.h>



HWND	CRenderer::m_Wnd;
HGLRC	CRenderer::m_GLRC;
HDC		CRenderer::m_DC;

void CRenderer::Init()
{
	//ウィンドウハンドルの保存
	m_Wnd = GetWindow();

	//ピクセルフォーマット
		PIXELFORMATDESCRIPTOR pfd = {
			sizeof(PIXELFORMATDESCRIPTOR),1, PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,//Flags
			PFD_TYPE_RGBA, //The kind of framebuffer. RGBA or palette. 7/00lordept h of the framebuffer.
			32,
			0, 0, 0, 0, 0, 0,
			0,
			0,
			0,
			0,0,0,0,
			24, //Number of bits for the dept hbuffer 
			8,	//Number of bits for the stenciI buf fer 7
			0,	//Number of Aux buffers in the framebuffer.
			PFD_MAIN_PLANE,
			0,
			0, 0, 0
	};

		//Windowsデバイスコンテキスト取得
		m_DC = GetDC(m_Wnd);

		int pixelFormat = ChoosePixelFormat(m_DC, &pfd);
		SetPixelFormat(m_DC, pixelFormat, &pfd);


		//GLコンテキスト作成
		m_GLRC = wglCreateContext(m_DC);
		wglMakeCurrent(m_DC, m_GLRC);


		//OpenGL描画設定
		glEnable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_LIGHTING);
		glEnable(GL_TEXTURE_2D);
	

}

void CRenderer::Uninit()
{
	wglMakeCurrent(NULL, NULL);
	ReleaseDC(m_Wnd, m_DC);
	wglDeleteContext(m_GLRC);

}

void CRenderer::Begin()
{
	
	//画像クリア
	glClearColor(1.0f, 0.0f, 0.0f, 0.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

}

void CRenderer::End()
{
	//フロントバッファ・バックバッファ入れ替え
	SwapBuffers(m_DC);
}






