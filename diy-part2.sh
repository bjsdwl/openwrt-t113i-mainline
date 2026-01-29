#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Ultimate Single-Target Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches synchronized."
fi

# 3. 核平重建 Makefile (保留前 21 行头部)
head -n 21 $UBOOT_MAKEFILE > Makefile.new
cat << 'EOF' >> Makefile.new

# --- Reconstructed for T113-i ---
define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

define U-Boot/orangepi_one
  NAME:=OrangePi One (Hijacked)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
endef

UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF
mv Makefile.new $UBOOT_MAKEFILE

echo "✅ diy-part2.sh: Done."
