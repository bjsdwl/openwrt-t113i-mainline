#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载模板 (MangoPi MQ-R) ---
# 依然使用 MangoPi 作为底座，因为它包含了 T113-S3 的基础架构配置
wget -qO /tmp/mangopi_mq_r_defconfig https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig

# --- 2. 注入 T113-i 官方参数 (源自 sys_config.fex) ---
# [DRAM]
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' /tmp/mangopi_mq_r_defconfig
sed -i '/CONFIG_DRAM_ZQ/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_ZQ=8092667" >> /tmp/mangopi_mq_r_defconfig
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_TYPE_DDR3=y" >> /tmp/mangopi_mq_r_defconfig
# [UART0]
sed -i '/CONFIG_CONS_INDEX/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_CONS_INDEX=1" >> /tmp/mangopi_mq_r_defconfig
# [SPL]
if ! grep -q "CONFIG_SPL=" /tmp/mangopi_mq_r_defconfig; then
    echo "CONFIG_SPL=y" >> /tmp/mangopi_mq_r_defconfig
fi
# [DTS名称]
sed -i '/CONFIG_DEFAULT_DEVICE_TREE/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DEFAULT_DEVICE_TREE=\"sun8i-t113-tronlong\"" >> /tmp/mangopi_mq_r_defconfig

# --- 3. 生成 Defconfig 补丁 ---
PATCH_FILE_CONF="$PATCH_DIR/999-add-t113-tronlong-defconfig.patch"
LINE_COUNT=$(wc -l < /tmp/mangopi_mq_r_defconfig)
cat <<EOF > $PATCH_FILE_CONF
--- /dev/null
+++ b/configs/allwinner_t113_tronlong_defconfig
@@ -0,0 +1,${LINE_COUNT} @@
EOF
sed 's/^/+/' /tmp/mangopi_mq_r_defconfig >> $PATCH_FILE_CONF

# --- 4. 生成 DTS 注入补丁 (核心修复：bootph-all) ---
PATCH_FILE_DTS="$PATCH_DIR/998-add-t113-tronlong-dts.patch"

# 构造 DTS：复刻官方引脚定义，并添加 U-Boot 必要的 bootph-all 标签
cat <<EOF > /tmp/sun8i-t113-tronlong.dts
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

&pio {
	/* 关键修复：添加 bootph-all 属性，确保 SPL 能初始化引脚 */
	bootph-all;

	/* 复刻官方: uart0_pins_a (PG17/PG18) */
	uart0_pg_pins: uart0-pg-pins {
		pins = "PG17", "PG18";
		function = "uart0";
		drive-strength = <10>;
		bias-pull-up;
		bootph-all;
	};

	/* 复刻官方: sdc0_pins_a (PF0-PF5) */
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
	/* 关键修复：让 SPL 初始化串口 */
	bootph-all;
};

&mmc0 {
	pinctrl-names = "default";
	pinctrl-0 = <&mmc0_pins>;
	bus-width = <4>;
	/* 复刻官方: 强制忽略卡检测 */
	broken-cd;
	status = "okay";
	bootph-all;
};
EOF

DTS_LINES=$(wc -l < /tmp/sun8i-t113-tronlong.dts)

# 生成 Patch 文件内容
cat <<EOF > $PATCH_FILE_DTS
--- /dev/null
+++ b/arch/arm/dts/sun8i-t113-tronlong.dts
@@ -0,0 +1,${DTS_LINES} @@
EOF
sed 's/^/+/' /tmp/sun8i-t113-tronlong.dts >> $PATCH_FILE_DTS

# 追加 Makefile 规则
cat <<EOF >> $PATCH_FILE_DTS
--- a/arch/arm/dts/Makefile
+++ b/arch/arm/dts/Makefile
@@ -1,2 +1,3 @@
 # 追加 Tronlong 规则
+dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-tronlong.dtb
EOF

# --- 5. 注册与截胡 ---
if ! grep -q "U-Boot/allwinner_t113_tronlong" $UBOOT_MAKEFILE; then
    cat <<EOF >> $UBOOT_MAKEFILE

define U-Boot/allwinner_t113_tronlong
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong T113-i
  BUILD_DEVICES:=allwinner_t113-s3
  UBOOT_CONFIG:=allwinner_t113_tronlong
  BL31:=
endef
EOF
fi

# 截胡目标
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_tronlong' $UBOOT_MAKEFILE

# --- 6. 镜像逻辑 (8KB) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 7. config ---
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_tronlong=y" >> .config
