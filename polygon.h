#pragma once

class CPolygon{

private:
	int m_Texture;

public:
	void Init(int cnt);
	void Uninit();
	void Update();
	void Draw();
};