#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 清理并搬运补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
    echo "✅ U-Boot patches copied."
fi

# --- 2. 重写 Makefile (核心修复：修正文件名) ---
cat <<'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1

# [Fix] 官方源码包名是 u-boot-2025.01.tar.bz2，不是 uboot-sunxi-xxx
PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=https://ftp.denx.de/pub/u-boot/
PKG_HASH:=skip

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=sunxi
  BUILD_SUBTARGET:=cortexa7
  BUILD_DEVICES:=xunlong_orangepi-one
endef

define U-Boot/allwinner_t113_tronlong
  NAME:=Tronlong T113-i
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef

UBOOT_TARGETS := allwinner_t113_tronlong

define Build/Prepare
	$(call Build/Prepare/Default)
	echo "dtb-$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile
endef

$(eval $(call BuildPackage/U-Boot))
EOF

# --- 3. 镜像布局修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh: Makefile patched with CORRECT source name."
