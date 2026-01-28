#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Final Makefile Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 外科手术：替换 UBOOT_TARGETS 列表
# 逻辑：
# A. 找到 UBOOT_TARGETS := 开始的行。
# B. 找到 $(eval $(call BuildPackage,U-Boot)) 这一行。
# C. 删除这中间的所有内容（包含那个巨大的目标列表）。
# D. 重新写入我们需要的内容。

# 删除从 UBOOT_TARGETS 开始直到文件末尾 eval 之前的所有内容
# 注意：这里我们保留 eval 行，只删它上面的
sed -i '/UBOOT_TARGETS :=/,/$(eval $(call BuildPackage,U-Boot))/ { /$(eval $(call BuildPackage,U-Boot))/!d }' $UBOOT_MAKEFILE

# 现在文件里 UBOOT_TARGETS 及其列表已经没了，eval 行还在。
# 我们在 eval 行之前插入新的定义。

# 准备新的内容块
cat << 'EOF' > makefile_inject.txt
UBOOT_TARGETS := nc_link_t113s3

define U-Boot/nc_link_t113s3
  NAME:=Tronlong T113-i (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

EOF

# 将内容块插入到 eval 行之前
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/i \\' $UBOOT_MAKEFILE
sed -i '/\$(eval \$(call BuildPackage,U-Boot))/e cat makefile_inject.txt' $UBOOT_MAKEFILE
rm makefile_inject.txt

echo "✅ diy-part2.sh: Makefile patched safely (Header preserved, Targets replaced)."
