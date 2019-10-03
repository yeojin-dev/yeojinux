[ORG 0x00]
[BITS 16]

SECTION .text       ; text 섹션(세그먼트)을 정의

jmp 0x1000:START    ; CS 세그먼트 레지스터에 0x1000을 복사하면서, START 레이블로 이동

SECTORCOUNT:    dw 0x0000   ; 현재 실행 중인 섹터 번호를 저장
TOTALSECTORCOUNT    equ 1024    ; 가상 OS의 총 섹터 수(최대 1152섹터까지 가능)

; 코드 영역
START:
    mov ax, cs      ; CS 세그먼트 레지스터의 값을 AX 레지스터에 저장
    mov ds, ax      ; AX 레지스터의 값을 DS 세그먼트 레지스터에 저장
    mov ax, 0xB800  ; 비디오 메모리 어드레스인 0x0B8000을 세그먼트 레지스터 값으로 변환
    mov es, ax      ; ES 세그먼트 레지스터에 설정

    ; 각 섹터 별로 코드를 생성
    %assign i 0     ; i라는 변수를 지정하고 0으로 초기화
    %rep TOTALSECTORCOUNT   ; TOTALSECTORCOUNT에 저장된 값만큼 아래 코드를 반복
        %assign i i+1       ; i를 1 증가

        ; 현재 실행 중인 코드가 포함된 섹터의 위치를 화면 좌표로 변환
        mov ax, 2       ; 한 문자를 나타내는 바이트 수(2)를 AX 레지스터에 설정
        mul word [ SECTORCOUNT ]    ; AX 레지스터와 섹터 수를 곱함
        mov si, ax      ; 곱한 결과를 SI 레지스터에 설정
    
        mov byte [ es:si + ( 160 * 2 ) ], '0' + (i % 10) ; 계산된 결과를 비디오 메모리에 오프셋으로 삼아 3번째 라인부터 화면에 0을 출력
        add word [ SECTORCOUNT ], 1 ; 섹터 수를 1 증가
    
        %if i == TOTALSECTORCOUNT
            jmp $   ; 마지막 섹터이면 무한 루프
        %else
            jmp ( 0x1000 + i * 0x20 ):0x0000    ; 다음 섹터 오프셋으로 이동
        %endif

        ; $(현재 라인의 어드레스), $$(현재 섹션(.text)의 시작 어드레스), $-$$(현재 섹션을 기준으로 하는 오프셋)
        ; 현재 섹터 내 남은 영역을 0으로 채움
        times (512 - ( $ - $$ ) % 512)    db 0x00
    %endrep
