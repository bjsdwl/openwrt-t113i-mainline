#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Makefile Truncate & Append..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 截断文件：保留头部模板，切除旧目标列表
# 这里的逻辑是：找到 UBOOT_TARGETS := 这一行，从这一行开始直到文件末尾全部删除
sed -i '/UBOOT_TARGETS :=/,$d' $UBOOT_MAKEFILE

# 4. 追加新结构
# 我们手动补上 UBOOT_TARGETS、我们的定义块，以及最后的 eval
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---
UBOOT_TARGETS := nc_link_t113s3

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile patched."
