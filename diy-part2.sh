#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Makefile Trojan Horse Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 截断文件：只保留头部包含文件 (前 ~20 行)
sed -i '/include \$(INCLUDE_DIR)\/package.mk/q' $UBOOT_MAKEFILE

# 4. 重建定义
# 关键点：
# 1. 补全 Package/U-Boot 模板
# 2. 定义 U-Boot/orangepi_one (必须叫这个名字，配合 Target Profile)
# 3. 指定 UBOOT_TARGETS := orangepi_one
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

# 特洛伊木马：名字是 OrangePi One，实际上是 T113-i
define U-Boot/orangepi_one
  NAME:=Tronlong T113-i (Hijacked OPi One)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Makefile rewritten. Target: orangepi_one (T113 payload)."
