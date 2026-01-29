#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Trojan Horse Makefile Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 核平重建：截取文件头
sed -i '/include \$(INCLUDE_DIR)\/package.mk/q' $UBOOT_MAKEFILE

# 4. 追加定义 (特洛伊木马：用 orangepi_one 的名字，装 T113 的配置)
# 注意：我们去掉了 HIDDEN:=1，增加 DEFAULT:=y，尝试强制让它浮出水面
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  DEFAULT:=y
endef

# 劫持 orangepi_one
define U-Boot/orangepi_one
  NAME:=Tronlong T113-i (Hijacked OPi One)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Trojan Horse loaded."
