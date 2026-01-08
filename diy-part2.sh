#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 0. 补丁格式自动修复 (核心救星) ---
# 在搬运之前，强制检查并修复所有补丁的末尾换行符问题
echo "🔍 Checking patch formats..."
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    for patch in $GITHUB_WORKSPACE/patches-uboot/*.patch; do
        # 如果文件最后没有换行符，强制追加一个
        if [ -n "$(tail -c 1 "$patch")" ]; then
            echo "🔧 Fixing missing newline in $(basename $patch)"
            echo "" >> "$patch"
        fi
    done
fi

# --- 1. 搬运静态补丁 ---
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    mkdir -p $PATCH_TARGET_DIR
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied."
else
    echo "❌ Error: patches-uboot not found!"
    exit 1
fi

# --- 2. 动态注入 Makefile 规则 (扁平化策略) ---
# 既然报错说找不到 arch/arm/dts/sun8i-t113-tronlong.dtb
# 我们就直接在 arch/arm/dts/Makefile 里注册这个文件名，不带 allwinner/ 前缀
# 注意：这里转义了 $ 符号
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'

# 注入到 Build/Prepare 钩子中
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 3. 注册 OpenWrt U-Boot 目标 ---
if ! grep -q "allwinner_t113_tronlong" $UBOOT_MAKEFILE; then
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_tronlong
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong T113-i
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef
EOF
fi

# 强制截胡
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 4. 镜像布局修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh finished."
