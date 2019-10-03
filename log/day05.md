# 플로피 디스크에서 OS 이미지를 로딩하자

## BIOS 서비스와 소프트웨어 인터럽트

* BIOS는 키보드, 마우스에서 디스크, 프린터까지 거의 모든 PC 주변기기를 제어하는 기능 제공
* BIOS는 라이브러리 파일과 달리 함수의 어드레스를 인터럽트 벡터 테이블(Interrupt Vector Table)에 넣어두고 소프트웨어 인터럽트를 호출하는 방법을 사용함

#### 인터럽트 벡터 테이블

* 메모리 어드레스 0에 있는 테이블로 특정 번호의 인터럽트가 발생했을 때 인터럽트를 처리하는 함수(인터럽트 핸들러) 검색에 사용
* 테이블의 각 항목은 인덱스에 해당하는 인터럽트가 발생했을 때 처리하는 함수 어드레스가 저장되어 있음(4바이트)
* 최대 256개까지 설정 가능하므로 리얼 모드의 인터럽트 벡터 크기는 256 * 4 = 1,024바이트

#### 리얼 모드의 주요 인터럽트 벡터 테이블

|테이블 인덱스|용도|설명|
|---------|---|---|
|0x00|CPU Exception|Divide by zero|
|0x01|CPU Exception|Single step for debugging|
|0x02|CPU Exception|Non-maskable interrupt|
|0x03|CPU Exception|Breakpoint instruction|
|0x04|CPU Exception|Overflow trap|
|0x05|BIOS Service|Print screen|
|0x06|CPU Exception|Invalid opcode|
|0x07|CPU Exception|Coprocessor not available|
|0x08|IRQ0 Interrupt|Timer|
|0x09|IRQ1 Interrupt|Keyboard|
|0x0A|IRQ2 Interrupt|Slave interrupt|
|0x0B|IRQ3 Interrupt|COM2 port|
|0x0C|IRQ4 Interrupt|COM1 port|
|0x0D|IRQ5 Interrupt|Printer port 2|
|0x0E|IRQ6 Interrupt|Floppy Disk|
|0x0F|IRQ7 Interrupt|Printer port 1|
|0x10|BIOS Service|Video control service|
|0x13|BIOS Service|Disk I/O service|
|0x70|IRQ8 Interrupt|Real time clock|
|0x74|IRQ12 Interrupt|Mouse|
|0x75|IRQ13 Interrupt|Math coprocessor error|
|0x76|IRQ14 Interrupt|Hard disk|

* BIOS 디스크 서비스를 이용하려면 0x13 인터럽트를 발생시켜야 함
  * 임의로 인터럽트를 발생시키기 위해 소프트웨어 인터럽트 명령을 사용(int 0x13)
  * 어떤 함수의 어드레스를 인터럽트 벡터 테이블에 넣어뒀다면 int 명령으로 해당 함수 이동 가능

#### BIOS 서비스

* BIOS 기능을 사용할 때는 AX, BX, CX, DX 레지스터와 ES 세그먼트 레지스터를 사용해서 파라미터를 넘겨주며 결괏값도 레지스터를 통해 넘겨받음
  * 각 서비스마다 사용하는 레지스터가 다르기 때문에 확인해야만 함

1. 리셋
  * 입력
    * AH: 기능 번호(리셋을 이용하려면 0으로 설정)
    * DL: 드라이브 번호, 플로피 디스크는 0x00, 1번째 하드디스크는 0x80, 2번째 하드디스크는 0x81
  * 출력
    * AH: 기능 수행 후 드라이브 상태값, 성공(0x00) 외 나머지 값은 에러 발생
    * FLAGS의 CF 비트: 성공 시 CF 비트를 0으로 설정, 에러 발생 시 1로 설정
