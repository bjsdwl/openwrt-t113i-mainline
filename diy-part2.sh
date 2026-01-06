#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
PATCH_DIR="package/boot/uboot-sunxi/patches"
mkdir -p $PATCH_DIR

# --- 1. 下载 MangoPi MQ-R 配置作为底座 ---
echo "Downloading MangoPi defconfig template..."
wget -qO /tmp/mangopi_mq_r_defconfig https://raw.githubusercontent.com/u-boot/u-boot/master/configs/mangopi_mq_r_defconfig

# --- 2. 注入 T113-i 工业级参数 ---
echo "Patching parameters for T113-i Industrial..."

# [参数修正]
sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' /tmp/mangopi_mq_r_defconfig
# ZQ 改为十进制 (8092667)
sed -i '/CONFIG_DRAM_ZQ/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_ZQ=8092667" >> /tmp/mangopi_mq_r_defconfig
# 强制 DDR3
sed -i '/CONFIG_DRAM_TYPE_DDR3/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DRAM_TYPE_DDR3=y" >> /tmp/mangopi_mq_r_defconfig
# 串口索引
sed -i '/CONFIG_CONS_INDEX/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_CONS_INDEX=1" >> /tmp/mangopi_mq_r_defconfig
# SPL 开启
if ! grep -q "CONFIG_SPL=" /tmp/mangopi_mq_r_defconfig; then
    echo "CONFIG_SPL=y" >> /tmp/mangopi_mq_r_defconfig
fi

# [关键修正] 修改默认设备树名称
sed -i '/CONFIG_DEFAULT_DEVICE_TREE/d' /tmp/mangopi_mq_r_defconfig
echo "CONFIG_DEFAULT_DEVICE_TREE=\"sun8i-t113-industrial\"" >> /tmp/mangopi_mq_r_defconfig

# --- 3. 生成 Defconfig 补丁 ---
PATCH_FILE_CONF="$PATCH_DIR/999-add-t113-industrial-defconfig.patch"
echo "Creating defconfig patch: $PATCH_FILE_CONF"

LINE_COUNT=$(wc -l < /tmp/mangopi_mq_r_defconfig)
cat <<EOF > $PATCH_FILE_CONF
--- /dev/null
+++ b/configs/allwinner_t113_s3_defconfig
@@ -0,0 +1,${LINE_COUNT} @@
EOF
sed 's/^/+/' /tmp/mangopi_mq_r_defconfig >> $PATCH_FILE_CONF

# --- 4. 生成 DTS 注入补丁 (全面补全引脚定义) ---
PATCH_FILE_DTS="$PATCH_DIR/998-add-t113-industrial-dts.patch"
echo "Creating DTS injection patch: $PATCH_FILE_DTS"

# 4.1 构造 DTS 内容
# 这里我们补全了 uart0_pg_pins 和 mmc0_pins，确保万无一失
cat <<EOF > /tmp/sun8i-t113-industrial.dts
/dts-v1/;
#include "sun8i-t113s.dtsi"
#include <dt-bindings/gpio/gpio.h>

/ {
	model = "Allwinner T113-i Industrial";
	compatible = "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

	aliases {
		serial0 = &uart0;
		mmc0 = &mmc0;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};
};

&pio {
	/* 修复 1: 显式定义 UART0 (PG17/PG18) */
	uart0_pg_pins: uart0-pg-pins {
		pins = "PG17", "PG18";
		function = "uart0";
	};

	/* 修复 2: 显式定义 MMC0 (PF0-PF5) */
	/* 防止主线 dtsi 没定义这个节点导致的报错 */
	mmc0_pins: mmc0-pins {
		pins = "PF0", "PF1", "PF2", "PF3", "PF4", "PF5";
		function = "mmc0";
		drive-strength = <30>;
		bias-pull-up;
	};
};

&uart0 {
	pinctrl-names = "default";
	pinctrl-0 = <&uart0_pg_pins>;
	status = "okay";
};

&mmc0 {
	pinctrl-names = "default";
	pinctrl-0 = <&mmc0_pins>;
	bus-width = <4>;
	/* 修复 3: 使用 broken-cd 忽略卡检测引脚，防止定义错误导致读不到卡 */
	broken-cd;
	status = "okay";
};
EOF

# 4.2 构造补丁文件
DTS_LINES=$(wc -l < /tmp/sun8i-t113-industrial.dts)

# Part A: 添加 .dts 文件
cat <<EOF > $PATCH_FILE_DTS
--- /dev/null
+++ b/arch/arm/dts/sun8i-t113-industrial.dts
@@ -0,0 +1,${DTS_LINES} @@
EOF
sed 's/^/+/' /tmp/sun8i-t113-industrial.dts >> $PATCH_FILE_DTS

# Part B: 修改 Makefile (追加编译规则)
cat <<EOF >> $PATCH_FILE_DTS
--- a/arch/arm/dts/Makefile
+++ b/arch/arm/dts/Makefile
@@ -1,2 +1,3 @@
 # 追加 T113 规则
+dtb-\$(CONFIG_MACH_SUN8I) += sun8i-t113-industrial.dtb
EOF

# --- 5. 注册板型到 OpenWrt Makefile ---
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

# --- 6. 截胡 UBOOT_TARGETS ---
sed -i '/BuildPackage\/U-Boot/i UBOOT_TARGETS := allwinner_t113_s3' $UBOOT_MAKEFILE

# --- 7. 镜像逻辑修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMG_MAKEFILE" ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 8. 锁定 .config ---
sed -i '/CONFIG_PACKAGE_uboot-sunxi/d' .config
echo "CONFIG_PACKAGE_uboot-sunxi-allwinner_t113_s3=y" >> .config
