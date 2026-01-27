#!/bin/bash

# --- 1. 环境准备 ---
UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Reconfiguring for T113-i Native Build..."

# --- 2. 升级版本与清理补丁 ---
# 强制锁定 2025.01 版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 清理原有补丁，注入 generate-patch.yml 生成的专业补丁 (Binman, 792MHz, 0x128钥匙)
rm -rf $UBOOT_PKG_DIR/patches
mkdir -p $UBOOT_PKG_DIR/patches
if [ -d "$GITHUB_WORKSPACE/patches-uboot" ]; then
    cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/
    echo "✅ Professional patches injected."
fi

# --- 3. 注册新目标 (nc_link_t113s3) ---
# 安全地将目标加入 UBOOT_TARGETS 列表
if ! grep -q "nc_link_t113s3" $UBOOT_MAKEFILE; then
    # 在 UBOOT_TARGETS := 行之后新起一行插入，末尾带反斜杠保证 Makefile 连续性
    sed -i '/UBOOT_TARGETS :=/a \	nc_link_t113s3 \\' $UBOOT_MAKEFILE
fi

# --- 4. 插入设备定义块 ---
# 先删除可能存在的旧定义块防止重复
sed -i '/define U-Boot\/nc_link_t113s3/,/endef/d' $UBOOT_MAKEFILE

# 定义设备块：明确 UBOOT_IMAGE 为 binman 生成的合体镜像名
# 注意：这里使用 2 个空格缩进，严禁在 define/endef 块内部使用 Tab
device_def="
define U-Boot/nc_link_t113s3
  NAME:=Tronlong TLT113-MiniEVM (Native Binman)
  BUILD_DEVICES:=xunlong_orangepi-one
  UBOOT_CONFIG:=nc_link_t113s3
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef
"

# 将定义块精准插入到 BuildPackage 调用之前
sed -i "/\$(eval \$(call BuildPackage,U-Boot))/i $device_def" $UBOOT_MAKEFILE

echo "✅ Target nc_link_t113s3 registered and defined."
echo ">>> diy-part2.sh: Setup complete."
