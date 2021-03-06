# 64비트 모드로 전환하자

* IA-32e 모드로 전환하는 7단계

1. 세그먼트 디스크립터 추가(IA-32e 모드 코드와 데이터용 세그먼트 디스크립터 추가)
2. CR4 컨트롤 레지스터 설정(CR4 컨트롤 레지스터의 PAE 비트 1)
3. CR3 컨트롤 레지스터 설정(CR3 컨트롤 레지스터에 PML4 테이블 어드레스 설정)
4. IA32_EFER 레지스터 설정(IA32_EFER 레지스터(MSR 레지스터)의 LME 비트 1)
5. CR0 컨트롤 레지스터 설정(CR0 컨트롤 레지스터의 PG 비트 1)
6. jmp 명령으로 CS 세그먼트 셀렉터 변경 및 IA-32e 모드로 전환(jmp 0x18:IA-32e 모드 커널의 시작 어드레스)
7. (여기서부터 64비트 IA-32e 모드)각종 세그먼트 셀렉터와 스택 초기화(DS, ES, FS, GS, SS 세그먼트 셀렉터와 RSP, RBP 레지스터 초기화)
8. IA-32e 모드 커널 실행

## 프로세서 제조사와 IA-32e 지원 여부 검사

### CPUID를 사용하여 프로세서 정보 확인 방법

* x86 계열 프로세서는 프로세서에 대한 정보를 확인할 수 있는 CPUID 명령어 제공

* CPUID(CPU IDentification): EAX 레지스터에 설정된 값에 따라 해당 정보를 조회하며 EAX, EBX, ECX, EDX에 결과를 넘겨줌

* 제조사와 64비트 지원 기능에 관한 CPUID 기능 목록

1. EAX 0x00000000
    * 기본 CPUID 정보 조회
    * EAX: 해당 프로세서가 지원하는 기본 CPUID 정보의 입력 최대값
    * EBX, EDX, ECX의 순서로 하위 바이트에서 상위의 순서로 12바이트 제조사 이름이 저장됨(인텔은 GenuineIntal, AMD는 AuthenticAMD)

2. EAX 0x80000001
    * 확장 기능 CPUID 정보 조회
    * EAX: 제조사마다 다름
    * EBX: 제조사마다 다름
    * ECX
        * 비트 0: 64비트 모드에서 LAHF/SAHF 명령 지원 여부
        * 그외 나머지 비트는 제조사마다 다름
    * EDX
        * 비트 11: 64비트 모드에서 SYSCALL/SYSRET 명령 지원 여부
        * 비트 20: Execute Disable 비트 지원 여부
        * 비트 29: 64비트 모드 지원 여부
        * 그외 나머지 비트는 제조사마다 다름
    
* EAX 0x80000001 값으로 CPUID 명령어 실행 시 EDX의 비트 29로 64비트 지원 여부를 알 수 있음

### 프로세서 제조사와 IA-32e 모드 지원 여부 확인

* C에서 사용할 수 있도록 global 지시어 사용해 어셈블리어 함수 작성

```assembly
global kReadCPUID   ; C에서 kReadCPUID를 호출할 수 있도록 이름을 외부로 노출

SECTION .text

; CPUID 반환
; PARAM: DWORD dwEAX, DWORD *pdwEAX, *pdwEBX, *pdwECX, *pdwEDX
kReadCPUID:
    push ebp        ; 베이스 포인터 레지스터(EBP)를 스택에 삽입
    mov ebp, esp    ; 베이스 포인터 레지스터에 스택 포인터 레지스터(ESP)의 값을 설정
    push eax        ; 함수에서 임시로 사용하는 레지스터로 함수의 마지막 부분에서 스택에 삽입된 부분을 꺼내 원래 값으로 복원
    push ebx
    push ecx
    push edx
    push esi

    ; EAX 레지스터의 값으로 CPUID 명령어 실행
    mov eax, dword [ ebp + 8 ]  ; 파라미터 1[dwEAX]를 EAX 레지스터에 저장
    cpuid                       ; CPUID 명령어 실행

    ; 반환된 값을 파라미터에 저장
    ; *pdwEAX
    mov esi, dword [ ebp + 12 ] ; 파라미터 2(pdwEAX)를 ESI 레지스터에 저장
    mov dword [ esi ], eax      ; pdwEAX가 포인터이므로 포인터가 가리키는 어드레스에 EAX 레지스터의 값을 저장

    ; *pdwEBX
    mov esi, dword [ ebp + 16 ] ; 파라미터 3(pdwEBX)를 ESI 레지스터에 저장
    mov dword [ esi ], ebx      ; pdwEBX가 포인터이므로 포인터가 가리키는 어드레스에 EBX 레지스터의 값을 저장

    ; *pdwECX
    mov esi, dword [ ebp + 20 ] ; 파라미터 4(pdwECX)를 ESI 레지스터에 저장
    mov dword [ esi ], ecx      ; pdwECX가 포인터이므로 포인터가 가리키는 어드레스에 ECX 레지스터의 값을 저장

    ; *pdwEDX
    mov esi, dword [ ebp + 24 ] ; 파라미터 5(pdwEDX)를 ESI 레지스터에 저장
    mov dword [ esi ], edx      ; pdwEDX가 포인터이므로 포인터가 가리키는 어드레스에 EDX 레지스터의 값을 저장

    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret
```

