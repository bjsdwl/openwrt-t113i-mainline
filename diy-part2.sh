#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Surgical Makefile Reconstruction..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 精准清理 UBOOT_TARGETS (解决 405 和 TITLE 缺失问题) ---
# 我们不再使用范围删除，而是先将 UBOOT_TARGETS 这一行直接替换掉
sed -i "s/^UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/g" $UBOOT_MAKEFILE

# 然后，针对紧随其后的那些带反斜杠的“孤儿行”（如 a64-olinuxino \），
# 我们精准删除所有以 Tab 开头且包含反斜杠的行，直到遇到下一个定义块
# 这样可以保留 Makefile 顶部的 Package/U-Boot 模板
sed -i '/UBOOT_TARGETS := nc_link_t113s3/,/UBOOT_CONFIGURE_VARS/ { /nc_link_t113s3/! { /UBOOT_CONFIGURE_VARS/! d } }' $UBOOT_MAKEFILE

# --- 4. 注册并补全设备定义块 ---
# 我们在定义中显式加入 TITLE 字段，双重保险
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  TITLE:=U-Boot for Tronlong T113-i
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

EOF

# 确保最后一行 eval 存在且唯一
sed -i '/$(eval $(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE
echo '$(eval $(call BuildPackage,U-Boot))' >> $UBOOT_MAKEFILE

echo "✅ diy-part2.sh: Makefile surgically repaired."
