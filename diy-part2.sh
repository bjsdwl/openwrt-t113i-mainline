#!/bin/bash

# --- 1. 暴力清理：强制所有 sunxi 变体都使用我们的频率 ---
# 这样即使它选错了板子，频率也是对的
find package/boot/uboot-sunxi/config/ -type f -exec sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/g' {} +

# --- 2. 针对 T113 变体注入 ZQ 和 DDR3 类型 ---
# 我们在 Makefile 中查找真实的 Variant 名称
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
T113_VAR=$(grep -o "allwinner_t113_s3" $UBOOT_MAKEFILE | head -1)

if [ ! -z "$T113_VAR" ]; then
    echo "Found T113 Variant in Makefile, applying precision patch..."
    CONF_FILE="package/boot/uboot-sunxi/config/allwinner_t113_s3"
    [ -f "$CONF_FILE" ] || CONF_FILE="package/boot/uboot-sunxi/config/sunxi"
    
    sed -i '/CONFIG_DRAM_ZQ/d' $CONF_FILE
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $CONF_FILE
    sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $CONF_FILE
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $CONF_FILE
    sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $CONF_FILE
fi

# --- 3. 修正镜像生成逻辑 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    # 强制修正主线 OpenWrt 的默认 128KB 偏移为 8KB
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
