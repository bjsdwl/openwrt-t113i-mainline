#!/bin/bash
UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# 1. 迁移补丁
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

# 3. 强行指定 nc_link_t113s3 目标 (特洛伊木马策略)
sed -i 's/^PKG_VERSION:=.*/PKG_VERSION:=2025.01/' $UBOOT_MAKEFILE
sed -i 's/^PKG_HASH:=.*/PKG_HASH:=skip/' $UBOOT_MAKEFILE
sed -i 's/UBOOT_CONFIG:=orangepi_one/UBOOT_CONFIG:=nc_link_t113s3/' $UBOOT_MAKEFILE
sed -i 's/NAME:=Orange Pi One/NAME:=Tronlong T113-i (Nagami Base)/' $UBOOT_MAKEFILE

# 4. 修改镜像偏移 (配合 160KB 逻辑)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
