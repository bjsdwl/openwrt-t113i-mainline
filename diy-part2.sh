#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"

# 1. 同步版本定义
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_PKG_DIR/Makefile

# 2. 注入 Patch Factory 生产的标准补丁
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
fi

# 3. 修改 Makefile 契约：指定产物为原生 with-spl.bin
if ! grep -q "UBOOT_IMAGE:=" $UBOOT_PKG_DIR/Makefile; then
    sed -i '/UBOOT_CONFIG:=/a \  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin' $UBOOT_PKG_DIR/Makefile
fi

# 4. 解决 nc_link 目标的定义
cat << 'EOF' >> $UBOOT_PKG_DIR/Makefile

define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Native Binman)
  UBOOT_CONFIG:=nc_link_t113s3
endef
EOF
