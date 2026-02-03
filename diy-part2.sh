#!/bin/bash

UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

echo ">>> 🚨 FORCE REWRITING U-BOOT MAKEFILE..."

# 直接重写 Makefile，只留下我们的 t113_nagami
cat << 'EOF' > $UBOOT_MAKEFILE
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_VERSION:=2025.01
PKG_HASH:=cdef7d507c93f1bbd9f015ea9bc21fa074268481405501945abc6f854d5b686f

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=sunxi
  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin
endef

define U-Boot/t113_nagami
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong T113-i (Native)
  BUILD_DEVICES:=tronlong_t113-i
endef

UBOOT_TARGETS := t113_nagami

$(eval $(call BuildPackage/U-Boot))
EOF

echo "✅ Makefile rewritten. Only t113_nagami target exists now."
