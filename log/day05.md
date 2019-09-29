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
