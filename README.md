# T113-i Step 1: U-Boot Only

## 如何验证
1. 下载 `t113i-u-boot-with-spl.bin`。
2. 使用 `hexdump -C` 检查文件头，0x04 处应为 `eGON.BT0`。
3. 烧录：`sudo dd if=t113i-u-boot-with-spl.bin of=/dev/sdX bs=1k seek=8`。
4. 串口：PG17/PG18, 115200bps。
