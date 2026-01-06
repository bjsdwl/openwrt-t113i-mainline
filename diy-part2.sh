#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

# --- 1. 注入 T113-S3 的板型定义块 ---
if ! grep -q "U-Boot/allwinner_t113_s3" $UBOOT_MAKEFILE; then
    echo "Injecting T113-S3 definition block..."
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_s3
  BUILD_SUBTARGET:=cortexa7
  NAME:=Allwinner T113-S3
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=allwinner_t113_s3
  BL31:=
endef
EOF
fi

# --- 2. 关键修复：将新板型注册到 UBOOT_TARGETS 列表 ---
# OpenWrt 通过遍历 UBOOT_TARGETS 变量来生成菜单。
# 我们在 Makefile 开头找到变量定义，并把我们的板子加进去。
if ! grep -q "UBOOT_TARGETS .*allwinner_t113_s3" $UBOOT_MAKEFILE; then
    echo "Registering T113-S3 to UBOOT_TARGETS list..."
    # 在 "UBOOT_TARGETS :=" 后面插入我们的板子
    sed -i 's/UBOOT_TARGETS :=/UBOOT_TARGETS := allwinner_t113_s3/' $UBOOT_MAKEFILE
fi

# --- 3. 强制锁定 .config ---
# 先删除可能存在的旧配置
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
# 重新写入
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config

# --- 4. 修正镜像生成逻辑 (8KB) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
