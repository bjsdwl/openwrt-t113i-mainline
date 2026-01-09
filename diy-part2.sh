#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"

# --- 1. 搬运所有静态补丁 ---
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    mkdir -p $PATCH_TARGET_DIR
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $PATCH_TARGET_DIR/
    echo "✅ Patches copied."
else
    echo "❌ Error: patches-uboot directory not found!"
    exit 1
fi

# --- 2. 【核心】修复静态补丁的格式陷阱 ---
# GitHub Web 编辑器或 Windows 环境可能会把 Patch 文件中的 Tab 转换为空格。
# 这里的 sed 命令会强制将关键行的缩进还原为 Tab，确保 quilt 能成功应用补丁。
if [ -f "$PATCH_TARGET_DIR/003-early-debug-led.patch" ]; then
    echo "🔧 Sanitizing 003-early-debug-led.patch indentation..."
    # 修复上下文行：将 [空格+spl_init] 替换为 [Tab+spl_init]
    sed -i 's/^ \+spl_init();/\tspl_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
    # 修复上下文行：将 [空格+gpio_init] 替换为 [Tab+gpio_init]
    sed -i 's/^ \+gpio_init();/\tgpio_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
    # 修复上下文行：将 [空格+preloader_console_init] 替换为 [Tab+preloader_console_init]
    sed -i 's/^ \+preloader_console_init();/\tpreloader_console_init();/' $PATCH_TARGET_DIR/003-early-debug-led.patch
    echo "✅ Patch 003 indentation fixed."
fi

# --- 3. 注入 Early Debug UART 配置 ---
# 强制写入 defconfig，确保 SPL 阶段开启串口调试
# 时钟强制为 24MHz (因为此时倍频尚未成功)
if [ -f "$PATCH_TARGET_DIR/002-add-t113-defconfig.patch" ]; then
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
fi

# --- 4. 动态注入 Makefile 规则 (DTS) ---
# 使用反斜杠转义 $ 符号，防止 shell 提前展开变量
INJECTION_CMD='echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb" >> $(PKG_BUILD_DIR)/arch/arm/dts/Makefile'
sed -i "/define Build\/Prepare/a \	$INJECTION_CMD" $UBOOT_MAKEFILE

# --- 5. 注册与截胡 (定义新 Target) ---
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
# 强制将我们的 Target 插队到编译列表首位
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 6. 镜像布局修正 ---
# 修正 SD 卡启动偏移量 (128KB -> 8KB)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 7. Kernel 补丁注入 ---
# 智能查找当前 OpenWrt 源码使用的内核版本目录
KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-6.*" | sort -V | tail -n 1)
if [ -z "$KERNEL_PATCH_DIR" ]; then
    KERNEL_PATCH_DIR=$(find target/linux/sunxi -maxdepth 1 -type d -name "patches-5.*" | sort -V | tail -n 1)
fi

if [ -d "$KERNEL_PATCH_DIR" ] && [ -d "$GITHUB_WORKSPACE/patches-kernel" ]; then
    echo "🔍 Detected Kernel Patch Dir: $KERNEL_PATCH_DIR"
    cp $GITHUB_WORKSPACE/patches-kernel/*.patch $KERNEL_PATCH_DIR/
    echo "✅ Linux Kernel patches copied."
else
    echo "⚠️ Warning: Kernel patch directory not found!"
fi

echo "✅ diy-part2.sh finished."
