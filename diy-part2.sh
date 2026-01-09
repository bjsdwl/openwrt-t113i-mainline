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

# --- 2. 注入 Early Debug UART 配置 ---
# 依然保持 24MHz 时钟设置，因为之前的闪烁证明时钟确实没倍频
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

# --- 3. 动态生成 003 补丁 (修复地址版) ---
echo "⚡ Generating 003-early-debug-led.patch..."

cat <<'EOF' > $PATCH_TARGET_DIR/003-early-debug-led.patch
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,1 +471,21 @@
 	spl_init();
+
+	/* 
+	 * 1. 强制 UART0 引脚复用 (PG17/18 -> Func 7)
+	 * T113 GPIO Base: 0x02000000
+	 * Port G Offset: 0x120
+	 * PG_CFG2 (Pin 16-23): Offset 0x08 -> Total: 0x02000128
+	 * Value: PG17(bits 7:4)=7, PG18(bits 11:8)=7
+	 */
+	*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFF00FF) | 0x00007700;
+
+	/* 2. 配置 LED (PC0) 为输出 (地址 0x02000060 是对的) */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+
+	/* 3. 快速闪烁 5 次 (确认系统存活) */
+	volatile int loop;
+	for (loop = 0; loop < 5; loop++) {
+		/* OFF */
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;
+		for (volatile int i = 0; i < 500000; i++);
+		/* ON */
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+		for (volatile int i = 0; i < 500000; i++);
+	}
+	/* 保持常亮 */
+	*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+
EOF

# 强制修复缩进
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^+ \+/\+\t/' $PATCH_TARGET_DIR/003-early-debug-led.patch

echo "✅ 003 Patch generated."

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
