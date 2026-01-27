#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Safe-repairing uboot-sunxi for T113-i..."

# 1. 强制版本升级与 Hash 跳过
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 清理旧补丁并注入由 generate-patch.yml 生产的标准补丁
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Patches injected."
fi

# 3. 修正 Makefile：安全地注册 nc_link_t113s3
# 不要直接追加到 UBOOT_TARGETS 这一行（防止破坏末尾的反斜杠）
# 我们在 BuildPackage 调用之前插入定义

# 先移除之前可能失败的追加内容（防止重复运行出错）
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 使用一个临时变量来存储我们的定义块（注意：此处必须使用 2 个空格，严禁使用 Tab）
define_block="
define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
"

# 将定义块插入到 $(eval $(call BuildPackage,U-Boot)) 之前
sed -i "/\$(eval \$(call BuildPackage,U-Boot))/i $define_block" $UBOOT_MAKEFILE

# 安全地将 nc_link_t113s3 添加到 UBOOT_TARGETS 列表
# 找到 UBOOT_TARGETS := 这一行，在它下面新起一行添加我们的目标
if ! grep -q "nc_link_t113s3" $UBOOT_MAKEFILE; then
    # 注意：这里使用一个空行和目标，确保不干扰原来的列表
    sed -i '/UBOOT_TARGETS :=/a \	nc_link_t113s3 \\' $UBOOT_MAKEFILE
    echo "✅ nc_link_t113s3 added to UBOOT_TARGETS."
fi

echo ">>> diy-part2.sh completed successfully."
