#!/bin/bash

# --- 1. 屏蔽掉会导致元数据扫描错误的源 (如 mesa/video) ---
# 这些源在编译 U-Boot 时完全不需要，删掉它们可以极大提高构建成功率和速度
sed -i '/video/d' feeds.conf.default

# --- 2. 可选：屏蔽掉其它暂时不需要的重型源 (进一步加速) ---
# sed -i '/luci/d' feeds.conf.default
# sed -i '/routing/d' feeds.conf.default
# sed -i '/telephony/d' feeds.conf.default

echo "✅ Problematic feeds (video/mesa) removed from configuration."
