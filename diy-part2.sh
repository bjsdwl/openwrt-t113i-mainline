#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Architecture Mismatch..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 彻底清空并重写 UBOOT_TARGETS (关键修复) ---
# 找到 UBOOT_TARGETS := 开头的行，并将其整行替换为仅包含我们的目标
# 这样可以阻止构建系统去尝试编译 64位的 a64-olinuxino 等不兼容目标
sed -i "s/UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/g" $UBOOT_MAKEFILE

# --- 4. 插入设备定义块 ---
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 这里的定义块不仅要包含 CONFIG，还要声明它属于 sunxi 构建目标
device_def="
define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native 32-bit)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
"

# 确保定义块被插入到正确的位置（BuildPackage 之前）
sed -i "/\$(eval \$(call BuildPackage,U-Boot))/i $device_def" $UBOOT_MAKEFILE

echo "✅ UBOOT_TARGETS restricted to nc_link_t113s3 only."
echo ">>> diy-part2.sh: Setup complete."
