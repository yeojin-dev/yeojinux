#!/bin/bash

qemu-system-x86_64 -m 64 -fda /Users/$1/projects/yeojinux/Disk.img -rtc base=localtime -M pc
