#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 0. 预下载 U-Boot 源码 (绕过 OpenWrt 下载逻辑) ---
# 这是最稳的办法，直接把文件放好，OpenWrt 就会以为已经下载完了
mkdir -p dl
if [ ! -f "dl/u-boot-2025.01.tar.bz2" ]; then
    echo ">>> Pre-downloading U-Boot v2025.01..."
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/u-boot-2025.01.tar.bz2
fi

# --- 1. 清理并搬运补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
    echo "✅ U-Boot patches copied."
fi

# --- 2. 重写 Makefile ---
# 注意：PKG_SOURCE 必须与我们要下载的文件名一致
cat <<'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1

# 显式指定文件名，匹配我们预下载的文件
PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.bz2
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

echo "✅ diy-part2.sh: Source pre-downloaded & Makefile patched."
