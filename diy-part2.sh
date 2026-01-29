#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Logical Target Alignment..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches synchronized."
fi

# 3. 核平重建 Makefile (使用统一的 nc_link_t113s3 名字)
head -n 21 $UBOOT_MAKEFILE > Makefile.new
cat << 'EOF' >> Makefile.new

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Build)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

# 必须与上面的 define 后缀以及 seed.config 勾选名完全一致
UBOOT_TARGETS := nc_link_t113s3

$(eval $(call BuildPackage,U-Boot))
EOF
mv Makefile.new $UBOOT_MAKEFILE

echo "✅ diy-part2.sh: Makefile logically aligned with nc_link_t113s3."
