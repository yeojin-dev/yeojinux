#!/bin/bash

qemu-system-x86_64
    -m 64  # 64M 메모리 할당
    -fda /Users/$1/projects/yeojinux/Disk.img  # 플로피 디스크 이미지 지정
    -rtc base=localtime  # 시간 설정
    -M pc  # 일반 PC 환경으로 설정
