#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# 1. 迁移 Step 1 补丁
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# 2. 预下载
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# 3. 偷梁换柱：将 OrangePi One 定义重定向到 nc_link_t113s3
sed -i 's/^PKG_VERSION:=.*/PKG_VERSION:=2025.01/' $UBOOT_MAKEFILE
sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' $UBOOT_MAKEFILE
sed -i 's/UBOOT_CONFIG:=orangepi_one/UBOOT_CONFIG:=nc_link_t113s3/' $UBOOT_MAKEFILE
sed -i 's/NAME:=Orange Pi One/NAME:=Nagami-Step1-PC0-LED/' $UBOOT_MAKEFILE
