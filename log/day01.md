# 맥에서 OS 개발 환경을 구축하자

## 준비물(아래 소스파일을 공식 사이트에서 다운로드)

* [binutils-2.32](https://ftp.gnu.org/gnu/binutils/)
* [gcc-8.2.0](http://mirrors-usa.go-parts.com/gcc/releases/)

## 환경변수 설정

```bash
export TARGET=x86_64-pc-linux  # 플랫폼
export PREFIX=/opt/cross  # 파일 복사 경로
export PATH=$PREFIX/bin:$PATH  # 실행 파일 경로가 저장된 셸 변수
```

## 어셈블러, 에뮬레이터, wget 설치

```bash
brew install qemu nasm wget
```

## binutils 설치

### binutils 압축 해제 후 루트 폴더에서

1. binutils에 포함된 옵션 설정

```bash
./configure --target=$TARGET --prefix=$PREFIX --enable-64-bit-bfd --disable-shared --disable-nls --disable-werror
```

2. 빌드를 수행할 OS에 대한 정보 수집

```bash
make configure-host
```

3. 빌드

```bash
make LDFLAGS="-all-static"
```

4. 설치

```bash
sudo make install
```

5. 테스트

```bash
➜  gcc-8.2.0 /opt/cross/bin/x86_64-pc-linux-ld --help | grep "supported"
/opt/cross/bin/x86_64-pc-linux-ld: supported targets: elf64-x86-64 elf32-i386 elf32-iamcu elf32-x86-64 pei-i386 pei-x86-64 elf64-l1om elf64-k1om elf64-little elf64-big elf32-little elf32-big plugin srec symbolsrec verilog tekhex binary ihex
/opt/cross/bin/x86_64-pc-linux-ld: supported emulations: elf_x86_64 elf32_x86_64 elf_i386 elf_iamcu elf_l1om elf_k1om
```

## gcc 설치

### gcc 압축 해제 후 루트 폴더에서

1. 빌드 시 필요한 패키지 자동 다운로드

```bash
./contrib/download_prerequisites
```

2. gcc에 포함된 옵션 설정

```bash
./configure --target=$TARGET --prefix=$PREFIX --disable-nls --enable-languages=c --without-headers --disable-shared --enable-multilib
```

3. 빌드를 수행할 OS에 대한 정보 수집

```bash
make configure-host
```

4. 빌드(매우 긴 시간이 걸림)

```bash
make all-gcc
```

5. 설치

```bash
sudo make install-gcc
```

6. 테스트

```bash
 ➜  gcc-8.2.0 /opt/cross/bin/x86_64-pc-linux-gcc -dumpspecs | grep -A1 multilib_options
*multilib_options:
m64/m32
```
