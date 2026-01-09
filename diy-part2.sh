#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运补丁 ---
mkdir -p $PATCH_TARGET_DIR
cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/ 2>/dev/null || :
cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/ 2>/dev/null || :

# --- 2. 注入 Early Debug UART 配置 ---
# 依然保留，作为双重保险
cat <<EOF >> $PATCH_TARGET_DIR/002-add-t113-defconfig.patch
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_SUNXI=y
CONFIG_DEBUG_UART_BASE=0x02500000
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_DEBUG_UART_ANNOUNCE=y
CONFIG_SPL_SERIAL=y
CONFIG_SPL_DM_SERIAL=y
EOF

# --- 3. 【核心】003 补丁：手动初始化串口 (裸机寄存器版) ---
# 这是一个终极的“不求人”版本，自己配置时钟、引脚和波特率
echo "⚡ Generating 003-early-debug-led.patch (Register Direct Access)..."

cat > $PATCH_TARGET_DIR/003-early-debug-led.patch <<'EOF'
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,7 +471,38 @@
 	gpio_init();
 
-	spl_init();
+	spl_init();
+
+	/* === 1. CCU: Enable UART0 Clock & De-assert Reset === */
+	/* Addr: 0x0200190C (CCU_BASE + UART_BGR_REG) */
+	/* Bit 16: Reset (1=Run), Bit 0: Gating (1=Pass) -> 0x00010001 */
+	*(volatile unsigned int *)(0x0200190C) |= 0x00010001;
+
+	/* === 2. GPIO: Force PG17/18 to UART Function (Func 7) === */
+	/* Addr: 0x02000128 (PG_CFG2) */
+	/* PG17 (Bits 7:4), PG18 (Bits 11:8) */
+	/* Mask: 0xFFFFF00F, Value: 0x00000770 */
+	*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;
+
+	/* === 3. UART: Configure 115200 8N1 (Base 24MHz) === */
+	/* LCR: Enable DLAB (Bit 7) to set Divisor */
+	*(volatile unsigned int *)(0x0250000C) = 0x83; 
+	/* DLL: Divisor Low = 13 (24M / 16 / 115200 = 13.02) */
+	*(volatile unsigned int *)(0x02500000) = 0x0D;
+	/* DLH: Divisor High = 0 */
+	*(volatile unsigned int *)(0x02500004) = 0x00;
+	/* LCR: Clear DLAB, Set 8N1 */
+	*(volatile unsigned int *)(0x0250000C) = 0x03;
+	/* FCR: Enable FIFO */
+	*(volatile unsigned int *)(0x02500008) = 0x07;
+
+	/* === 4. Send Character 'U' (0x55) === */
+	*(volatile unsigned int *)(0x02500000) = 0x55;
+
+	/* === 5. LED Setup & Quick Blink === */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+	volatile int loop;
+	for (loop = 0; loop < 5; loop++) {
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;
+		for (volatile int i = 0; i < 200000; i++); /* Short delay */
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+		for (volatile int i = 0; i < 200000; i++);
+	}
+
 	preloader_console_init();
 
 #if CONFIG_IS_ENABLED(I2C) && CONFIG_IS_ENABLED(SYS_I2C_LEGACY)
EOF

# 修复缩进 (确保 quilt 能识别)
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+gpio_init();/\tgpio_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+preloader_console_init();/\tpreloader_console_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch

echo "✅ 003 Patch generated (Register Mode)."

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

# --- 7. Kernel 补丁注入 ---
KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-6.*" | sort -V | tail -n 1)
if [ -z "$KERNEL_PATCH_DIR" ]; then
    KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-5.*" | sort -V | tail -n 1)
fi
if [ -d "$KERNEL_PATCH_DIR" ] && [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
fi

echo "✅ diy-part2.sh finished."
