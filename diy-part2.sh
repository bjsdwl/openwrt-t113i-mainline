# 修改 package/boot/uboot-sunxi/Makefile
# 这一步至关重要！它注册了新的 T113 Target，让 OpenWrt 使用正确的架构编译。

sed -i '/define U-Boot\/Default/i \
define U-Boot/t113_nagami\n\
  BUILD_SUBTARGET:=cortexa7\n\
  NAME:=Tronlong T113-i (Native)\n\
  BUILD_DEVICES:=tronlong_t113-i\n\
endef\n' package/boot/uboot-sunxi/Makefile

# 还需要告诉 Makefile 使用哪个 defconfig
# 通常 NAME 对应 UBOOT_TARGETS，OpenWrt 会去 configs/ 目录下找 <NAME>_defconfig
# 所以我们需要把 UBOOT_TARGETS 加上 t113_nagami
sed -i 's/UBOOT_TARGETS := \\/UBOOT_TARGETS := t113_nagami \\/g' package/boot/uboot-sunxi/Makefile
