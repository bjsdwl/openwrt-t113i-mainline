#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Reconfiguring for T113-i Native Build (Hijack Mode)..."

# --- 2. 升级版本与清理补丁 ---
# 强制锁定 2025.01 版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 清理原有补丁，注入 generate-patch.yml 生成的专业补丁
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 实施“夺舍” (Hijack Orange Pi One) ---
# OpenWrt 默认会根据 Target Profile 强制编译 orangepi_one 的 U-Boot。
# 我们不抗争，直接修改 Makefile 中 orangepi_one 的定义，让它指向我们的 T113 配置。

# 删除原有的 orangepi_one 定义块
sed -i '/define U-Boot\/orangepi_one/,/endef/d' $UBOOT_MAKEFILE

# 注入被我们篡改的定义块
# 注意：NAME 依然保留 Orange Pi One 以防混淆，但 CONFIG 指向我们的 nc_link_t113s3
hijack_def="
define U-Boot/orangepi_one
  NAME:=Tronlong T113-i (Hijacked OPi One)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
"

# 将篡改后的定义插入到 BuildPackage 之前
sed -i "/\$(eval \$(call BuildPackage,U-Boot))/i $hijack_def" $UBOOT_MAKEFILE

echo "✅ Target orangepi_one has been hijacked to build T113-i."

# --- 4. 确保新 Defconfig 能被识别 ---
# 由于我们用了 UBOOT_CONFIG:=nc_link_t113s3，OpenWrt 会去 configs/ 找 nc_link_t113s3_defconfig
# 这个文件由我们的 011 补丁提供，所以这里不需要额外操作。

echo ">>> diy-part2.sh: Setup complete."
