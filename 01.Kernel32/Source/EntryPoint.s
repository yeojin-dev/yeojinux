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
    jmp dword 0x08: ( PROTECTEDMODE - $$ + 0x10000 )

; 보호 모드로 진입
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

    ; 화면에 보호 모드로 전환되었다는 메시지를 찍는다
    push ( SWITCHSUCCESSMESSAGE - $$ + 0x10000 )    ; 출력할 메시지의 어드레스를 스택에 삽입
    push 2                                          ; 화면 Y 좌표(2) 스택에 삽입
    push 0                                          ; 화면 X 좌표(0) 스택에 삽입
    call PRINTMESSAGE
    add esp, 12                                     ; 삽입한 파라미터 제거

    jmp dword 0x08: 0x10200                         ; C 언어 커널이 존재하는 0x10200 어드레스로 이동하여 C 언어 커널 수행

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

; 데이터 영역
align 8, db 0                   ; 아래의 데이터들을 8바이트에 맞춰 정렬하기 위해 추가
dw 0x0000                       ; GDTR의 끝을 8바이트에 맞춰 정렬하기 위해 추가

GDTR:
    dw GDTEND - GDT - 1         ; 아래에 위치하는 GDT 테이블의 전체 크기
    dd ( GDT - $$ + 0x10000 )   ; 아래에 위치하는 GDT 테이블의 시작 어드레스

; GDT 테이블 정의
GDT:
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00

    CODEDESCRIPTOR:
        dw 0xFFFF           ; Limit[15:0]
        dw 0x0000           ; Base[15:0]
        db 0x00             ; Base[23:16]
        db 0x9A             ; P=1, DPL=0, Code Segment, Excute/Read
        db 0xCF             ; G=1, D/B=1, L=0, Limit[19:16]
        db 0x00             ; Base[31:24]    

    DATADESCRIPOR:
        dw 0xFFFF           ; Limit[15:0]
        dw 0x0000           ; Base[15:0]
        db 0x00             ; Base[23:16]
        db 0x92             ; P=1, DPL=0, Data Segment, Read/Write
        db 0xCF             ; G=1, D/B=1, L=0, Limit[19:16]
        db 0x00             ; Base[31:24]
GDTEND:

; 보호 모드로 전환되었다는 메시지
SWITCHSUCCESSMESSAGE: db 'Switch To Protected Mode Success!', 0

times (512 - ( $ - $$ ) % 512)    db 0x00   ; 512바이트를 맞추기 위해 남은 부분을 0으로 채움
