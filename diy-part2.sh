#!/bin/bash

# --- 1. 搬运补丁 (Patches Injection) ---
UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# 清理旧补丁并创建目录
rm -rf $PATCH_TARGET_DIR
mkdir -p $PATCH_TARGET_DIR

# 搬运新生成的补丁
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ U-Boot patches copied to $PATCH_TARGET_DIR"
fi

# --- 2. 动态注入 Makefile 规则 (DTS Support) ---
# 这一步是为了让 OpenWrt 构建系统知道我们要编译 sun8i-t113-tronlong.dtb
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'

# 防止重复注入
if ! grep -q "sun8i-t113-tronlong.dtb" $UBOOT_MAKEFILE; then
    sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE
    echo "✅ Makefile updated for DTS support."
fi

# --- 3. 注册新 Target (OpenWrt Menuconfig) ---
# 这让我们可以在 menuconfig 中看到 Tronlong T113 选项 (虽然我们是用命令行选的)
if ! grep -q "allwinner_t113_tronlong" $UBOOT_MAKEFILE; then
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_tronlong
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong T113-i
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef
EOF
    # 强制将我们的 Target 加入构建列表
    sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS += allwinner_t113_tronlong' $UBOOT_MAKEFILE
    echo "✅ New U-Boot target registered."
fi

# --- 4. 镜像布局修正 (SD Card Offset) ---
# 确保生成的烧录脚本使用正确的 8KB (16 sectors) 偏移
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
    echo "✅ Image generation offset fixed (8KB)."
fi

echo "✅ diy-part2.sh execution completed."
