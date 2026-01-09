#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"
BOARD_C_PATH="arch/arm/mach-sunxi/board.c"

# --- 1. 搬运常规补丁 (001, 002) ---
mkdir -p $PATCH_TARGET_DIR
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 注入 Early Debug UART 配置 ---
echo "🔧 Injecting Early Debug UART configs..."
cat <<EOF >> $PATCH_TARGET_DIR/002-add-t113-defconfig.patch
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_SUNXI=y
CONFIG_DEBUG_UART_BASE=0x02500000
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_DEBUG_UART_ANNOUNCE=y
CONFIG_SPL_SERIAL=y
CONFIG_SPL_DM_SERIAL=y
EOF

# --- 3. 【核心】直接修改源码 (代替 Patch 003) ---
# 既然 Patch 容易坏，我们就用 sed 直接把代码插进去
# 这段逻辑会在 U-Boot 编译前的 Prepare 阶段执行
echo "⚡ Injecting LED & UART Debug code directly via Makefile..."

# 我们构造一段 C 代码字符串，注意转义换行符
DEBUG_CODE='	/* UART0 PG17/PG18 Force Func 7 */\
	*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;\
	/* LED PC0 Output */\
	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;\
	/* Blink 5 times */\
	volatile int loop;\
	for (loop = 0; loop < 5; loop++) {\
		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;\
		for (volatile int i = 0; i < 500000; i++);\
		*(volatile unsigned int *)(0x02000070) |= 0x00000001;\
		for (volatile int i = 0; i < 500000; i++);\
	}\
	*(volatile unsigned int *)(0x02000070) |= 0x00000001;'

# 将这段 sed 命令注入到 U-Boot Makefile 的 Build/Prepare 钩子中
# 这样当 OpenWrt 解压完 U-Boot 源码后，会自动执行这一行替换
# 目标：在 spl_init(); 后面插入代码
SED_CMD="sed -i '/spl_init();/a $DEBUG_CODE' \$(PKG_BUILD_DIR)/$BOARD_C_PATH"

# 注入到 Makefile
sed -i "/define Build\/Prepare/a \	$SED_CMD" $UBOOT_MAKEFILE

# --- 4. 动态注入 Makefile 规则 (DTS) ---
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

# --- 7. Kernel 补丁注入 ---
KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-6.*" | sort -V | tail -n 1)
if [ -z "$KERNEL_PATCH_DIR" ]; then
    KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-5.*" | sort -V | tail -n 1)
fi
if [ -d "$KERNEL_PATCH_DIR" ] && [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
fi

echo "✅ diy-part2.sh finished."
