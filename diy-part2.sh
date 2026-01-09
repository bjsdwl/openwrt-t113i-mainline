#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运常规补丁 ---
mkdir -p $PATCH_TARGET_DIR
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 注入 Early Debug UART 配置 ---
# 此时必须强制 24MHz，否则波特率是错的
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

# --- 3. 动态生成 003 补丁 (安全替换版) ---
echo "⚡ Generating 003-early-debug-led.patch..."

# 我们使用 printf 生成补丁，确保 Tab (\t) 准确无误
# 逻辑：查找 "spl_init();" 这一行，把它替换为 "spl_init();" 加上初始化代码
# 这样不会破坏文件的上下文结构
cat > $PATCH_TARGET_DIR/003-early-debug-led.patch <<'EOF'
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,7 +471,24 @@
 	gpio_init();
 
-	spl_init();
+	spl_init();
+
+	/* 1. UART0 PG17/18 Force (0x0770 = PG17/TX, PG18/RX) */
+	*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;
+
+	/* 2. LED PC0 Setup */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+
+	/* 3. Blink 5 times (Proof of Life) */
+	volatile int loop;
+	for (loop = 0; loop < 5; loop++) {
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001; /* OFF */
+		for (volatile int i = 0; i < 500000; i++);
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;  /* ON */
+		for (volatile int i = 0; i < 500000; i++);
+	}
+	/* 4. Force print 'X' to UART TX FIFO (Address 0x02500000) */
+	*(volatile unsigned int *)(0x02500000) = 0x58;
+
 	preloader_console_init();
 
 #if CONFIG_IS_ENABLED(I2C) && CONFIG_IS_ENABLED(SYS_I2C_LEGACY)
EOF

# 再次保险：修复缩进
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+gpio_init();/\tgpio_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+preloader_console_init();/\tpreloader_console_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch

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