* kReadCPU() 함수를 사용하여 제조사 문자열을 조합하는 코드

```c
void kReadCPUID( DWORD dwEAX, DWORD* pdwEAX, DWORD* pdwEBX, DWORD* pdwECX, DWORD* pdwEDX );

DWORD dwEAX, dwEBX, dwECX, dwEDX;
char vcVendorString[ 13 ] = { 0, };  // 제조사 문자열을 담을 문자열 버퍼, kPrintString() 함수로 출력하려고 13바이트를 할당하고 0으로 채움

// 프로세서 제조사 정보 읽기
kReadCPUID( 0x00, &dwEAX, &dwEBX, &dwECX, &dwEDX );
*( ( DWORD* ) vcVendorString ) = dwEBX;  // 문자가 저장된 순서가 하위 바이트에서 상위 순서이므로 그대로 문자열 버퍼에 복사하면 정상으로 출력 가능, 4바이트씩 복사하려고 DWORD 타입으로 캐스팅
*( ( DWORD* ) vcVendorString + 1 ) = dwEDX;
*( ( DWORD* ) vcVendorString + 2 ) = dwECX;

// 제조사 문자열이 출력됨
kPrintString( 0, 0, vcVendorString );
```

* IA-32e 모드 지원하는지 여부 검사

```c
DWORD dwEAX, dwEBX, dwECX, dwEDX;

// 64비트 지원 여부 확인
kReadCPUID( 0x80000001, &dwEAX, &dwEBX, &dwECX, &dwEDX );
if( dwEAX & ( 1 << 29) )
{
    kPrintString( 0, 0, "Pass" );
}
else
{
    kPrintString( 0, 0, "Fail" );
}
```

## IA-32e 모드용 세그먼트 디스크립터 추가

### 보호 모드 커널 엔트리 포인트에 디스크립터 추가

* 보호 모드용 커널 디스크립터를 기반으로 L 비트를 1, D 비트를 0으로 설정

```assembly
GDT:
    ; null 디스크립터
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00
    
    ; IA-32e 모드 커널용 코드 세그먼트 디스크립터
    IA_32eCODEDESCRIPTOR:
        dw 0xFFFF   ; Limit[15:0]
        dw 0x0000   ; Base[15:0]
        db 0x00     ; Base[23:16]
        db 0x9A     ; P=1, DPL=0, Code Segment, Execute/Read
        db 0xAF     ; G=1, D=0, L=1, Limit[19:16]
        db 0x00     ; Base[31:24]
    
    ; IA-32e 모드 커널용 데이터 세그먼트 디스크립터
    IA_32eDATADESCRIPTOR:
        dw 0xFFFF   ; Limit[15:0]
        dw 0x0000   ; Base[15:0]
        db 0x00     ; Base[23:16]
        db 0x92     ; P=1, DPL=0, Data Segment, Read/Write
        db 0xAF     ; G=0, D=0, L=1, Limit[19:16]
        db 0x00     ; Base[31:24]

    ; 보호 모드 커널용 코드 세그먼트 디스크립터
    ; 0~4GB 전체 영역을 포함하고 있기 때문에 선형 주소가 물리 주소와 일치
    CODEDESCRIPTOR:
        dw 0xFFFF       ; Limit[15:0]
        dw 0x0000       ; Base[15:0]
        db 0x00         ; Base[23:16]
        db 0x9A         ; P=1, DPL=0, Code Segment, Excute/Read
        db 0xCF         ; G=1, D/B=1, L=0, Limit[19:16]
        db 0x00         ; Base[31:24]

    ; 보호 모드 커널용 데이터 세그먼트 디스크립터
    ; 0~4GB 전체 영역을 포함하고 있기 때문에 선형 주소가 물리 주소와 일치
    DATADESCRIPTOR:
        dw 0xFFFF       ; Limit[15:0]
        dw 0x0000       ; Base[15:0]
        db 0x00         ; Base[23:16]
        db 0x92         ; P=1, DPL=0, Data Segment, Read/Write
        db 0xCF         ; G=1, D/B=1, L=0, Limit[19:16]
        db 0x00         ; Base[31:24]
GDTEND:
```

