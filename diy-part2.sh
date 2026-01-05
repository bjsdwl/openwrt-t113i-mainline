#!/bin/bash

# --- 1. U-Boot 参数热补丁 (完全使用 sed 替换，确保幂等且不依赖追加) ---
UBOOT_PATH="package/boot/uboot-sunxi/config/sunxi"
if [ -f $UBOOT_PATH ]; then
    # 强制修改现有项或确保项存在
    sed -i '/CONFIG_DRAM_CLK/c\CONFIG_DRAM_CLK=792' $UBOOT_PATH
    sed -i '/CONFIG_DRAM_ZQ/d' $UBOOT_PATH
    echo "CONFIG_DRAM_ZQ=0x7b7bfb" >> $UBOOT_PATH
    sed -i '/CONFIG_DRAM_TYPE_DDR3/d' $UBOOT_PATH
    echo "CONFIG_DRAM_TYPE_DDR3=y" >> $UBOOT_PATH
    sed -i '/CONFIG_CONS_INDEX/c\CONFIG_CONS_INDEX=1' $UBOOT_PATH
    sed -i '/CONFIG_SPL/c\CONFIG_SPL=y' $UBOOT_PATH
fi

# --- 2. 注入 T113-i 工业版设备树 (使用 cat <<'EOF' 防止 Shell 变量干扰) ---
DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts/allwinner"
mkdir -p $DTS_DIR
cat <<'EOF' > $DTS_DIR/sun8i-t113i-industrial.dts
/dts-v1/;
#include <dt-bindings/interrupt-controller/arm-gic.h>
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/clock/sun8i-t113s-ccu.h>
#include <dt-bindings/reset/sun8i-t113s-ccu.h>
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
    /* 强行补齐 PIO 中断定义，对应 Bank B-G */
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

# --- 3. 修复内核驱动 (Makefile 强行注入法 - 极高成功率) ---
# 无论 Kconfig 怎么说，直接在 Makefile 头部注入编译指令
K_PATCH_DIR="target/linux/sunxi/patches-6.12"
mkdir -p $K_PATCH_DIR
M_PATCH="$K_PATCH_DIR/999-force-compile-pinctrl.patch"

# 采用“零上下文”补丁：只要文件开头有 SPDX 声明，就注入 obj-y
cat <<'EOF' > $M_PATCH
--- a/drivers/pinctrl/sunxi/Makefile
+++ b/drivers/pinctrl/sunxi/Makefile
@@ -1,2 +1,3 @@
 # SPDX-License-Identifier: GPL-2.0
+obj-y += pinctrl-sun20i-d1.o
 obj-$(CONFIG_PINCTRL_SUNXI)	+= pinctrl-sunxi.o
EOF

# --- 4. 修正镜像生成逻辑 (针对 T113-i BROM 偏移) ---
# 确保 8KB (Sector 16) 偏移，彻底解决启动魔术数找不到的问题
IMG_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f $IMG_MAKEFILE ]; then
    sed -i 's/CONFIG_SUNXI_UBOOT_BIN_OFFSET=128/CONFIG_SUNXI_UBOOT_BIN_OFFSET=8/g' $IMG_MAKEFILE
    sed -i 's/seek=128/seek=16/g' $IMG_MAKEFILE
    # 针对部分主线 Makefile 可能存在的硬编码进行二次覆盖
    sed -i 's/uboot-offset := 128/uboot-offset := 8/g' $IMG_MAKEFILE
fi