2. 섹터 읽기
  * 입력
    * AH: 기능 번호(섹터 읽기를 이용하려면 2로 설정)
    * AL: 읽을 섹터의 수(1~128)
    * CH: 트랙이나 실린더 번호, CL의 상위 2비트를 포함해 10비트 크기를 사용(0~1023 사이의 값)
    * CL: 읽기 시작할 섹터 번호(0~15의 값)
    * DH: 읽기 시작할 헤드 번호, 0~15의 값
    * DL: 드라이브 번호, 플로피 디스크는 0x00, 1번째 하드디스크는 0x80, 2번째 하드디스크는 0x81
    * ES:BX: 읽은 섹터를 저장할 메모리 어드레스, 64KB 경계에 걸치지 않게 지정
  * 출력
    * AH: 기능 수행 후 드라이브 상태값, 성공(0x00) 외 나머지 값은 에러 발생
    * AL: 읽은 섹터 수
    * FLAGS의 CF 비트: 성공 시 CF 비트를 0으로 설정, 에러 발생 시 1로 설정

## OS 이미지 로딩 구현

### 디스크 읽기 기능 구현

* MINT64 OS는 부트 로더, 보호 모드 커널, IA-32e 모드 커널로 구성되어 있는데 각 부분은 섹터 단위로 정렬해 하나의 부팅 이미지 파일로 합칠 예정
  * 디스크의 2번째 섹터부터 특정 메모리 어드레스에 복사하면 이미지 로딩
  * 메모리 어드레스는 임의로 정하면 되는데 여기서는 0x10000(64KB)에 로딩
  * 첫 번째 섹터는 부트 로더로, BIOS가 자동으로 메모리 로딩

```c
int main(int argc, char* argv[])
{
    int iTotalSectorCount = 1024;
    int iSectorNumber = 2;
    int iHeadNumber = 0;
    int iTrackNumber = 0;
    // 실제 이미지를 복사할 어드레스(물리 주소)
    char* pcTargetAddress = (char*) 0x10000;

    while (1)
    {
        // 전체 섹터 수를 감소시키면서 0이 될 때까지 섹터를 복사
        if (iTotlaSectorCount == 0)
        {
            break;
        }
        iTotalSectorCount = iTotalSectorCount - 1;

        // 1 섹터를 읽어들여서 메모리 어드레스에 복사
        if (BIOSReadOneSector(iSectorNumber, iHeadNumber, iTrackNumber, pcTargetAddress) == ERROR)
        {
            HandleDiskError();
        }

        // 1 tprxjsms 512(0x200)바이트이므로, 복사한 섹터 수만큼 어드레스 증가
        pcTargetAddress = pcTargetAddress + 0x200;

        // 섹터 -> 헤드 -> 트랙 순으로 번호 증가
        iSectorNumber = iSectorNumber + 1;
        if (iSectorNumber < 19)
        {
            continue;
        }

        iHeadNumber = iHeadNumber ^ 0x01;  // 헤드의 번호는 0과 1이 반복되므로 비트 연산자 활용
        iSectorNumber = 1;

        if (iHeadNumber != 0)
        {
            continue;
        }

        iTrackNumber = iTrackNumber + 1;
    }
    return 0;
}

// 발생한 에러를 처리하는 함수
void HandleDiskError()
{
    printf("DISK Error~!!");
    while (1);
}
```

