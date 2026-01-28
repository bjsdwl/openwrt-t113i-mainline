#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Fixing Makefile (Printf Strategy)..."

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
sed -i 's/^UBOOT_TARGETS :=.*/UBOOT_TARGETS := nc_link_t113s3/' $UBOOT_MAKEFILE

# --- 4. 核心修复：使用 printf 重构文件尾部 ---

# 第一步：删除旧定义和尾部 eval
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/d' $UBOOT_MAKEFILE

# 第二步：使用 printf 严格写入新内容 (0 风险)
# 注意：\n 表示换行，行首的空格是明确的 2 个空格
printf "\n" >> $UBOOT_MAKEFILE
printf "define U-Boot/nc_link_t113s3\n" >> $UBOOT_MAKEFILE
printf "  NAME:=Tronlong T113-i (Native Binman)\n" >> $UBOOT_MAKEFILE
printf "  BUILD_DEVICES:=xunlong_orangepi-one\n" >> $UBOOT_MAKEFILE
printf "  UBOOT_CONFIG:=nc_link_t113s3\n" >> $UBOOT_MAKEFILE
printf "  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin\n" >> $UBOOT_MAKEFILE
printf "endef\n" >> $UBOOT_MAKEFILE
printf "\n" >> $UBOOT_MAKEFILE
printf "\$(eval \$(call BuildPackage,U-Boot))\n" >> $UBOOT_MAKEFILE

echo "✅ Makefile tail reconstructed using printf."

# --- 5. 自检 ---
# 打印最后 10 行确认结构正确
echo ">>> Checking Makefile tail:"
tail -n 10 $UBOOT_MAKEFILE

echo ">>> diy-part2.sh: Setup complete."
