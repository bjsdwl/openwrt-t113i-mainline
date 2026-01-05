#!/bin/bash

# --- 1. U-Boot 参数热补丁 ---
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
[ -f $UBOOT_PATH ] && {
    sed -i 's/CONFIG_DRAM_CLK=.*/CONFIG_DRAM_CLK=792/' $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    echo "CONFIG_CONS_INDEX=1" >> $UBOOT_PATH
    echo "CONFIG_SPL=y" >> $UBOOT_PATH
    echo "CONFIG_SUPPORT_SPL=y" >> $UBOOT_PATH
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

    soc {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;
    };

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

# --- 3. 修复内核补丁 (解决 Hunk FAILED 问题) ---
# 使用 printf 来确保 Tab 键被正确写入补丁文件，避免 6.12 核心 Kconfig 匹配失败
K_PATCH_DIR="target/linux/sunxi/patches-6.12"
mkdir -p $K_PATCH_DIR
K_PATCH="$K_PATCH_DIR/999-unlock-pinctrl.patch"

# 构造符合 Linux 6.12 语法的补丁
# 注意：\t 代表制表符，这是 Kconfig 必须的格式
printf -- "---\ a/drivers/pinctrl/sunxi/Kconfig\n" > $K_PATCH
printf -- "+++ b/drivers/pinctrl/sunxi/Kconfig\n" >> $K_PATCH
printf -- "@@ -81,3 +81,3 @@\n" >> $K_PATCH
printf -- " config PINCTRL_SUN20I_D1\n" >> $K_PATCH
printf -- "-\tdef_bool MACH_SUN20I\n" >> $K_PATCH
printf -- "+\tdef_bool MACH_SUN20I || ARCH_SUNXI\n" >> $K_PATCH
printf -- " \tselect PINCTRL_SUNXI\n" >> $K_PATCH

# --- 4. 强制镜像打包偏移修正 ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
