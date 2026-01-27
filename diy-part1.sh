#!/bin/bash

# 1. 替换镜像源
sed -i 's/git.openwrt.org\/openwrt\/openwrt.git/github.com\/openwrt\/openwrt.git/g' feeds.conf.default
sed -i 's/git.openwrt.org\/feed\/packages.git/github.com\/openwrt\/packages.git/g' feeds.conf.default

# 2. 移除所有不必要的、可能引起报错的 Feed
# 我们只需要 base (默认在 core) 和 packages
sed -i '/luci/d' feeds.conf.default
sed -i '/routing/d' feeds.conf.default
sed -i '/telephony/d' feeds.conf.default
sed -i '/video/d' feeds.conf.default

echo "✅ Feeds simplified: video/luci/routing/telephony removed to prevent build errors."
