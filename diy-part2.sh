#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"

echo ">>> Starting diy-part2.sh: Patch Injection Only..."

# 1. 物理注入补丁 (保留这个！)
# 这是我们将 "Patch Factory" 生成的 T113 外科手术补丁注入的地方
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches synchronized."
else
    echo "⚠️ Warning: No patches found in $GITHUB_WORKSPACE/patches-uboot"
fi

# 2. ❌ 删除原来的 Makefile 重写逻辑
# 还原官方 Makefile 的全部功能，这样 BUILD_DEVICES 关联才能生效。
# 我们不需要修改 Makefile，因为我们已经通过 patch 修改了 defconfig 的内容。

echo "✅ diy-part2.sh completed."
