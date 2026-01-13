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

# --- 2. 重写整个 Makefile 结构 ---
# 我们不再用 sed 修改，而是直接构造一个支持单一变体的 Makefile
# 这样可以 100% 避免 "No rule to make target" 错误

cat <<'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-sunxi
PKG_VERSION:=2025.01
PKG_RELEASE:=1

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

# --- 3. 镜像布局修正 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh: Makefile overwritten for T113-i."
