#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载模板 ---
URL="https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig"
DEST="/tmp/mangopi_mq_r_defconfig"
wget -qO $DEST $URL || exit 1

# --- 2. 注入参数 (强制开启调试和正确参数) ---
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' $DEST
sed -i '/CONFIG_DRAM_ZQ/d' $DEST
echo "CONFIG_DRAM_ZQ=8092667" >> $DEST
echo "CONFIG_DRAM_TYPE_DDR3=y" >> $DEST

# 开启 Early Debug (这是为了防止 DRAM 初始化失败时串口没反应)
echo "CONFIG_DEBUG_UART=y" >> $DEST
echo "CONFIG_DEBUG_UART_SUNXI=y" >> $DEST
echo "CONFIG_DEBUG_UART_BASE=0x05000000" >> $DEST
echo "CONFIG_DEBUG_UART_CLOCK=24000000" >> $DEST
echo "CONFIG_DEBUG_UART_ANNOUNCE=y" >> $DEST

# 强制 SPL 包含串口驱动
echo "CONFIG_SPL_SERIAL=y" >> $DEST
echo "CONFIG_SPL_DRIVERS_MISC=y" >> $DEST
echo "CONFIG_CONS_INDEX=1" >> $DEST

# --- 4. 生成 DTS 补丁 (全节点标记方案) ---
PATCH_FILE_DTS="$PATCH_DIR/998-add-t113-tronlong-dts.patch"
DTS_TMP="/tmp/sun8i-t113-tronlong.dts"

cat <<EOF > $DTS_TMP
/dts-v1/;
#include "sun8i-t113s.dtsi"
#include <dt-bindings/gpio/gpio.h>

/ {
	model = "Tronlong TLT113-MiniEVM (OpenWrt)";
	compatible = "tronlong,tlt113-minievm", "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

	aliases {
		serial0 = &uart0;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};
};

&ccu {
	bootph-all; /* 必须给时钟控制器加标记，否则串口没时钟 */
};

&pio {
	bootph-all; /* 必须给引脚控制器加标记 */
	uart0_pg_pins: uart0-pg-pins {
		pins = "PG17", "PG18";
		function = "uart0";
		bootph-all;
	};
};

&uart0 {
	pinctrl-names = "default";
	pinctrl-0 = <&uart0_pg_pins>;
	status = "okay";
	bootph-all;
};
EOF
# (后续生成补丁并“截胡” Makefile 的代码保持不变...)
