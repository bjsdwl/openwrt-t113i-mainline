#!/bin/bash
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_PKG_DIR/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_PKG_DIR/Makefile
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
