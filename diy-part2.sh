#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"

# --- 1. 预下载 U-Boot v2025.01 源码 ---
# 这一步非常重要，防止 OpenWrt 下载旧版或连接超时
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    echo ">>> Downloading U-Boot v2025.01..."
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 2. 迁移补丁 (Generate-Patch 生成的产物) ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    echo ">>> Copying patches..."
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 3. 锁定版本号 ---
# 我们只修改版本变量，不修改 Target 定义，保证 OpenWrt 扫描通过
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_DIR/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_DIR/Makefile

# 4. (可选) 修改镜像偏移逻辑
# 虽然我们在 build.yml 里手动打包，但改一下这个能防止 OpenWrt 默认流程报错
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
