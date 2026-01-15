#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 0. 预下载并伪装 v2025.01 源码包 ---
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    echo ">>> Downloading U-Boot v2025.01..."
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 1. 清理补丁目录 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 2. 重写 Makefile 定向到 v2025.01 ---
cat <<'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1

PKG_SOURCE:=uboot-sunxi-$(PKG_VERSION).tar.bz2
PKG_HASH:=skip

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=sunxi
  BUILD_SUBTARGET:=cortexa7
  BUILD_DEVICES:=xunlong_orangepi-one
endef

define U-Boot/allwinner_t113_tronlong
  NAME:=Tronlong TLT113-MiniEVM
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef

UBOOT_TARGETS := allwinner_t113_tronlong

define Build/Prepare
	# 手动解压并处理目录名
	tar -xjf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(Build/Patch)
	echo "dtb-$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile
endef

$(eval $(call BuildPackage/U-Boot))
EOF

# --- 3. 修正镜像偏移 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
