#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运常规补丁 ---
mkdir -p $PATCH_TARGET_DIR
# 搬运 001, 002
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 处理 003 补丁 (无论仓库里有没有，我们都重写它) ---
# 这样做的好处：
# 1. 确保补丁内容是我们最新的“2000万次循环”时钟测试版。
# 2. 确保缩进是 Tab，解决 malformed 报错。
echo "⚡ Overwriting 003-clock-test-led.patch for Frequency Test..."

cat > $PATCH_TARGET_DIR/003-early-debug-led.patch <<'EOF'
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,7 +471,20 @@
 	gpio_init();
 
-	spl_init();
+	spl_init();
+
+	/* 1. LED PC0 Setup (Output) */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+
+	/* 2. Clock Speed Test (Blink 5 times) */
+	/* Delay count: 20,000,000. Target: Distinguish 24MHz vs 800MHz */
+	volatile int loop;
+	for (loop = 0; loop < 5; loop++) {
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001; /* OFF */
+		for (volatile int i = 0; i < 20000000; i++);
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;  /* ON */
+		for (volatile int i = 0; i < 20000000; i++);
+	}
+
 	preloader_console_init();
 
 #if CONFIG_IS_ENABLED(I2C) && CONFIG_IS_ENABLED(SYS_I2C_LEGACY)
EOF

# 关键修复：把所有行首的空格强制转回 Tab
# 这行命令能拯救任何格式错误的补丁
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+gpio_init();/\tgpio_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+preloader_console_init();/\tpreloader_console_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch

echo "✅ 003 Patch overwritten and sanitized."

# --- 3. 动态注入 Makefile 规则 ---
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 4. 注册与截胡 ---
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

# --- 5. 镜像布局修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 6. Kernel 补丁注入 ---
KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-6.*" | sort -V | tail -n 1)
if [ -z "$KERNEL_PATCH_DIR" ]; then
    KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-5.*" | sort -V | tail -n 1)
fi
if [ -d "$KERNEL_PATCH_DIR" ] && [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
fi

echo "✅ diy-part2.sh finished."