#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Safe Makefile Patching..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 核心修复：替换 UBOOT_TARGETS 列表
# 逻辑：匹配以 UBOOT_TARGETS := 开头的行，直到遇到下一个空行（^$）
# 将这个块整体替换为单一目标定义。这样既删除了旧列表，又保留了上下文。
sed -i '/^UBOOT_TARGETS :=/,/^$/c\UBOOT_TARGETS := nc_link_t113s3' $UBOOT_MAKEFILE

# 4. 插入子包定义块
# 为了防止重复运行导致堆积，先尝试删除旧定义
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 使用 cat 追加定义，确保格式绝对正确 (2个空格缩进)
# 我们将其插入到 eval 行之前
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE

cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile patched safely."
