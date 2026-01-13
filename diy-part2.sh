#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 0. 预下载并伪装源码包 (绝杀) ---
mkdir -p dl
# 1. 下载真正的 U-Boot 源码
if [ ! -f "dl/u-boot-2025.01.tar.bz2" ]; then
    echo ">>> Downloading official U-Boot source..."
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/u-boot-2025.01.tar.bz2
fi

# 2. 【关键】复制一份，命名为 OpenWrt 想要的名字
# 既然它非要找 uboot-sunxi-2025.01.tar.bz2，我们就给它这个名字
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    echo ">>> Creating symlink/copy for OpenWrt build system..."
    cp dl/u-boot-2025.01.tar.bz2 dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 1. 清理并搬运补丁 ---
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
    echo "✅ U-Boot patches copied."
fi

# --- 2. 重写 Makefile ---
cat <<'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1

# 这里可以不用改了，反正我们在 dl 目录里已经放好了它默认想要的文件
# 但为了保险，我们还是指定一下
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
  NAME:=Tronlong T113-i
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef

UBOOT_TARGETS := allwinner_t113_tronlong

define Build/Prepare
	# 因为文件名改了，解压出来的目录名可能还是 u-boot-2025.01
	# 我们手动解压，确保目录名正确
	tar -xjf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	
	# 应用补丁
	$(Build/Patch)
	
	# 注入 DTS
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

echo "✅ diy-part2.sh: Source spoofed & Makefile patched."
