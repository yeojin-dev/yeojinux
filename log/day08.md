## 보호 모드로 전환

### 프로세서에 GDT 정보 설정

* lgdt 명령어를 사용해 설정 가능

```assembly
lgdt[GDTR]      ; GDTR 자료구조를 프로세서에 설정하여 GDT 테이블을 로드
```

* 보호 모드로 전환하는 과정과 전환 후 인터럽트 설정을 완료하기 전까지는 인터럽트가 발생하지 않도록 하는 것이 좋음

### CR0 컨트롤 레지스터 설정

* CR0 레지스터 : 보호 모드 전환에 관련된 필드 외에 캐시, 페이징, 실수 연산 장치 등과 관련된 필드가 포함되어 있음

![CR0 레지스터](https://img1.daumcdn.net/thumb/R800x0/?scode=mtistory2&fname=https%3A%2F%2Ft1.daumcdn.net%2Fcfile%2Ftistory%2F2360E54E54DC910215)

|필드|의미|
|---|---|
|PE|Protection Enable의 약자로 보호 모드 진입 여부를 결정(1-보호 모드, 0-리얼 모드)|
|MP|Monitor Coprocessor의 약자로 wait, fwait 명령 실행 시 TS 필드 참고 여부를 설정(1로 설정하면 wait/fwait 명령 실행 시 TS 필드가 1이면 Device-not-available 예외가 발생하며, 0으로 설정하면 TS 필드의 값 무시)|
|EM|Emulation의 약자로 프로세서에 FPU 내장되었는지 여부(1-FPU 관련 명령 실행 시 Device-not-available/Invalid-opcode 예외 발생)를 나타내며 FPU가 없으면 소프트웨어적으로 연산을 처리할 목적으로 활용|
|TS|Task Switched의 약자로 태스크가 전환되었음을 나타냄(1로 설정하면 FPU 관련 명령 실행 시 Device-not-available 예외 발생하며 0이면 관련 명령을 정상 실행) - EM, MP 필드와 조합하여 FPU의 상태를 저장하고 복구하는 용도로 사용|
|ET|Extension Type의 약자로 1로 예약됨(과거 386, 486 프로세서에서 FPU를 지원한다는 것을 표시하는 요도로 사용)|
|NE|Numeric Error의 약자로 FPU 에러 처리 여부를 내부 인터럽트 또는 외부 인터럽트 중 선택(1로 설정하면 FPU 에러를 프로세서 내부 예외로 연결하며 0으로 설정하면 인터럽트로 연결함)|
|WP|Write Protect의 약자로 쓰기 금지 기능을 사용할지 여부를 결정(1로 설정하면 상위 권한(0~2)의 코드가 유저 권한(3)으로 설정된 읽기 전용 페이지에 쓸 수 없으며, 0으로 설정하면 페이지 속성에 관계 없이 쓸 수 있음)|
|AM|Alignment Mask의 약자로 어드레스 정렬 검사 기능을 사용할지 여부를 설정(1로 설정하면 데이터/어드레스가 특정 값의 배수에서 시작하는지 체크)|
|NW|Now-Write-Through의 약자로 캐시 정책 중 Write-Through를 사용할지 여부 설정(1로 설정하면 Write-back, 0으로 설정하면 Write-through 정책)|
|CD|Cache Disable의 약자로 프로세스의 캐시를 사용할지 여부 설정(1 사용, 0 미사용)|
|PG|Paging의 약자로 페이징을 사용할지 여부를 설정(1 사용, 0 미사용)|

* MINT64 OS에서는 세그멘테이션 이외 기능은 사용하지 않음
    * 프로세서에 FPU 내장되어 있으므로 EM 필드 0, ET 필드 1이지만 MP 필드, NE 필드를 1로 설정해 예외 발생하도록 설정

```assembly
mov eax, 0x4000003B     ; PG=0, CD=1, NW=0, AM=0, WP=0, NE=1, ET=1, TS=1, EM=0, MP=1, PE=1
mov cr0, eax            ; 보호 모드로 전환
```

##### Write-through, Write-back

* 캐시 메모리의 내용을 외부 메모리에 언제 쓸 것인가의 문제

1. Write-through : 메모리에 쓰기가 수행될 때마다 캐시의 내용과 외부 메모리의 내용을 모두 갱신
2. Write-back : 쓴 내용을 캐시에만 갱신하고 외부 메모리에 쓰는 시점을 최대한 뒤로 미룸(캐시를 버릴 때 외부 메모리에 쓰기 실행)

* 속도를 보면 Write-back 방식이 유리하지만 메모리 맵 I/O 방식을 사용하는 디바이스에서는 문제를 일으킴

### 보호 모드로 전환과 세그먼트 셀렉터 초기화

* 32비트 코드를 준비한 후 CS 세그먼트 셀렉터(레지스터)의 값을 바꾸는 시점
* CS 세그먼트 셀렉터를 교체하려면 jmp 명령과 세그먼트 레지스터 접두사를 사용해야만 함
    * 리얼 모드와 달리 보호 모드에서는 GDT의 시작 어드레스로부터 떨어진 거리(오프셋)을 셀렉터에 저장
    * 리얼 모드에서는 셀렉터에 세그먼트 기준 주소값을 그대로 저장

```assembly
jmp dword 0x08: ( PROTECTEDMODE - $$ + 0x10000 )  ; 커널 코드 세그먼트가 0x00을 기준으로 하는 반면 실제 코드는 0x10000을 기준으로 실행되고 있으므로 오프셋에 0x10000을 더해서 세그먼트 교체 후에도 같은 선형 주소를 가리키게 함

[BITS 32]
PROTECTEDMODE:
    mov ax, 0x10    ; 보호 모드 커널용 데이터 세그먼트 디스크립터를 AX 레지스터에 저장(3번째 디스크립터 사용)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; 스택을 0x00000000~0x0000FFFF 영역에 64KB 크기로 설정
    mov ss, ax          ; SS 세그먼트 셀렉터에 설정
    mov esp, 0xFFFE     ; ESP 레지스터 어드레스를 FFFE로 설정
    mov ebp, 0xFFFE     ; EBP 레지스터 어드레스를 FFFE로 설정
```

### 보호 모드용 PRINTSTRING 함수

```aseembly
; 메시지를 출력하는 함수
; 스택에 x 좌표, y 좌표, 문자열
PRINTMESSAGE:
    push ebp                    ; BP를 스택에 삽입
    mov ebp, esp                ; BP에 SP의 값을 설정
    ; 함수에서 임시로 사용하는 레지스터들로 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 원래 값으로 복원
    push esi
    push edi
    push eax
    push ecx
    push edx

    ; X, Y의 좌표로 비디오 메모리 어드레스를 계산함
    ; Y 좌표를 이용해서 먼저 라인 어드레스를 구함
    mov eax, dword [ ebp + 12 ] ; 파라미터 2(화면 좌표 Y)를 EAX 레지스터에 설정
    mov esi, 160                ; 한 라인의 바이트 수(2 * 80 컬럼)를 ESI 레지스터에 설정
    mul esi                     ; EAX 레지스터와 ESI 레지스터를 곱하여 화면 Y 레지스터 계산
    mov edi, eax                ; 계산된 Y 어드레스를 EDI 레지스터에 설정

    ; X 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov eax, dword [ ebp + 8 ]  ; 파라미터 1(화면 좌표 X)를 EAX 레지스터에 설정
    mov esi, 2                  ; 한 문자를 나타내는 바이트 수(2)를 ESI 레지스터에 설정
    mul esi                     ; EAX 레지스터와 ESI 레지스터를 곱하여 화면 X 어드레스를 계산
    add edi, eax                ; 화면 Y 어드레스와 계산된 X 어드레를 더해서 실제 비디오 메모리 어드레스를 계산

    ; 출력할 문자열의 어드레스
    mov esi, dword [ ebp + 16 ] ; 파라미터 3(출력할 문자열의 어드레스)

.MESSAGELOOP:                   ; 메시지 출력 루프
    mov cl, byte [ esi ]        ; ESI 레지스터가 가리키는 문자열 위치에서 한 문자를 CL 레지스터(ECX 레지스터의 하위 1바이트)에 복사
    cmp cl, 0                   ; 복사한 문자와 0 비교
    je .MESSAGEEND              ; 복사한 문자의 값이 0이면 문자열이 종료되었음을 의미하므로 .MESSAGEEND로 이동하여 문자 출력 종료
    mov byte [ edi + 0xB8000 ], cl  ; 0이 아니라면 비디오 메모리 어드레스 0xB8000 + EDI에 문자를 출력
                                    ; 보호 모드에서는 32비트 오프셋을 사용할 수 있으므로, 리얼 모드처럼 별도의 세그먼트 셀렉터를 사용하지 않고 바로 접근 가능
    add esi, 1                  ; ESI 레지스터에 1을 더하여 다음 문자열로 이동
    add edi, 2                  ; EDI 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
                                ; 비디오 메모리는 문자, 속성의 쌍으로 구성되므로 문자만 출력하려면 2를 더해야 함
    jmp .MESSAGELOOP            ; 메시지 출력 루프로 이동하여 다음 문자를 출력

.MESSAGEEND:
    pop edx                     ; 함수에서 사용이 끝난 EDX 레지스터에서 EBP 레지스터까지를 스택 값을 이용해 복원
    pop ecx
    pop eax
    pop edi
    pop esi
    pop ebp
    ret                         ; 함수를 호출한 다음 코드의 위치로 복귀
```
