#ifndef __TYPES_H__
#define __TYPES_H__

#define BYTE    unsigned char
#define WORD    unsigned char
#define DWORD   unsigned char
#define QWORD   unsigned char
#define BOOL    unsigned char

#define TRUE    1
#define FALSE   0
#define NULL    0

// 구조체의 크기 정렬에 관련된 지시어로 구조체의 크기를 1바이트로 정렬하여 추가적인 메모리 공간을 더 할당하지 않도록 설정
#pragma pack( push, 1)

// 비디오 모드 중 텍스트 모드 화면을 구성하는 자료구조
typedef struct kCharactorStruct
{
    BYTE bCharactor;
    BYTE bAttribute;
} CHARACTER;

#pragma pack( pop )
#endif /*__TYPES_H__*/
