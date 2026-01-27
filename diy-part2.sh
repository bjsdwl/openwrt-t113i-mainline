#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Reconfiguring uboot-sunxi for T113-i..."

# 1. 强制版本升级与 Hash 跳过 (为了匹配 v2025.01)
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 清理旧补丁并注入由 generate-patch.yml 生产的标准补丁
# 包含：Binman 定义, Defconfig (792M/扇区对齐), 0x128 物理解锁, DTS 本体
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches injected from patches-uboot directory."
else
    echo "⚠️ Warning: patches-uboot directory not found!"
fi

# 3. 在 Makefile 中注册 nc_link_t113s3 目标
# 我们需要确保它被加入 UBOOT_TARGETS 变量
if ! grep -q "nc_link_t113s3" $UBOOT_MAKEFILE; then
    # 在 UBOOT_TARGETS 定义行追加我们的目标
    sed -i '/UBOOT_TARGETS :=/ s/$/ nc_link_t113s3/' $UBOOT_MAKEFILE
    
    # 在文件末尾追加设备定义块
    cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
EOF
    echo "✅ Target nc_link_t113s3 registered in Makefile."
fi

# 4. 移除对默认目标的依赖，防止编译无用的镜像浪费时间
sed -i 's/CONFIG_PACKAGE_uboot-sunxi-orangepi_one=y/# CONFIG_PACKAGE_uboot-sunxi-orangepi_one is not set/g' .config 2>/dev/null || true

echo ">>> diy-part2.sh completed."
