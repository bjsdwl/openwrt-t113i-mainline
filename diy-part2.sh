#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Strategic Hijack of orangepi_one target..."

# 1. 强制版本与清理
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches synchronized."
fi

# 2. 物理重建 Makefile (核平夺舍 orangepi_one)
# 理由：OpenWrt 的元数据系统对 orangepi_one 非常信任。我们直接替换其内部参数。
head -n 21 $UBOOT_MAKEFILE > Makefile.new
cat << 'EOF' >> Makefile.new

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

define U-Boot/orangepi_one
  NAME:=OrangePi One (T113-i Hijacked)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=orangepi_one
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

# 物理锁定唯一目标
UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF
mv Makefile.new $UBOOT_MAKEFILE

echo "✅ diy-part2.sh: Target 'orangepi_one' hijacked and logically re-aligned."
