#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Clean Build Strategy..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 截断文件头
sed -i '/include \$(INCLUDE_DIR)\/package.mk/q' $UBOOT_MAKEFILE

# 4. 追加定义 (DEFAULT:=y 是关键)
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  DEFAULT:=y
  HIDDEN:=0
endef

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

UBOOT_TARGETS := nc_link_t113s3

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile prepared with DEFAULT:=y"
