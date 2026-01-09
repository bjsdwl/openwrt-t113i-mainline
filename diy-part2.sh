#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"
BOARD_SRC="arch/arm/mach-sunxi/board.c"

# --- 1. 搬运常规补丁 ---
mkdir -p $PATCH_TARGET_DIR
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 【核心】强力代码注入 ---
echo "⚡ Preparing direct source injection..."

# 构造 C 代码字符串 (单行模式，方便 sed 处理)
# 关键点：volatile int i; 防止循环被优化
# 逻辑：配置 PC0 -> 循环 5 次 -> 亮 -> 灭
C_CODE='spl_init(); /* INJECTED */ *(volatile unsigned int *)(0x02000060) &= ~0xF; *(volatile unsigned int *)(0x02000060) |= 1; volatile int loop; for(loop=0; loop<5; loop++) { *(volatile unsigned int *)(0x02000070) &= ~1; for(volatile int i=0; i<20000000; i++); *(volatile unsigned int *)(0x02000070) |= 1; for(volatile int i=0; i<20000000; i++); }'

# 构造 sed 命令：将 "spl_init();" 替换为 上面的大段代码
# 使用 | 作为分隔符，避免与 C 代码中的分号冲突
SED_CMD="sed -i 's|spl_init();|$C_CODE|' \$(PKG_BUILD_DIR)/$BOARD_SRC"

# 注入到 Makefile 的 Build/Prepare 中
sed -i "/define Build\/Prepare/a \	$SED_CMD" $UBOOT_MAKEFILE

# 添加一个 grep 检查，确保编译日志里能看到
CHECK_CMD="grep 'INJECTED' \$(PKG_BUILD_DIR)/$BOARD_SRC || echo '❌ Injection Failed!'"
sed -i "/define Build\/Prepare/a \	$CHECK_CMD" $UBOOT_MAKEFILE

echo "✅ Source injection rule added."

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

echo "✅ diy-part2.sh finished."
