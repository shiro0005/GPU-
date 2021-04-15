#include "main.h"
#include "renderer.h"
#include "polygon.h"
#include "texture.h"

void  CPolygon::Init(int cnt) {
	
	if (cnt == 0) {
		m_Texture = LoadTexture("white.ppm");
	}
	else {
		m_Texture = LoadTexture("result.ppm");
	}
}

void CPolygon::Uninit()
{
	UnloadTexture(m_Texture);
}

void CPolygon::Update() {
	
	
}

void CPolygon::Draw() {

    //ライティング無効
	glDisable(GL_LIGHTING);


	//２D用マトリクスの設定
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(0, SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0, 1);

	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, m_Texture);
	
	//ポリゴン描画
	glBegin(GL_TRIANGLE_STRIP);

	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	glTexCoord2f(0.0f, 0.0f);
	glVertex3f(00.0f, 00.0f, 0.0f);

	// 各頂点で変更
	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	glTexCoord2f(0.0f, 1.0f);
	glVertex3f(00.0f, 800.0f, 0.0f);

	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	glTexCoord2f(1.0f, 0.0f);
	glVertex3f(1200.0f, 00.0f, 0.0f);

	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	glTexCoord2f(1.0f, 1.0f);
	glVertex3f(1200.0f, 800.0f, 0.0f);

	glEnd();

	glEnable(GL_LIGHTING);

	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}