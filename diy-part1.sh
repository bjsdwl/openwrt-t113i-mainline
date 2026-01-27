#!/bin/bash
sed -i 's/git.openwrt.org\/openwrt\/openwrt.git/github.com\/openwrt\/openwrt.git/g' feeds.conf.default
sed -i 's/git.openwrt.org\/feed\/packages.git/github.com\/openwrt\/packages.git/g' feeds.conf.default
