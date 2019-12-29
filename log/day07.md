## GDT 정보 생성

* GDT(Global Desciptor Table) 객체는 연속된 디스크립터의 집합
    * MINT64 OS에서 사용하는 코드 세그먼트 디스크립터와 데이터 세그먼트 디스클비터를 연속된 어셈블리어 코드로 나타내면 그 전체 영역이 GDT
    * 널 디스크립터를 제일 앞에 추가 필요함
    * 널 디스크립터 : 프로세서에 의해 예약된 디스크립터로 모든 필드가 0으로 초기화된 디스크립터이며 일반적으로 참조되지 않음
* GDT는 디스크립터의 집합이므로 프로세서에 GDT의 시작 어드레스와 크기 정보를 로딩해야만 함
    * 47~16비트 : 32비트 기준 주소, 물리 어드레스 0을 기준으로 하는 선형 주소
    * 15~0비트 : 크기, 2바이트이므로 8바이트의 디스크립터는 65536/8 = 최대 8192개
* 디스크립터가 부족할 경우 LGT(Local Descriptor Table) 사용하기도 함(역시 최대 8192개) - MINT64 OS에서는 구현하지 않음

```assembly
GDTR:
    dw GDTEND - GDT - 1     ; 아래에 위치하는 GDT 테이블의 전체 크기
    dd GDT - $$ + 0x10000   ; 아래에 위치하는 GDT 테이블의 시작 어드레스
                            ; 실제 GDT가 있는 선형 주소 계산을 위해 현제 섹션 내의 GDT 오프셋에 세그먼트의 기준 주소인 0x10000을 더함

GDT:
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00

    ; 생략

    DATADESCRIPOR:
        dw 0xFFFF           ; Limit[15:0]
        dw 0x0000           ; Base[15:0]
        db 0x00             ; Base[23:16]
        db 0x92             ; P=1, DPL=0, Data Segment, Read/Write
        db 0xCF             ; G=1, D/B=1, L=0, Limit[19:16]
        db 0x00             ; Base[31:24]
GDTEND:
```
