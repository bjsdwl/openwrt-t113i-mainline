#!/bin/bash

# --- 1. 核心修复：向 OpenWrt 注入 T113-S3 的板型定义 ---
# OpenWrt 源码里可能还没收录 T113，导致选不上。我们手动追加定义。
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

# 检查是否已存在，不存在则追加
if ! grep -q "U-Boot/allwinner_t113_s3" $UBOOT_MAKEFILE; then
    echo "Injecting T113-S3 definition into Makefile..."
    # 这里的 define 块必须符合 OpenWrt 语法
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_s3
  BUILD_SUBTARGET:=cortexa7
  NAME:=Allwinner T113-S3
  BUILD_DEVICES:=allwinner_t113-s3
  # 对应主线 U-Boot 源码中的 configs/allwinner_t113_s3_defconfig
  UBOOT_CONFIG:=allwinner_t113_s3
  BL31:=
endef
EOF
fi

# --- 2. 强制锁定 .config (双重保险) ---
# 防止 make defconfig 把它冲掉
sed -i '/CONFIG_PACKAGE_uboot-sunxi-Sinovoip_BPI_M3/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config
echo "# CONFIG_PACKAGE_uboot-sunxi-Sinovoip_BPI_M3 is not set" >> .config

# --- 3. U-Boot 源码参数修正 ---
# 此时源码可能还没解压，但我们可以预埋 hooks，或者修改 config 模板
# 由于 OpenWrt 是编译时解压，我们只能修改 OpenWrt 的 patch 机制或覆盖逻辑
# 这里我们采用“通用覆盖法”：创建 OpenWrt 补丁
# 但为了简单测试，我们利用 OpenWrt 的 UBOOT_CUSTOM_ARGS (如果支持)
# 或者直接依赖我们刚才注入的 UBOOT_CONFIG:=allwinner_t113_s3

# 修正镜像生成逻辑 (8KB)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
