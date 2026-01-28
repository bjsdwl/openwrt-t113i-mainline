#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Makefile Syntax & Arch Mismatch..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 彻底重写 UBOOT_TARGETS ---
# 强制只保留一个 32 位目标，从源头切断 64 位编译尝试
sed -i "s/UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/g" $UBOOT_MAKEFILE

# --- 4. 注入设备定义块 (使用安全格式) ---
# 先删除所有现有的自定义定义块
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 使用 cat 追加到文件末尾，确保缩进为 2 个空格而不是 Tab
# 注意：一定要放在 $(eval $(call BuildPackage,U-Boot)) 这行之前
# 我们先通过 sed 删除最后一行 eval，然后追加定义，再把 eval 加回来
sed -i '/$(eval $(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE

cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native 32-bit)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ Makefile syntax fixed: UBOOT_TARGETS restricted and definition appended."
echo ">>> diy-part2.sh: Setup complete."
