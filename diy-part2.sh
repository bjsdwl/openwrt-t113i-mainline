#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Makefile Nuclear Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 核平重建：截取文件头，丢弃所有旧躯干
# 我们只保留到 'include $(INCLUDE_DIR)/package.mk' 这一行
# 这通常是文件的前 20 行左右
sed -i '/include \$(INCLUDE_DIR)\/package.mk/q' $UBOOT_MAKEFILE

# 4. 追加完整的、纯净的定义
# 注意：这里我们手动补上了之前丢失的 Package/U-Boot 模板
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---

# 1. 补全丢失的基础包定义 (修复 missing TITLE 报错)
define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

# 2. 定义我们的目标板
define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

# 3. 指定唯一编译目标
UBOOT_TARGETS := nc_link_t113s3

# 4. 执行构建
$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile rewritten from scratch (Header preserved)."
