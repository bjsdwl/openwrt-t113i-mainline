#!/bin/bash

# --- 1. U-Boot 配置修正 (确保幂等性) ---
# 逻辑：先删除已有的冲突配置，再重新追加，防止重复编译时配置堆叠
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
[ -f $UBOOT_PATH ] && {
    sed -i '/CONFIG_DRAM_CLK/d' $UBOOT_PATH
    sed -i '/CONFIG_DRAM_ZQ/d' $UBOOT_PATH
    sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $UBOOT_PATH
    sed -i '/CONFIG_CONS_INDEX/d' $UBOOT_PATH
    
    echo "CONFIG_DRAM_CLK=792" >> $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    echo "CONFIG_CONS_INDEX=1" >> $UBOOT_PATH
    echo "CONFIG_SPL=y" >> $UBOOT_PATH
    echo "CONFIG_SUPPORT_SPL=y" >> $UBOOT_PATH
}

# --- 2. 注入 T113-i 工业版设备树 (补齐缺失头文件) ---
DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts/allwinner"
mkdir -p $DTS_DIR
cat <<EOF > $DTS_DIR/sun8i-t113i-industrial.dts
/dts-v1/;
/* 补齐 dt-bindings 头文件，防止 GIC_SPI 等宏编译报错 */
#include <dt-bindings/interrupt-controller/arm-gic.h>
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/clock/sun8i-t113s-ccu.h>
#include <dt-bindings/reset/sun8i-t113s-ccu.h>
#include "sun8i-t113s.dtsi"

/ {
    model = "Allwinner T113-i Industrial Board";
    compatible = "allwinner,sun8i-t113i", "allwinner,sun8i-t113s";

    soc {
        /* 强制 32位地址空间，规避总线挂死 */
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;
    };

    cpus {
        cpu@0 {
            device_type = "cpu";
            compatible = "arm,cortex-a7";
            enable-method = "psci";
        };
        cpu@1 {
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
    /* 补齐 PIO 中断定义，确保主线 MMC 驱动不挂起 */
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

# --- 3. 修复内核补丁 (使用 printf 确保 Tab 键与路径正确) ---
K_PATCH_DIR="target/linux/sunxi/patches-6.12"
mkdir -p $K_PATCH_DIR
K_PATCH="$K_PATCH_DIR/999-unlock-pinctrl.patch"

# 使用 printf 严格控制输出格式，移除多余反斜杠，确保 Tab (\t) 被内核识别
# 补丁采用模糊匹配范围 (@@ -81,7 +81,7 @@) 提高对小版本更新的容忍度
printf -- "--- a/drivers/pinctrl/sunxi/Kconfig\n" > $K_PATCH
printf -- "+++ b/drivers/pinctrl/sunxi/Kconfig\n" >> $K_PATCH
printf -- "@@ -81,3 +81,3 @@\n" >> $K_PATCH
printf -- " config PINCTRL_SUN20I_D1\n" >> $K_PATCH
printf -- "-\tdef_bool MACH_SUN20I\n" >> $K_PATCH
printf -- "+\tdef_bool MACH_SUN20I || ARCH_SUNXI\n" >> $K_PATCH
printf -- " \tselect PINCTRL_SUNXI\n" >> $K_PATCH

# --- 4. 镜像打包偏移修正 (强制适配 T113-i BROM) ---
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    # 适配主线偏移量：8KB (Sector 16)
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
fi
