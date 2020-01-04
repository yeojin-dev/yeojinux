# C언어로 커널을 작성하자

## 실행 가능한 C 코드 커널 생성 방법

* C 소스 파일을 추가하고 빌드하여 보호 모드 커널 이미지에 통합시키자!
* C 코드는 어셈블리어와 달리 컴파일과 링크 과정을 거쳐서 최종 결과물이 생성됨
    * 컴파일 : 소스 파일을 중간 단계인 오브젝트 파일로 변환(소스 파일을 해석해 코드/데이터 영역으로 나누고 메모리 영역에 대한 정보를 생성)
    * 링크 : 오브젝트 파일의 정보를 취합하여 실행 파일에 통합, 필요한 라이브러리 등을 연결해주는 역할

![커널 이미지 생성 과정](https://img1.daumcdn.net/thumb/R720x0.q80/?scode=mtistory2&fname=http%3A%2F%2Fcfile28.uf.tistory.com%2Fimage%2F26334E4A58116221154013)

### 빌드 조건과 제약 사항

* 엔트리 포인트가 C 코드를 실행하기 위한 제약 조건
    1. C 라이브러리를 사용하지 않게 빌드 : 부팅 직후 보호 모드 커널이 실행되면 C 라이브러리가 없기 때문임
    2. 0x10200 위치에서 실행하게끔 빌드 : 0x10000 위치에 보호 모드 엔트리 포인트가 있으므로 C 코드는 512바이트 이후인 0x10200 위치부터 로딩
        * 해당 위치에서 가장 먼저 실행되어야 하는 함수(엔트리 포인트) 위치
        * 선형 주소를 참조하게 생성된 코드/데이터 때문에 중요함 : C에서 전역 변수, 함수의 어드레스를 참조하는 경우 실제 존재하는 선형 주소로 변환됨
    3. 코드/데이터 외에 기타 정보를 포함하지 않은 순수한 바이너리 파일 형태 : ELF, PE 파일 포맷과 같이 특정 OS에서 실행할 수 있는 포맷으로 생성할 경우 해당 포맷을 해석해야 하는 불편함이 존재하기 때문

### 소스 파일 컴파일 - 라이브러리를 사용하지 않는 오브젝트 파일 생성 방법

* 필요한 gcc 옵션
    1. -c : 소스 파일을 컴파일 단계까지만 진행
    2. -ffreestanding : 라이브러리를 사용하지 않고 홀로 진행

### 오브젝트 파일 링크 - 라이브러리를 사용하지 않고 특정 어드레스에서 실행 가능한 커널 이미지 파일 생성 방법

* 실행 파일을 구성하는 섹션의 배치와 로딩될 어드레스, 코드 내에서 가장 먼저 실행될 코드인 엔트리 포인트를 지정해줘야 하기 때문에 까다로운 작업임
    * 섹션 배치를 다시 하는 이유 : 실행 파일이 링크될 때 코드나 데이터 이외에 디버깅 관련 정보와 심볼 정보 등이 포함되는데 이들 정보는 커널 실행과는 직접적인 관계가 없으므로 최종 바이너리 파일을 생성할 때는 제거하기 때문

#### 섹션 배치와 링커 스크립트, 라이브러리를 사용하지 않는 링크

* 섹션 : 실행 파일 또는 오브젝트 파일에 있으며 공통된 속성(코드, 데이터, 각종 심볼과 디버깅 정보)를 담는 영역

* 핵심 섹션들
    1. .text : 실행 가능한 코드로 일반적으로 read-only 속성
    2. .data : 초기화 된 데이터로 전역 변수, 정적 변수 등을 포함(읽기/쓰기 속성)
    3. .bss : 초기화되지 않은 데이터 영역으로 0으로 초기화되어 있음. 실행 파일, 오브젝트 파일에는 별도의 영역을 차지하지 않고 프로세스가 될 때 메모리를 할당 받음.

* 오브젝트 파일에는 각 섹션의 크기와 오프셋 정보만 들어 있음 - 다른 오브젝트 파일과 합쳐지면서 섹션 어드레스는 바뀔 수 있기 때문

* linking : 오브젝트 파일들을 결합하여 정리하고 실제 메모리에 로딩될 위치를 정하는 과정
* 링커 스크립트 : 각 섹션의 배치 순서와 시작 어드레스, 섹션 크기 정렬 등의 정보를 저장해 놓은 텍스트 파일

```
OUTPUT_FORMAT("elf32-i386", "elf32-i386",
	      "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(_start)
SEARCH_DIR("/opt/cross/i386-pc-linux/lib32"); SEARCH_DIR("/opt/cross/i386-pc-linux/lib");
SECTIONS
{
  /* Read-only sections, merged into text segment: */
  PROVIDE (__executable_start = SEGMENT_START("text-segment", 0x08048000)); . = SEGMENT_START("text-segment", 0x08048000) + SIZEOF_HEADERS;
  .interp         : { *(.interp) }
  .note.gnu.build-id  : { *(.note.gnu.build-id) }
  .hash           : { *(.hash) }
  .gnu.hash       : { *(.gnu.hash) }
  .dynsym         : { *(.dynsym) }
  .dynstr         : { *(.dynstr) }
  .gnu.version    : { *(.gnu.version) }
  .gnu.version_d  : { *(.gnu.version_d) }
  .gnu.version_r  : { *(.gnu.version_r) }
  .rel.init       : { *(.rel.init) }
  .rel.text       : { *(.rel.text .rel.text.* .rel.gnu.linkonce.t.*) }
  .rel.fini       : { *(.rel.fini) }
  .rel.rodata     : { *(.rel.rodata .rel.rodata.* .rel.gnu.linkonce.r.*) }
  .rel.data.rel.ro   : { *(.rel.data.rel.ro .rel.data.rel.ro.* .rel.gnu.linkonce.d.rel.ro.*) }
  .rel.data       : { *(.rel.data .rel.data.* .rel.gnu.linkonce.d.*) }
  .rel.tdata	  : { *(.rel.tdata .rel.tdata.* .rel.gnu.linkonce.td.*) }
  .rel.tbss	  : { *(.rel.tbss .rel.tbss.* .rel.gnu.linkonce.tb.*) }
  .rel.ctors      : { *(.rel.ctors) }
  .rel.dtors      : { *(.rel.dtors) }
  .rel.got        : { *(.rel.got) }
  .rel.bss        : { *(.rel.bss .rel.bss.* .rel.gnu.linkonce.b.*) }
  .rel.ifunc      : { *(.rel.ifunc) }
  .rel.plt        :
    {
      *(.rel.plt)
      PROVIDE_HIDDEN (__rel_iplt_start = .);
      *(.rel.iplt)
      PROVIDE_HIDDEN (__rel_iplt_end = .);
    }
  .init           :
  {
    KEEP (*(SORT_NONE(.init)))
  }
  .plt            : { *(.plt) *(.iplt) }
.plt.got        : { *(.plt.got) }
.plt.sec        : { *(.plt.sec) }
  .text           :
  {
    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(.text .stub .text.* .gnu.linkonce.t.*)
    /* .gnu.warning sections are handled specially by elf32.em.  */
    *(.gnu.warning)
  }
  .fini           :
  {
    KEEP (*(SORT_NONE(.fini)))
  }
  PROVIDE (__etext = .);
  PROVIDE (_etext = .);
  PROVIDE (etext = .);
  .rodata         : { *(.rodata .rodata.* .gnu.linkonce.r.*) }
  .rodata1        : { *(.rodata1) }
  .eh_frame_hdr   : { *(.eh_frame_hdr) *(.eh_frame_entry .eh_frame_entry.*) }
  .eh_frame       : ONLY_IF_RO { KEEP (*(.eh_frame)) *(.eh_frame.*) }
  .gcc_except_table   : ONLY_IF_RO { *(.gcc_except_table .gcc_except_table.*) }
  .gnu_extab   : ONLY_IF_RO { *(.gnu_extab*) }
  /* These sections are generated by the Sun/Oracle C++ compiler.  */
  .exception_ranges   : ONLY_IF_RO { *(.exception_ranges*) }
  /* Adjust the address for the data segment.  We want to adjust up to
     the same address within the page on the next page up.  */
  . = DATA_SEGMENT_ALIGN (CONSTANT (MAXPAGESIZE), CONSTANT (COMMONPAGESIZE));
  /* Exception handling  */
  .eh_frame       : ONLY_IF_RW { KEEP (*(.eh_frame)) *(.eh_frame.*) }
  .gnu_extab      : ONLY_IF_RW { *(.gnu_extab) }
  .gcc_except_table   : ONLY_IF_RW { *(.gcc_except_table .gcc_except_table.*) }
  .exception_ranges   : ONLY_IF_RW { *(.exception_ranges*) }
  /* Thread Local Storage sections  */
  .tdata	  :
   {
     PROVIDE_HIDDEN (__tdata_start = .);
     *(.tdata .tdata.* .gnu.linkonce.td.*)
   }
  .tbss		  : { *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon) }
  .preinit_array    :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  }
  .init_array    :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
    PROVIDE_HIDDEN (__init_array_end = .);
  }
  .fini_array    :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
    KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
    PROVIDE_HIDDEN (__fini_array_end = .);
  }
  .ctors          :
  {
    /* gcc uses crtbegin.o to find the start of
       the constructors, so we make sure it is
       first.  Because this is a wildcard, it
       doesn't matter if the user does not
       actually link against crtbegin.o; the
       linker won't look for a file to match a
       wildcard.  The wildcard also means that it
       doesn't matter which directory crtbegin.o
       is in.  */
    KEEP (*crtbegin.o(.ctors))
    KEEP (*crtbegin?.o(.ctors))
    /* We don't want to include the .ctor section from
       the crtend.o file until after the sorted ctors.
       The .ctor section from the crtend file contains the
       end of ctors marker and it must be last */
    KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
    KEEP (*(SORT(.ctors.*)))
    KEEP (*(.ctors))
  }
  .dtors          :
  {
    KEEP (*crtbegin.o(.dtors))
    KEEP (*crtbegin?.o(.dtors))
    KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
    KEEP (*(SORT(.dtors.*)))
    KEEP (*(.dtors))
  }
  .jcr            : { KEEP (*(.jcr)) }
  .data.rel.ro : { *(.data.rel.ro.local* .gnu.linkonce.d.rel.ro.local.*) *(.data.rel.ro .data.rel.ro.* .gnu.linkonce.d.rel.ro.*) }
  .dynamic        : { *(.dynamic) }
  .got            : { *(.got) *(.igot) }
  . = DATA_SEGMENT_RELRO_END (SIZEOF (.got.plt) >= 12 ? 12 : 0, .);
  .got.plt        : { *(.got.plt) *(.igot.plt) }
  .data           :
  {
    *(.data .data.* .gnu.linkonce.d.*)
    SORT(CONSTRUCTORS)
  }
  .data1          : { *(.data1) }
  _edata = .; PROVIDE (edata = .);
  . = .;
  __bss_start = .;
  .bss            :
  {
   *(.dynbss)
   *(.bss .bss.* .gnu.linkonce.b.*)
   *(COMMON)
   /* Align here to ensure that the .bss section occupies space up to
      _end.  Align after .bss to ensure correct alignment even if the
      .bss section disappears because there are no input sections.
      FIXME: Why do we need it? When there is no .bss section, we do not
      pad the .data section.  */
   . = ALIGN(. != 0 ? 32 / 8 : 1);
  }
  . = ALIGN(32 / 8);
  . = SEGMENT_START("ldata-segment", .);
  . = ALIGN(32 / 8);
  _end = .; PROVIDE (end = .);
  . = DATA_SEGMENT_END (.);
  /* Stabs debugging sections.  */
  .stab          0 : { *(.stab) }
  .stabstr       0 : { *(.stabstr) }
  .stab.excl     0 : { *(.stab.excl) }
  .stab.exclstr  0 : { *(.stab.exclstr) }
  .stab.index    0 : { *(.stab.index) }
  .stab.indexstr 0 : { *(.stab.indexstr) }
  .comment       0 : { *(.comment) }
  .gnu.build.attributes : { *(.gnu.build.attributes .gnu.build.attributes.*) }
  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */
  /* DWARF 1 */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }
  /* GNU DWARF 1 extensions */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }
  /* DWARF 1.1 and DWARF 2 */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  /* DWARF 2 */
  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }
  /* SGI/MIPS DWARF 2 extensions */
  .debug_weaknames 0 : { *(.debug_weaknames) }
  .debug_funcnames 0 : { *(.debug_funcnames) }
  .debug_typenames 0 : { *(.debug_typenames) }
  .debug_varnames  0 : { *(.debug_varnames) }
  /* DWARF 3 */
  .debug_pubtypes 0 : { *(.debug_pubtypes) }
  .debug_ranges   0 : { *(.debug_ranges) }
  /* DWARF Extension.  */
  .debug_macro    0 : { *(.debug_macro) }
  .debug_addr     0 : { *(.debug_addr) }
  .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink) *(.gnu.lto_*) }
}
```

* 위 파일에서 아래와 같은 구조가 반복됨 - 링커 스크립트 파일 수정(01.Kernel32/elf_i386.x)

```
SECTIONS
{
    SectionName Load Address :  ; 섹션 이름과 메모리에 로드할 어드레스
    {
        *(.text)                ; 오브젝트 파일의 섹션 중에 SectionName에 통합할 섹션 이름
        (생략)
        . = ALIGN (AlignValue)  ; 현재 어드레스를 Align Value에 맞춰 이동, 다음 섹션의 시작은 AlignValue의 변수
    } =0x00000000               ; 섹션을 채울 기본 값
    (생략)
}
```

* 새로운 링커 스크립트 사용하기 예

```bash
x86_64-pc-linux-ld -melf_i386 -T elf_i386.x -nostdlib Main.o -o Main.elf
```

1. -melf_i386 : 32비트 실행 파일 생성 옵션
2. -T : 링커 스크립트 파일 지정
3. -nostdlib : 표준 라이브러리 사용하지 않고 링크 수행
4. -o : 링크하여 생성할 파일 이름