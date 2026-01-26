#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 预下载源码 ---
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 2. 迁移补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 3. 偷梁换柱：原地修改 Makefile (不破坏元数据结构) ---
# 锁定 U-Boot 版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 核心动作：将 Orangepi One 的配置替换为 Nagami
# 这样 OpenWrt 以为自己在编译 OP One，实际上在编译 Nagami
# 1. 找到 OrangePi One 的定义块
# 2. 替换 BUILD_DEVICES
# 3. 替换 UBOOT_CONFIG

sed -i 's/xunlong_orangepi-one/xunlong_orangepi-one/g' $UBOOT_MAKEFILE # 保持 Device ID 不变，骗过 Target 扫描
# 修改 UBOOT_CONFIG 为我们的 Nagami 配置
sed -i '/UBOOT_CONFIG:=orangepi_one/c\  UBOOT_CONFIG:=nc_link_t113s3' $UBOOT_MAKEFILE
# 修改显示名称
sed -i '/NAME:=Orange Pi One/c\  NAME:=Tronlong T113-i (Nagami Base)' $UBOOT_MAKEFILE

# --- 4. 修改镜像物理偏移 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 5. seed.config 保持原样 (继续用 OrangePi One 的壳) ---
# 不需要改 seed.config，因为我们已经把 OrangePi One 的内核偷换了
