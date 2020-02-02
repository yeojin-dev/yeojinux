# 키보드 디바이스 드라이버를 추가하자

## 키보드 컨트롤러의 구조와 기능

### 키보드 컨트롤러, I/O 포트, 레지스터

* 키보드 컨트롤러는 PC 내부 버스(BUS)와 포드 I/O 방식으로 연결되어 있으며, 포트 어드레스는 0x60, 0x64를 사용
    * 할당된 포트는 2개지만 포트에서 데이터를 일글 때와 쓸 때 접근하는 레지스터가 다르기 때문에 레지스터 입장에서는 4개가 연결된 것과 같음

![키보드와 마우스, 키보드 컨트롤러, PC의 관계](https://img1.daumcdn.net/thumb/R800x0/?scode=mtistory2&fname=https%3A%2F%2Ft1.daumcdn.net%2Fcfile%2Ftistory%2F2539BE455868ECCA38)

* I/O 포트와 키보드 컨트롤러 레지스터의 관계

|포트 번호|읽기/쓰기|레지스터 이름|설명|
|------|-------|----------|---|
|0x64|쓰기|컨트롤 레지스터|키보드 컨트롤러를 제어하는 레지스터|
|0x64|읽기|상태 레지스터|키보드 컨트롤러의 상태를 나타내는 레지스터|
|0x60|쓰기|입력 버퍼|프로세서가 키보드나 마우스로 보내는 커맨드 또는 데이터를 저장하는 레지스터|
|0x60|읽기|출력 버퍼|키보드나 마우스가 프로세서로 보내는 데이터를 저장하는 레지스터|

* 각 레지스터는 1바이트 크기

#### 상태 레지스터의 비트 구성과 의미

|비트|필드|설명|
|---|---|---|
|7|PARE|Parity Error의 약자로 키보드나 마우스로 온 마지막 데이터에 패리티 에러가 발생했음을 의미, 1로 설정되면 패리티 에러가 발생했음을 나타내며 0으로 설정되면 에러가 발생하지 않았음을 나타냄|
|6|TIM|General Time-Out의 약자로 키보드 또는 마우스가 정해진 시간에 응답하지 않았음을 의미, 1로 설정되면 타임 아웃이 발생했음을 나타내며 0으로 설정되면 발생하지 않았음을 의미|
|5|AUXB|출력 버퍼에 보조 디바이스(Auxiliary Device=마우스)의 데이터가 있음을 의미, 1로 설정되면 마우스 데이터임을 나타내며 0으로 나타내면 키보드 데이터임을 나타냄|
|4|KEYL|Keyboard Lock Status의 약자로 키보드가 잠겼는지(Lock) 여부를 설정, 1로 설정되면 잠겼음을 나타내며 0으로 설정되면 잠기지 않았음을 나타냄|
|3|C/D|Command/Data의 약자로 마지막으로 송신된 데이터의 종류를 의미, 1로 설정되면 마지막으로 송수신된 데이터가 커맨드(포트 Ox64)임을 나타내고, 0으로 설정되면 데이터(포트 0x60)임을 나타냄|
|2|SYSF|System Flag의 약자로 Self-Test가 정상적으로 끝났는지 여부를 의미, 1로 설정되면 Self-Test가 성공적으로 끝나서 사용 가능함을 나타내며, 0으로 설정되면 Power-On-Reset이 진행중임을 나타냄|
|1|INPB|Input Buffer State의 약자로 입력 버퍼에 프로세서가 쓴 데이터가 남아있는지 여부를 의미, 1로 설정되면 키보드 컨트롤러가 아직 입력 버퍼의 데이터를 가져가지 않았음을 나타내며 0으로 설정되면 컨트롤러가 데이터를 가져가서 키보드나 마우스로 전송하여 입력 버퍼가 비었음을 나타냄|
|0|OUTB|Output Buffer State의 약자로 출력 버퍼에 키보드 컨트롤러가 보낸 데이터가 남아있는지 여부를 의미, 1로 설정되면 키보드 컨트롤러가 키보드 또는 마우스에서 수신한 데이터가 출력 버퍼에 있음을 나타내며, 0으로 설정되면 프로세서가 데이터를 가져가서 출력 버퍼가 비어있음을 나타냄|

* 키보드 컨트롤러가 키 값을 얻는 것만 생각하면 상태 레지스터를 읽어서 OUTB 비트가 1인지 검사하고 나서 출력 버퍼 레지스터를 읽은 것만으로 충분하지만 키보드 컨트롤러를 제어할 때는 키보드 컨트롤러 커맨드로 제어

#### 키보드 컨트롤러 커맨드

|키보드 컨트롤러 커맨드|설명|
|----------------|---|
|0x20|키보드 컨트롤러의 커맨드 바이트를 출력 버퍼(포트 0x60)로 복사|
|0x60|입력 버퍼(포트 0x60)에 쓴 값을 키보드 컨트롤러의 커맨드 바이트로 복사, 비트 1을 1로 설정하면 마우스 인터럽트 활성화, 비트 0을 1로 설정하면 키보드 인터럽트 활성화|
|0xA7|마우스 디바이스 비활성화|
|0xA8|마우스 디바이스 활성화|
|0xAD|키보드 디바이스 비활성화|
|0xAE|키보드 디바이스 활성화|
|0xD0|키보드 컨트롤러의 출력 포트 값을 출력 버퍼(포트 0x60)로 복사|
|0xD1|입력 버퍼(0x60)에 쓴 값을 키보드 컨트롤러의 출력 포트로 복사, 비트 1을 1로 설정하면 A20 게이트 활성화, 비트 0을 0으로 설정하면 프로세서 리셋(PC 재부팅)|
|0xD4|입력 버퍼(포트 0x60)에 쓴 값을 마우스 디바이스로 송신|

## 키보드 컨트롤러 제어

### 키보드와 키보드 컨트롤러 활성화

* 부트 로더가 실행되기 이전에 BIOS에 의해 키보드 활성화하지만 직접 활성화시키기 위해서는 키보드 디바이스 활성화 커맨드 `0xAE` 전송 필요
    * 키보드 컨트롤러가 아닌 키보드를 활성화하기 위해서 입력 버퍼에 키보드로 보낼 커맨드를 써야만 함
    * 키보드가 정상적으로 처리한 경우 ACK(0xFA) 전송

#### LED와 키보드 활성화에 관련된 키보드 커맨드

|키보드 커맨드|설명|
|---------|---|
|0xED|키보드의 LED 상태를 변경, 비트 2를 1로 설정하면 Caps Lock 켜짐, 비트 1을 1로 설정하면 Num Lock 켜짐, 비트 0을 1로 설정하면 Scrool Lock 켜짐|
|0xF4|키보드 활성화|

* 키보드 컨트롤러는 CPU보다 매우 느리기 때문에 CPU 입장에서는 커맨드 전송 이후 매우 긴 시간을 기다려야 함
    * 키보드 컨트롤러의 상태 레지스터(포트 0x64)를 이용해 컨트롤러의 상태를 알 수 있음

```c
// 출력 버퍼(포트 0x60)에 수신된 데이터가 있는지 여부를 반환
BOOL kIsOutputBufferFull( void )
{
    // 상태 레지스터(포트 0x64)에서 읽은 값에 출력 버퍼 상태 비트(비트 0)가 1로 설정되어 있으면 출력 버퍼에 키보드가 전송한 데이터가 존재함
    if( kInPortByte( 0x64 ) & 0x01 )
    {
        return TRUE;
    }
    return FALSE;
}

// 입력 버퍼(포트 0x64)에 프로세서가 쓴 데이터가 남아있는지 여부를 반환
BOOL kIsInputBufferFull( void )
{
    // 상태 레지스터(포트 0x64)에서 읽은 값에 입력 버퍼 상태 비트(비트 1)가 1로 설정되어 있으면 아직 키보드가 데이터를 가져가지 않았음
    if( kInPortByte( 0x64 ) & 0x02 )
    {
        return TRUE;
    }
    return FALSE;
}

// 키보드 활성화
BOOL kActivateKeyboard( void )
{
    int i;
    int j;

    // 컨트롤 레지스터(포트 0x64)에 키보드 활성화 커맨드(0xAE)를 전달하여 키보드 디바이스 활성화
    kOutPortByte( 0x64, 0xAE );
    
    // 입력 버퍼(포트 0x60)가 빌 떄까지 기다렸다가 키보드에 활성화 커맨드를 전송
    // 0xFFFF만큼 루프를 수행할 시간이면 충분이 커맨드가 전송될 수 있음
    // 0xFFFF 루프를 수행한 이후에도 입력 버퍼(포트 0x60)가 비지 않으면 무시하고 전송
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        if( kIsInputBufferFull() == FALSE )
        {
            break;
        }
    }

    // 입력 버퍼(포트 0x60)로 키보드 활성화(0xF4) 커맨드를 전달하여 키보드로 전송
    kOutPortByte( 0x60, 0xF4 );

    // ACK 올 때까지 대기함
    // ACK가 오기 전에 키보드 출력 버퍼(포트 0x60)에 키 데이터가 저장될 수 있으므로 키보드에서 전달된 데이터를 최대 100개까지 수신하여 ACK를 확인
    for( j = 0 ; j < 100 ; j++ )
    {
        // 0xFFFF만큼 루프를 수행할 시간이면 충분히 커맨드의 응답이 올 수 있음
        // 0xFFFF 루프를 수행한 이후에도 출력 버퍼(0x60)가 차 있지 않으면 무시하고 읽음
        for( i = 0 ; i < 0xFFFF ; i++ )
        {
            if( kIsOutputBufferFull() == TRUE )
            {
                break;
            }
        }

        // 출력 버퍼(포트 0x60)에서 읽은 데이터가 ACK(0xFA)이면 성공
        if( kInPortByte( 0x60 ) == 0xFA )
        {
            return TRUE;
        }
    }
    return FALSE;
}
```

```assembly
; 포트로부터 1바이트를 읽음
; PARAM: 포트 번호
kInPortByte:
    push idx        ; 함수에서 임시로 사용하는 레지스터를 스택에 저장, 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 복원
    mov rdx, rdi    ; RDX 레지스터에 파라미터 1(포트 번호)를 저장
    mov rax, 0      ; RAX 레지스터를 초기화
    in al, dx       ; DX 레지스터에 저장된 포트 어드레스에서 한 바이트를 읽어 AL 레지스터에 저장, AL 레지스터는 함수의 반환 값으로 사용됨
    pop rdx         ; 함수에서 사용이 끝난 레지스터를 복원
    ret             ; 함수를 호출한 다음 코드의 위치로 복귀

; 포트에 1바이트를 씀
; PARAM: 포트 번호, 데이터
kOutPortByte:
    push rdx        ; 함수에서 임시로 사용하는 레지스터를 스택에 저장
    push rax        ; 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 복원
    mov rdx, rdi    ; RDX 레지스터에 파리미터 1(포트 번호)를 저장
    mov rax, rsi    ; RAX 레지스터에 파라미터 2(데이터)를 저장
    out dx, al      ; DX 레지스터에 저장된 포트 어드레스에 AL 레지스터에 저장된 한 바이트를 씀
    pop rax         ; 함수에서 사용이 끝난 레지스터를 복원
    pop rdx
    ret
```

### IA-32e 모드의 호출 규약

* IA-32e 모드의 C 호출 규약과 보호 모드의 C 호출 규약 비교

1. 파라미터를 전달할 때 레지스터를 우선 사용 : 정수 데이터의 경우 RDI, RSI, RDX, RCX, R8, R9 레지스터의 순서로 6개를 사용하며 실수의 경우에는 XMM0~7 레지스터의 순서로 모두 8개 사용, 파라미터 수가 정해진 레지스터의 수를 넘으면 보호 모드와 마찬가지로 스택 영역을 사용

2. 레지스터 또는 스택에 파라미터를 삽입하는 순서 : 보호 모드에서는 파라미터 리스트의 오른쪽에서 왼쪽으로 이동하면서 파라미터를 스택에 삽입한 것과 달리 64비트 모드에서는 파라미터 리스트의 왼쪽에서 오른쪽으로 이동하면서 레지스터나 스택을 사용해 삽입

3. 함수의 반환 값으로 사용하는 레지스터 : 보호 모드는 EAX 레지스터를 사용하여 반환 값 처리하지만 64비트 모드는 정수 타입이면 RAX, RDX 레지스터 사용하고 실수 타입은 XMM0 또는 XMM0, XMM1 레지스터 사용

* 비교적 스택을 덜 사용하는 구조로 변환함

### 키보드 컨트롤러에서 키 값 읽기

* 스캔 코드 : 키보드 키가 눌리거나 떨어질 때마다 키 별로 할당된 특수한 값, 이를 키보드 컨트롤러에 저장함
* 별다른 커맨드를 키보드 컨트롤러로 보내지 않으면, 키보드 컨트롤러의 출력 버퍼에는 키보드 또는 마우스에서 수신된 데이터 저장
    * 상태 레지스터를 읽어서 출력 버퍼에 데이터가 있는지 확인한 후, 데이터가 있다면 출력 버퍼를 읽어서 저장

```c
BYTE kGetKeyboardScanCode( void )
{
    while( kIsOutputBufferFull() == FALSE )
    {
        ;
    }
    return kInPortByte( 0x60 );  // 출력 버퍼(포트 0x60에서 키 값(스캔 코드)를 읽어서 반환)
}
```

### A20 게이트 활성화와 프로세스 리셋

* A20 게이트 비트와 프로세서 리셋 비트는 출력 포트의 비트 1과 비트 0에 있고 키보드 컨트롤러의 출력 포트는 0xD0, 0xD1 커맨드로 접근 가능

```c
void kEnableA20Gate( void )
{
    BYTE bOutputPortData;
    int i;

    // 컨트롤 레지스터(포트 0x64)에 키보드 컨트롤러의 출력 포트 값을 읽는 커맨드(0xD0) 전송
    kOutPortByte( 0x64, 0xD0 );

    // 출력 포트의 데이터를 기다렸다가 읽음
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        if( kIsOutputBufferFull() == TRUE )
        {
            break;
        }
    }
    bOutputPortData = kInPortByte( 0x60 );

    // A20 게이트 비트 설정
    bbOutputPortData != 0x02;

    // 입력 버퍼(포트 0x60)에 데이터가 비어있으면 출력 포트에 값을 쓰는 커맨드와 출력 포트 데이터 전송
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        if( kIsInputBufferFull() == FALSE )
        {
            break;
        }
    }

    // 커맨드 레지스터(0x64)에 출력 포트 설정 커맨드(0xD1) 전달
    kOutPortByte( 0x64, 0xD1 );
    // 입력 버퍼(0x60)에 A20 게이트 비트가 1로 설정된 값을 전달
    kOutPortByte( 0x60, bOutputPortData )
}
```

### 키보드 LED 상태 제어

* LED 상태를 변경하는 방법은 커맨드 포트를 사용하지 않고 입력 버퍼만을 사용

1. 입력 버퍼(0x60)로 0xED 커맨드를 전송해서 키보드에 LED 상태 데이터가 전송될 것임을 미리 알림
2. ACK를 확인하고 나서 LED 상태를 나타내는 데이터를 전송
3. LED 상태를 나타내는 데이터 전송
4. 키보도를 데이터를 전송하고 나서 확인

* LED 상태 데이터는 1바이트 중 하위 3비트만 사용하며 Caps Lock은 비트 2, Num Lock은 비트 1, Scroll Lock은 비트 0에 할당되어 있음

```c
BOOL kChangeKeyboardLED( BOOL bCapsLockOn, BOOL bNumLockOn, BOOL bScrollLockOn )
{
    int i, j;
    // 키보드에 LED 변경 커맨드 전송하고 커맨드가 처리될 떄까지 대기
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        // 입력 버퍼(0x60)가 비었으면 커맨드 전송 가능
        if( kIsInputBufferFull() == FALSE )
        {
            break;
        }
    }

    // 입력 버퍼(포트 0x60)로 LED 상태 변경 커맨드(0xED) 전송
    kOutPortByte( 0x60, 0xED );
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        // 입력 버퍼(포트 0x60)가 비어 있으면 키보드가 커맨드를 가져간 것임
        if( kIsInputBufferFull() == FALSE )
        {
            break;
        }
    }

    // 키보드가 LED 상태 변경 커맨드를 가져갔으므로 ACK가 올 떄까지 대기
    for( j = 0 ; j < 100 ; j++ )
    {
        for( i = 0 ; i < 0xFFFF ; i++ )
        {
            // 출력 버퍼(포트 0x60)가 차 있으면 데이터를 읽을 수 있음
            if( kIsOutputBufferFull() == TRUE )
            {
                break;
            }
        }

        // 출력 버퍼(포트 0x60)에서 가져온 데이터가 ACK(0xFA)이면 성공
        if( kInPortByte( 0x60 ) == 0xFA )
        {
            break;
        }
    }

    if( j >= 100 )
    {
        return FALSE;
    }

    // LED 변경 값을 키보드로 전송하고 데이터가 처리가 완료될 떄까지 대기
    kOutPortByte( 0x60, ( bCapsLockOn << 2 ) | ( bNumLockOn << 1 ) | bScrollLockOn );
    for( i = 0 ; i < 0xFFFF ; i++ )
    {
        // 입력 버퍼(포트 0x60)가 비어 있으면 키보드가 커맨드를 가져간 것임
        if( kIsInputBufferFull() == FALSE )
        {
            break;
        }
    }

    // 키보드가 LED 데이터를 가져갔으므로 ACK가 올 떄까지 대기
    for( j = 0 ; j < 100 ; j++ )
    {
        for( i = 0 ; i < 0xFFFF ; i++ )
        {
            // 출력 버퍼(포트 0x60)가 차 있으면 데이터를 읽을 수 있음
            if( kIsOutputBufferFull() == TRUE )
            {
                break;
            }
        }

        // 출력 버퍼(포트 0x60)에서 읽은 데이터가 ACK(0xFA)이면 성공
        if( kInPortByte( 0x60 ) == 0xFA )
        {
            break;
        }
    }

    if( j >= 100 )
    {
        return FALSE;
    }

    return TRUE;
}
```

## 스캔 코드와 간단한 셸

* 수신한 데이터를 ASCII 코드로 변환

### 키보드와 스캔 코드

* 스캔 코드는 키가 눌리거나 떨어질 때마다 그 상태에 해당하는 키 값을 키보드 컨트롤러로 전송
* 일반적으로 떨어졌을 때 키 값은 눌러졌을 때의 값에 최상위 비트(비트 7)을 1로 설정한 값
* 스캔 코드와 아스키 코드는 서로 다르기 때문에 이를 치환해주어야 함

![스캔 코드](https://img1.daumcdn.net/thumb/R800x0/?scode=mtistory2&fname=https%3A%2F%2Ft1.daumcdn.net%2Fcfile%2Ftistory%2F2657C23A56B5EA873B)

### 스캔 코드를 아스키 문자로 변환

```c
typedef struct kKeyMappingEntryStruct
{
    // Shift 키나 Caps Lock 키와 조합되지 않는 아스키 코드
    BYTE bNormalCode;

    // Shift 키나 Caps Lock 키와 조합된 아스키 코드
    BYTE bCombinedCode; 
} KEYMAPPINGENTRY;
```

```c
// 스캔 코드를 ASCII 코드로 변환하는 테이블
static KEYMAPPINGENTRY gs_vstKeyMappingTable[ KEY_MAPPINGTABLEMAXCOUNT ] =
{
    /*  0   */  {   KEY_NONE        ,   KEY_NONE        },
    /*  1   */  {   KEY_ESC         ,   KEY_ESC         },
    /*  2   */  {   '1'             ,   '!'             },
    /*  3   */  {   '2'             ,   '@'             },
    /*  4   */  {   '3'             ,   '#'             },
    /*  5   */  {   '4'             ,   '$'             },
    /*  6   */  {   '5'             ,   '%'             },
    /*  7   */  {   '6'             ,   '^'             },
    /*  8   */  {   '7'             ,   '&'             },
    /*  9   */  {   '8'             ,   '*'             },
    /*  10  */  {   '9'             ,   '('             },
    /*  11  */  {   '0'             ,   ')'             },
    /*  12  */  {   '-'             ,   '_'             },
    /*  13  */  {   '='             ,   '+'             },
    /*  14  */  {   KEY_BACKSPACE   ,   KEY_BACKSPACE   },
    /*  15  */  {   KEY_TAB         ,   KEY_TAB         },
    /*  16  */  {   'q'             ,   'Q'             },
    /*  17  */  {   'w'             ,   'W'             },
    /*  18  */  {   'e'             ,   'E'             },
    /*  19  */  {   'r'             ,   'R'             },
    /*  20  */  {   't'             ,   'T'             },
    /*  21  */  {   'y'             ,   'Y'             },
    /*  22  */  {   'u'             ,   'U'             },
    /*  23  */  {   'i'             ,   'I'             },
    /*  24  */  {   'o'             ,   'O'             },
    /*  25  */  {   'p'             ,   'P'             },
    /*  26  */  {   '['             ,   '{'             },
    /*  27  */  {   ']'             ,   '}'             },
    /*  28  */  {   '\n'            ,   '\n'            },
    /*  29  */  {   KEY_CTRL        ,   KEY_CTRL        },
    /*  30  */  {   'a'             ,   'A'             },
    /*  31  */  {   's'             ,   'S'             },
    /*  32  */  {   'd'             ,   'D'             },
    /*  33  */  {   'f'             ,   'F'             },
    /*  34  */  {   'g'             ,   'G'             },
    /*  35  */  {   'h'             ,   'H'             },
    /*  36  */  {   'j'             ,   'J'             },
    /*  37  */  {   'k'             ,   'K'             },
    /*  38  */  {   'l'             ,   'L'             },
    /*  39  */  {   ';'             ,   ':'             },
    /*  40  */  {   '\''            ,   '\"'            },
    /*  41  */  {   '`'             ,   '~'             },
    /*  42  */  {   KEY_LSHIFT      ,   KEY_LSHIFT      },
    /*  43  */  {   '\\'            ,   '|'             },
    /*  44  */  {   'z'             ,   'Z'             },
    /*  45  */  {   'x'             ,   'X'             },
    /*  46  */  {   'c'             ,   'C'             },
    /*  47  */  {   'v'             ,   'V'             },
    /*  48  */  {   'b'             ,   'B'             },
    /*  49  */  {   'n'             ,   'N'             },
    /*  50  */  {   'm'             ,   'M'             },
    /*  51  */  {   ','             ,   '<'             },
    /*  52  */  {   '.'             ,   '>'             },
    /*  53  */  {   '/'             ,   '?'             },
    /*  54  */  {   KEY_RSHIFT      ,   KEY_RSHIFT      },
    /*  55  */  {   '*'             ,   '*'             },
    /*  56  */  {   KEY_LALT        ,   KEY_LALT        },
    /*  57  */  {   ' '             ,   ' '             },
    /*  58  */  {   KEY_CAPSLOCK    ,   KEY_CAPSLOCK    },
    /*  59  */  {   KEY_F1          ,   KEY_F1          },
    /*  60  */  {   KEY_F2          ,   KEY_F2          },
    /*  61  */  {   KEY_F3          ,   KEY_F3          },
    /*  62  */  {   KEY_F4          ,   KEY_F4          },
    /*  63  */  {   KEY_F5          ,   KEY_F5          },
    /*  64  */  {   KEY_F6          ,   KEY_F6          },
    /*  65  */  {   KEY_F7          ,   KEY_F7          },
    /*  66  */  {   KEY_F8          ,   KEY_F8          },
    /*  67  */  {   KEY_F9          ,   KEY_F9          },
    /*  68  */  {   KEY_F10         ,   KEY_F10         },
    /*  69  */  {   KEY_NUMLOCK     ,   KEY_NUMLOCK     },
    /*  70  */  {   KEY_SCROLLLOCK  ,   KEY_SCROLLLOCK  },

    /*  71  */  {   KEY_HOME        ,   '7'             },
    /*  72  */  {   KEY_UP          ,   '8'             },
    /*  73  */  {   KEY_PAGEUP      ,   '9'             },
    /*  74  */  {   '-'             ,   '-'             },
    /*  75  */  {   KEY_LEFT        ,   '4'             },
    /*  76  */  {   KEY_CENTER      ,   '5'             },
    /*  77  */  {   KEY_RIGHT       ,   '6'             },
    /*  78  */  {   '+'             ,   '+'             },
    /*  79  */  {   KEY_END         ,   '1'             },
    /*  80  */  {   KEY_DOWN        ,   '2'             },
    /*  81  */  {   KEY_PAGEDOWN    ,   '3'             },
    /*  82  */  {   KEY_INS         ,   '0'             },
    /*  83  */  {   KEY_DEL         ,   '.'             },
    /*  84  */  {   KEY_NONE        ,   KEY_NONE        },
    /*  85  */  {   KEY_NONE        ,   KEY_NONE        },
    /*  86  */  {   KEY_NONE        ,   KEY_NONE        },
    /*  87  */  {   KEY_F11         ,   KEY_F11         },
    /*  88  */  {   KEY_F12         ,   KEY_F12         }
};
```

* 스캔 코드를 아스키로 변환하려면 Shift, Caps Lock, Num Lock 키 조합의 상태를 알고 있어야 함
* 확장 키의 경우 0xE0, 0xE1 코드가 먼저 도착하므로 이후 코드는 무시하여야 함

```c
// 키보드의 키 상태를 관리하는 자료구조
typedef struct kKeyboardManagerStruct
{
    // 조합 키 정보
    BOOL bShiftDown;
    BOOL bCapsLockOn;
    BOOL bNumLockOn;
    BOOL bScrollLockOn;

    // 확장 키를 관리하기 위한 정보
    BOOL bExtendedCodeIn;
    int iSkipCountForPause;

} KEYBOARDMANAGER;
```

* 조합된 키를 선택해야 하는지 여부를 반환하는 함수 추가

```c
// 조합된 키 값을 사용해야 하는지 여부 반환
BOOL kIsUseCombinedCode( BYTE bScanCode )
{
    BYTE bDownScanCode;
    BOOL bUseCombinedKey = FALSE;

    bDownScanCode = bScanCode & 0x7F;  // 최상위 비트 체크

    // 알파벳 키라면 Shift 키와 Caps Lock 키의 영향을 받음
    if( kIsAlphabetScanCode( bDownScanCode ) == TRUE )
    {
        // 만약 Shift 키와 Caps Lock 키 중에 하나만 눌러져있으면 조합된 키를 되돌려 줌
        if( gs_stKeyboardManager.bShiftDown ^ gs_stKeyboardManager.bCapsLockOn )
        {
            bUseCombinedKey = TRUE;          
        }
        else
        {
            bUseCombinedKey = FALSE;
        }
    }
    // 숫자와 기호 키라면 Shift 키의 영향을 받음
    else if( kIsNumberOrSymbolScanCode( bDownScanCode ) == TRUE )
    {
        // Shift 키가 눌려져 있으면 조합된 키를 되돌려 줌
        if( gs_stKeyboardManager.bShiftDown == TRUE )
        {
            bUseCombinedKey = TRUE;          
        }
        else
        {
            bUseCombinedKey = FALSE;
        }
    }  
    // 숫자 패드 키라면 Num Lock 키의 영향을 받음
    // 0xE0만 제외하면 확장 키 코드와 숫자 패드의 코드가 겹치므로 확장 키 코드가 수신되지 않았을 때만 조합된 코드 사용
    else if( ( kIsNumberPadScanCode( bDownScanCode ) == TRUE ) && ( gs_stKeyboardManager.bExtendedCodeIn == FALSE ) )
    {
        // Num Lock 키가 눌러져있으면, 조합된 키를 되돌려 줌
        if( gs_stKeyboardManager.bNumLockOn == TRUE )
        {
            bUseCombinedKey = TRUE;
        }
        else
        {
            bUseCombinedKey = FALSE;
        }
    }

    return bUseCombinedKey;
}

// 스캔 코드가 알파벳 범위인지 여부를 반환
BOOL kIsAlphabetScanCode( BYTE bScanCode )
{
    // 변환 테이블을 값을 직접 읽어서 알파벳 범위인지 확인
    if( ( 'a' <= gs_vstKeyMappingTable[ bScanCode ].bNormalCode ) &&
        ( gs_vstKeyMappingTable[ bScanCode ].bNormalCode <= 'z' ) )
    {
        return TRUE;
    }
    return FALSE;
}

// 숫자 또는 기호 범위인지 여부를 반환
BOOL kIsNumberOrSymbolScanCode( BYTE bScanCode )
{
    // 숫자 패드나 확장 키 범위를 제외한 범위(스캔 코드 2~53)에서 영문자가 아니면
    // 숫자 또는 기호임
    if( ( 2 <= bScanCode ) && ( bScanCode <= 53 ) && ( kIsAlphabetScanCode( bScanCode ) == FALSE ) )
    {
        return TRUE;
    }
    return FALSE;
}

// 숫자 패드 범위인지 여부를 반환
BOOL kIsNumberPadScanCode( BYTE bScanCode )
{
    // 숫자 패드는 스캔 코드의 71~83에 있음
    if( ( 71 <= bScanCode ) && ( bScanCode <= 83 ) )
    {
        return TRUE;
    }

    return FALSE;
}
```

* 스캔 코드가 조합 키나 LED 상태 변경이 필요한 키일 때 이를 처리하는 함수 구현

```
void UpdateCombinationKeyStatusAndLED( BYTE bScanCode )
{
    BOOL bDown;
    BYTE bDownScanCode;
    BOOL bLEDStatusChanged = FALSE;

    // 눌림 또는 떨어짐 상태처리, 최상위 비트(비트 7)가 1이면 키가 떨어졌음을 의미하고
    // 0이면 떨어졌음을 의미함
    if( bScanCode & 0x80 )
    {
        bDown = FALSE;
        bDownScanCode = bScanCode & 0x7F;
    }
    else
    {
        bDown = TRUE;
        bDownScanCode = bScanCode;
    }

    // 조합 키 검색
    // Shift 키의 스캔 코드(42 or 54)이면 Shift 키의 상태 갱신
    if( ( bDownScanCode == 42 ) || ( bDownScanCode == 54 ) )
    {
        gs_stKeyboardManager.bShiftDown = bDown;
    }
    // Caps Lock 키의 스캔 코드(58)이면 Caps Lock의 상태 갱신하고 LED 상태 변경
    else if( ( bDownScanCode == 58 ) && ( bDown == TRUE ) )
    {
        gs_stKeyboardManager.bCapsLockOn ^= TRUE;
        bLEDStatusChanged = TRUE;
    }
    // Num Lock 키의 스캔 코드(69)이면 Num Lock의 상태를 갱신하고 LED 상태 변경
    else if( ( bDownScanCode == 69 ) && ( bDown == TRUE ) )
    {
        gs_stKeyboardManager.bNumLockOn ^= TRUE;
        bLEDStatusChanged = TRUE;
    }
    // Scroll Lock 키의 스캔 코드(70)이면 Scroll Lock의 상태를 갱신하고 LED 상태 변경
    else if( ( bDownScanCode == 70 ) && ( bDown == TRUE ) )
    {
        gs_stKeyboardManager.bScrollLockOn ^= TRUE;
        bLEDStatusChanged = TRUE;
    }

    // LED 상태가 변했으면 키보드로 커맨드를 전송하여 LED를 변경
    if( bLEDStatusChanged == TRUE )
    {
        kChangeKeyboardLED( gs_stKeyboardManager.bCapsLockOn, gs_stKeyboardManager.bNumLockOn, gs_stKeyboardManager.bScrollLockOn );
    }
}
```

* 스캔 코드를 아스키 코드로 변환
    * 확장 키라는 것을 알려주는 스캔 코드(0xE0, 0xE1)을 받으면 다음 스캔 코드는 확장 키로서 처리하도록 알고리즘 구현
    * Shift, Caps Lock, Num Lock 역시 같은 형태로 구현 : 이전 코드가 눌림 상태의 스캔 코드인지 확인

```
// 스캔 코드를 ASCII 코드로 변환
BOOL kConvertScanCodeToASCIICode( BYTE bScanCode, BYTE* pbASCIICode, BOOL* pbFlags )
{
    BOOL bUseCombinedKey;

    // 이전에 Pause 키가 수신되었다면, Pause의 남은 스캔 코드를 무시
    if( gs_stKeyboardManager.iSkipCountForPause > 0 )
    {
        gs_stKeyboardManager.iSkipCountForPause--;
        return FALSE;
    }

    // Pause 키는 특별히 처리
    if( bScanCode == 0xE1 )
    {
        *pbASCIICode = KEY_PAUSE;
        *pbFlags = KEY_FLAGS_DOWN;
        gs_stKeyboardManager.iSkipCountForPause = KEY_SKIPCOUNTFORPAUSE;
        return TRUE;
    }
    // 확장 키 코드가 들어왔을 때, 실제 키 값은 다음에 들어오므로 플래그 설정만 하고 종료
    else if( bScanCode == 0xE0 )
    {
        gs_stKeyboardManager.bExtendedCodeIn = TRUE;
        return FALSE;
    }

    // 조합된 키를 반환해야 하는가?
    bUseCombinedKey = kIsUseCombinedCode( bScanCode );

    // 키 값 설정
    if( bUseCombinedKey == TRUE )
    {
        *pbASCIICode = gs_vstKeyMappingTable[ bScanCode & 0x7F ].bCombinedCode;
    }
    else
    {
        *pbASCIICode = gs_vstKeyMappingTable[ bScanCode & 0x7F ].bNormalCode;
    }

    // 확장 키 유무 설정
    if( gs_stKeyboardManager.bExtendedCodeIn == TRUE )
    {
        *pbFlags = KEY_FLAGS_EXTENDEDKEY;
        gs_stKeyboardManager.bExtendedCodeIn = FALSE;
    }
    else
    {
        *pbFlags = 0;
    }

    // 눌러짐 또는 떨어짐 유무 설정
    if( ( bScanCode & 0x80 ) == 0 )
    {
        *pbFlags |= KEY_FLAGS_DOWN;
    }

    // 조합 키 눌림 또는 떨어짐 상태를 갱신
    UpdateCombinationKeyStatusAndLED( bScanCode );
    return TRUE;
}
```

### 간단한 셸 구현

* 셸(Shell) : 사용자에게서 명령을 받아 작업을 수행하는 프로그램

* 입력된 스캔 코드를 변환하여 화면에 순차적으로 출력하는 기능 구현

```c
char vcTemp[ 2 ] = { 0, };
BYTE bFlags;
BYTE bTemp;
int i = 0;

while( 1 )
{
    // 출력 버퍼(포트 0x60)가 차 있으면 스캔 코드를 읽을 수 있음
    if( kIsOutputBufferFull() == TRUE )
    {
        // 출력 버퍼(포트 0x60)에서 스캔 코드를 읽어서 저장
        bTemp = kGetKeyboardScanCode();
        // 스캔 코드를 아스키 코드로 반환하는 함수를 호출하여 아스키 코드와 눌림 또는 떨어짐 정보를 반환
        if( kConvertScanCodeToASCIICode( bTemp, &( vcTemp[ 0 ] ), &bFlags ) == TRUE )
        {
            // 키가 눌러졌으면 키의 아스키 코드 값을 화면에 출력
            if( bFlags & KEY_FLAGS_DOWN )
            {
                kPrintString( i++, 13, vcTemp );
            }
        }
    }
}
```
