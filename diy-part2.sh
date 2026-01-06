#!/bin/bash

# 修正所有 sunxi 配置的 DRAM 频率为 792MHz
find package/boot/uboot-sunxi/config/ -type f | xargs sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/g' 2>/dev/null

# 对 T113 特有配置进行 ZQ 和 DDR3 类型注入
T113_CONF="package/boot/uboot-sunxi/config/allwinner_t113_s3"
if [ -f "$T113_CONF" ]; then
    echo "Patching T113 U-Boot Config..."
    sed -i '/CONFIG_DRAM_ZQ/d' $T113_CONF
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $T113_CONF
    sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $T113_CONF
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $T113_CONF
    # 强制控制台引脚 UART0
    sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $T113_CONF
fi

# 修正镜像生成逻辑：偏移量改为 8KB (Sector 16)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