* 이전과 달리 보호 모드용 코드/데이터 세그먼트 디스크립터는 0x08/0x10에서 0x18/0x20으로 변경되었으므로 엔트리 포인트 파일 수정

```assembly
START:
    
    ; 생략

    ; jmp dword 0x18 보호 모드 커널용 코드 세그먼트 디스크립터를 0x18fh dlehd
    ; PROTECTEDMODE - $$ 레이블에서 현재 세그먼트의 시작 어드레스를 뺐으므로 .text 섹션에서 떨어진 오프셋을 나타냄
    ; $$ 세그먼트의 시작 어드레스
    ; PROTECTEDMODE - $$ + 0x10000 보호 모드 엔트리 포인트는 0x10000 어드레스에 로딩되므로 ( PROTECTEDMODE - $$ )에 0x10000을 더해주면 PROTECTEDMODE 레이블의 절대 어드레스를 구할 수 있음
    ; 0x18
    jmp dword 0x18: ( PROTECTEDMODE - $$ + 0x10000 )

; 보호 모드로 진입
[BITS 32]
PROTECTEDMODE:
    mov ax, 0x20    ; 보호 모드 커널용 데이터 세그먼트 디스크립터를 AX 레지스터에 저장

    ; 생략

    jmp dword 0x18: 0x10200 ; C언어 커널이 존재하는 0x10200 어드레스로 이동하여 커널 수행, 코드 디스크립터의 기준 주소가 0x0000이기 때문에 선형 주소와 물리 주소가 같은 상태
```

## IA-32e 모드 전환과 1차 정리

### 물리 메모리 확장 기능 활성화와 페이지 테이블 설정

* 물리 메모리 확장(PAE, Physical Address Extensions): CR4 레지스터의 PAE 비트(비트 5)가 담당하고 있으며 PAE 비트를 1로 설정해서 물리 메모리 확장 기능을 사용할 수 있음

```assembly
; CR4 컨트롤 레지스터의 PAE 비트를 1로 설정
mov eax, cr4        ; CR4 컨트롤 레지스터의 값을 EAX 레지스터에 저장
or eax, 0x20        ; PAE 비트(비트 5)를 1로 설정
mov cr4, eax        ; PAE 비트가 1로 설정된 값을 CR4 컨트롤 레지스터에 저장

; CR3 컨트롤 레지스터에 PML4 테이블의 어드레스 및 캐시 활성화
mov eax, 0x100000   ; EAX 테이블에 PM4 테이블이 존재하는 0x100000(1MB) 저장
mov cr3, eax        ; CR3 컨트롤 레지스터에 0x100000(1MB) 저장
```

### 64비트 모드 활성화와 페이징 활성화

* MSR(Model-Specific Register): 프로세서 모델에 따라 특수하게 정의된 레지스터로 크기는 64비트
    1. Debugging And Performance Monitoring
    2. Machine-Check
    3. Memory Type Range Registers, MTRRs
    4. Thermal And Power Management
    5. Instruction-Specific Support
    6. Processor Feature/Mode Support

