#!/bin/bash

UBOOT_DIR="package/boot/uboot-sunxi"
PATCH_TARGET_DIR="$UBOOT_DIR/patches"
UBOOT_MAKEFILE="$UBOOT_DIR/Makefile"
# 目标源文件路径（相对于 OpenWrt 的 PKG_BUILD_DIR）
BOARD_SRC="arch/arm/mach-sunxi/board.c"

# --- 1. 搬运常规补丁 (只搬运 001 和 002) ---
mkdir -p $PATCH_TARGET_DIR
if [ -f "$GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/001-add-t113-dts.patch $PATCH_TARGET_DIR/
fi
if [ -f "$GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/002-add-t113-defconfig.patch $PATCH_TARGET_DIR/
fi

# --- 2. 【核心】直接修改源码 (替代 Patch 003) ---
# 我们构造一个 sed 命令，直接在 spl_init(); 后面插入代码
# 这个命令会被注入到 Makefile 的 Build/Prepare 钩子中

echo "⚡ Preparing direct source injection via Makefile..."

# 构造要插入的 C 代码 (注意：这里不需要关心缩进，C语言对缩进不敏感)
# 我们插入一段 2000万次循环的代码，用于测试时钟频率
DEBUG_CODE='	/* LED PC0 Setup */\
	*(volatile unsigned int *)(0x02000060) = (*(volatile unsigned int *)(0x02000060) & 0xFFFFFFF0) | 0x00000001;\
	/* Clock Test: Blink 5 times */\
	volatile int loop;\
	for (loop = 0; loop < 5; loop++) {\
		*(volatile unsigned int *)(0x02000070) &= ~0x00000001;\
		for (volatile int i = 0; i < 20000000; i++);\
		*(volatile unsigned int *)(0x02000070) |= 0x00000001;\
		for (volatile int i = 0; i < 20000000; i++);\
	}'

# 将 sed 命令注入到 U-Boot Makefile
# 逻辑：在解压补丁之后，执行 sed，在 "spl_init();" 这一行后面追加 DEBUG_CODE
# 注意：使用反斜杠转义 $ 符号
SED_INJECT="sed -i '/spl_init();/a $DEBUG_CODE' \$(PKG_BUILD_DIR)/$BOARD_SRC"

# 将这个命令插入到 define Build/Prepare 的末尾
sed -i "/define Build\/Prepare/a \	$SED_INJECT" $UBOOT_MAKEFILE

echo "✅ Source injection rule added to Makefile."

# --- 3. 动态注入 DTS 规则 ---
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
