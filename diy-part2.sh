#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运所有静态补丁 ---
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    mkdir -p $PATCH_TARGET_DIR
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied (001, 002, 003)."
else
    echo "❌ Error: patches-uboot directory not found!"
    exit 1
fi

# --- 2. 动态注入 Makefile 规则 (降维打击版) ---
# 注意：这里使用反斜杠转义 $ 符号
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'

# 注入到 Build/Prepare 钩子中
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 3. 注册与截胡 ---
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
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 4. 镜像布局修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 5. Kernel 补丁注入 ---
# 定义目标路径：OpenWrt 的 kernel 补丁通常放在 target/linux/sunxi/patches-6.x/ 下
# 但由于我们不知道具体版本，更稳妥的方法是直接打在 build_dir 的源码里（不推荐），
# 或者把补丁放到 target/linux/sunxi/patches-6.6/ (假设用 6.6)

# 更好的方法：利用 OpenWrt 的补丁机制
KERNEL_PATCH_DIR="target/linux/sunxi/patches-6.6" # 根据你的 OpenWrt 版本调整，可能是 6.1
mkdir -p $KERNEL_PATCH_DIR

if [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
    echo "✅ Linux Kernel patches copied."
fi

echo "✅ diy-part2.sh finished."
