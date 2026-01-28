#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Strategic Makefile Reconstruction..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 彻底清除旧的目标列表 (解决 405 行报错) ---
# 逻辑：删除从 UBOOT_TARGETS 开始，一直到最后一个已知目标 libretech_all_h3_cc_h5 的所有行
# 然后在原地插入我们唯一的 nc_link_t113s3
sed -i '/UBOOT_TARGETS :=/,/libretech_all_h3_cc_h5/d' $UBOOT_MAKEFILE
# 在 UBOOT_CONFIGURE_VARS 之前插入我们的目标定义
sed -i '/UBOOT_CONFIGURE_VARS/i UBOOT_TARGETS := nc_link_t113s3\n' $UBOOT_MAKEFILE

# --- 4. 注入设备定义块 (插入到 eval 之前) ---
# 先删除可能存在的重复定义
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 准备定义内容 (严格空格缩进)
# 我们把它插入到第 481 行 (原来的 eval) 之前
printf "define U-Boot/nc_link_t113s3\n" > device_meta.txt
printf "  NAME:=Tronlong T113-i (Native Binman)\n" >> device_meta.txt
printf "  BUILD_DEVICES:=xunlong_orangepi-one\n" >> device_meta.txt
printf "  UBOOT_CONFIG:=nc_link_t113s3\n" >> device_meta.txt
printf "  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin\n" >> device_meta.txt
printf "endef\n\n" >> device_meta.txt

# 执行插入
sed -i '/\$(eval \$(call BuildPackage\/U-Boot))/i \\' $UBOOT_MAKEFILE
sed -i '/\$(eval \$(call BuildPackage\/U-Boot))/e cat device_meta.txt' $UBOOT_MAKEFILE

rm device_meta.txt

echo "✅ Makefile successfully reconstructed. Orphan recipes removed."
echo ">>> diy-part2.sh: Setup complete."
