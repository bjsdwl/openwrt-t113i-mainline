#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 清理并搬运补丁 ---
rm -rf $PATCH_TARGET_DIR
mkdir -p $PATCH_TARGET_DIR
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied."
fi

# --- 2. 注入 DTS 编译规则 ---
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
if ! grep -q "sun8i-t113-tronlong.dtb" $UBOOT_MAKEFILE; then
    sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE
fi

# --- 3. 注册并【强行限定】唯一 Target ---
# 我们不再使用 UBOOT_TARGETS +=，而是直接强制 UBOOT_TARGETS :=
# 这样 OpenWrt 就不会去尝试编译 BananaPi 或 OrangePi，从而避开报错。

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

# 关键改动：强制覆盖目标列表
sed -i 's/^UBOOT_TARGETS :=.*/UBOOT_TARGETS := allwinner_t113_tronlong/' $UBOOT_MAKEFILE

# --- 4. 镜像布局修正 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh finished successfully."
