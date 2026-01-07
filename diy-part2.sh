#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载模板 (MangoPi MQ-R 是 T113 的最佳主线基板) ---
URL="https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig"
DEST="/tmp/mangopi_mq_r_defconfig"
wget -qO $DEST $URL || exit 1

# --- 2. 注入参数 (彻底清除旧 Dts 引用，防止编译报错) ---
sed -i '/CONFIG_DEFAULT_DEVICE_TREE/d' $DEST
sed -i '/CONFIG_OF_LIST/d' $DEST
{
    echo 'CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong"'
    echo 'CONFIG_OF_LIST="sun8i-t113-tronlong"'
    echo "CONFIG_DRAM_CLK=792"
    echo "CONFIG_DRAM_ZQ=8092667"
    echo "CONFIG_DRAM_TYPE_DDR3=y"
    # 强制开启早期调试 (DRAM 失败也能看到输出)
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

# --- 4. 生成 DTS 补丁 (适配 2025.01 路径: arch/arm/dts/allwinner/) ---
PATCH_FILE_DTS="$PATCH_DIR/998-add-t113-tronlong-dts.patch"
DTS_TMP="/tmp/sun8i-t113-tronlong.dts"

cat <<EOF > $DTS_TMP
/dts-v1/;
#include "sun8i-t113s.dtsi"
#include <dt-bindings/gpio/gpio.h>

/ {
	model = "Tronlong TLT113-MiniEVM";
	compatible = "tronlong,tlt113-minievm", "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

	aliases {
		serial0 = &uart0;
		mmc0 = &mmc0;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};
};

&ccu {
	bootph-all;
};

&pio {
	bootph-all;
	uart0_pg_pins: uart0-pg-pins {
		pins = "PG17", "PG18";
		function = "uart0";
		bootph-all;
	};
	mmc0_pins: mmc0-pins {
		pins = "PF0", "PF1", "PF2", "PF3", "PF4", "PF5";
		function = "sdc0";
		drive-strength = <30>;
		bias-pull-up;
		bootph-all;
	};
};

&uart0 {
	pinctrl-names = "default";
	pinctrl-0 = <&uart0_pg_pins>;
	status = "okay";
	bootph-all;
};

&mmc0 {
	pinctrl-names = "default";
	pinctrl-0 = <&mmc0_pins>;
	bus-width = <4>;
	broken-cd;
	status = "okay";
	bootph-all;
};
EOF

DTS_LINES=$(wc -l < $DTS_TMP)
cat <<EOF > $PATCH_FILE_DTS
--- /dev/null
+++ b/arch/arm/dts/allwinner/sun8i-t113-tronlong.dts
@@ -0,0 +${DTS_LINES} @@
EOF
sed 's/^/+/' $DTS_TMP >> $PATCH_FILE_DTS

# 修正 Makefile 路径到 allwinner/Makefile
cat <<EOF >> $PATCH_FILE_DTS
--- a/arch/arm/dts/allwinner/Makefile
+++ b/arch/arm/dts/allwinner/Makefile
@@ -1,3 +1,4 @@
 # sunxi
+dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb
EOF

# --- 5. 截胡 OpenWrt U-Boot 目标 ---
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
# 强行重置编译目标
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 6. 镜像布局修正 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ diy-part2.sh: Configuration applied successfully."
