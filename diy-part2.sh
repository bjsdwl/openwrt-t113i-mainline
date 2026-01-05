#!/bin/bash

# --- U-Boot 核心参数修正 ---
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
if [ -f $UBOOT_PATH ]; then
    # 1. 修正 DRAM 频率
    sed -i '/CONFIG_DRAM_CLK/c\CONFIG_DRAM_CLK=792' $UBOOT_PATH
    # 2. 注入 ZQ 校准值 (针对 T113-i 工业版)
    sed -i '/CONFIG_DRAM_ZQ/d' $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    # 3. 强制 DDR3 类型
    sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    # 4. 修正串口索引 (UART0)
    sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $UBOOT_PATH
    # 5. 确保生成 SPL
    sed -i '/CONFIG_SPL/c\CONFIG_SPL=y' $UBOOT_PATH
fi

# --- 镜像偏移修正 (关键！) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    # 确保生成镜像时，U-Boot 被放置在 8KB (Sector 16) 位置
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