```assembly
TOTALSECTORCOUNT:   dw 1024   ; 부트 로더를 제외한 MINT64 OS 이미지의 크기, 최대 1152 섹터(0x90000바이트)까지 가능
SECTORNUMBER:       db 0x02   ; OS 이미지가 시작하는 섹터 번호를 저장하는 영역
HEADNUMBER:         db 0x00   ; OS 이미지가 시작하는 헤드 번호를 저장하는 영역
TRACKNUMBER:        db 0x00   ; OS 이미지가 시작하는 트랙 번호를 저장하는 영역

    ; 디스크의 내용을 메모리로 복사할 어드레스(ES:BX)를 0x10000으로 설정
    mov si, 0x1000                    ; OS 이미지를 복사할 어드레스(0x10000)를 세그먼트 레지스터 값으로 변환
    mov es, si                        ; ES 세그먼트 레지스터에 값 설정
    mov bx, 0x0000                    ; BX 레지스터에 0x0000을 설정하여 복사할 어드레스를 0x1000:0000(0x10000)으로 최종 설정
    mov di, word [ TOTALSECTORCOUNT ] ; 복사할 OS 이미지의 섹터 수를 DI 레지스터에 설정

READDATA:                             ; 디스크를 읽는 코드의 시작
    ; 모든 섹터를 다 읽었는지 확인
    cmp di, 0                         ; 복사할 OS 이미지의 섹터 수를 0과 비교
    je READEND                        ; 복사할 섹터 수가 0이라면 다 복사했으므로 READEND로 이동
    sub di, 0x1                       ; 복사할 섹터 수를 1 감소

    ; BIOS Read Function 호출
    mov ah, 0x02                      ; BIOS 서비스 번호 2(Read Sector)
    mov al, 0x1                       ; 읽을 섹터 수는 1
    mov ch, byte [ TRACKNUMBER ]      ; 읽을 트랙 번호 설정
    mov cl, byte [ SECTORNUMBER ]     ; 읽을 섹터 번호 설정
    mov dh, byte [ HEADNUMBER ]       ; 읽을 헤드 번호 설정
    mov dl, 0x00                      ; 읽을 드라이브 번호(0=Floppy) 설정
    int 0x13                          ; 인터럽트 서비스 수행
    jc HANDLEDISKERROR                ; 에러가 발생했다면 HANDLEDISKERROR로 이동

    ; 복사할 어드레스와 트랙, 헤드, 섹터 어드레스 계산
    add si, 0x0020                    ; 512(0x200)바이트만큼 읽었으므로 이를 세그먼트 레지스터 값으로 변환
    mov es, si                        ; ES 세그먼트 레지스터에 더해서 어드레스를 한 섹터만큼 증가

    ; 한 섹터를 읽었으므로 섹터 번호를 증가시키고 마지막 섹터(18)까지 읽었는지 확인, 마지막 섹터가 아니면 섹터 읽기로 이동해서 다시 섹터 읽기 수행
    mov al, byte [ SECTORNUMBER ]     ; 섹터 번호를 AL 레지스터에 설정
    add al, 0x01                      ; 섹터 번호를 1 증가
    mov byte [ SECTORNUMBER ], al     ; 증가시킨 섹터 번호를 SECTORNUMBER에 다시 설정
    cmp al, 19                        ; 증가시킨 섹터 번호를 19와 비교
    jl READDATA                       ; 섹터 번호가 19미만이라면 READDATA로 이동

    ; 마지막 섹터까지 읽었으면(섹터 번호가 19이면) 헤드를 토글(0->1, 1->0)하고 섹터 번호를 1로 설정
    xor byte [ HEADNUMBER ], 0x01     ; 헤드 번호를 0x01과 XOR하여 토글
    mov byte [ SECTORNUMBER ], 0x01   ; 섹터 번호를 다시 1로 설정

    ; 만약 헤드가 1->0으로 바뀌었으면 양쪽 헤드를 모두 읽은 것이므로 아래로 이동하여 트랙 번호를 1 증가
    cmp byte [ TRACKNUMBER ], 0x01    ; 트랙 번호를 1 증가
    jmp READDATA                      ; READDATA로 이동
READEND;

HANDLEDDISKERROR:                     ; 에러를 처리하는 코드
    ; 생략
    jmp $
```

### 스택 초기화와 함수 구현

