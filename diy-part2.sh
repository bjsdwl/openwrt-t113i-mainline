#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Makefile (Append Strategy)..."

# --- 2. 升级版本与清理补丁 ---
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 重写目标列表 ---
# 使用单引号强力替换，确保只有我们的目标
sed -i 's/^UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/' $UBOOT_MAKEFILE

# --- 4. 核心修复：重构文件尾部 ---
# 第一步：删除可能存在的旧定义 (防止重复运行时的堆积)
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 第二步：删除文件末尾的 BuildPackage 调用 (这是 Makefile 的“句号”)
# 我们稍后会把它加回来
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE

# 第三步：追加新的定义块和 BuildPackage 调用
# 使用 cat >> 追加模式，配合 'EOF' (单引号) 防止 Shell 尝试解析 $(...)
# 缩进严格使用 2 个空格
cat << 'EOF' >> $UBOOT_MAKEFILE

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

$(eval $(call BuildPackage,U-Boot))
EOF

echo "✅ Makefile tail reconstructed successfully."
echo ">>> diy-part2.sh: Setup complete."
