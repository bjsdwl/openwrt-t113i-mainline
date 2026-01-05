#!/bin/bash

# --- 1. U-Boot 参数热补丁 ---
# 修改 U-Boot 默认配置，注入工业级 DDR3 参数
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
[ -f $UBOOT_PATH ] && {
    sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    echo "CONFIG_CONS_INDEX=1" >> $UBOOT_PATH
}

# --- 2. 注入 T113-i 工业版 32位设备树 ---
DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts/allwinner"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/sun8i-t113i-industrial.dts
/dts-v1/;
#include "sun8i-t113s.dtsi"

/ {
    model = "Allwinner T113-i Industrial Board";
    compatible = "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

    cpus {
        cpu0: cpu@0 { enable-method = "psci"; };
        cpu1: cpu@1 { enable-method = "psci"; };
    };

    psci {
        compatible = "arm,psci-1.0", "arm,psci-0.2";
        method = "smc";
    };

    /* 强制锁定 32位地址空间 */
    soc {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;
    };
};

&pio {
    /* 补齐主线 PIO 缺失的 6 组中断定义，防止 MMC 挂起 */
    interrupts = <GIC_SPI 14 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 15 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 16 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 17 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 18 IRQ_TYPE_LEVEL_HIGH>,
                 <GIC_SPI 19 IRQ_TYPE_LEVEL_HIGH>;
};

&uart0 {
    pinctrl-names = "default";
    pinctrl-0 = <&uart0_pg_pins>;
    status = "okay";
};

&mmc0 {
    vmmc-supply = <&reg_vcc3v3>;
    bus-width = <4>;
    cd-gpios = <&pio PF 6 GPIO_ACTIVE_LOW>;
    status = "okay";
};
EOF

# --- 3. 内核 Kconfig 解锁 ---
# 允许 ARM 架构选择 sun20i (D1) 的 PIO 驱动（逻辑相同，主线误加了 RISCV 限制）
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

# --- 4. 镜像打包逻辑修正 ---
# 将 U-Boot 在 SD 卡的偏移量从 128KB (旧 SDK 标准) 修正为 8KB (主线标准)
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
[ -f $IMG_MAKEFILE ] && sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/' $IMG_MAKEFILE
