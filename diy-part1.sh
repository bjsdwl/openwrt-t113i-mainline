#!/bin/bash

# --- 1. 替换为更稳定的 GitHub 镜像源 (解决 git.openwrt.org 连接超时) ---
sed -i 's/git.openwrt.org\/openwrt\/openwrt.git/github.com\/openwrt\/openwrt.git/g' feeds.conf.default
sed -i 's/git.openwrt.org\/feed\/packages.git/github.com\/openwrt\/packages.git/g' feeds.conf.default

# --- 2. 移除不需要的无关源 (解决 find 报错和 mesa 编译错误) ---
# U-Boot 只需要核心包，删除这些可以显著加快速度并提高成功率
sed -i '/luci/d' feeds.conf.default
sed -i '/routing/d' feeds.conf.default
sed -i '/telephony/d' feeds.conf.default
sed -i '/video/d' feeds.conf.default

echo "✅ Feeds optimized: GitHub mirrors used, useless feeds removed."
