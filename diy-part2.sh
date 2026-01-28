#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Strategic Makefile Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 彻底清空并重构 UBOOT_TARGETS (关键：只留一个目标)
# 删除原有 UBOOT_TARGETS 块，直到第一个 define 之前
sed -i '/UBOOT_TARGETS :=/,/define U-Boot\// { /define U-Boot\//! d }' $UBOOT_MAKEFILE
# 在 define 之前插入单一目标行
sed -i '/define U-Boot\//i UBOOT_TARGETS := nc_link_t113s3\n' $UBOOT_MAKEFILE

# 4. 插入子包定义块
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

cat << 'EOF' > device_meta.txt
define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

EOF

# 将定义块插入到 BuildPackage 之前
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/i \\' $UBOOT_MAKEFILE
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/e cat device_meta.txt' $UBOOT_MAKEFILE
rm device_meta.txt

echo ">>> diy-part2.sh: Makefile Reconstructed."
