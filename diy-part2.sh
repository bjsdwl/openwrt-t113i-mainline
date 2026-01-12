#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运补丁 (强制覆盖) ---
rm -rf $PATCH_TARGET_DIR
mkdir -p $PATCH_TARGET_DIR
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied."
fi

# --- 2. DTS 注入 ---
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 3. 注册新 Target ---
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
# 确保 OpenWrt 知道我们要把 U-Boot 写到 Sector 16 (8KB) 之后
# CONFIG_SUNXI_UBOOT_BIN_OFFSET=8 (Sector 16 -> 8KB? No, standard is sectors? Let's assume Kbytes in Makefile context)
# OpenWrt sunxi image Makefile usually uses dd bs=1024 seek=...
# seek=8 (8KB) is for SPL.
# seek=40 (40KB) is standard for U-Boot Legacy.
# 但因为我们在 Defconfig 设了 RAW_SECTOR=0x110 (272 sectors = 136KB)
# 如果我们把 raw binary (包含 SPL+Uboot) 写到 SD 的开头 (8KB 偏移), 
# 那么 U-Boot Proper 的位置必须跟 Defconfig 里的 0x110 吻合。

IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
# 这里我们不做过激修改，只要保证 raw binary 被保留即可
if [ -f "$IMG_MAKEFILE" ]; then
    # 强制让 OpenWrt 使用 raw binary (u-boot-sunxi-with-spl.bin)
    # 并将其写入到 SD 卡偏移 8KB 处 (bs=1k seek=8)
    sed -i 's/u-boot.bin/u-boot-sunxi-with-spl.bin/g' $IMG_MAKEFILE
fi

# --- 5. Kernel Patches ---
KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-6.*" | sort -V | tail -n 1)
if [ -z "$KERNEL_PATCH_DIR" ]; then
    KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-5.*" | sort -V | tail -n 1)
fi
if [ -d "$KERNEL_PATCH_DIR" ] && [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
fi
