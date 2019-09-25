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
