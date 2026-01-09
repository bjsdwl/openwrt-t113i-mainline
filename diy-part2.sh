#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运常规补丁 ---
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

# --- 3. 【核心】生成无缩进 003 补丁 (修复 EOF 问题) ---
echo "⚡ Generating uglified 003 patch..."

# 注意：最后那个空行至关重要
cat > $PATCH_TARGET_DIR/003-early-debug-led.patch <<'EOF'
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,1 +471,28 @@
 	spl_init();
+/* MANUAL UART INIT */
+*(volatile unsigned int *)(0x0200190C) |= 0x00010001;
+*(volatile unsigned int *)(0x02000128) = (*(volatile unsigned int *)(0x02000128) & 0xFFFFF00F) | 0x00000770;
+*(volatile unsigned int *)(0x0250000C) = 0x83;
+*(volatile unsigned int *)(0x02500000) = 0x0D;
+*(volatile unsigned int *)(0x02500004) = 0x00;
+*(volatile unsigned int *)(0x0250000C) = 0x03;
+*(volatile unsigned int *)(0x02500008) = 0x07;
+*(volatile unsigned int *)(0x02500000) = 0x55;
+/* LED SETUP */
+*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+volatile int loop;
+for (loop = 0; loop < 5; loop++) {
+*(volatile unsigned int *)(0x02000070) &= ~0x00000001;
+for (volatile int i = 0; i < 200000; i++);
+*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+for (volatile int i = 0; i < 200000; i++);
+}
EOF

# 强制在补丁末尾追加一个换行符，解决 "unexpected end of file"
echo "" >> $PATCH_TARGET_DIR/003-early-debug-led.patch

# 仅修复第一行上下文的缩进
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch

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
