#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Makefile Syntax once and for all..."

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
# 找到 UBOOT_TARGETS := 开头的行，将其重置。注意使用单引号防止 shell 干扰
sed -i 's/^UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/' $UBOOT_MAKEFILE

# --- 4. 插入定义块 (安全注入法) ---
# 先删除之前可能失败的插入内容
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 创建一个临时文件，包含严格空格缩进的定义
# 注意：每行前面的空格是 2 个空格，严禁 TAB
cat << 'EOF' > device_meta.txt

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

EOF

# 寻找 Makefile 中最后一行 eval 的位置，并在其上方注入临时文件内容
# 'r' 命令会把文件内容读取并插入到匹配行之后，所以我们要找 eval 的前一行或者先插后删
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/i \\' $UBOOT_MAKEFILE # 先插一个空行保平安
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/e cat device_meta.txt' $UBOOT_MAKEFILE

# 检查是否有多余的空行或语法错误
echo "✅ Makefile patched via safe injection."
rm device_meta.txt

echo ">>> diy-part2.sh: Setup complete."
