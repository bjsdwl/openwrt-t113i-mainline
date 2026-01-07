#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载并准备模板 ---
URL="https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig"
DEST="/tmp/mangopi_mq_r_defconfig"
wget -qO $DEST $URL || exit 1

# --- 2. 注入参数 ---
sed -i '/CONFIG_DEFAULT_DEVICE_TREE/d' $DEST
sed -i '/CONFIG_OF_LIST/d' $DEST
{
    echo 'CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong"'
    echo 'CONFIG_OF_LIST="sun8i-t113-tronlong"'
    echo "CONFIG_DRAM_CLK=792"
    echo "CONFIG_DRAM_ZQ=8092667"
    echo "CONFIG_DRAM_TYPE_DDR3=y"
    echo "CONFIG_DEBUG_UART=y"
    echo "CONFIG_DEBUG_UART_SUNXI=y"
    echo "CONFIG_DEBUG_UART_BASE=0x05000000"
    echo "CONFIG_DEBUG_UART_CLOCK=24000000"
    echo "CONFIG_DEBUG_UART_ANNOUNCE=y"
    echo "CONFIG_CONS_INDEX=1"
} >> $DEST

# --- 3. 生成 Defconfig 补丁 ---
PATCH_FILE_CONF="$PATCH_DIR/999-add-t113-tronlong-defconfig.patch"
cat <<EOF > $PATCH_FILE_CONF
--- /dev/null
+++ b/configs/allwinner_t113_tronlong_defconfig
@@ -0,0 +$(wc -l < $DEST) @@
EOF
sed 's/^/+/' $DEST >> $PATCH_FILE_CONF

# --- 4. 生成 DTS 补丁 (分两个文件，确保 Makefile 兼容性) ---

# 补丁 A: 创建新的 DTS 文件 (放在 allwinner 目录下)
PATCH_FILE_DTS_DATA="$PATCH_DIR/998-add-t113-tronlong-dts-file.patch"
DTS_TMP="/tmp/sun8i-t113-tronlong.dts"

cat <<EOF > $DTS_TMP
/dts-v1/;
#include "sun8i-t113s.dtsi"
#include <dt-bindings/gpio/gpio.h>
/ {
	model = "Tronlong TLT113-MiniEVM";
	compatible = "tronlong,tlt113-minievm", "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";
	aliases { serial0 = &uart0; mmc0 = &mmc0; };
	chosen { stdout-path = "serial0:115200n8"; };
};
&ccu { bootph-all; };
&pio {
	bootph-all;
	uart0_pg_pins: uart0-pg-pins { pins = "PG17", "PG18"; function = "uart0"; bootph-all; };
	mmc0_pins: mmc0-pins { pins = "PF0", "PF1", "PF2", "PF3", "PF4", "PF5"; function = "sdc0"; drive-strength = <30>; bias-pull-up; bootph-all; };
};
&uart0 { pinctrl-names = "default"; pinctrl-0 = <&uart0_pg_pins>; status = "okay"; bootph-all; };
&mmc0 { pinctrl-names = "default"; pinctrl-0 = <&mmc0_pins>; bus-width = <4>; broken-cd; status = "okay"; bootph-all; };
EOF

cat <<EOF > $PATCH_FILE_DTS_DATA
--- /dev/null
+++ b/arch/arm/dts/allwinner/sun8i-t113-tronlong.dts
@@ -0,0 +$(wc -l < $DTS_TMP) @@
EOF
sed 's/^/+/' $DTS_TMP >> $PATCH_FILE_DTS_DATA

# 补丁 B: 修改 Makefile (针对 arch/arm/dts/Makefile，这是最保险的路径)
PATCH_FILE_DTS_MAKE="$PATCH_DIR/997-add-t113-tronlong-dts-makefile.patch"
cat <<EOF > $PATCH_FILE_DTS_MAKE
--- a/arch/arm/dts/Makefile
+++ b/arch/arm/dts/Makefile
@@ -1,5 +1,6 @@
 # sunxi
+dtb-\$(CONFIG_MACH_SUN8I) += allwinner/sun8i-t113-tronlong.dtb
EOF

# --- 5. 注册与截胡 (保持不变) ---
if ! grep -q "allwinner_t113_tronlong" $UBOOT_MAKEFILE; then
    cat <<EOF >> $UBOOT_MAKEFILE
define U-Boot/allwinner_t113_tronlong
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong T113-i
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=allwinner_t113_tronlong
endef
EOF
fi
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 6. 镜像布局修正 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh: Fixed paths for U-Boot 2025.01"
