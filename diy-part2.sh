#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 强制迁移补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 2. 重写 Makefile (完全转向 nc_link_t113s3) ---
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

# 这里是灵魂！借用 Nagami 的源码配置名
define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Nagami-based)
  UBOOT_CONFIG:=nc_link_t113s3
endef

UBOOT_TARGETS := nc_link_t113s3

define Build/Prepare
	tar -xjf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(Build/Patch)
endef

$(eval $(call BuildPackage/U-Boot))
EOF

# --- 3. 修改镜像偏移 (Sector 16 / 8KB) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 4. 强制 seed.config 同步 ---
sed -i 's/CONFIG_PACKAGE_uboot-sunxi-.*/CONFIG_PACKAGE_uboot-sunxi-nc_link_t113s3=y/g' $GITHUB_WORKSPACE/seed.config
