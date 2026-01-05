#!/bin/bash

# --- 1. 强力修正所有 sunxi U-Boot 配置 (扩大搜索范围) ---
# 找到所有 U-Boot 的板级配置文件进行批量修改
find package/boot/uboot-sunxi/config/ -name "*" | xargs -n 1 sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/g' 2>/dev/null

# 针对 T113-S3 这个具体变体注入 ZQ 和 DDR 类型
# OpenWrt 源码中对应的文件通常是 package/boot/uboot-sunxi/config/allwinner_t113_s3
T113_UBOOT_CONF="package/boot/uboot-sunxi/config/allwinner_t113_s3"
if [ ! -f $T113_UBOOT_CONF ]; then
    # 如果找不到特定文件，就修改通用的 sunxi 配置文件
    T113_UBOOT_CONF="package/boot/uboot-sunxi/config/sunxi"
fi

echo "Forcing T113-i parameters into $T113_UBOOT_CONF"
sed -i '/CONFIG_DRAM_ZQ/d' $T113_UBOOT_CONF
echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $T113_UBOOT_CONF
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $T113_UBOOT_CONF
echo "CONFIG_DRAM_TYPE_DDR3=y" >> $T113_UBOOT_CONF
sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $T113_UBOOT_CONF

# --- 2. 镜像偏移修正 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
