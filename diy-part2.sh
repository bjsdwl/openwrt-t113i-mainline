#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Reconstructing Makefile..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 精准替换 UBOOT_TARGETS (清理原有的几十个目标)
# 使用 sed 匹配 UBOOT_TARGETS := 这一行并整行替换，不再使用范围删除
sed -i '/UBOOT_TARGETS :=/c\UBOOT_TARGETS := nc_link_t113s3' $UBOOT_MAKEFILE

# 4. 插入子包定义块 (如果不存在则追加)
if ! grep -q "define U-Boot/nc_link_t113s3" $UBOOT_MAKEFILE; then
    sed -i '/define U-Boot\/Default/i \
define U-Boot/nc_link_t113s3\
  NAME:=Tronlong T113-i (Native Binman)\
  BUILD_DEVICES:=xunlong_orangepi-one\
  UBOOT_CONFIG:=nc_link_t113s3\
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin\
endef\
' $UBOOT_MAKEFILE
fi

echo ">>> diy-part2.sh: Makefile patched successfully."
