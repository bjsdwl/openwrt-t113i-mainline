#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"

echo ">>> Starting diy-part2.sh: Stealth Mode..."

# 1. 注入补丁 (这是唯一需要的动作)
# 补丁 099 会自动把 configs/orangepi_one_defconfig 变成 T113 的形状
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches injected. The swap will happen during 'make prepare'."
fi

# 2. 强制版本为 2025.01 以支持 T113 (R528)
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_PKG_DIR/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_PKG_DIR/Makefile

echo ">>> diy-part2.sh: Ready for standard compilation."
