# 페이징 기능을 활성화하여 64비트 전환을 준비하자

## 선형 주소와 4단계 페이징 기법

![IA-32e 페이징](https://blog.quarkslab.com/resources/2016-07-12_xsa-148/images/paging.png)

* 위 그림에서는 Table + Offset
* 책에는 63~48비트 영역이 부호 확장으로 존재

* 페이징에 사용되는 각 테이블은 512(2^9)개의 엔트리로 구성되며, 다음 레벨에서 사용할 테이블의 기준 주소를 포함
    * 가장 마지막 레벨인 페이지 디렉터리의 엔트리는 2MB 페이지의 기준 주소를 포함

* 선형 주소를 물리 주소로 변환하기
    1. CR3 레지스터에 설정된 PML4(Page Map Level 4) 테이블의 기준 주소(40비트)로부터 PML4 엔트리 조회
    2. PML4 엔트리의 디렉터리 포인터 테이블의 기준 주소(40비트)로부터 디렉터리 엔트리 조회
    3. 디렉터리 엔트리 테이블의 기준 주소(19비트)로부터 페이지 기준 주소 조회
    4. 페이지 기준 주소(물리 주소)에서 오프셋(21비트)만큼의 위치가 조회할 물리 주소

![PML4 테이블 엔트리](https://camo.githubusercontent.com/b3453a4fa1d8d04657cafe9bb036cd5d599f298e/68747470733a2f2f692e696d6775722e636f6d2f5058466b6745572e706e67)
![페이지 디렉터리 포인터 테이블 엔트리](https://camo.githubusercontent.com/90e4ef56164159e97e185b79e87f92728c9102ba/68747470733a2f2f692e696d6775722e636f6d2f36584b484a796b2e706e67)
![페이지 디렉터리 엔트리](https://camo.githubusercontent.com/2c972366091df3be8d1d45ba692d449471beeb06/68747470733a2f2f692e696d6775722e636f6d2f3857476c784e442e706e67)

* 이미지 오타 : PWD -> PWT

* 페이지 테이블을 구성하는 엔트리의 각 필드와 의미

|필드|설명|
|---|---|
|EXB|Execute-Disable 비트의 약자로 관련된 페이지를 데이터 전용으로 설정하는 것을 의미, 1로 설정하면 해당 페이지는 데이터 전용으로 설정되며 해당 영역에서 코드를 실행하면 페이지 폴트 예외가 발생함, 0으로 설정하면 제약 사항 없음, IA32_EFER 레지스터의 NXE 비트를 1로 설정할 경우 유효함|
|Avail|Available의 약자로 OS에서 임의의 용도로 사용할 수 있는 영역을 의미, 임의의 용도로 사용할 수 있음|
|Base Address|다음 레벨 테이블 또는 페이지의 기준 주소를 의미|
|A|Accessed의 약자로 해당 페이지가 접근(읽기 또는 쓰기)되었음을 의미, 프로세서가 페이지를 검사하여 접근이 있으면 해당 비트를 설정함, 1로 설정되면 접근되었음을 나타내고 0으로 설정되면 접근되지 않았음을 나타냄|
|PCD|Page-level Cache Disable의 약자로 해당 페이지의 캐시 활성화 여부를 의미, CR0 레지스터의 CD 비트가 1로 설정되어 전체 캐시가 비활성화된 경우, PCD 비트는 무시됨, 1로 설정하면 해당 페이지의 캐시를 비활성화하며, 0으로 설정하면 페이지의 캐시를 활성화함|
|PWT|Page-level Write Through의 약자로 해당 페이지의 캐시 정책을 의미, PCD와 마찬가지로 CR0 레지스터의 CD 비트가 1로 설정되어 전체 캐시가 비활성화된 경우 PWT 비트는 무시됨, 1로 설정하면 해당 페이지는 Write-Through 정책이 적용되며 0으로 설정하면 Write-Back 정책이 적용됨|
|U/S|User/Supervisor의 약자로 해당 페이지의 권한을 의미, 1로 설정하면 유저 레벨 권한(Ring 3)임을 나타내며, 모든 레벨에서 해당 페이지에 접근할 수 있음, 0으로 설정하면 특권 레벨 권한(Ring 0~2)을 나타내며, 유저 레벨에서 해당 페이지에 접근하면 페이지 폴트 예외가 발생함|
|R/W|Read/Write의 약자로 해당 페이지의 읽기/쓰기 정책을 의미, 1로 설정하면 읽기/쓰기 모두 가능, 0으로 설정하면 읽기만 가능하며 쓰기를 시도하면 페이지 폴트 예외 발생|
|P|Present의 약자로 해당 엔트리가 유효함을 의미, 1로 설정하면 유효함을 나타내며, 0으로 설정하면 유효하지 않음을 나타냄, 0으로 설정된 페이지에 접근하면 페이지 폴트 예외 발생|
|PAT|Page Attribute Table Index의 약자로 PAT 선택에 사용되는 최상위 비트를 의미, 프로세서가 PAT를 지원할 경우 PAT, PCD, PWT 3비트를 사용하여 PAT를 선택, 프로세서가 PAT를 지원하지 않으면 0으로 예약됨|
|G|Global의 약자로 CR3 레지스터 값이 바뀌더라도 해당 페이지를 페이지 테이블 캐시인 TLB(Transaction Lookaside Buffer)에서 교체하지 않음을 의미, CR4 레지스터의 PGE 비트를 1로 설정할 때만 유효함, 1로 설정하면 CR3 레지스터 교체 시에 해당 페이지를 TLB에서 교체하지 않으며, 0으로 설정하면 TLB에서 교체함|
|PS|Page Size의 약자로 페이지의 크기를 의미, 1로 설정했을 때 CR4 레지스터의 PAE 비트가 0이면 4MB 페이지를 나타내며 PAE 비트가 1이면 2MB 페이지를 나타냄, 0으로 설정하면 4KB 페이지를 나타냄|
|D|Dirty의 약자로 페이지에 쓰기가 수행되었음을 의미, A 비트와 마찬가지로 프로세서가 해당 페이지를 감시하여 해당 비트를 설정함, 1로 설정되면 쓰기가 수행되었음을 나타내고 0으로 설정되면 쓰기가 수행되지 않았음을 나타냄|

* MINT64 OS를 실행하는 데 필요한 페이지의 역할
    1. 선형 주소와 물리 주소를 1:1로 매핑하여 직관적인 어드레스 변환을 수행해야 함
    2. 2MB 페이지를 사용하여 최대 64GB의 물리 메모리를 매핑해야 함
    3. 물리 메모리 전체 영역에 대해 캐시를 활성화하여 수행 속도 향상시켜야 함
    4. 위 기능 외 다른 기능은 사용하지 않음

## 페이지 테이블 구성과 공간 할당

### 64GB의 물리 메모리 관리를 위한 메모리 계산

* 페이지 디렉터리는 8바이트의 엔트리 512개(2^9)로 구성되어 있으며 각 엔트리는 2MB
    * 페이지 디렉터리 하나는 1GB 메모리 영역을 관리하며 자체의 크기는 4KB
    * 64GB 메모리 영역을 관리하려면 64개의 페이지 디렉터리가 필요하며 필요한 크기는 256KB

* 페이지 디렉터리 포인터 테이블은 8바이트의 엔트리 512개(2^9)로 구성되어 있음
    * 1개만 있으면 되기 때문에 필요한 크기는 4KB

* PML4 테이블도 8바이트의 엔트리 512개
    * 1개만 있으면 되기 때문에 필요한 크기는 4KB
    * PML4 테이블의 엔트리를 모두 사용하면 265TB까지 가능

* MINT64 OS에서 메모리 관리를 위해 필요한 메모리 공간은 264KB

### 페이지 테이블을 위한 공간 할당

* 0x100000(1MB) ~ 0x200000(2MB) 영역이 IA-32e 모드용 커널 자료구조 영역으로 사용하며 이 중 가장 앞부분에 페이지 테이블 사용
    * 0x100000 ~ 0x142000 영역을 PML4 테이블, 페이지 디렉터리 포인터 테이블, 페이지 디렉터리 순서로 저장

### 공통 속성 필드 설정

#### PCD 필드와 PWT 필드

* 속도 향상을 위해 캐시를 사용하며 Write-Back 방식 사용
    * PCD = 0, PWT = 0

#### U/S 필드와 R/W 필드

* 현재는 커널만 존재하고 유저 레벨 애플리케이션이 없기 때문에 모든 페이지를 읽기/쓰기 가능하도록 설정
    * U/S = 0, R/W = 1

#### EXB 필드, A 필드, P 필드, Avail 필드

* EXB 필드는 사용하지 않으므로 0
* 코드 실행 도중에 특정 페이지에 접근했는지 여부도 참조하지 않으므로 A = 0
* P 필드는 해당 엔트리가 유효하다는 것을 나타내는 필드이므로 다른 필드와 달리 반드시 1로 설정

### 페이지 디렉터리 엔트링용 속성 필드 설정

* PAT 필드는 사용하지 않으므로 0
* 태스크 별로 페이지 매핑을 따로 구성하지 않으므로 G 필드 0으로 설정
* D 필드 역시 참조하지 않으르몰 0

## 페이지 테이블 생성과 페이징 기능 활성화

### 페이지 엔트리를 위한 자료구조 정의와 매크로 정의

* PML4 엔트리, 페이지 디렉터리 포인터 엔트리, 페이지 디렉터리 엔트리는 내부 필드가 거의 유사하므로 1개의 형태로만 정의

```c
typedef struct pageTableEntryStruct
{
    DWORD dwAttributeAndLowerBaseAddress;
    DWORD dwUpperBaseAddressAndEXB;
} PML4ENTRY, PDPTENTRY, PDENTRY, PTENTRY
```

* dwAttributeAndLowerBaseAddress : 8바이트 크기의 페이지 엔트리 중에 하위 4바이트를 의미. 기준 주소의 하위 필드와 G, PAT, D, A, PCD, PWT, U/S, R/W, P 비트 등을 포함
* dwUpperBaseAddressAndEXB : 8바이트 크기의 페이지 엔트리 중에 상위 4바이트를 의미. 기준 주소의 상위 필드와 EXB 비트 등을 포함

```c
// 하위 32비트용 속성 필드
#define PAGE_FLAGS_P    0x00000001  // Present
#define PAGE_FLAGS_RW   0x00000002  // Read/Write
#define PAGE_FLAGS_US   0x00000004  // User/Supervisor(플래그 설정 시 유저 레벨)
#define PAGE_FLAGS_PWT  0x00000008  // Page Level Write-through
#define PAGE_FLAGS_PCD  0x00000010  // Page Level Cache Disable
#define PAGE_FLAGS_A    0x00000020  // Accessed
#define PAGE_FLAGS_D    0x00000040  // Dirty
#define PAGE_FLAGS_PS   0x00000080  // Page Size
#define PAGE_FLAGS_G    0x00000100  // Global
#define PAGE_FLAGS_PAT  0x00001000  // Page Attribute Table Index

// 상위 32비트용 속성 필드
#define PAGE_FLAGS_EXB  0x80000000  // Execute Disable 비트

// 기타
#define PAGE_FLAGS_DEFAULT  ( PAGE_FLAGS_P | PAGE_FLAGS_RW )  // 실제 속성을 나타내지는 않지만 편의를 위해 정의함
```

### 페이지 엔트리 생성과 페이지 테이블 생성

1. PML4 테이블 엔트리
    * P, R/W 비트 1로 설정
    * 나머지 엔트리는 모두 0으로 설정(사용하지 않음)

```c
// 페이지 엔트리에 데이터를 설정하는 함수
void kSetPageEntryData( PTENTRY* pstEntry, DWORD dwUpperBaseAddress, DWORD dwLowerBaseAddress, DWORD dwLowerFlags, DWORD dwUpperFlags )
{
    pstEntry->dwAttributeAndLowerBaseAddress = dwLowerBaseAddress | dwLowerFlags;
    pstEntry->dwUpperBaseAddressAndEXB = ( dwUpperBaseAddress & 0xFF ) | dwUpperFlags;
}

void kInitializePageTables( void )
{
    PML4ENTRY* pstPMLEntry;
    int i;

    pstPMLEntry = ( PML4ENTRY* ) 0x100000;
    kSetPageEntryData( &( pstPML4TEntry[0] ), 0x00, 0x101000, PAGE_FLAGS_DEFAULT, 0 );
    for ( i = 1 ; i < 512 ; i++ )
    {
        kSetPageEntryData( &( pstPML4TEntry[i] ), 0, 0, 0, 0 );
    }
}
```

* 32비트 환경(보호 모드)에서 64비트 어드레스를 표현하기 위해 2개의 변수를 사용함(레지스터가 32비트만 사용할 수 있기 때문)

* 64비트 어드레스를 계산할 때도 32비트 * 2개의 레지스터로 계산하기 때문에 Lower 부분이 4GB를 넘으면 Upper 부분에 1을 더해주어야 함

```c
pstPDEntry = ( PDENTRY* ) 0x102000;
dwMappingAddress = 0;
for ( i = 0 ; i < 512 * 64 ; i++ )
{
    kSetPageEntryData( &( pstPDEntry[i] ), ( i * ( 0x200000 >> 20 ) ) >> 12, dwMappingAddress, PAGE_FLAGS_DEFAULT | PAGE_FLAGS_PS, 0 );
    dwMappingAddress += PAGE_DEFAULTSIZE;
}
```

### 프로세서의 페이징 기능 활성화

![CR0~4 레지스터](https://img1.daumcdn.net/thumb/R800x0/?scode=mtistory2&fname=https%3A%2F%2Ft1.daumcdn.net%2Fcfile%2Ftistory%2F243FB03656234D0220)

* CR0 레지스터의 PG 비트와 CR3/CR4 레지스터의 PAE 비트만 1로 설정하면 페이징 기능 사용
    * 위 기능을 설정하기 전에 CR3 레지스터에 PML4 테이블의 어드레스 설정 필요함

* CR3 레지스터는 페이지 디렉터리 베이스 레지스터라고도 불리며, 최상위 페이지 테이블의 어드레스를 프로세서에 알리는 역할
* CR2 레지스터는 페이지 폴트 예외가 발생했을 때 예외가 발생한 선형 주소를 저장

* CR4 컨트롤 레지스터의 필드와 의미

|필드|설명|
|---|---|
|SMXE|Safe Mode Extensions Enable의 약자로 SMX 명령어를 사용할지 여부를 결정, 1로 설정하면 SMX를 사용함을 나타내며 0으로 설정하면 사용하지 않음을 나타냄|
|VMXE|Virtual Machine Extension Enable의 약자로 VMX 명령어를 사용할지 여부를 설정, 1로 설정하면 VMX 명령어를 사용함을 나타내며, 0으로 설정하면 사용하지 않음을 나타냄|
|OSXMMEXCPT|OS Support for Unmasked SIMD Floating-Point Extensions를 의미하며 SIMD 관련 실수 연산 시 마스크되지 않은 예외가 발생했을 때 예외 처리 방법을 설정, 1로 설정하면 예외가 SIMD Floating-Point Exception으로 발생하며 0으로 설정하면 예외가 Invalid Opcode Exception으로 발생함, 실수 연산을 사용하는 경우 정확한 예외 처리를 위해 1로 설정하는 것을 권장|
|OSFXSR|OS Support for FXSAVE and FXRSTOR instructions를 의미하며 OS가 FXSAVE/FXRSTOR 명령 및 실수 연산 관련 명령을 지원하는지 여부를 설정, 1로 설정하면 실수 연산 관련 명령을 지원함을 나타내며 0으로 설정하면 실수 연산 관련 명령을 지원하지 않음을 나타냄, 0으로 설정하면 실수를 연산할 때마다 Invaild Opcode Exception이 발생하므로 1로 설정하는 것을 권장|
|PCE|Performance-Monitoring Counter Enable의 약자로 RDPMC 명령어를 사용할 수 있는 권한 레벨을 설정, 1로 설정하면 모든 레벨에서 사용 가능함을 나타내며 0으로 설정하면 최상위 레벨(0)에서만 사용 가능함을 나타냄|
|PGE|Page Global Enable의 약자로 Global Page Feature를 사용할지 여부를 결정, 1로 설정하면 Globel Page Feature를 사용함을 나타내며 CR3 레지스터가 교체되어 페이지 테이블이 바뀌는 경우 페이지 엔트리의 PG 비트가 1로 설정된 페이지는 TLB에서 교체 안됨, 0으로 사용하면 Global Page Feature 기능을 사용하지 않음을 나타냄|
|MCE|Machine-Check Enable의 약자로 Machine-Check 예외를 사용할지 여부를 나타냄, 1로 설정하면 Machine-Check 예외를 사용함을 나타내며, 0으로 설정하면 사용하지 않음을 나타냄|
|PAE|Physical Address Extensions의 약자로 36비트 이상의 물리 메모리를 사용할지 여부를 나타냄, 1로 설정하면 36비트 이상의 물리 메모리를 사용함을 나타내며, 0으로 설정하면 사용하지 않음을 나타냄, IA-32e 모드에서는 필수적으로 1로 설정해야 함|
|PSE|Page Size Extensions의 약자로 4KB 또는 그 이상의 페이지 크기를 사용할지 여부를 설정, 1로 설정할 경우 2MB 또는 4MB 페이지를 사용함을 나타내며 0으로 설정할 경우 4KB 페이지를 사용함을 나타냄, PAE가 1로 설정될 경우 PSE 비트는 무시되며 페이지 디렉터리 엔트리의 PS 비트에 의해 페이지 크기가 설정됨|
|DE|Debugging Extensions의 약자로 DR4와 DR5 레지스터에 접근을 허락할지 여부를 설정, 1로 설정하면 DR4, DR5 레지스터는 프로세서에 의해 예약되며 해당 레지스터에 접근할 경우 Undefined Opcode Exception이 발생, 0으로 설정하면 DR4, DR5 레지스터는 각각 DR6, DR7 레지스터의 다른 이름 역할을 함|
|TSD|Time Stamp Diable의 약자로 RDTSC 명령어를 사용할 수 있는 권한 레벨을 설정, 1로 설정하면 VIF를 사용함을 나타내고 0으로 설정하면 VIF를 사용하지 않음을 나타냄|
|PVI|Protected-Mode Virtual Interrupts의 약자로 Virtual Interrupt Flag를 사용할지 여부를 설정, 1로 설정하면 VIF를 사용함을 나타내고 0으로 설정하면 VIF를 사용하지 않음을 나타냄|
|VME|Virtual-8086 Mode Extensions의 약자로 가상 8086 모드에서 Interrupt And Exception-Handling Extensions 사용 여부를 설정, 1로 설정하면 Interrupt And Exception-Handling Extensions 사용함을 나타내고 0으로 설정하면 사용하지 않음을 나타냄|

```assembly
; PAE 비트를 1로 설정
mov eax, cr4            ; CR4 컨트롤 레지스터의 값을 EAX에 저장
or eax, 0x20            ; PAE 비트(비트 5)를 1로 설정
mov cr4, eax            ; 설정된 값을 다시 CR4 컨트롤 레지스터에 저장

; PML4 테이블의 어드레스와 캐시 활성화
mov eax, 0x100000       ; EAX 레지스터에 PML4 테이블이 존재하는 0x100000(1MB) 저장
mov cr3, eax            ; CR3 레지스터에 0x100000(1MB) 저장

; 프로세서의 페이징 기능 활성화
mov eax, cr0            ; EAX 레지스터에 CR0 컨트롤 레지스터를 저장
or eax, 0x80000000      ; PG 비트(비트 31)을 1로 설정
mov cr0, eax            ; 설정된 값을 다시 CR0 컨트롤 레지스터에 저장
```

## 보호 모드 커널에 페이지 테이블 생성 기능 추가

### 페이징 기능 고나련 파일 생성

* 페이지 헤더 파일 추가

```c
#ifndef __PAGE_H__
#define __PAGE_H__

#include "Types.h"

// 매크로
// 하위 32비트용 속성 필드
#define PAGE_FLAGS_P    0x00000001  // Present
#define PAGE_FLAGS_RW   0x00000002  // Read/Write
#define PAGE_FLAGS_US   0x00000004  // User/Supervisor(플래그 설정 시 유저 레벨)
#define PAGE_FLAGS_PWT  0x00000008  // Page Level Write-through
#define PAGE_FLAGS_PCD  0x00000010  // Page Level Cache Disable
#define PAGE_FLAGS_A    0x00000020  // Accessed
#define PAGE_FLAGS_D    0x00000040  // Dirty
#define PAGE_FLAGS_PS   0x00000080  // Page Size
#define PAGE_FLAGS_G    0x00000100  // Global
#define PAGE_FLAGS_PAT  0x00001000  // Page Attribute Table Index

// 상위 32비트용 속성 필드
#define PAGE_FLAGS_EXB  0x80000000  // Execute Disable 비트

// 기타
#define PAGE_FLAGS_DEFAULT  ( PAGE_FLAGS_P | PAGE_FLAGS_RW )  // 실제 속성을 나타내지는 않지만 편의를 위해 정의함
#define PAGE_TABLESIZE      0x1000
#define PAGE_MAXENTRYCOUNT  512
#define PAGE_DEFAULTSIZE    0x200000

// 구조체
#pragma pack( push, 1 )

// 페이지 엔트리에 대한 자료구조
typedef struct kPageTableEntryStruct
{
    // PML4와 PDPTE의 경우
    // 1비트 P, RW, US, PWT, PCD, A, D, PS, G, 3비트 Avail, 1비트 PAT, 8비트 Reserved, 20비트 Base Address
    // PDE의 경우
    // 1비트 P, RW, US, PWT, PCD, A, G, 1, G, 3비트 Avail, 1비트 PAT, 8비트 Avail, 11비트 Base Address
    DWORD dwAttributeAndLowerBaseAddress;
    // 8비트 Upper BaseAddress, 12비트 Reserved, 11비트 Avail, 1비트 EXB
    DWORD dwUpperBaseAddressAndEXB;
} PML4TENTRY, PDPTENTRY, PDENTRY, PTENTRY;
#pragma pack( pop )

// 함수
void kInitializePageTables( void );
void kSetPageEntryData( PTENTRY* pstEntry, DWORD dwUpperBaseAddress, DWORD dwLowerBaseAddress, DWORD dwLowerFlags, DWORD dwUpperFlags );

#endif /*__PAGE_H__*/
```

* 페이지 소스 파일

```c
#include "Page.h"

// IA-32e 모드 커널을 위한 페이지 테이블 생성
void kInitializePageTables( void )
{
    PML4TENTRY* pstPML4TEntry;
    PDPTENTRY* pstPDPTEntry;
    PDENTRY* pstPDEntry;
    DWORD dwMappingAddress;
    int i;

    // PML4 테이블 생성
    // 첫 번째 엔트리 외에 나머지는 모드 0으로 초기화
    pstPML4TEntry = ( PML4TENTRY* ) 0x100000;
    kSetPageEntryData( &( pstPML4TEntry[0] ), 0x00, 0x101000, PAGE_FLAGS_DEFAULT, 0 );
    for( i = 1 ; i < PAGE_MAXENTRYCOUNT ; i++ )
    {
        kSetPageEntryData( &( pstPML4TEntry[i] ), 0, 0, 0, 0 );
    }

    // 페이지 디렉터리 포인터 테이블 생성
    // 하나의 PDPT로 512GB까지 매핑 가능하므로 하나로 충분함
    // 64개의 엔트리를 설정하여 64GB까지 매핑함
    pstPDPTEntry = ( PDPTENTRY* ) 0x101000;
    for( i = 0 ; i < 64 ; i++ )
    {
        kSetPageEntryData( &( pstPDPTEntry[i] ), 0, 0x102000 + ( i * PAGE_TABLESIZE ), PAGE_FLAGS_DEFAULT, 0 );
    }
    for( i = 64 ; i < PAGE_MAXENTRYCOUNT ; i++ )
    {
        kSetPageEntryData( &( pstPDPTEntry[i] ), 0, 0, 0, 0 );
    }

    // 페이지 디렉터리 테이블 생성
    // 하나의 페이지 디렉터리가 1GB까지 메핑 가능
    // 여유있게 64개의 페이지 디렉터리를 생성하여 총 64GB까지 지원
    pstPDEntry = ( PDENTRY* ) 0x102000;
    dwMappingAddress = 0;
    for( i = 0 ; i < PAGE_MAXENTRYCOUNT * 64 ; i++ )
    {
        // 32비트로는 상위 어드레스를 표현할 수 없으므로, MB 단위로 계산한 다음
        // 최종 결과를 다시 4KB로 나누어 32비트 이상의 어드레스를 계산함
        kSetPageEntryData( &( pstPDEntry[i] ), ( i * ( 0x200000 >> 20 ) ) >> 12, dwMappingAddress, PAGE_FLAGS_DEFAULT | PAGE_FLAGS_PS, 0 );
        dwMappingAddress += PAGE_DEFAULTSIZE;
    }
}

// 페이지 엔트리에 기준 주소와 속성 플래그를 설정
void kSetPageEntryData( PTENTRY* pstEntry, DWORD dwUpperBaseAddress, DWORD dwLowerBaseAddress, DWORD dwLowerFlags, DWORD dwUpperFlags )
{
    pstEntry->dwAttributeAndLowerBaseAddress = dwLowerBaseAddress | dwLowerFlags;
    pstEntry->dwUpperBaseAddressAndEXB = ( dwUpperBaseAddress & 0xFF ) | dwUpperFlags;
}
```

* C 커널 엔트리 포인트(01.Kernel32/Source/Main.c) 수정 - 아래 코드를 기존 파일에 추가

```c
#inclue "Page.h"

void Main( void )
{
    // 생략
    kPrintString( 0, 6, "IA-32e Page Tables Initialize...............[    ]" );
    kInitializePageTables();
    kPrintString( 45, 6, "Pass" );
    // 생략
}
```
