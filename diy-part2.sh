#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Strategic Makefile Reconstruction..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 彻底清空 UBOOT_TARGETS 列表 (解决 405 报错的关键) ---
# 逻辑：删除从 UBOOT_TARGETS := 开始，一直到遇到 UBOOT_CONFIGURE_VARS 之前的所有行
# 这会把所有残留的 a64-olinuxino 等带 TAB 的行全部杀掉
sed -i '/UBOOT_TARGETS :=/,/UBOOT_CONFIGURE_VARS/ { /UBOOT_CONFIGURE_VARS/! d }' $UBOOT_MAKEFILE

# 在 UBOOT_CONFIGURE_VARS 之前插入我们干净的单一目标
sed -i '/UBOOT_CONFIGURE_VARS/i UBOOT_TARGETS := nc_link_t113s3\n' $UBOOT_MAKEFILE

# --- 4. 插入设备定义块 (确保 eval 行在最下面) ---
# 先删除重复定义
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 为了绝对安全，我们把原来的 eval 行也先删掉，然后再追加定义和 eval
sed -i '/$(eval $(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE

cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile fully reconstructed."
