#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 0. 预下载并伪装 v2025.01 源码包 ---
mkdir -p dl
if [ ! -f "dl/uboot-sunxi-2025.01.tar.bz2" ]; then
    echo ">>> Downloading U-Boot v2025.01..."
    wget -nv https://ftp.denx.de/pub/u-boot/u-boot-2025.01.tar.bz2 -O dl/uboot-sunxi-2025.01.tar.bz2
fi

# --- 1. 清理并迁移补丁 ---
# 这一步会将我们在 generate-patch.yml 中生成的 3 个核心补丁放入编译目录
mkdir -p $UBOOT_DIR/patches
rm -f $UBOOT_DIR/patches/*
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    echo ">>> Migrating T113-i (Nagami-based) patches..."
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_DIR/patches/
fi

# --- 2. 重写 Makefile (改为 Nagami 策略模式) ---
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

# 注意：这里我们借用 Nagami 的配置名，但在 OpenWrt 里显示为我们的开发板
define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Nagami-Base)
  UBOOT_CONFIG:=nc_link_t113s3
endef

UBOOT_TARGETS := nc_link_t113s3

define Build/Prepare
	# 手动解压并应用补丁
	tar -xjf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(Build/Patch)
	# 提示：由于 Nagami 的 DTS 已经在主线 Makefile 中，这里不需要额外添加 dtb 映射
endef

$(eval $(call BuildPackage/U-Boot))
EOF

# --- 3. 修正镜像偏移 (全志主线标准：8KB 偏移) ---
# T113-i 必须从 SD 卡的 8KB 处 (Sector 16) 开始烧录
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 4. 修改编译种子配置 (强制关联) ---
# 确保 seed.config 中的包名与我们 Makefile 定义的 UBOOT_TARGETS 一致
sed -i 's/CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_tronlong=y/CONFIG_PACKAGE_uboot-sunxi-nc_link_t113s3=y/g' $GITHUB_WORKSPACE/seed.config

echo "✅ diy-part2.sh: Nagami replica mode configured."
