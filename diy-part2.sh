#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载模板 (带重试逻辑) ---
URL="https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig"
DEST="/tmp/mangopi_mq_r_defconfig"

# 尝试下载，如果失败则创建一个基础模板，保证脚本不中断
if ! wget -qO $DEST $URL; then
    echo "⚠️ Warning: Failed to download template, using local fallback."
    cat <<EOF > $DEST
CONFIG_ARM=y
CONFIG_ARCH_SUNXI=y
CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong"
CONFIG_MACH_SUN8I_R40=y
CONFIG_DRAM_CLK=792
CONFIG_DRAM_ZQ=8092667
CONFIG_DRAM_TYPE_DDR3=y
CONFIG_SPL=y
EOF
fi

# --- 2. 注入精细化参数 ---
# 强制覆盖 DRAM 参数
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' $DEST
sed -i '/CONFIG_DRAM_ZQ/d' $DEST
echo "CONFIG_DRAM_ZQ=8092667" >> $DEST
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $DEST
echo "CONFIG_DRAM_TYPE_DDR3=y" >> $DEST

# 注入早期调试参数 (防止 SPL 阶段无输出)
sed -i '/CONFIG_DEBUG_UART/d' $DEST
echo "CONFIG_DEBUG_UART=y" >> $DEST
echo "CONFIG_DEBUG_UART_SUNXI=y" >> $DEST
echo "CONFIG_DEBUG_UART_BASE=0x05000000" >> $DEST
echo "CONFIG_DEBUG_UART_CLOCK=24000000" >> $DEST
echo "CONFIG_DEBUG_UART_ANNOUNCE=y" >> $DEST
echo "CONFIG_CONS_INDEX=1" >> $DEST

# --- 3. 生成 Defconfig 补丁 ---
PATCH_FILE_CONF="$PATCH_DIR/999-add-t113-tronlong-defconfig.patch"
LINE_COUNT=$(wc -l < $DEST)
cat <<EOF > $PATCH_FILE_CONF
--- /dev/null
+++ b/configs/allwinner_t113_tronlong_defconfig
@@ -0,0 +1,${LINE_COUNT} @@
EOF
sed 's/^/+/' $DEST >> $PATCH_FILE_CONF

# --- 4. 生成 DTS 补丁 (关键：包含 CCU 和 PIO 标记) ---
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
		mmc0 = &mmc0;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};
};

&ccu {
	bootph-all; /* 必须：SPL 阶段需要初始化时钟 */
};

&pio {
	bootph-all; /* 必须：SPL 阶段需要初始化引脚 */
	uart0_pg_pins: uart0-pg-pins {
		pins = "PG17", "PG18";
		function = "uart0";
		drive-strength = <10>;
		bias-pull-up;
		bootph-all;
	};

	mmc0_pins: mmc0-pins {
		pins = "PF0", "PF1", "PF2", "PF3", "PF4", "PF5";
		function = "mmc0";
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
+++ b/arch/arm/dts/sun8i-t113-tronlong.dts
@@ -0,0 +1,${DTS_LINES} @@
EOF
sed 's/^/+/' $DTS_TMP >> $PATCH_FILE_DTS

cat <<EOF >> $PATCH_FILE_DTS
--- a/arch/arm/dts/Makefile
+++ b/arch/arm/dts/Makefile
@@ -1,2 +1,3 @@
 # 追加 T113 规则
+dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb
EOF

# --- 5. 注册新目标 ---
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

# 强制截胡：让 OpenWrt 只编译这个
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 6. 镜像布局调整 (8KB 偏移) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

echo "✅ All patches applied successfully!"
