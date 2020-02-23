# GDT, IDT 테이블, TSS 세그먼트를 추가해 인터럽트에 대비하자

## 인터럽트와 예외

### 인터럽트와 예외의 차이점

* 인터럽트와 예외의 공통점은 코드 수행 도중에 발생하거나 프로세서에 의해 처리가 필요한 일종의 이벤트라는 점
    * 차이점 : 인터럽트는 키보드, 마우스, HDD와 같은 외부 디바이스에 의해 발생하여 프로세서에 전달되는 이벤트인 것에 반해 예외는 프로세서가 코드를 수행하는 도중에 페이지 폴트, 잘못된 명령과 같은 오류 발견 시 발생

* 예외 핸들러 : 인터럽트, 예외 이벤트에 대해 이벤트마다 필요한 특수 처리 함수로 인터럽트/예외 처리 후 발생 시점으로 복귀하도록 상태를 저장/복구하는 역할도 같이 수행해야만 함

### IDT와 IDT 게이트 디스크립터

* 프로세서는 외부 인터럽트나 소프트웨어 인터럽트가 발생했을 때 벡터 테이블의 인덱스에 해당하는 어드레스로 이동하여 처리 함수를 수행
    * 벡터 테이블을 각 운영 모드마다 존재 : 리얼 모드의 벡터 테이블은 `세그먼트:어드레스`의 형태로 어드레스 0x0000:0x0000에 위치하고 보호 모드, IA-32e 모드에서는 IDT라고 불리는 특수 형태의 벡터 테이블 사용

* IDT : IDT 게이트 디스크립터로 구성된 테이블이며 IDTR 레지스터를 통해 프로세서에 IDT 테이블 정보 설정
    * IDT 테이블은 최대 256개의 엔트리를 포함할 수 있고 IDT 게이트 디스크립터는 16바이트를 차지함

