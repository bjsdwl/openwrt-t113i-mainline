#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Makefile Orphan Recipes..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 彻底清理 UBOOT_TARGETS 块 (核心止血逻辑)
# 逻辑：删除从 UBOOT_TARGETS := 开始，直到遇到下一个 Makefile 关键字 (UBOOT_CONFIGURE_VARS) 之前的所有行
sed -i '/UBOOT_TARGETS :=/,/UBOOT_CONFIGURE_VARS/ { /UBOOT_CONFIGURE_VARS/! d }' $UBOOT_MAKEFILE
# 在 UBOOT_CONFIGURE_VARS 上方插入我们干净的单一目标定义
sed -i '/UBOOT_CONFIGURE_VARS/i UBOOT_TARGETS := nc_link_t113s3\n' $UBOOT_MAKEFILE

# 4. 插入子包定义块 (确保不重复且缩进正确)
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 使用 printf 确保没有多余的 TAB 污染
printf "define U-Boot/nc_link_t113s3\n" > device_meta.txt
printf "  NAME:=Tronlong T113-i (Native Binman)\n" >> device_meta.txt
printf "  BUILD_DEVICES:=xunlong_orangepi-one\n" >> device_meta.txt
printf "  UBOOT_CONFIG:=nc_link_t113s3\n" >> device_meta.txt
printf "  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin\n" >> device_meta.txt
printf "endef\n" >> device_meta.txt

# 将定义块插入到 eval 行之前
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/i \\' $UBOOT_MAKEFILE
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/e cat device_meta.txt' $UBOOT_MAKEFILE
rm device_meta.txt

echo "✅ diy-part2.sh: Makefile cleaned and nc_link_t113s3 injected."
