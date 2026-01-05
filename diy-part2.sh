#!/bin/bash

# --- 1. U-Boot 配置修正 (确保输出符合 BROM 要求的 eGON 格式) ---
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
[ -f $UBOOT_PATH ] && {
    # 基础 DDR 参数
    sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    
    # 串口魔术修正：确保控制台索引正确 (UART0 = 1)
    echo "CONFIG_CONS_INDEX=1" >> $UBOOT_PATH
    
    # 核心：确保编译出的镜像包含 SPL 且支持 FIT 镜像（T113-i 必须）
    echo "CONFIG_SPL=y" >> $UBOOT_PATH
    echo "CONFIG_SUPPORT_SPL=y" >> $UBOOT_PATH
    echo "CONFIG_SPL_LIBCOMMON_SUPPORT=y" >> $UBOOT_PATH
    echo "CONFIG_SPL_LIBGENERIC_SUPPORT=y" >> $UBOOT_PATH
    echo "CONFIG_SPL_SERIAL=y" >> $UBOOT_PATH
}

# --- 2. 修正 BROM 查找偏移量 ---
# T113-i 的 BROM 首先查找第 16 扇区 (8KB)。
# 我们不仅要修改 Makefile，还要在生成镜像时确保前 8KB 是空的（或保留分区表）
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    # 强制修改 U-Boot 偏移为 8 (8KB / 512 = 16 sectors)
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    # 特别注意：部分 OpenWrt 分支使用的是硬编码的 128，需深度替换
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi

# --- 3. 注入 32位 T113-i 专用设备树 (含 BROM 识别的 Compatible 字符串) ---
DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts/allwinner"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/sun8i-t113i-industrial.dts
/dts-v1/;
#include "sun8i-t113s.dtsi"

/ {
    model = "Allwinner T113-i Industrial Board";
    /* 重点：compatible 顺序，确保内核能匹配到 sun8i-t113s 的初始化逻辑 */
    compatible = "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

    soc {
        /* 强制 32位地址：解决 D1 衍生版 64位地址导致的总线挂死 */
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;
    };

    /* 必须启用 PSCI，否则多核无法启动（BROM 之后的操作） */
    cpus {
        cpu0: cpu@0 {
            device_type = "cpu";
            compatible = "arm,cortex-a7";
            enable-method = "psci";
        };
        cpu1: cpu@1 {
            device_type = "cpu";
            compatible = "arm,cortex-a7";
            enable-method = "psci";
        };
    };

    psci {
        compatible = "arm,psci-1.0", "arm,psci-0.2";
        method = "smc";
    };
};

&pio {
    /* 注入 PIO 中断，防止主线驱动因为找不到中断而导致 GPIO/SD卡 崩溃 */
    interrupts = <GIC_SPI 14 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 15 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 16 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 17 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 18 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 19 IRQ_TYPE_LEVEL_HIGH>;
};

&mmc0 {
    vmmc-supply = <&reg_vcc3v3>;
    bus-width = <4>;
    cd-gpios = <&pio PF 6 GPIO_ACTIVE_LOW>;
    status = "okay";
};

&uart0 {
    pinctrl-names = "default";
    pinctrl-0 = <&uart0_pg_pins>;
    status = "okay";
};
EOF

# --- 4. 强制内核解锁（针对 T113/D1 的 pinctrl 限制） ---
K_PATCH="target/linux/sunxi/patches-6.12/999-unlock-pinctrl.patch"
mkdir -p $(dirname $K_PATCH)
cat <<EOF > $K_PATCH
--- a/drivers/pinctrl/sunxi/Kconfig
+++ b/drivers/pinctrl/sunxi/Kconfig
@@ -81,7 +81,7 @@
 
 config PINCTRL_SUN20I_D1
 	def_bool y if MACH_SUN20I
-	select PINCTRL_SUNXI
+	select PINCTRL_SUNXI if ARCH_SUNXI || MACH_SUN20I
EOF
