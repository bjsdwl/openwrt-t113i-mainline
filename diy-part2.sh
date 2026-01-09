#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"
BOARD_SRC="arch/arm/mach-sunxi/board.c"

# --- 1. 搬运补丁 (只搬运 001/002) ---
mkdir -p $PATCH_TARGET_DIR
cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/ 2>/dev/null || :
cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/ 2>/dev/null || :

# --- 2. 注入 Debug UART 配置 ---
cat <<EOF >> $PATCH_TARGET_DIR/002-add-t113-defconfig.patch
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_SUNXI=y
CONFIG_DEBUG_UART_BASE=0x02500000
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_DEBUG_UART_ANNOUNCE=y
CONFIG_SPL_SERIAL=y
CONFIG_SPL_DM_SERIAL=y
EOF

# --- 3. 【核心】直接修改源码 (绕过 Patch 机制) ---
echo "⚡ Preparing direct source injection..."

# 构造要插入的 C 代码 (单行化，用分号隔开)
# 这段代码做了三件事：1.配CCU 2.配GPIO 3.配UART 4.发字符'U' 5.闪灯
# 注意：所有分号后都加了反斜杠，供 sed 使用
DEBUG_CODE='	/* CCU: Enable UART0 */\
	*(volatile unsigned int *)(0x0200190C) |= 0x00010001;\
	/* GPIO: Force PG17/18 Func 7 */\
	*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;\
	/* UART: 115200 @ 24MHz */\
	*(volatile unsigned int *)(0x0250000C) = 0x83;\
	*(volatile unsigned int *)(0x02500000) = 0x0D;\
	*(volatile unsigned int *)(0x02500004) = 0x00;\
	*(volatile unsigned int *)(0x0250000C) = 0x03;\
	*(volatile unsigned int *)(0x02500008) = 0x07;\
	/* Send U */\
	*(volatile unsigned int *)(0x02500000) = 0x55;\
	/* LED Setup */\
	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;\
	/* Blink 5 times */\
	volatile int loop;\
	for (loop = 0; loop < 5; loop++) {\
		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;\
		for (volatile int i = 0; i < 200000; i++);\
		*(volatile unsigned int *)(0x02000070) |= 0x00000001;\
		for (volatile int i = 0; i < 200000; i++);\
	}'

# 构造 sed 命令：找到 "spl_init();" 这一行，在它后面追加 (a 命令) 代码
# 使用 | 作为分隔符
SED_CMD="sed -i '/spl_init();/a $DEBUG_CODE' \$(PKG_BUILD_DIR)/$BOARD_SRC"

# 将这个 sed 命令注入到 Makefile 的 Build/Prepare 钩子中
sed -i "/define Build\/Prepare/a \	$SED_CMD" $UBOOT_MAKEFILE

echo "✅ Source injection rule added."

# --- 4. 动态注入 Makefile 规则 ---
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 5. 注册与截胡 ---
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
