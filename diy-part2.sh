#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载 MangoPi MQ-R 配置作为底座 ---
echo "Downloading MangoPi defconfig template..."
# 使用 wget 下载，存入临时文件
wget -qO /tmp/mangopi_mq_r_defconfig https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig

# --- 2. 注入 T113-i 工业级参数 ---
echo "Patching parameters for T113-i Industrial..."
# 1. 修正 DRAM 频率 (792MHz)
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' /tmp/mangopi_mq_r_defconfig
# 2. 移除旧 ZQ，注入新 ZQ (0x7b7bfb)
sed -i '/CONFIG_DRAM_ZQ/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> /tmp/mangopi_mq_r_defconfig
# 3. 强制 DDR3 类型
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_TYPE_DDR3=y" >> /tmp/mangopi_mq_r_defconfig
# 4. 修正串口索引 (UART0)
sed -i '/CONFIG_CONS_INDEX/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_CONS_INDEX=1" >> /tmp/mangopi_mq_r_defconfig
# 5. 确保 SPL 开启
echo "CONFIG_SPL=y" >> /tmp/mangopi_mq_r_defconfig

# --- 3. 生成合法的 Unified Diff 补丁 (关键修复步骤) ---
PATCH_FILE="$PATCH_DIR/999-add-t113-industrial-defconfig.patch"
echo "Creating compliant patch file: $PATCH_FILE"

# 计算行数，用于生成补丁头
LINE_COUNT=$(wc -l < /tmp/mangopi_mq_r_defconfig)

# 写入补丁头
cat <<EOF > $PATCH_FILE
--- /dev/null
+++ b/configs/allwinner_t113_s3_defconfig
@@ -0,0 +1,${LINE_COUNT} @@
EOF

# 关键修正：使用 sed 给每一行前面加一个 "+" 号
sed 's/^/+/' /tmp/mangopi_mq_r_defconfig >> $PATCH_FILE

# --- 4. 注册板型到 OpenWrt Makefile ---
# 如果 Makefile 里还没这个定义，就加进去
if ! grep -q "U-Boot/allwinner_t113_s3" $UBOOT_MAKEFILE; then
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_s3
  BUILD_SUBTARGET:=cortexa7
  NAME:=Allwinner T113-S3 (Industrial)
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=allwinner_t113_s3
  BL31:=
endef
EOF
fi

# --- 5. 截胡 UBOOT_TARGETS 列表 ---
# 强制让 Makefile 只编译这一个板子，防止去编 BPI-M3
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_s3' $UBOOT_MAKEFILE

# --- 6. 修正镜像生成逻辑 (8KB) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 7. 清理并锁定 .config ---
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config