* MSR은 MSR용 명령어인 RDMSR(Read From MSR), WRMSR(Write To MSR) 명령어를 사용해야만 함
    * ECX 레지스터에 읽을 MSR 어드레스를 넘겨주면 상위 32비트는 EDX, 하위 32비트는 EAX 레지스터에 저장

* IA32_EFER(Extended Feature Enable Register)는 프로세서 특성과 모드 지원에 속하는 MSR
    * SYSCALL/SYSRET 사용, IA-32e 모드 사용, EXB 사용 등을 제어 가능
    * IA32_EFER 어드레스는 0xC0000080 어드레스

* IA32_EFER 비트 구성
    * 63~12: 제조사마다 다름
    * 11(NXE): (읽기, 쓰기)No-Execute Enable의 약자로 Execute Disable 비트를 사용할지 여부를 표시, 1로 설정하면 페이지 엔트리의 EXB 비트 값에 따라 실행 불가 기능이 활성화/비활성화 됨, 0으로 설장하면 EXB 비트가 무시됨
    * 10(LMA): (읽기 전용)Long Mode Active의 약자로 현재 동작 중인 모드가 IA-32e 모드인지 여부를 표시, 1로 설정하면 프로세서 모드가 IA-32e 모드(호환 모드 또는 64비트)임을 나타내며, 0으로 설정하면 기타 모드임을 나타냄
    * 9: 예약됨
    * 8(LME): (읽기, 쓰기)Long Mode Enalbe의 약자로 IA-32e 모드를 활성화함을 의미, 1로 설정하면 IA-32e 모드를 활성화함을 나타내며 0으로 설정하면 비활성화함을 나타냄
    * 7~1: 예약됨
    * 0(SCE): (읽기 쓰기)System Call Enable의 약자로 SYSCALL, SYSRET 명령어를 사용할지 여부를 의미, 1로 설정하면 SYSCALL, SYSRET 명령어를 사용함을 나타내며, 0으로 설정하면 사용하지 않음

* LME 비트를 1로 설정하는 코드 추가

```assembly
mov ecx, 0xC0000080 ; IA32_EFER MSR 어드레스 저장
rdmsr               ; MSR 읽기
or eax, 0x0100       ; IA32_EFER MSR의 하위 32비트에서 LME 비트(비트 8)을 1로 설정
wrmsr               ; MSR 쓰기
```

### IA-32e 모드로 전환과 세그먼트 셀렉터 초기화

* CR0 레지스터 변경해 캐시, 페이징 활성화 이후 세그먼트 셀렉터를 IA-32e 커널용으로 교체

* 캐시 활성화
    * CR0 레지스터의 NW 비트(비트 29), CD 비트(비트 30) 0으로 설정
    * 페이지 테이블의 PCD 비트, PWT 비트 활성화

```assembly
; CR0 컨트롤 레지스터를 NW 비트(비트 29) 0, CD 비트(비트 30) 0, PG 비트(비트 31) 1로 설정하여 캐시 기능과 페이지 기능을 활성화
mov eax, cr0
or eax, 0xE0000000  ; NW, CD, PG 비트 모두 1로 설정
xor eax, 0x60000000 ; NW, CD 비트 XOR하여 0으로 설정
mov cr0, eax

jmp 0x08: 0x200000  ; CS 세그먼트 셀렉터를 IA-32e 모드용 코드 세그먼트 디스크립터로 교체하교 0x200000(2MB) 어드레스로 이동

; 0x200000(2MB) 어드레스에 위치하는 코드
[BITS 64]
; 기타 세그먼트 셀렉터를 IA-32e 모드용 데이터 세그먼트 디스크립터로 교체
mov ax, 0x10
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax

; 스택을 0x600000~0x6FFFFF 영역에 1MB 크기로 생성
mov ss, ax
mov rsp, 0x6FFF8
mov rbp, 0x6FFF8

; 생략
```

## IA-32e 모드용 커널 준비

### 커널 엔트리 포인트 파일 생성

* IA-32e 모드 커널 엔트리 포인트는 세그먼트 레지스터 교체, C언어 커널 엔트리 포인트 함수를 호출하는 역할

#### 커널 엔트리 포인트 파일

