
#include "main.h"



unsigned int LoadTexture( const char *FileName )
{
	unsigned int	texture;
	
	unsigned char* image;
	FILE* file;
	unsigned int	width, height;
	
	file = fopen(FileName, "rb");
	assert(file);

	// �摜�T�C�Y�擾
	width = 1200;
	height = 800;

    char buff[128];                             // �w�b�_���o�p
	int r = 0;
	int g = 0;
	int b = 0;
	// �������m��
	image = new unsigned char[width * height * 4];

	fgets(buff,20,file);                        // �t�@�C���̎��ʕ�����ǂݍ���
	fgets(buff, 20, file);                       // �摜�T�C�Y�̓ǂݍ���
	fgets(buff, 20, file);                   // �ő�P�x�l�̓ǂݍ���

	// �摜�ǂݍ���
	for (unsigned int y = 0; y < height; y++)
	{
		for (unsigned int x = 0; x < width; x++)
		{
			fscanf(file, "%d %d %d", &r, &g, &b);
			image[(y * width + x) * 4 + 0] = r;
			image[(y * width + x) * 4 + 1] = g;
			image[(y * width + x) * 4 + 2] = b;
			image[(y * width + x) * 4 + 3] = 255;
		}
	}

	fclose(file);
	
	// �e�N�X�`������
	glGenTextures( 1, &texture );
	glBindTexture( GL_TEXTURE_2D, texture );

	glPixelStorei( GL_UNPACK_ALIGNMENT, 1 );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, image );

	glBindTexture( GL_TEXTURE_2D, 0 );

	// ���������
	delete[] image;

	return texture;
}



void UnloadTexture( unsigned int Texture )
{
	glDeleteTextures( 1, &Texture );
}