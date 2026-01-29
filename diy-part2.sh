#!/bin/bash

UBOOT_PKG_DIR="package/boot/uboot-sunxi"
UBOOT_MAKEFILE="$UBOOT_PKG_DIR/Makefile"

echo ">>> Starting diy-part2.sh: Logic-aware Makefile Reconstruction..."

# 1. 强制版本
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2025.01/g' $UBOOT_MAKEFILE
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' $UBOOT_MAKEFILE

# 2. 注入补丁
rm -rf $UBOOT_PKG_DIR/patches && mkdir -p $UBOOT_PKG_DIR/patches
[ -d "$GITHUB_WORKSPACE/patches-uboot" ] && cp $GITHUB_WORKSPACE/patches-uboot/*.patch $UBOOT_PKG_DIR/patches/

# 3. 使用 Python 精准重写 Makefile
# 相比 sed，Python 能更好处理多行反斜杠逻辑，防止误删文件头
cat << 'EOF' > rewrite_makefile.py
import sys
import os

makefile_path = sys.argv[1]
with open(makefile_path, 'r') as f:
    lines = f.readlines()

new_lines = []
skip_mode = False
targets_replaced = False

for line in lines:
    stripped = line.strip()
    
    # 逻辑 1: 遇到 UBOOT_TARGETS 开始的行 -> 开启跳过模式
    if stripped.startswith('UBOOT_TARGETS :='):
        skip_mode = True
        # 只写入一次新的目标定义
        if not targets_replaced:
            new_lines.append('UBOOT_TARGETS := nc_link_t113s3\n')
            targets_replaced = True
    
    # 逻辑 2: 处理跳过模式 (删除旧列表)
    if skip_mode:
        # 如果当前行不以反斜杠结尾，说明列表结束，关闭跳过模式
        if not stripped.endswith('\\'):
            skip_mode = False
        # 跳过当前行，不写入
        continue

    # 逻辑 3: 删除已有的 nc_link_t113s3 定义 (防止重复)
    if stripped.startswith('define U-Boot/nc_link_t113s3'):
        skip_mode = True # 复用跳过模式逻辑，直到 endef
        continue
    if skip_mode and stripped == 'endef':
        skip_mode = False
        continue

    # 逻辑 4: 暂时移除最后的 eval，稍后统一追加
    if '$(eval $(call BuildPackage,U-Boot))' in line:
        continue

    # 默认写入行
    new_lines.append(line)

# 逻辑 5: 追加新的设备定义和 eval
new_lines.append('\n')
new_lines.append('define U-Boot/nc_link_t113s3\n')
new_lines.append('  NAME:=Tronlong T113-i (Native Binman)\n')
new_lines.append('  BUILD_DEVICES:=xunlong_orangepi-one\n')
new_lines.append('  UBOOT_CONFIG:=nc_link_t113s3\n')
new_lines.append('  UBOOT_IMAGE:=u-boot-sunxi-with-spl.bin\n')
new_lines.append('endef\n')
new_lines.append('\n$(eval $(call BuildPackage,U-Boot))\n')

with open(makefile_path, 'w') as f:
    f.writelines(new_lines)
EOF

# 执行 Python 脚本
python3 rewrite_makefile.py "$UBOOT_MAKEFILE"
rm rewrite_makefile.py

echo "✅ diy-part2.sh: Makefile rewritten safely."
