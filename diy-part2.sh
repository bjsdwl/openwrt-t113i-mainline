#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Atomic Hijack of orangepi_one..."

# 1. 物理注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches synchronized."
fi

# 2. 彻底重写 Makefile
# 我们直接定义一个极其精简的 Makefile，只留 orangepi_one 这一条路
cat << 'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1
PKG_HASH:=skip

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=sunxi
  BUILD_SUBTARGET:=cortexa7
  BUILD_DEVICES:=xunlong_orangepi-one
endef

define U-Boot/orangepi_one
  NAME:=OrangePi One (Hijacked T113-i)
  UBOOT_CONFIG:=orangepi_one
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ $UBOOT_MAKEFILE has been atomically rewritten."
