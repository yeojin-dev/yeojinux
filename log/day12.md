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