![IDT Gate Descriptor](https://image.slideserve.com/397411/slide24-l.jpg)

* IDT Gate Descriptor 필드의 의미

|필드|설명|
|---|---|
|핸들러 오프셋|인터럽트 또는 예외 핸들러의 엔트리 포인트, 64비트 크기|
|세그먼트 셀렉터|인터럽트 또는 예외 핸들러 수행 시 사용할 코드 세그먼트 디스크립터|
|IST|인터럽트나 예외 발생 시, 사용할 스택 어드레스(Top), 0이 아닌 값으로 설정하면 인터럽트 발생 시 강제로 스택을 교환함(이후 IST 섹션 참조)|
|타입|IDT 게이트의 종류(0110 - 인터럽트 게이트, 0111 - 트랩 게이트), 인터럽트 게이트로 설정하면 핸들러를 수행하는 동안 인터럽트가 발생하지 못 하며, 트랩 게이트로 설정하면 다른 인터럽트 발생 가능|
|DPL|Descriptor Privilege Level의 약자로 해당 디스크립터를 사용하는 데 필요한 권한을 의미, 0(Highest)~3(Lowest)의 범위를 가짐, CPL, RPL과 조합되어 접근 권한을 제한하는 데 사용|
|P|Present의 의미로 현재 디스크립터가 유효한 디스크립터인지 표시, 1로 설정하면 유효한 디스크립터임을 나타내며, 0으로 설정하면 유효하지 않은 디스크립터임을 나타냄|

* 세그먼트 셀렉터 : 이 셀렉터는 인터럽트 또는 예외 핸들러가 수행될 때 코드 세그먼트를 대체하며 핸들러 함수를 수행하는 데 충분한 권한으로 상승시키는 역할
    * 유저 레벨의 애플리케이션 코드를 실행할 때 인터럽트/예외 발생할 경우 권한 문제를 해결하기 위함

* 인터럽트 게이트 : 핸들러를 수행하는 동안 다른 인터럽트 발생하지 않음
    * MINT64에서는 인터럽트 게이트 사용

* IST(Interrupt Stack Table) : 인터럽트나 예외가 발생했을 때 별도의 스택 공간을 할당
    * 핸들러 수행 도중 오버플로우 방지하기 위함

### 인터럽트와 예외의 종류

* x86 프로세서는 IDT 테이블의 상위 32개 디스크립터를 예약해서 예외처리에 사용(실제 사용하는 20개이며 12개는 나중을 위해 예약)
    * 나머지 224개를 OS가 임의로 사용할 수 있음 : 인터럽트 처리와 애플리케이션 시스템 콜 용도로 사용함

* 프로세서의 20개 예외는 Faults, Traps, Aborts 3가지로 분류

1. Faults : 문제가 발생했으나 해당 코드의 문제를 수정하면 정상적으로 실행 가능한 예외
    * Fault 발생하면 복귀할 어드레스는 Fault 발생한 코드를 가리키며 핸들러의 실행이 완료된 후 해당 코드부터 다시 실행

2. Traps : Trap을 유발하는 명령어를 실행했을 때 발생
    * 디버깅과 관련이 있으며 핸들러 실행 후 해당 코드의 다음 코드부터 실행

3. Aborts : 심각한 문제가 발생하여 문제가 발생한 정확한 어드레스를 찾을 수 없으며 더 이상 코드를 수행할 수 없음
    * 시스템 오동작 또는 리부팅

![보호 모드, IA-32e 모드의 예외와 인터럽트 목록](https://i.stack.imgur.com/HayQE.png)

* NMI 인터럽트 : 프로세서에 연결된 Nonmaskable Interrupt Pin)으로 전달된 인터럽트로 프로세서 외부에서 심각한 장애 발생 시 발생

### PC 인터럽트의 종류와 원인

* PIC(Programmable Interrupt Controller) 컨트롤러를 사용해서 외부 인터럽트 관리

* PIC는 8개의 핀이 있으며 과거의 PC는 컨트롤러 2개를 마스터-슬레이브 방식으로 연결해 사용

![PIC](https://www.helpwithpcs.com/upgrading/irq-settings/viewing-irq-settings.jpg)

## 인터럽트와 예외, 스택과 태스크 상태 세그먼트

### 스택 스위칭과 IST

* 스택 스위칭 : 인터럽트나 예외가 발생했을 때, IDT 게이트 디스크립터에 의해 설정된 코드 디스클비터의 권한이 현재 수행 중인 코드의 권한보다 높으면 새로운 스택으로 전환

* 스택 스위칭을 하는 이유
    1. 핸들러가 스택 공간의 부족으로 오류가 발생하는 일을 미리 방지
    2. 권한이 높은 함수가 낮은 권한의 스택을 공유함으로써 발생할 수 있는 간섭 최소화

* IST(Interrupt Stack Table) : 인터럽트 처리를 위한 테이블로 최대 7개의 스택 저장, 기존 스택 스위칭 기법과는 달리 무조건 스택 스위칭이 발생
    * IDT 테이블의 게이트 디스크립터를 찾아 IST 필드를 1~7 사이의 값으로 설정
    * 인터럽트, 예외가 발생했을 때 핸들러의 스택에서 수행 중이던 코드의 정보(CS, RIP 레지스터)와 스택의 정보(SS, RSP 레지스터)가 삽입됨

### 프로세서와 태스크 상태 세그먼트, 태스크 디스크립터

* TSS(Task Status Segment) : 태스크의 상태를 저장하는 영역으로, 프로세서의 상태-레지스터의 값들-을 저장하는 역할

* 보호 모드의 TSS
    * 보호 모드의 TSS는 FPU에 관련된 레지스터를 제외하는 프로세서의 모든 레지스터를 저장(하드웨어 멀티태스킹 구현에서 핵심 역할)
    * 권한별 스택 정보를 저장하는 역할과 유저 앱이 I/O 포트에 접근하는 것을 제한하는 I/O 맵 어드레스의 주소를 지정하는 역할

![보호 모드의 TSS](https://img1.daumcdn.net/thumb/R720x0.q80/?scode=mtistory2&fname=http%3A%2F%2Fcfs2.tistory.com%2Fupload_control%2Fdownload.blog%3Ffhandle%3DYmxvZzEyNDIxQGZzMi50aXN0b3J5LmNvbTovYXR0YWNoLzAvMjUucG5n)

* IA-32e 모드의 TSS
    * 레지스터의 크기가 커지면서 기존 104바이트에는 모든 레지스터 저장 불가능
    * 7개의 IST 정보를 저장하는 역할로 변경
    * 권한별 스택 정보 저장, I/O 맵 기준 주소 저장 기능은 그대로

![IA-32e 모드의 TSS](https://img1.daumcdn.net/thumb/R720x0.q80/?scode=mtistory2&fname=http%3A%2F%2Fcfile10.uf.tistory.com%2Fimage%2F0248C13B510013D622B66D)

* 예약된 영역은 모드 0으로 설정한다는 뜻
* IST 기능을 사용하면 기존 스택 스위칭 방식에서 사용되는 RSP0~2 필드는 사용하지 않음
* I/O 맵 기준 주소 필드는 I/O 제한을 설정하는 비트맵(I/O Permission Bit Map) 시작 어드레스

#### TSS 디스크립터, LTR

* TSS 세그먼트는 단순한 데이터이며 TSS 디스크립터와 LTR 어셈블리 명령어를 통해 프로세서에 TSS 세그먼트에 대한 정보를 알려줌

![TSS 디스크립터](https://img1.daumcdn.net/thumb/R720x0.q80/?scode=mtistory2&fname=http%3A%2F%2Fcfile25.uf.tistory.com%2Fimage%2F2430984E587A432B17D3D7)

* B 필드는 Busy 필드로 1로 설정되면 현재 TSS 디스크립터가 가리키는 태스크가 실행 중임을 나타냄
* GDT 테이블에 위와 같은 구조의 TSS 디스크립터 생성 후 프로세서에 현재 수행 중인 태스크의 TSS가 어떤 것인지 알려줌
    * LTR 명령어를 사용하며 이는 GDT 테이블 내의 TSS 디스크립터의 오프셋을 사용

#### I/O Permission Bit Map

* 현재 수행 중인 코드의 특권 레벨(CPL)과 RFLAGS 레지스터에 설정된 I/O 레벨(IOPL)의 값을 비교하여 CPL이 더 낮으면 1로 설정된 포트 어드레스의 I/O 제한
* 9번 I/O 포트에 접근하는 것을 막고 싶다면 3바이트 할당 후 마지막 바이트를 0xFF로 설정, 비트맵의 2번째 바이트의 비트 2를 1로 설정하고 RFLAGS 레지스터의 IOPL 필드를 최고 특권 레벨인 Ring 0로 설정

## GDT 테이블 교환과 TSS 세그먼트 디스크립터 추가

### 왜 GDT 테이블을 교환해야 하는가?

* 커널 엔트리 포인트 영역(512바이트)에 비해 104바이트의 TSS 세그먼트 디스크립터의 크기가 너무 큼
    * 멀티코어를 활성화하게 되면 각 코어마다 TSS 세그먼트가 필요하므로 미리 대용량의 공간에 GDT 테이블 생성 필요

### GDT 테이블 생성과 TSS 세그먼트 디스크립터 추가

```c
// GDT
// 조합에 사용할 기본 매크로
#define GDT_TYPE_CODE           0x0A
#define GDT_TYPE_DATA           0x02
#define GDT_TYPE_TSS            0x09
#define GDT_FLAGS_LOWER_S       0x10
#define GDT_FLAGS_LOWER_DPL0    0x00
#define GDT_FLAGS_LOWER_DPL1    0x20
#define GDT_FLAGS_LOWER_DPL2    0x40
#define GDT_FLAGS_LOWER_DPL3    0x60
#define GDT_FLAGS_LOWER_P       0x80
#define GDT_FLAGS_UPPER_L       0x20
#define GDT_FLAGS_UPPER_DB      0x40
#define GDT_FLAGS_UPPER_G       0x80

// 실제로 사용할 매크로
// Lower Flags는 Code/Data/TSS, DPL0, Present로 설정
#define GDT_FLAGS_LOWER_KERNELCODE ( GDT_TYPE_CODE | GDT_FLAGS_LOWER_S | \
        GDT_FLAGS_LOWER_DPL0 | GDT_FLAGS_LOWER_P )
#define GDT_FLAGS_LOWER_KERNELDATA ( GDT_TYPE_DATA | GDT_FLAGS_LOWER_S | \
        GDT_FLAGS_LOWER_DPL0 | GDT_FLAGS_LOWER_P )
#define GDT_FLAGS_LOWER_TSS ( GDT_FLAGS_LOWER_DPL0 | GDT_FLAGS_LOWER_P )
#define GDT_FLAGS_LOWER_USERCODE ( GDT_TYPE_CODE | GDT_FLAGS_LOWER_S | \
        GDT_FLAGS_LOWER_DPL3 | GDT_FLAGS_LOWER_P )
#define GDT_FLAGS_LOWER_USERDATA ( GDT_TYPE_DATA | GDT_FLAGS_LOWER_S | \
        GDT_FLAGS_LOWER_DPL3 | GDT_FLAGS_LOWER_P )

// Upper Flags는 Granulaty로 설정하고 코드 및 데이터는 64비트 추가
#define GDT_FLAGS_UPPER_CODE ( GDT_FLAGS_UPPER_G | GDT_FLAGS_UPPER_L )
#define GDT_FLAGS_UPPER_DATA ( GDT_FLAGS_UPPER_G | GDT_FLAGS_UPPER_L )
#define GDT_FLAGS_UPPER_TSS ( GDT_FLAGS_UPPER_G )

// 세그먼트 디스크립터 오프셋
#define GDT_KERNELCODESEGMENT 0x08
#define GDT_KERNELDATASEGMENT 0x10
#define GDT_TSSSEGMENT        0x18

// 기타 GDT에 관련된 매크로
// GDTR의 시작 어드레스, 1Mbyte에서 264Kbyte까지는 페이지 테이블 영역
#define GDTR_STARTADDRESS   0x142000
// 8바이트 엔트리의 개수, 널 디스크립터/커널 코드/커널 데이터
#define GDT_MAXENTRY8COUNT  3
// 16바이트 엔트리의 개수, TSS
#define GDT_MAXENTRY16COUNT 1
// GDT 테이블의 크기
#define GDT_TABLESIZE       ( ( sizeof( GDTENTRY8 ) * GDT_MAXENTRY8COUNT ) + \
        ( sizeof( GDTENTRY16 ) * GDT_MAXENTRY16COUNT ) )
#define TSS_SEGMENTSIZE     ( sizeof( TSSSEGMENT ) )

// IDT
// 조합에 사용할 기본 매크로
#define IDT_TYPE_INTERRUPT      0x0E
#define IDT_TYPE_TRAP           0x0F
#define IDT_FLAGS_DPL0          0x00
#define IDT_FLAGS_DPL1          0x20
#define IDT_FLAGS_DPL2          0x40
#define IDT_FLAGS_DPL3          0x60
#define IDT_FLAGS_P             0x80
#define IDT_FLAGS_IST0          0
#define IDT_FLAGS_IST1          1

// 실제로 사용할 매크로
#define IDT_FLAGS_KERNEL        ( IDT_FLAGS_DPL0 | IDT_FLAGS_P )
#define IDT_FLAGS_USER          ( IDT_FLAGS_DPL3 | IDT_FLAGS_P )

// 기타 IDT에 관련된 매크로
// IDT 엔트리의 개수
#define IDT_MAXENTRYCOUNT       100
// IDTR의 시작 어드레스, TSS 세그먼트의 뒤쪽에 위치
#define IDTR_STARTADDRESS       ( GDTR_STARTADDRESS + sizeof( GDTR ) + GDT_TABLESIZE + TSS_SEGMENTSIZE )
// IDT 테이블의 시작 어드레스
#define IDT_STARTADDRESS        ( IDTR_STARTADDRESS + sizeof( IDTR ) )
// IDT 테이블의 전체 크기
#define IDT_TABLESIZE           ( IDT_MAXENTRYCOUNT * sizeof( IDTENTRY ) )

// IST의 시작 어드레스
#define IST_STARTADDRESS        0x700000
// IST의 크기
#define IST_SIZE                0x100000

// 1바이트로 정렬
#pragma pack( push, 1 )

// GDTR 및 IDTR 구조체
typedef struct kGDTRStruct
{
    WORD wLimit;
    QWORD qwBaseAddress;
    // 16바이트 어드레스 정렬을 위해 추가
    WORD wPading;
    DWORD dwPading;
} GDTR, IDTR;

// 8바이트 크기의 GDT 엔트리 구조
typedef struct kGDTEntry8Struct
{
    WORD wLowerLimit;
    WORD wLowerBaseAddress;
    BYTE bUpperBaseAddress1;
    // 4비트 Type, 1비트 S, 2비트 DPL, 1비트 P
    BYTE bTypeAndLowerFlag;
    // 4비트 Segment Limit, 1비트 AVL, L, D/B, G
    BYTE bUpperLimitAndUpperFlag;
    BYTE bUpperBaseAddress2;
} GDTENTRY8;

// 16바이트 크기의 GDT 엔트리 구조
typedef struct kGDTEntry16Struct
{
    WORD wLowerLimit;
    WORD wLowerBaseAddress;
    BYTE bMiddleBaseAddress1;
    // 4비트 Type, 1비트 0, 2비트 DPL, 1비트 P
    BYTE bTypeAndLowerFlag;
    // 4비트 Segment Limit, 1비트 AVL, 0, 0, G
    BYTE bUpperLimitAndUpperFlag;
    BYTE bMiddleBaseAddress2;
    DWORD dwUpperBaseAddress;
    DWORD dwReserved;
} GDTENTRY16;

// TSS Data 구조체
typedef struct kTSSDataStruct
{
    DWORD dwReserved1;
    QWORD qwRsp[ 3 ];
    QWORD qwReserved2;
    QWORD qwIST[ 7 ];
    QWORD qwReserved3;
    WORD wReserved;
    WORD wIOMapBaseAddress;
} TSSSEGMENT;

// IDT 게이트 디스크립터 구조체
typedef struct kIDTEntryStruct
{
    WORD wLowerBaseAddress;
    WORD wSegmentSelector;
    // 3비트 IST, 5비트 0
    BYTE bIST;
    // 4비트 Type, 1비트 0, 2비트 DPL, 1비트 P
    BYTE bTypeAndFlags;
    WORD wMiddleBaseAddress;
    DWORD dwUpperBaseAddress;
    DWORD dwReserved;
} IDTENTRY;

#pragma pack ( pop )
```

```c
// GDT 테이블을 초기화
void kInitializeGDTTableAndTSS( void )
{
    GDTR* pstGDTR;
    GDTENTRY8* pstEntry;
    TSSSEGMENT* pstTSS;
    int i;
    
    // GDTR 설정
    pstGDTR = ( GDTR* ) GDTR_STARTADDRESS;
    pstEntry = ( GDTENTRY8* ) ( GDTR_STARTADDRESS + sizeof( GDTR ) );
    pstGDTR->wLimit = GDT_TABLESIZE - 1;
    pstGDTR->qwBaseAddress = ( QWORD ) pstEntry;
    // TSS 영역 설정
    pstTSS = ( TSSSEGMENT* ) ( ( QWORD ) pstEntry + GDT_TABLESIZE );

    // NULL, 64비트 Code/Data, TSS를 위해 총 4개의 세그먼트를 생성한다.
    kSetGDTEntry8( &( pstEntry[ 0 ] ), 0, 0, 0, 0, 0 );
    kSetGDTEntry8( &( pstEntry[ 1 ] ), 0, 0xFFFFF, GDT_FLAGS_UPPER_CODE, 
            GDT_FLAGS_LOWER_KERNELCODE, GDT_TYPE_CODE );
    kSetGDTEntry8( &( pstEntry[ 2 ] ), 0, 0xFFFFF, GDT_FLAGS_UPPER_DATA,
            GDT_FLAGS_LOWER_KERNELDATA, GDT_TYPE_DATA );
    kSetGDTEntry16( ( GDTENTRY16* ) &( pstEntry[ 3 ] ), ( QWORD ) pstTSS, 
            sizeof( TSSSEGMENT ) - 1, GDT_FLAGS_UPPER_TSS, GDT_FLAGS_LOWER_TSS, 
            GDT_TYPE_TSS ); 
    
    // TSS 초기화 GDT 이하 영역을 사용함
    kInitializeTSSSegment( pstTSS );
}

// 8바이트 크기의 GDT 엔트리에 값을 설정
// 코드와 데이터 세그먼트 디스크립터를 설정하는데 사용
void kSetGDTEntry8( GDTENTRY8* pstEntry, DWORD dwBaseAddress, DWORD dwLimit,
        BYTE bUpperFlags, BYTE bLowerFlags, BYTE bType )
{
    pstEntry->wLowerLimit = dwLimit & 0xFFFF;
    pstEntry->wLowerBaseAddress = dwBaseAddress & 0xFFFF;
    pstEntry->bUpperBaseAddress1 = ( dwBaseAddress >> 16 ) & 0xFF;
    pstEntry->bTypeAndLowerFlag = bLowerFlags | bType;
    pstEntry->bUpperLimitAndUpperFlag = ( ( dwLimit >> 16 ) & 0xFF ) | 
        bUpperFlags;
    pstEntry->bUpperBaseAddress2 = ( dwBaseAddress >> 24 ) & 0xFF;
}

// 16바이트 크기의 GDT 엔트리에 값을 설정
// TSS 세그먼트 디스크립터를 설정하는데 사용
void kSetGDTEntry16( GDTENTRY16* pstEntry, QWORD qwBaseAddress, DWORD dwLimit,
        BYTE bUpperFlags, BYTE bLowerFlags, BYTE bType )
{
    pstEntry->wLowerLimit = dwLimit & 0xFFFF;
    pstEntry->wLowerBaseAddress = qwBaseAddress & 0xFFFF;
    pstEntry->bMiddleBaseAddress1 = ( qwBaseAddress >> 16 ) & 0xFF;
    pstEntry->bTypeAndLowerFlag = bLowerFlags | bType;
    pstEntry->bUpperLimitAndUpperFlag = ( ( dwLimit >> 16 ) & 0xFF ) | 
        bUpperFlags;
    pstEntry->bMiddleBaseAddress2 = ( qwBaseAddress >> 24 ) & 0xFF;
    pstEntry->dwUpperBaseAddress = qwBaseAddress >> 32;
    pstEntry->dwReserved = 0;
}
```

### TSS 세그먼트 초기화

* MINT64 OS는 I/O 맵을 사용하지 않기 때문에 I/O 맵 기준 주소를 TSS 디스크립터에서 설정한 Limit 필드 값보다 크게 설정

```c
// TSS 세그먼트의 정보를 초기화
void kInitializeTSSSegment( TSSSEGMENT* pstTSS )
{
    kMemSet( pstTSS, 0, sizeof( TSSSEGMENT ) );  // 메모리 영역을 특정 값으로 초기화하는 함수
    pstTSS->qwIST[ 0 ] = IST_STARTADDRESS + IST_SIZE;
    // IO 를 TSS의 limit 값보다 크게 설정함으로써 IO Map을 사용하지 않도록 함
    pstTSS->wIOMapBaseAddress = 0xFFFF;
}
```

### GDT 테이블 교체와 TSS 세그먼트 로드

* GDT 테이블 교체는 LGDT 명령어를 사용해서 GDT 정보를 수정하면 가능

* TSS 세그먼트 로드 변경
    * x86 프로세서에는 태스크에 관련된 정보를 저장하는 태스크 레지스터(TR)가 있음
    * TR 레지스터는 현재 프로세서가 수행 중인 태스크 정보를 관리하며 GDT 테이블 내에 TSS 세그먼트 디스크립터의 오프셋이 저장되어 있음
    * LTR 명령어를 사용하여 GDT 테이블 내의 TSS 세그먼트 인덱스인 0x18을 지정하면 TSS 세그먼트를 프로세서에 설정

```assembly
; GDTR 레지스터에 GDT 테이블을 설정
;   PARAM: GDT 테이블의 정보를 저장하는 자료구조의 어드레스
kLoadGDTR:
    lgdt [ rdi ]    ; 파라미터 1(GDTR 어드레스)를 프로세서에 로드하여 GDT 테이블 설정
    ret

; TR 레지스터에 TSS 세그먼트 디스크립터 설정
;   PARAM: TSS 세그먼트 디스크립터의 오프셋
kLoadTR:
    ltr di          ; 파라미터 1(TSS 세그먼트 디스크립터의 오프셋)을 프로세서에 설정하여 TSS 세그먼트를 로드
    ret
```

```c
void kLoadGDTR( QWORD qwGDTRAddress );
void kLoadTR( WORD wTSSSegmentOffset );
```

* GDT 테이블을 갱신하고 TSS 세그먼트를 프로세서에 로드하는 코드

```c
void Main( void )
{
    // 생략
    kInitializeGDTTableAndTSS();
    kLoadGDTR( 0x142000 );
    kLoadTR( 0x18 );
    // 생략
}
```

## IDT 테이블 생성, 인터럽트, 예외 핸들러 등록

### IDT 테이블 생성

* IDT 테이블은 IDT 게이트 디스크립터로 구성
    * IDT 게이트 디스크립터는 세그먼트 디스크립터와 구조적으로 다르지만 타입, DPL 그리고 P 필드의 위치가 같고 더 간단함

```c
// 조합에 사용할 기본 매크로
#define IDT_TYPE_INTERRUPT      0x0E
#define IDT_TYPE_TRAP           0x0F
#define IDT_FLAGS_DPL0          0x00
#define IDT_FLAGS_DPL1          0x20
#define IDT_FLAGS_DPL2          0x40
#define IDT_FLAGS_DPL3          0x60
#define IDT_FLAGS_P             0x80
#define IDT_FLAGS_IST0          0
#define IDT_FLAGS_IST1          1

// 실제로 사용할 매크로
#define IDT_FLAGS_KERNEL        ( IDT_FLAGS_DPL0 | IDT_FLAGS_P )
#define IDT_FLAGS_USER          ( IDT_FLAGS_DPL3 | IDT_FLAGS_P )

// 1바이트로 정렬
#pragma pack ( push, 1 )

// IDT 게이트 디스크립터 구조체
typedef struct kIDTEntryStruct
{
    WORD wLowerBaseAddress;
    WORD wSegmentSelector;
    // 3비트 IST, 5비트 0
    BYTE bIST;
    // 4비트 Type, 1비트 0, 2비트 DPL, 1비트 P
    BYTE bTypeAndFlags;
    WORD wMiddleBaseAddress;
    DWORD dwUpperBaseAddress;
    DWORD dwReserved;
} IDTENTRY;

#pragma pack ( pop )
```

```c
void kSetIDTEntry( IDTENTRY* pstEntry, void* pvHandler, WORD wSelector, 
        BYTE bIST, BYTE bFlags, BYTE bType )
{
    pstEntry->wLowerBaseAddress = ( QWORD ) pvHandler & 0xFFFF;
    pstEntry->wSegmentSelector = wSelector;
    pstEntry->bIST = bIST & 0x3;
    pstEntry->bTypeAndFlags = bType | bFlags;
    pstEntry->wMiddleBaseAddress = ( ( QWORD ) pvHandler >> 16 ) & 0xFFFF;
    pstEntry->dwUpperBaseAddress = ( QWORD ) pvHandler >> 32;
    pstEntry->dwReserved = 0;
}
```

* pstEntry 파라미터 : 값을 저장한 IDT 게이트 디스크립터의 어드레스를 넘겨주는 용도
* pvHandler 파라미터 : 해당 인터럽트 또는 예외가 발생했을 때 실행할 핸들러 함수의 어드레스
* wSelector 파라미터 : 인터럽트, 예외가 발생했을 때 교체할 CS 세그먼트 셀렉터의 값
    * 핸들러 함수는 커널 모드에서 동작하므로 커널 코드 세그먼트인 0x08 사용
* bIST 파라미터 : 인터럽트, 예외가 발생했을 때 IST 중 어느 것을 사용할지를 설정하는 용도로 사용
    * MINT64 OS는 1번 IST만 사용하므로 1로 설정
* bFlags, bType : 권한, 게이트 타입 설정

```c
// IDT 테이블을 초기화
void kInitializeIDTTables( void )
{
    IDTR* pstIDTR;
    IDTENTRY* pstEntry;
    int i;
        
    // IDTR의 시작 어드레스
    pstIDTR = ( IDTR* ) IDTR_STARTADDRESS;
    // IDT 테이블의 정보 생성
    pstEntry = ( IDTENTRY* ) ( IDTR_STARTADDRESS + sizeof( IDTR ) );
    pstIDTR->qwBaseAddress = ( QWORD ) pstEntry;
    pstIDTR->wLimit = IDT_TABLESIZE - 1;
    
    // 0~99까지 벡터를 모두 DummyHandler로 연결
    for( i = 0 ; i < IDT_MAXENTRYCOUNT ; i++ )
    {
        kSetIDTEntry( &( pstEntry[ i ] ), kDummyHandler, 0x08, IDT_FLAGS_IST1, 
            IDT_FLAGS_KERNEL, IDT_TYPE_INTERRUPT );
    }
}

// 임시 예외 또는 인터럽트 핸들러
void kDummyHandler( void )
{
    kPrintString( 0, 0, "====================================================" );
    kPrintString( 0, 1, "          Dummy Interrupt Handler Execute~!!!       " );
    kPrintString( 0, 2, "           Interrupt or Exception Occur~!!!!        " );
    kPrintString( 0, 3, "====================================================" );

    while( 1 ) ;
}
```

### IDT 테이블 로드

* IDTR 레지스터에 LIDT 명령어를 사용하여 IDT 테이블에 대한 정보를 갖고 있는 자료구조의 어드레스를 넘겨줌으로써 프로세서에 로드할 수 있음

```assembly
; IDTR 레지스터에 IDT 테이블을 설정
;   PARAM: IDT 테이블의 정보를 저장하는 자료구조의 어드레스
kLoadIDTR:
    lidt [ rdi ]    ; 파라미터 1(IDTR의 어드레스)를 프로세서에 로드하여 IDT 테이블을 설정
    ret

// C 함수 선언
void kLoadIDTR( QWORD qwIDTRAddress );
```

```c
void Main( void )
{
    // 생략
    kInitializeIDTTables();
    kLoadIDTR( 0x1420A0 );
    // 생략
}
```

## IDT, TSS 통합과 빌드

### 디스크립터 파일 추가

* GDT, IDT에 관련된 모든 함수와 매크로 정의

### 어셈블리어 유틸리티 파일 수정

* 새로 추가한 어셈블리어 함수 kLoadGDTR(), kLoadTR(), kLoadIDTR() 추가

### 유틸리티 파일 추가

* kMemSet(), kMemCpy(), kMemCmp() 함수 추가

### C 언어 커널 엔트리 포인트 파일 수정

* 엔트리 포인트의 뒷부분에 GDT, IDT, TSS와 관련된 함수를 호출하는 코드를 추가
* 0으로 나누는 코드를 추가하여 핸들러가 제대로 동작하는지 확인

### 빌드와 실행

* 임시 핸들러 함수는 이전 코드로 복귀하는 능력이 없음
    * 프로세서는 인터럽트, 예외 발생 시 자신의 상태 일부 정보만 저장하기 때문에 나머지는 OS에서 처리해야만 함
