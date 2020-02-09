# yeojinux

## Build

```shell
$ export PATH=$PATH:/opt/cross/bin
$ make
```

## Clean Build

```shell
$ make clean
```

## Run in QEMU

```shell
$ qemu-system-x86_64 -L . -m 64 -fda ./Disk.img -rtc base=localtime -M pc
```