```assembly
[BITS 64]   ; 이하 코드는 64비트 코드로 설정

SECTION .text

extern Main ; 외부에서 정의된 함수를 쓸 수 있도록 선언함

; 코드 영역
START:
    mov ax, 0x10    ; IA-32e 모드 커널용 데이터 세그먼트 디스크립터를 AX 레지스터에 저장
    mov ds, ax      ; DS 세그먼트 셀렉터에 설정
    mov es, ax      ; ES 세그먼트 셀렉터에 설정
    mov fs, ax      ; FS 세그먼트 셀렉터에 설정
    mov gs, ax      ; GS 세그먼트 셀렉터에 설정
    
    ; 스택을 0x600000~0x6FFFFF 영역에 1MB 크기로 설정
    mov ss, ax      ; SS 세그먼트 셀렉터에 설정
    mov rsp, 0x6FFFF8   ; RSP 레지스터의 어드레스를 0x6FFFF8 설정
    mov rbp, 0x6FFFF8   ; RBP 레지스터의 어드레스를 0x6FFFF8 설정

    call Main       ; C언어 엔트리 포인트 함수(Main) 호출

    jmp $
```

#### C언어 엔트리 포인트 파일 생성

```c
#include "Types.h"  // 보호 모드와 같은 파일 사용

// 함수 선언
void kPrintString( int iX, int iY, const char* pcString );

void Main( void )
{
    kPrintString( 0, 10, "Switch To IA-32e Mode Success~!!" );
    kPrintString( 0, 11, "IA-32e C Language Kernel Start..............[Pass]" );
}

void kPrintString( int iX, int iY, const char* pcString )
{
    CHARACTER* pstScreen = ( CHARACTER* ) 0xB8000;
    int i;
    
    // X, Y 좌표를 이용해서 문자열을 출력할 어드레스를 계산
    pstScreen += ( iY * 80 ) + iX;

    // NULL이 나올 때까지 문자열 출력
    for( i = 0 ; pcString[ i ] != 0 ; i++ )
    {
        pstScreen[ i ].bCharactor = pcString[ i ];
    }
}
```

#### 링커 스크립트 파일 생성(02.Kernel64/elf_x86_64.x)

* 0x200000(2MB) 어드레스에 복사되어 실행될 것이므로 커널 이미지를 생성할 때 별도의 링크 스크립트 파일 필요함
    * 내용이 길어 교재에서 파일 복사해와 사용

#### makefile 생성

