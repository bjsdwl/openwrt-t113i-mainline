#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运常规补丁 (001, 002) ---
mkdir -p $PATCH_TARGET_DIR
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 注入 Debug UART 配置 ---
if [ -f "$PATCH_TARGET_DIR/002-add-t113-defconfig.patch" ]; then
    cat <<EOF >> $PATCH_TARGET_DIR/002-add-t113-defconfig.patch
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_SUNXI=y
CONFIG_DEBUG_UART_BASE=0x02500000
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_DEBUG_UART_ANNOUNCE=y
CONFIG_SPL_SERIAL=y
CONFIG_SPL_DM_SERIAL=y
EOF
fi

# --- 3. 【核心】二进制生成 003 补丁 ---
# 使用 printf 显式写入 \t (Tab) 和 \n (换行)，确保补丁 100% 符合源码格式
echo "⚡ Generating 003-early-debug-led.patch via binary-safe printf..."

PFILE="$PATCH_TARGET_DIR/003-early-debug-led.patch"
printf -- "--- a/arch/arm/mach-sunxi/board.c\n" > $PFILE
printf -- "+++ b/arch/arm/mach-sunxi/board.c\n" >> $PFILE
printf -- "@@ -471,1 +471,16 @@\n" >> $PFILE
printf -- " \tspl_init();\n" >> $PFILE  # 注意：这行开头是一个空格，接着是一个Tab
printf -- "+\t*(volatile unsigned int *)(0x0200190C) |= 0x00010001;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x0250000C) = 0x83;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02500000) = 0x0D;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02500004) = 0x00;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x0250000C) = 0x03;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02500008) = 0x07;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02500000) = 0x55;\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;\n" >> $PFILE
printf -- "+\tvolatile int loop, i;\n" >> $PFILE
printf -- "+\tfor(loop=0;loop<5;loop++){\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02000070) &= ~1;\n" >> $PFILE
printf -- "+\tfor(i=0;i<200000;i++);\n" >> $PFILE
printf -- "+\t*(volatile unsigned int *)(0x02000070) |= 1;\n" >> $PFILE
printf -- "+\tfor(i=0;i<200000;i++);\n" >> $PFILE
printf -- "+\t}\n" >> $PFILE
printf -- "\n" >> $PFILE # 补丁末尾空行，防止 unexpected end of file

echo "✅ 003 Patch generated successfully."

# --- 4. 动态注入 Makefile 规则 (DTS) ---
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 5. 注册新 Target ---
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

# --- 6. 镜像布局修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh finished."
