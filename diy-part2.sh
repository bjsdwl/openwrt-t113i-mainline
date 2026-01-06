#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载模板并生成 Defconfig 补丁 ---
# 我们从 U-Boot 主线下载 MangoPi MQ-R (T113) 的配置作为底座
# 这样能确保所有的架构参数 (ARCH_SUNXI, MACH_SUN8I 等) 都是对的
echo "Downloading MangoPi defconfig template..."
wget -qO /tmp/mangopi_mq_r_defconfig https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig

# --- 2. 注入工业级参数 (魔改) ---
echo "Patching parameters for T113-i Industrial..."
# 替换/添加关键参数
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' /tmp/mangopi_mq_r_defconfig
sed -i '/CONFIG_DRAM_ZQ/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> /tmp/mangopi_mq_r_defconfig
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_TYPE_DDR3=y" >> /tmp/mangopi_mq_r_defconfig
sed -i '/CONFIG_CONS_INDEX/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_CONS_INDEX=1" >> /tmp/mangopi_mq_r_defconfig
# 确保 SPL 开启
echo "CONFIG_SPL=y" >> /tmp/mangopi_mq_r_defconfig

# --- 3. 创建 U-Boot 源码补丁 (无中生有) ---
# 我们创建一个 patch，作用是：在 configs/ 目录下新建 allwinner_t113_s3_defconfig 文件
# 这样 make allwinner_t113_s3_config 就能找到文件了！
PATCH_FILE="$PATCH_DIR/999-add-t113-industrial-defconfig.patch"
echo "Creating patch file: $PATCH_FILE"

cat <<EOF > $PATCH_FILE
--- /dev/null
+++ b/configs/allwinner_t113_s3_defconfig
@@ -0,0 +1,$(wc -l < /tmp/mangopi_mq_r_defconfig) @@
EOF
cat /tmp/mangopi_mq_r_defconfig >> $PATCH_FILE

# --- 4. 注册板型到 OpenWrt Makefile ---
# 定义 T113-S3，让 UBOOT_CONFIG 指向我们刚刚用补丁创建的文件名
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
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_s3' $UBOOT_MAKEFILE

# --- 6. 修正镜像生成逻辑 (8KB) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 7. 锁定 .config ---
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config
