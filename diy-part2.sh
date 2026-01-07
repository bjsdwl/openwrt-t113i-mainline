#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运静态补丁 (DTS & Defconfig) ---
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    mkdir -p $PATCH_TARGET_DIR
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied."
else
    echo "❌ Error: patches-uboot not found!"
    exit 1
fi

# --- 2. 动态注入 Makefile 规则 (最稳健的方式) ---
# 使用 OpenWrt 的 Build/Prepare 钩子，在源码解压后，
# 无论 Makefile 内容怎么变，直接在文件末尾追加我们的编译规则。
# 注意：U-Boot 2025.01 要求 dts 路径带 allwinner/ 前缀
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += allwinner/sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'

# 将注入命令插入到 OpenWrt 的 Makefile 中
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
