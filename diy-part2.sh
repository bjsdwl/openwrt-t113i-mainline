#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Infinite Board Build..."

# --- 2. 升级版本与清理补丁 ---
# 强制锁定 2025.01 版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 清理原有补丁，注入我们的专业补丁
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 彻底清空并重构 UBOOT_TARGETS (解决“无限循环”关键) ---
# 先找到 UBOOT_TARGETS := 开始的地方，把后面带反斜杠的行全部干掉
# 然后强制重写 UBOOT_TARGETS 为仅包含我们要的目标
sed -i '/UBOOT_TARGETS :=/,/UBOOT_CONFIGURE_VARS/ { /UBOOT_CONFIGURE_VARS/! d }' $UBOOT_MAKEFILE
# 在 UBOOT_CONFIGURE_VARS 之前重新插入单一目标
sed -i '/UBOOT_CONFIGURE_VARS/i UBOOT_TARGETS := nc_link_t113s3\n' $UBOOT_MAKEFILE

# --- 4. 插入设备定义块 ---
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

device_def="
define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native 32-bit)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
"

# 确保定义块插入在 eval 之前
sed -i "/\$(eval \$(call BuildPackage,U-Boot))/i $device_def" $UBOOT_MAKEFILE

echo "✅ All other Sunxi boards removed from build list."
echo ">>> diy-part2.sh: Setup complete."
