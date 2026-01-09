#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运补丁 ---
mkdir -p $PATCH_TARGET_DIR
# 搬运 001, 002
cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/ 2>/dev/null || :
cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/ 2>/dev/null || :

# --- 2. 【强制重写】003 时钟测试补丁 (100次循环版) ---
# 无论你仓库里的 003 格式是对是错，这里都会用正确的内容覆盖它
# 这样彻底解决了 GitHub Web 编辑器导致的 Tab 变空格问题
echo "⚡ Overwriting 003-early-debug-led.patch with known-good content..."

cat > $PATCH_TARGET_DIR/003-early-debug-led.patch <<'EOF'
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,7 +471,20 @@
 	gpio_init();
 
-	spl_init();
+	spl_init();
+
+	/* LED PC0 Setup */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+
+	/* Clock Test: Blink 100 times (20M cycles) */
+	volatile int loop;
+	for (loop = 0; loop < 100; loop++) {
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;
+		for (volatile int i = 0; i < 20000000; i++);
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+		for (volatile int i = 0; i < 20000000; i++);
+	}
+
 	preloader_console_init();
 
 #if CONFIG_IS_ENABLED(I2C) && CONFIG_IS_ENABLED(SYS_I2C_LEGACY)
EOF

# 再次保险：使用 sed 将上下文的空格强制转换为 Tab
# 这一步是为了防止 cat 输出时 Shell 环境的差异
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+gpio_init();/\tgpio_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^ \+preloader_console_init();/\tpreloader_console_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch

echo "✅ 003 Patch restored to pristine condition."

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
