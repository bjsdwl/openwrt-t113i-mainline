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

# --- 2. 动态生成 003 LED 频率测试补丁 ---
# 目标：通过 100 次闪烁的总时间，反推 CPU 当前频率
# 逻辑：外层循环 100 次，内层延时 2,000,000 次
echo "⚡ Generating 003-early-debug-led.patch (Frequency Test Mode)..."

cat <<'EOF' > $PATCH_TARGET_DIR/003-early-debug-led.patch
--- a/arch/arm/mach-sunxi/board.c
+++ b/arch/arm/mach-sunxi/board.c
@@ -471,1 +471,19 @@
 	spl_init();
+
+	/* 1. 强制配置 UART0 引脚 (Function 7) - 确保物理通道打开 */
+	*(volatile unsigned int *)(0x020000D8) = (*(volatile unsigned int *)(0x020000D8) & 0xFFFF00FF) | 0x00007700;
+	/* 2. 配置 PC0 为输出 */
+	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;
+
+	/* 3. 进入 100 次闪烁循环 (用于测量时钟频率) */
+	volatile int loop;
+	for (loop = 0; loop < 100; loop++) {
+		/* OFF */
+		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;
+		for (volatile int i = 0; i < 2000000; i++);
+		
+		/* ON */
+		*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+		for (volatile int i = 0; i < 2000000; i++);
+	}
+	
+	/* 循环结束后保持常亮，作为完成标志 */
+	*(volatile unsigned int *)(0x02000070) |= 0x00000001;
+
EOF

# 强制修复缩进：将生成的补丁中的行首空格转换为 Tab
# 这一步是为了保险，防止 cat命令 在某些 shell 下处理缩进不一致
sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
sed -i 's/^+ \+/\+\t/' $PATCH_TARGET_DIR/003-early-debug-led.patch

echo "✅ 003 Patch generated (100x blink mode)."

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
