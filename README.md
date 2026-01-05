# OpenWrt for Allwinner T113-i (Mainline Strategy)

这是一个基于 OpenWrt Master 分支的 T113-i 适配项目。

## 核心设计
1. **Bootloader**: Mainline U-Boot (2024+)，写入偏移 **8KB (Sector 16)**。
2. **Kernel**: Linux 6.12+ (Pure 32-bit Address Model)。
3. **Multicore**: 采用 PSCI 方案，无需 vendor 特殊补丁。
4. **DDR**: 256MB DDR3 @ 792MHz (ZQ: 0x7b7bfb)。

## 烧录说明
编译完成后，从 Artifacts 下载镜像。

### 1. 烧录完整镜像 (SD卡)
```bash
dd if=openwrt-sunxi-cortexa7-allwinner_t113-i-sdcard.img of=/dev/sdX bs=1M
