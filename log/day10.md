# A20 게이트를 활성화하여 1MB 이상 영역에 접근해보자

## IA-32e 모드 커널과 메모리 맵

![IA-32e 모드 커널과 메모리 맵](https://dongyeollee.github.io/images/OS/6/1.png)

* 1MB 이하의 어드레스 중 비디오 메모리 공간을 제외하면 사용 가능한 공간은 576KB 정도
    * 다양한 OS 기능을 생각했을 때 매우 작은 영역
    * 초기화되지 않는 .bss 섹션을 생각하면 가용 공간은 더 작아짐

* MINT64 OS에서는 IA-32e 모드 커널은 2MB 어드레스에 복사해 2~6MB 영역을 할당
    * 할당하기 전에 해당 영역을 모두 0으로 초기화
    * 커널 이미지에는 초기화되지 않은 영역을 포함하고 있으며 이 영역은 이미지에 제외되어 있기 때문에 쓰레기값이 사용될 수 있음

## IA-32e 모드 커널을 위한 메모리 초기화

### 메모리 초기화 기능 추가

* Main.c 파일에 아래와 같이 초기화 코드 추가

```c
void kPrintString( int iX, int iY, const char* pcString );
BOOL kInitializeKernel64Area( void );

void Main( void )
{
    DWORD i;

    kPrintString( 0, 3, "C Language Kernel Started~!!!");

    // IA-32e 모드의 커널 영역을 초기화
    kInitializeKernel64Area();
    kPrintString( 0, 4, "IA-32e Kernel Area Initialization Complete");

    while (1);  // 생략
}

BOOL kInitializeKernel64Area( void )
{
    DWORD* pdwCurrentAddress;

    // 초기화를 시작할 어드레스인 0x100000(1MB) 설정
    pdwCurrentAddress = ( DWORD* ) 0x100000;

    // 마지막 어드레스인 0x600000(6MB)까지 루프를 돌면서 4바이트씩 0으로 채움
    while( ( DWORD ) pdwCurrentAddress < 0x600000 )
    {
        *pdwCurrentAddress = 0x00;

        // 0으로 저장한 이후 다시 읽었을 때 0이 나오지 않으면 어드레스를 사용하는 데 문제가 생긴 것이므로 바로 종료
        if ( *pdwCurrentAddress != 0 )
        {
            return FALSE;
        }

        pdwCurrentAddress++;
    }
    return TRUE;
}
```

* 위 코드를 적용해도 실제로는 문제가 나타날 수 있는데 이는 PC가 하위 기종에 대한 호환성을 유지하기 위해 어드레스 라인을 비활성화했기 때문
