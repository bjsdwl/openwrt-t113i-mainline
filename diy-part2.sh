#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

# --- 第一步：定义 T113-S3 板型 ---
# 我们借用主线 U-Boot 中已存在的 "mangopi_mq_r" (MangoPi MQ-R) 配置
# 因为它是基于 T113-S3 的真实板型，主线源码里肯定有这个 defconfig
# 这样能避免 "Target not found" 错误
cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_s3
  BUILD_SUBTARGET:=cortexa7
  NAME:=Allwinner T113-S3 (Industrial)
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=mangopi_mq_r
  BL31:=
endef
EOF

# --- 第二步：必杀技 —— 截胡 UBOOT_TARGETS 列表 ---
# 在 Makefile 构建命令执行前，强行将目标列表重置为只有 T113 一个
# 这一行是杀手锏：它会屏蔽掉原来的 BPI-M3、H3 等几十个板子
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_s3' $UBOOT_MAKEFILE

# --- 第三步：参数魔改 (针对 MangoPi MQ-R 的壳，注入我们的参数) ---
# 创建一个针对 mangopi_mq_r 的配置覆盖文件
CONFIG_OVERRIDE="package/boot/uboot-sunxi/config/mangopi_mq_r"
mkdir -p $(dirname $CONFIG_OVERRIDE)

# 清空旧配置，写入我们的工业级参数
cat <<EOF > $CONFIG_OVERRIDE
CONFIG_DRAM_CLK=792
CONFIG_DRAM_ZQ=0x7b7bfb
CONFIG_DRAM_TYPE_DDR3=y
CONFIG_CONS_INDEX=1
CONFIG_SPL=y
EOF

# --- 第四步：修正镜像生成逻辑 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 第五步：清理 .config 里的垃圾 ---
# 既然 Makefile 里只有 T113 了，.config 里选谁都不重要了
# 但为了日志好看，我们还是修正一下
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config