![스택](https://www.geeksforgeeks.org/wp-content/uploads/gq/2013/03/stack.png)

* x86 프로세서에서는 함수를 호출한 코드의 다음 어드레스, 즉 되돌아갈 어드레스를 저장하는 용도로 스택을 사용
  * 함수를 call하면 프로세서가 자동으로 되돌아올 어드레스를 스택에 저장하며 호출된 함수에 ret을 요청하면 자동으로 스택에서 어드레스를 꺼내 호출한 다음 어드레스로 이동
  * 복귀 어드레스 이외에 파라미터를 저장하는 역할도 겸함

#### 스택 관련 레지스터

![스택 관련 레지스터](http://cfile2.uf.tistory.com/image/210F03355974D8CE09DECF
)

* 스택 세그먼트 레지스터(SS): 스택 영역으로 사용할 세그먼트 기준 주소 저장
* 스택 포인터 레지스터(SP): 데이터를 저장하고 제거하는 상위(TOP) 저장
* 베이스 포인터 레지스터(BP): 스택의 기준 주소를 임시 저장할 때 사용

* 16비트 모드에서는 최대 64KB(0x10000)까지 스택 영역으로 지정 가능
  * SS에 0x10000 설정한다면 스택의 범위는 0x10000~0x1FFFF
  * 스택의 실제 크기는 SP, BP의 초깃값으로 설정

* 0x10000 어드레스부터는 OS 이미지가 로딩되므로 0x0000:0000 ~ 0x0000:FFFF 영역을 스택으로 사용

```asembler
; 스택을 0x0000:0000~0x0000:FFFF 영역에 64KB로 설정
mov ax, 0x0000  ; 스택 세그먼트의 시작 어드레스(0x0000)를 세그먼트 레지스터 값으로 변환
mov ss, ax      ; SS 세그먼트 레지스터에 설정
mov sp, 0xFFFE  ; SP 레지스터의 어드레스를 0xFFFE로 설정
mov bp, 0xFFFE  ; BP 레지스터의 어드레스를 0xFFFE로 설정
```

* x86 프로세서는 push, pop 명령을 지원
  1. push: SP 어드레스가 가리키는 어드레스에 데이터를 저장하고 SP 레지스터를 감소
  2. pop: SP 레지스터 증가
  3. 대량의 데이터 처리는 데이터 복사와 SP 레지스터의 값 변경으로도 가능

#### C와 어셈블리어 함수

* C의 호출 규약에 맞게 어셈블리어 코드 작성

```c
PrintMessage(iX, iY, pcString);
```

```assembly
push word [ pcString ]  ; 문자열의 어드레스를 스택에 삽입
push word [ iY ]        ; 화면의 Y 좌표를 스택에 삽입
push word [ iX ]        ; 화면의 X 좌표를 스택에 삽입
call PRINTMESSAGE       ; PRINTMESSAGE 함수 호출
add sp, 6               ; 스택에 삽입된 함수 파라미터 3개(2바이트 * 3개)를 제거
```

* 함수 구현
    * 스택 포인터 레지스터는 push, pop 명령에 따라 계속 변하기 때문에 고정된 값을 사용하는 베이스 포인터 레지스터가 효과적

```assembly
push bp                 ; 베이스 포인터 레지스터를 스택에 삽입
mov bp, sp              ; 베이스 포인터 레지스터에 스택 포인터 레지스터의 값을 설정, 앞으로는 베이스 포인터 레지스터를 이용해 파라미터에 접근
push es                 ; ES 세그먼트 레지스터부터 DX 레지스터까지 스택에 삽입, 함수에서 임시로 사용하는 레지스터로 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 원래 값으로 복원
push si
push di
push ax
push cx
push dx
; 기타 부분 생략
; 함수를 호출하면 스택에 복귀 어드레스가 삽입되며, 함수의 첫 부분에서 스택 프레임 레지스터를 삽입했음, 그래서 bp + 4 영역부터 읽어들임
; 16비트 모드이기 때문에 스택의 크기가 2바이트
mov ax, word [ bp + 4 ] ; 파라미터 1(iX)
mov bx, word [ bp + 6 ] ; 파라미터 2(iY)
mov cx, word [ bp + 8 ] ; 파라미터 3(pcString)
; context switching
pop dx
pop cx
pop ax
pop di
pop si
pop es
pop bp
ret                     ; 함수를 호출한 다음 코드의 위치로 복귀
```

#### 함수 형태로 수정된 PRINTMESSAGE 함수의 코드

```assembler
; 메시지를 출력하는 함수
; PARAM: x좌표, y좌표, 문자열
PRINTMESSAGE:
    push bp             ; 베이스 포인터 레지스터를 스택에 삽입
    mov bp, sp          ; 베이스 포인터 레지스터에 스택 포인터 레지스터의 값을 설정
    ; ES 세그먼트 레지스터부터 DX 레지스터까지 스택에 삽입
    push es
    push si
    push di
    push ax
    push cx
    push dx
    ; ES 세그먼트 레지스터에 비디오 모드 어드레스 설정
    mov ax, 0xB800      ; 비디오 메모리 시작 어드레스(0x0B8000)를 세그먼트 레지스터 값으로 변환
    mov es, ax          ; ES 세그먼트 레지스터에 설정

    ; X, Y의 좌표로 비디오 메모리의 어드레스를 계산함
    mov ax, word [ bp + 6 ] ; 파라미터 2(화면 좌표 Y)를 AX 레지스터에 설정
    mov si, 160             ; 한 라인의 바이트 수(2 * 80 컬럼)를 SI 레지스터에 설정
    mul si                  ; AX 레지스터와 SI 레지스터를 곱하여 화면 Y 어드레스 계산
    mov di, ax              ; 계산된 화면 Y 어드레스를 DI 레지스터에 설정

    ; X 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov ax, word [ bp + 4 ] ; 파라미터 1(화면 좌표 X)를 AX 레지스터에 설정
    mov si, 2               ; 한 문자를 나타내는 바이트 수(2)를 SI 레지스터에 설정
    mul si                  ; AX 레지스터와 SI 레지스터를 곱하여 화면 X 어드레스를 계산
    mov di, ax              ; 화면 Y 어드레스와 계산된 X 어드레스를 더해서 실제 비디오 메모리 어드레스를 계산

    ; 출력할 문자열의 어드레스
    mov si, word [ bp + 8 ] ; 파라미터 3(출력할 문자열의 어드레스)

.MESSAGELOOP:               ; 메시지 출력 루프
    mov cl, byte [ si ]     ; SI 레지스터가 가리키는 문자열 위치에서 한 문자를 CL 레지스터에 복사(CL 레지스터는 CX 레지스터의 하위 1바이트, 문자열은 1바이트면 충분)
    cmp cl, 0               ; 복사된 문자와 0을 비교
    je .MESSAGEEND          ; 복사한 문자의 값이 0이면 문자열이 종료되었음을 의미하므로 .MESSAGEEND로 이동하여 문자 출력 종료

    mov byte [ es:di ], cl  ; 0이 아니라면 비디오 메모리 어드레스 0xB800:di에 문자를 출력

    add si, 1               ; SI 레지스터에 1을 더하여 다음 문자열로 이동
    add di, 2               ; DI 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
    jmp .MESSAGELOOP        ; 메시지 출력 루프로 이동하여 다음 문자를 출력

.MESSAGEEND:
    pop dx
    pop cx
    pop ax
    pop di
    pop si
    pop es
    pop bp
    ret                     ; 함수를 호출한 다음 코드의 위치로 복귀
```

#### 보호 모드에서 사용되는 세 가지 함수 호출 규약 

* 호출 규약(Calling Convention): 함수를 호출할 때 파라미터와 복귀 어드레스 등을 지정하는 규칙

1. stdcall: 파라미터를 스택에 저장하며, 호출된 쪽에서 스택 정리
2. cdecl: 파라미터를 스택에 저장하지만, 함수를 호출한 쪽에서 스택 정리
3. fastcall: 일부 파라미터를 레지스터에 저장하되 나머지는 stdcall과 동일

```c
int Add(int iA, int iB, int iC)
{
    return iA + iB + iC;
}

void main(void)
{
    int iReturn;
    iReturn = Add(1, 2, 3);
}
```

* stdcall은 파라미터를 스택에 넣을 때 오른쪽에서 왼쪽 순서로 넣고 함수의 반환값은 EAX 레지스터를 사용하며 스택에서 파라미터를 제거하는 작업은 호출된 함수가 처리

```assembler
Add:
    push ebp                        ; 32비트 베이스 포인터 레지스터를 스택에 삽입
    mov ebp, esp                    ; 베이스 포인터 레지스터(BP)에 스택 포인터 레지스터(SP) 값을 설정
    mov eax, dword [ ebp + 8 ]      ; 32비트 파라미터 1(iA)을 32비트 AX 레지스터에 설정
    add eax, dword [ ebp + 12 ]     ; 파라미터 2
    add eax, dword [ ebp + 16 ]     ; 파라미터 3
    pop ebp
    ret 12                          ; 호출한 함수로 복귀한 후, 스택에 삽입된 파라미터 3개를 제거(3 * 4), "ret" "add esp, 12"와 같은 역할

main:
    push ebp                        ; BP 스택 삽입
    mov ebp, esp                    ; BP에 SP 값 설정
    sub esp, 8                      ; SP 레지스터에서 8만큼을 빼서 지역변수 iReturn을 위한 공간 할당
    push 3
    push 2
    push 1
    call Add                        ; Add 함수 호출
    mov dword[ ebp - 4 ], eax       ; iReturn 변수에 Add 함수의 변환값 저장
    ret
```

* cdecl 방식은 stdcall 방식과 달리 스택에서 파라미터를 제거하는 작업을 호출 함수가 처리

```assembler
Add:
    push ebp                        ; 32비트 베이스 포인터 레지스터를 스택에 삽입
    mov ebp, esp                    ; 베이스 포인터 레지스터(BP)에 스택 포인터 레지스터(SP) 값을 설정
    mov eax, dword [ ebp + 8 ]      ; 32비트 파라미터 1(iA)을 32비트 AX 레지스터에 설정
    add eax, dword [ ebp + 12 ]     ; 파라미터 2
    add eax, dword [ ebp + 16 ]     ; 파라미터 3
    pop ebp
    ret

main:
    push ebp                        ; BP 스택 삽입
    mov ebp, esp                    ; BP에 SP 값 설정
    sub esp, 8                      ; SP 레지스터에서 8만큼을 빼서 지역변수 iReturn을 위한 공간 할당
    push 3
    push 2
    push 1
    call Add                        ; Add 함수 호출
    mov dword[ ebp - 4 ], eax       ; iReturn 변수에 Add 함수의 변환값 저장
    add esp, 12                     ; SP에 12를 더하여 삽입한 파라미터 3개를 제거(cdecl 방식)
    ret
```

* fastcall 방식은 컴파일러마다 구현 방식이 다름 - MS 컴파일러의 기준으로는 ECX, EDX 레지스터 삽입하는 점을 제외하고 stdcall과 같음
* IA-32e 모드의 호출 규약은 fastcall 확장한 방식으로 파라미터 개수를 제한한다면 스택 관련 작업을 줄일 수 있음

```assembler
Add:
    push ebp                        ; 32비트 베이스 포인터 레지스터를 스택에 삽입
    mov ebp, esp                    ; 베이스 포인터 레지스터(BP)에 스택 포인터 레지스터(SP) 값을 설정
    mov eax, ecx                    ; 32비트 파라미터 1(iA)을 32비트 AX 레지스터에 설정
    add eax, edx                    ; 파라미터 2
    add eax, dword [ ebp + 8 ]      ; 파라미터 3(스택에 존재)
    pop ebp
    ret 4                           ; 호출한 함수로 복귀한 후, 스택에 삽입된 파라미터 1개를 제거(1 * 4), "ret" "add esp, 4"와 같은 역할

main:
    push ebp                        ; BP 스택 삽입
    mov ebp, esp                    ; BP에 SP 값 설정
    sub esp, 8                      ; SP 레지스터에서 8만큼을 빼서 지역변수 iReturn을 위한 공간 할당
    push 3
    mov edx, 2
    mov ecx, 1
    call Add                        ; Add 함수 호출
    mov dword[ ebp - 4 ], eax       ; iReturn 변수에 Add 함수의 변환값 저장
    ret
```

## 테스트를 위한 가상 OS 이미지 생성

* 테스트용이기 때문에 OS가 실행되었음을 표시하는 기능만 구현
* 섹터를 읽을 때마다 섹터 앞부분에 구현된 코드 실행하도록 설계
* 코드 반복을 줄이기 위해 NASM 어셈블러의 전처리문 사용

#### NASM 전처리문

* %assign i: i라는 변수를 지정하고 0으로 설정, `i = 0`과 동일
* %rep COUNT: $endrep까지의 라인을 COUNT번 반복하여 삽입
* %assign i i+1: i의 값을 1 증가, `i = i + 1`과 동일
* %if i == COUNT: i의 값이 COUNT와 같으면 아래의 라인을 삽입
* %else: %if의 조건이 일치하지 않으면 아래의 라인을 삽입
* %endif: %if 블록 종료
* %endrep: %rep 블록 종료

#### OS 이미지 통합

* 부트 로더 이미지와 OS 이미지를 cat 명령어를 이용해 통합시킴
* MINT64 OS는 0x10000부터 OS 이미지를 로딩하고 BIOS는 0xA0000 이후 영역을 비디오 메모리로 이용하기 때문에 OS 이미지는 576KB가 최대 용량이 됨
  * 이보다 더 큰 이미지는 압축하거나 보호 모드를 이용해서 추가로 로딩해야만 함
