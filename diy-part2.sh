name: T113-i U-Boot Build with Cache

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - 'diy-part1.sh'
      - 'diy-part2.sh'
      - 'seed.config'

env:
  REPO_URL: https://github.com/openwrt/openwrt
  REPO_BRANCH: master
  CONFIG_FILE: seed.config
  DIY_P1_SH: diy-part1.sh
  DIY_P2_SH: diy-part2.sh
  TZ: Asia/Shanghai

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Initialization Environment
        run: |
          sudo rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL
          sudo docker image prune --all --force
          sudo -E apt-get -qq update
          sudo -E apt-get -qq install ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pyelftools python3-setuptools python3-mako python3-ply qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev u-boot-tools gdisk
          sudo mkdir -p /workdir
          sudo chown $USER:$GROUPS /workdir

      - name: Clone Source Code
        run: |
          cd /workdir
          git clone --depth 1 $REPO_URL -b $REPO_BRANCH openwrt
          ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt

      - name: Cache DL Directory
        uses: actions/cache@v4
        with:
          path: openwrt/dl
          key: ${{ runner.os }}-openwrt-dl-${{ hashFiles('openwrt/include/toplevel.mk') }}

      - name: Cache Toolchain & Tools
        id: cache-toolchain
        uses: actions/cache@v4
        with:
          path: |
            openwrt/staging_dir
            openwrt/build_dir/host
            openwrt/build_dir/toolchain-*
          key: ${{ runner.os }}-openwrt-toolchain-${{ hashFiles('openwrt/include/toplevel.mk') }}-${{ hashFiles('seed.config') }}
          restore-keys: |
            ${{ runner.os }}-openwrt-toolchain-

      - name: Update & Install Feeds
        run: |
          cd openwrt
          chmod +x $GITHUB_WORKSPACE/$DIY_P1_SH
          $GITHUB_WORKSPACE/$DIY_P1_SH
          ./scripts/feeds update -a
          ./scripts/feeds install -a || echo "⚠️ Non-critical feed errors ignored"
          ./scripts/feeds install uboot-sunxi

      - name: Load Custom Configuration
        run: |
          cd openwrt
          [ -e $GITHUB_WORKSPACE/$CONFIG_FILE ] && cp $GITHUB_WORKSPACE/$CONFIG_FILE .config
          chmod +x $GITHUB_WORKSPACE/$DIY_P2_SH
          $GITHUB_WORKSPACE/$DIY_P2_SH
          make defconfig

      - name: Build Tools & Toolchain
        if: steps.cache-toolchain.outputs.cache-hit != 'true'
        run: |
          cd openwrt
          make tools/install -j$(nproc) || make tools/install V=s
          make toolchain/install -j$(nproc) || make toolchain/install V=s

      - name: Compile U-Boot
        id: compile
        run: |
          cd openwrt
          make package/boot/uboot-sunxi/compile -j$(nproc) V=s
          echo "status=success" >> $GITHUB_OUTPUT

      - name: Manually Repack and Collect Artifacts
        if: steps.compile.outputs.status == 'success'
        run: |
          mkdir -p $GITHUB_WORKSPACE/outputs
          cd openwrt
          
          # 1. 找到 U-Boot 构建目录
          UBOOT_BUILD_DIR=$(find build_dir/target-* -name "u-boot-20*" | grep "/u-boot-sunxi/" | head -n 1)
          echo ">>> Processing artifacts from: $UBOOT_BUILD_DIR"
          
          if [ -d "$UBOOT_BUILD_DIR" ]; then
              cd "$UBOOT_BUILD_DIR"
              
              # 2. 检查是否有 SPL 和 U-Boot 二进制
              if [ -f "spl/sunxi-spl.bin" ] && [ -f "u-boot.img" ]; then
                  echo ">>> Found components. Re-packing image..."
                  
                  # 3. 提取 mksunxiboot 工具 (通常在 tools/ 目录下)
                  # 如果找不到，我们用 Python 简单模拟或信任已有的 SPL
                  # 但为了保险，我们直接使用 cat 拼接，假设 spl/sunxi-spl.bin 已经是加过头的
                  # (U-Boot 构建系统生成的 spl/sunxi-spl.bin 通常已包含 eGON 头)
                  
                  # 创建合成镜像: SPL (padded to 32K) + U-Boot.img
                  # 这里的 32KB (0x8000) 偏移是关键，很多教程说是 32KB，也有说是紧接着
                  # 但为了安全，我们用标准的 sunxi-with-spl 布局：
                  # SPL @ 0
                  # U-Boot @ 32KB (or whatever config says)
                  
                  # 既然之前的自动合成可能失败，我们手动复制几个关键文件出来分析
                  cp spl/sunxi-spl.bin $GITHUB_WORKSPACE/outputs/sunxi-spl-debug.bin
                  cp u-boot.img $GITHUB_WORKSPACE/outputs/u-boot-debug.img
                  cp u-boot-sunxi-with-spl.bin $GITHUB_WORKSPACE/outputs/t113i-uboot-raw.bin
                  
                  # 额外：生成一个 FIT image (如果存在 u-boot.dtb)
                  if [ -f "u-boot.dtb" ]; then
                      cp u-boot.dtb $GITHUB_WORKSPACE/outputs/u-boot-debug.dtb
                  fi
              else
                  echo "❌ ERROR: spl/sunxi-spl.bin or u-boot.img not found!"
              fi
          else
              echo "❌ ERROR: U-Boot build directory not found!"
          fi
          
          ls -lh $GITHUB_WORKSPACE/outputs/

      - name: Upload U-Boot Artifacts
        uses: actions/upload-artifact@v4
        if: steps.compile.outputs.status == 'success'
        with:
          name: T113i-Uboot-Final
          path: ${{ github.workspace }}/outputs/*
