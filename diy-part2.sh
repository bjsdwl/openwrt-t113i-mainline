#!/bin/bash

# 修正所有板型的默认频率，并对 T113 板型注入 ZQ
find package/boot/uboot-sunxi/config/ -name "*" | xargs -n 1 sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/g' 2>/dev/null

# 找到特定的 T113 配置文件
T113_CONF=$(find package/boot/uboot-sunxi/config/ -name "*t113_s3*")
if [ -z "$T113_CONF" ]; then T113_CONF="package/boot/uboot-sunxi/config/sunxi"; fi

echo "Targeting U-Boot Config: $T113_CONF"
sed -i '/CONFIG_DRAM_ZQ/d' $T113_CONF
echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $T113_CONF
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $T113_CONF
echo "CONFIG_DRAM_TYPE_DDR3=y" >> $T113_CONF
sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $T113_CONF

# 修正镜像生成偏移 (BROM 魔术数查找位置)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
