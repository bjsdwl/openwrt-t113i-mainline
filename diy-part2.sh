#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 预下载源码 ---
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 2. 迁移补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 3. 重写 Makefile (关键修复：保持 OrangePi One 的外壳) ---
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
endef

# --- 特洛伊木马逻辑 ---
# 定义名必须是 xunlong_orangepi-one，以匹配 seed.config
# 但 UBOOT_CONFIG 指向 nc_link_t113s3，以编译 Nagami 代码
define U-Boot/xunlong_orangepi-one
  NAME:=Tronlong T113-i (Nagami Core)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
endef

UBOOT_TARGETS := xunlong_orangepi-one

define Build/Prepare
	tar -xjf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(Build/Patch)
endef

$(eval $(call BuildPackage/U-Boot))
EOF

# --- 4. 修改镜像物理偏移 (配合 Patch 002 的 0x140 / 160KB) ---
# 注意：这里只改 OpenWrt 默认的生成逻辑，实际上我们的 build.yml 会覆盖它
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    # 这里不需要改动太多，因为主要靠 build.yml 手动打包
    # 但为了防止报错，我们把它改回默认或者保持原样
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 5. 确保 seed.config 仍然指向 OrangePi One ---
# 不需要改动 seed.config，因为它本来就是 DEVICE_xunlong_orangepi-one=y