```makefile
# 빌드 환경 및 규칙 설정 

# 컴파일러 및 링커 정의
NASM64 = nasm -f elf64
GCC64 = x86_64-pc-linux-gcc.exe -c -m64 -ffreestanding
LD64 = x86_64-pc-linux-ld.exe -melf_x86_64 -T ../elf_x86_64.x -nostdlib -e Main -Ttext 0x200000

# 바이너리 이미지 생성을 위한 OBJCOPY 옵션 정의
OBJCOPY64 = x86_64-pc-linux-objcopy -j .text -j .data -j .rodata -j .bss -S -O binary

# 디렉터리 정의
OBJECTDIRECTORY = Temp
SOURCEDIRECTORY	= Source

# 빌드 항목 및 빌드 방법 설정

# 기본적으로 빌드를 수행할 목록
all: prepare Kernel64.bin

# 오브젝트 파일이 위치할 디렉터리를 생성
prepare:
	mkdir -p $(OBJECTDIRECTORY)

# 커널의 C 소스 파일에 대한 의존성 정보 생성
dep:
	@echo === Make Dependancy File ===
	make -C $(OBJECTDIRECTORY) -f ../makefile InternalDependency
	@echo === Dependancy Search Complete ===

# 디렉터리를 오브젝트 파일 디렉터리로 이동해서 의존성 파일 및 실행 파일을 생성
ExecuteInternalBuild: dep
	make -C $(OBJECTDIRECTORY) -f ../makefile Kernel64.elf

# 커널 이미지를 바이너리 파일로 변환하여 IA-32e 모드 바이너리 생성
Kernel64.bin: ExecuteInternalBuild
	$(OBJCOPY64) $(OBJECTDIRECTORY)/Kernel64.elf $@
		
# 소스 파일을 제외한 나머지 파일 정리	
clean:
	rm -f *.bin
	rm -f $(OBJECTDIRECTORY)/*.*

# Make에 의해 다시 호출되는 부분, Temp 디렉터리를 기준으로 수행됨

# 빌드할 어셈블리어 엔트리 포인트 소스 파일 정의, Temp 디렉터리를 기준으로 설정
ENTRYPOINTSOURCEFILE = ../$(SOURCEDIRECTORY)/EntryPoint.s
ENTRYPOINTOBJECTFILE = EntryPoint.o

# 빌드할 C 소스 파일 정의, Temp 디렉터리를 기준으로 설정
CSOURCEFILES = $(wildcard ../$(SOURCEDIRECTORY)/*.c)
ASSEMBLYSOURCEFILES = $(wildcard ../$(SOURCEDIRECTORY)/*.asm)
COBJECTFILES = $(notdir $(patsubst %.c,%.o,$(CSOURCEFILES)))
ASSEMBLYOBJECTFILES = $(notdir $(patsubst %.asm,%.o,$(ASSEMBLYSOURCEFILES)))

# 어셈블리어 엔트리 포인트 빌드
$(ENTRYPOINTOBJECTFILE): $(ENTRYPOINTSOURCEFILE)
	$(NASM64) -o $@ $<

# .c 파일을 .o 파일로 바꾸는 규칙 정의
%.o: ../$(SOURCEDIRECTORY)/%.c
	$(GCC64) -c $<

# .asm 파일을 .o 파일로 바꾸는 규칙 정의
%.o: ../$(SOURCEDIRECTORY)/%.asm
	$(NASM64) -o $@ $<

# 실제 의존성에 관련된 파일을 생성
InternalDependency:
	$(GCC64) -MM $(CSOURCEFILES) > Dependency.dep

# 실제 커널 이미지를 빌드
Kernel64.elf: $(ENTRYPOINTOBJECTFILE) $(COBJECTFILES) $(ASSEMBLYOBJECTFILES)
	$(LD64) -o $@ $^

# 현재 디렉터리의 파일 중, dependency 파일이 있으면 make에 포함	
ifeq (Dependency.dep, $(wildcard Dependency.dep))
include Dependency.dep
endif
```

## 보호 모드 커널과 IA-32e 모드 커널 통합

### 최상위 makefile 수정

* 02.Kernel64 디렉터리에서 make 수행하도록 변경하고 clean 부분에도 추가

### 부트 로더 파일 수정

* TOTALSECTORCOUNT 영역 이후에 2바이트를 할당해 보호 모드 커널 섹터 수 저장

```assembly
KERNEL32SECTORCOUNT:    dw 0x02 ; 보호 모드 커널의 총 섹터 수
```

### 이미지 메이커 프로그램 수정

* 아래와 같이 수정 후 빌드한 후에 최상위 디렉터리의 ImageMaker.exe 파일을 교체

#### Main()

* IA-32e 모드 커널 인자를 받을 수 있도록 수정
* IA-32e 모드 커널 이미지를 OS 이미지 파일에 쓰도록 코드 수정

#### WriteKernelInfomation()

* 총 섹터 수와 보호 모드 커널 섹터 수를 같이 기록

### 보호 모드 커널의 C언어 엔트리 포인트 파일 수정

* IA-32e 모드 지원 여부 판단하는 부분, IA-32e 모드 커널을 0x200000 어드레스로 복사하는 부분, IA-32e 모드로 전환하는 코드 호출 부분을 변경해야만 함

#### IA-32e 모드 커널 이미지 복사

* OS 이미지에서 IA-32e 모드 커널은 보호 모드 커널의 직후에 위치 + 부트 로더는 OS 이미지를 OS 이미지 파일의 내용 그대로 0x10000 위치에 옮겨줌

* 커널의 총 섹터 수가 7이고 보호 모드 커널의 섹터 수가 4라면 IA-32e 모드 커널의 크기는 3섹터이며 시작 어드레스는 0x10000에서 4섹터만큼 떨어진 (0x10000 + 512바이트 * 4)

![IA-32e 모드 커널 이미지의 시작 어드레스와 크기 계산 과정](https://camo.githubusercontent.com/02b3073a49ebd1fb5726edf84b9b2adde2ecefec/68747470733a2f2f692e696d6775722e636f6d2f307046514644372e706e67)
