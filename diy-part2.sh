#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"

echo ">>> Starting diy-part2.sh: Patch Injection Only..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_PKG_DIR/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_PKG_DIR/Makefile

# 2. 注入补丁 (特洛伊木马的核心)
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches injected successfully."
fi

echo ">>> diy-part2.sh: Ready."
