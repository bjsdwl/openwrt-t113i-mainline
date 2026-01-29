#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Makefile Reconstruction (Trojan Horse Mode)..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 核平重建：截取文件头
sed -i '/include \$(INCLUDE_DIR)\/package.mk/q' $UBOOT_MAKEFILE

# 4. 追加定义 (特洛伊木马：用 orangepi_one 的名字，装 T113 的配置)
cat << 'EOF' >> $UBOOT_MAKEFILE

# --- Reconstructed by diy-part2.sh ---

define Package/U-Boot
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Allwinner sunxi platforms
  DEPENDS:=@TARGET_sunxi
  HIDDEN:=1
endef

# 这里虽然叫 orangepi_one，但 UBOOT_CONFIG 指向我们的 T113 配置
# 这样可以完美骗过 OpenWrt 的 Target Profile 依赖检查
define U-Boot/orangepi_one
  NAME:=Tronlong T113-i (Hijacked OPi One)
  BUILD_SUBTARGET:=cortexa7
  BUILD_TARGET:=sunxi
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

# 指定目标为这个被劫持的包
UBOOT_TARGETS := orangepi_one

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ diy-part2.sh: Trojan Horse loaded into Makefile."
