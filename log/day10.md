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

## 1MB 어드레스와 A20 게이트

### A20 게이트의 의미와 용도

![A20 게이트](https://img1.daumcdn.net/thumb/R720x0.q80/?scode=mtistory2&fname=http%3A%2F%2Fcfs13.tistory.com%2Fimage%2F27%2Ftistory%2F2008%2F12%2F28%2F17%2F41%2F49573bb2acd45)

* 초창기 XT PC는 1MB 어드레스까지만 접근 가능했으나 AT PC에서 16MB 이상의 메모리를 사용할 수 있게 되면서 호환성을 위해 A20 게이트를 궁여지책으로 도입

* A20 게이트의 의미 메모리 어드레스 주소의 20번째 비트를 활성화/비활성화
    * 20번째 비트를 0으로 만들면 어드레스 주소는 항상 1MB 이내의 주소 영역만 가리키게 됨(XT PC와 호환)
    * 초기 BIOS에서 A20 게이트를 비활성화 하면 홀수 MB에는 접근이 불가능함

### A20 게이트 활성화 방법

1. 키보드 컨트롤러로 활성화
2. 시스템 컨트롤 포트로 활성화
3. BIOS 서비스로 활성화

#### 시스템 컨트롤 포트로 A20 게이트 활성화하기

* 시스템 컨트롤 포트는 I/O 포트 어드레스의 0x92에 위치

* 시스템 컨트롤 포트의 각 비트와 의미
    * 7, 6 : (읽기와 쓰기)하드디스크 LED 제어, 모두 0으로 설정하면 LED가 꺼지며 그 외의 경우는 켜짐
    * 5, 4 : 사용하지 않음
    * 3 : (읽기와 쓰기)부팅 패스워드 접근 제어, 1로 설정하면 전원을 다시 인가할 때까지 CMOS 레지스터(0x38~0x3F)에 설정된 부팅 패스워드를 삭제 불가능하며 0으로 설정하면 부팅 패스워드 삭제 가능
    * 2 : (읽기 전용)사용하지 않음
    * 1 : (읽기와 쓰기)A20 게이트 제어
    * 0 : (쓰기 전용)빠른 시스템 리셋, 1로 설정하면 시스템 리셋(리얼 모드로 전환)을 수행하며 0이면 아무런 변화 없음

```assembly
in al, 0x92     ; 시스템 컨트롤 포트(0x92)에서 1바이트를 읽어 AL 레지스터에 저장
or al, 0x02     ; 읽은 값에 A20 게이트 비트(비트 1)를 1로 설정
and al, 0xFE    ; 시스템 리셋 방지를 위해 0xFE와 AND 연산하여 비트 0을 0으로 설정
out 0x92, al    ; 시스템 컨트롤 포트(0x92)에 변경된 값을 1바이트 설정
```

##### 주변장치 I/O에 있어서 메모리 맵 I/O 방식과 포트 맵 I/O 방식

* 메모리 맵 : 물리 메모리 어드레스를 I/O 용도로 할당 - mov 명령어 사용, 프로세서 캐시를 사용하면 문제를 일으킴
* 포트 맵 : 물리 메모리 어드레스와 별개로 I/O 전용 어드레스를 할당하는 방식 - in/out 명령어 사용
* x86 계열 프로세서에서는 2가지 방식 모두 지원함

#### BIOS 서비스로 A20 게이트 활성화 방법

* A20 게이트 관련 설정을 AX 레지스터에 넣고 나서 A20 게이트를 활성화하는 BIOS의 시스템 서비스(인터럽트 벡터 0x15) 호출

```assembly
mov ax, 0x2401      ; A20 게이트 활성화 서비스 설정
int 0x15            ; BIOS 인터럽트 서비스 호출

jc .A20GATEERROR    ; A20 게이트가 활성화가 성공했는지 확인 - 활성화가 실패하면 EFLAGS 레지스터의 CF 비트가 1로 설정되므로 이를 검사
jmp .A20GATESUCCESS ; 

.A20GATEERROR
    (에러 처리)

.A20GATESUCCESS
    (성공 처리)
```

## A20 게이트 적용과 메모리 크기 검사

### A20 게이트 활성화 코드 적용

* BIOS 서비스를 실행하고 BIOS 서비스가 실패할 경우 시스템 컨트롤 포트를 사용하는 순서로 적용

```assembly
[ORG 0x00]          ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]           ; 이하의 코드는 16비트 코드로 설정

SECTION .text       ; text 섹션(세그먼트)을 정의

; 코드 영역
START:
    mov ax, 0x1000  ; 보호 모드 엔트리 포인트의 시작 어드레스(0x10000)를 세그먼트 레지스터 값으로 변환
    mov ds, ax      ; DS 세그먼트 레지스터에 설정
    mov es, ax      ; ES 세그먼트 레지스터에 설정

    ; A20 게이트 활성화 - BIOS 이용한 전환이 실패했을 때 시스템 컨트롤 포트로 전환 시도
    mov ax, 0x2401  ; A20 게이트 활성화 서비스 설정
    int 0x15        ; BIOS 인터럽트 서비스 호출
    
    jc .A20GATEERROR    ; A20 게이트가 활성화가 성공했는지 확인 - 활성화가 실패하면 EFLAGS 레지스터의 CF 비트가 1로 설정되므로 이를 검사
    jmp .A20GATESUCCESS ; 

.A20GATEERROR:
    ; 에러 발생 시, 시스템 컨트롤 포트로 전환 시도
    in al, 0x92     ; 시스템 컨트롤 포트(0x92)에서 1바이트를 읽어 AL 레지스터에 저장
    or al, 0x02     ; 읽은 값에 A20 게이트 비트(비트 1)를 1로 설정
    and al, 0xFE    ; 시스템 리셋 방지를 위해 0xFE와 AND 연산하여 비트 0을 0으로 설정
    out 0x92, al    ; 시스템 컨트롤 포트(0x92)에 변경된 값을 1바이트 설정

.A20GATESUCCESS:
    cli             ; 인터럽트가 발생하지 못 하도록 설정
    lgdt [ GDTR ]   ; GDTR 자료구조를 프로세서에 설정하여 GDT 테이블을 로드

    ; 보호 모드로 진입
    mov eax, 0x4000003B ; PG=0, CD=1, NW=0, AM=0, WP=0, NE=1, ET=1, TS=1, EM=0, MP=1, PE=1
    mov cr0, eax        ; CR0 컨트롤 레지스터에 위해서 저장한 플래그를 설정하여 보호 모드로 전환

    ; 커널 코드 세그먼트를 0x00을 기준으로 하는 것으로 교체하고 EIP의 값을 0x00을 기준으로 재설정
    ; CS 세그먼트 셀렉터 - EIP
    jmp dword 0x08: (PROTECTMODE - $$ + 0x10000 )

; 보호 모드로 진입
```

### 메모리 크기 검사 기능 추가

* 사용 가능한 메모리를 검사하는 가장 확실한 방법은 메모리에 특정 값을 쓰고 다시 읽어서 같은 값이 나오는지 확인한느 것
    * MINT64 OS에서는 1MB 단위로 어드레스를 증가시키면서 각 MB의 첫 번째 4바이트에 0x12345678을 쓰고 읽어보기

```c
#include "Types.h"

// 함수 선언
void kPrintString( int iX, int iY, const char* pcString );
BOOL kInitializeKernel64Area( void );
BOOL kIsMemoryEnough( void );

// 아래 함수는 C 언어 커널의 시작 부분
void Main( void )
{
    DWORD i;
    
    kPrintString( 0, 3, "C Language Kernel Start.....................[Pass]" );

    // 최소 메모리 크기를 만족하는지 검사
    kPrintString( 0, 4, "Minimum Memory Size Check...................[    ]" );
    if( kIsMemoryEnough() == FALSE )
    {
        kPrintString( 45, 4, "Fail" );
        kPrintString( 0, 5, "Not Enough Memory~!! MINT64 OS Requires Over 64Mbyte Memory~!!" );
        while( 1 );
    }
    else
    {
        kPrintString( 45, 4, "Pass");
    }

    // IA-32e 모드의 커널 영역을 초기화
    kPrintString( 0, 5, "IA-32e Kernel Area Initialize...............[    ]" );
    if( kInitializeKernel64Area() == FALSE )
    {
        kPrintString( 45, 5, "Fail" );
        kPrintString( 0, 6, "Kernel Area Initialization Fail~!!" );
        while( 1 );
    }
    else
    {
        kPrintString( 45, 5, "Pass");
    }

    while( 1 );
}

// 문자열을 X, Y 위치에 출력
void kPrintString( int iX, int iY, const char* pcString )
{
    CHARACTER* pstScreen = ( CHARACTER* ) 0xB8000;
    int i;

    // X, Y 좌표를 이용해서 문자열을 출력할 어드레스를 계산
    pstScreen += ( iY * 80 ) + iX;

    // NULL이 나올 떄까지 문자열 출력
    for( i = 0; pcString[i] != 0; i++ )
    {
        pstScreen[i].bCharacter = pcString[i];
    }
}

// IA-32e 모드용 커널 영역을 0으로 초기화
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

// MINT64 OS를 실행하기에 충분한 메모리를 가지고 있는지 체크
BOOL kIsMemoryEnough( void )
{
    DWORD* pdwCurrentAddress;

    // 0x100000(1MB)부터 검사 시작
    pdwCurrentAddress = ( DWORD* ) 0x100000;

    // 0x4000000(64MB)까지 루프를 돌면서 확인
    while( ( DWORD ) pdwCurrentAddress < 0x4000000 )
    {
        *pdwCurrentAddress = 0x12345678;

        // 0x12345678로 저장한 후 다시 읽었을 때 0x12345678이 나오지 않으면 해당 어드레스를 사용하는 데 문제가 생긴 것이므로 바로 종료
        if( *pdwCurrentAddress != 0x12345678 )
        {
            return FALSE;
        }

        // 1MB씩 이동하면서 확인
        pdwCurrentAddress += ( 0x100000 / 4 );
    }
    return TRUE;
}
