#!/bin/bash
#设置环境变量
#CPU型号(骁龙8至尊默认为sm8750)
export CPU_MODEL="sm8750"
#要编译的机型xml源码文件名前缀
export XML_FILE="oneplus_ace5_pro"
#处理器代号
#export CPU_CODE="sun"
#安卓版本
export ANDROID_VERSION="android15"
#内核版本
export KERNEL_VERSION="6.6"
#内核名称
export KERNEL_NAME="-By-TG@Q1udaoyu"
#内核构建时间
export BUILD_TIME="2024-12-17 23:36:49 UTC"
#是否开启KPM 1开启0关闭
export KERNEL_KPM="1"
#是否开启风驰内核 1开启0关闭
export KERNEL_SCX="1"
#是否开启lz4kd 1开启0关闭
export KERNEL_LZ4="0"

#设置Git用户名与邮箱
git config --global user.name "Q1udaoyu"
git config --global user.email "sucisama2888@gmail.com"

#安装环境依赖
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 git curl

#下载repo并移动至bin目录给予权限
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/repo
chmod a+x ~/repo
sudo mv ~/repo /usr/local/bin/repo

#创建内核工作目录并克隆源码
mkdir build_kernel && cd build_kernel
repo init -u https://github.com/sucigmail/kernel_manifest.git -b refs/heads/oneplus/${CPU_MODEL} -m ${XML_FILE}.xml --depth=1
#同步内核源码
repo --trace sync -c -j$(nproc --all) --no-tags
#删除ABI保护符
rm kernel_platform/common/android/abi_gki_protected_exports_* || echo "No File"
rm kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No File"

#拉取SukiSU源码并设置版本号
cd kernel_platform
curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev

cd ./KernelSU
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count main) "+" 10606)
echo "KSUVER=$KSU_VERSION" >> .env
source .env

export KSU_VERSION=$KSU_VERSION

sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile

#写入SUSFS补丁
cd ~/build_kernel
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION}
git clone https://github.com/ShirkNeko/SukiSU_patch.git
cd ~/build_kernel/kernel_platform
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

# lz4k
cp -r ../SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux
cp -r ../SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
cp -r ../SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
cp -r ../SukiSU_patch/other/zram/lz4k_oplus ./common/lib/
cd ./common
sed -i 's/-32,12 +32,38/-32,11 +32,37/g' 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch
sed -i '/#include <trace\/hooks\/fs.h>/d' 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch

# 应用补丁
patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
# 复制补丁文件
cp ../../SukiSU_patch/hooks/syscall_hooks.patch ./

# 应用补丁
patch -p1 -F 3 < syscall_hooks.patch

# 输出完成信息
echo "完成"



if [ "${KERNEL_LZ4}" = "1" ]; then
    cd ~/build_kernel/kernel_platform/common
    
    # 复制补丁文件
    cp ../../SukiSU_patch/other/zram/zram_patch/${KERNEL_VERSION}/lz4kd.patch ./
    
    # 应用补丁
    patch -p1 -F 3 < lz4kd.patch || true

else
    echo "未启用LZ4，跳过修补LZ4"
fi

# 进入工作目录
cd ~/build_kernel/kernel_platform

# 配置项数组
CONFIGS=(
  "CONFIG_KSU=y"
  "CONFIG_KSU_SUSFS_SUS_SU=n"
  "CONFIG_KSU_MANUAL_HOOK=y"
  "CONFIG_KSU_SUSFS=y"
  "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_PATH=y"
  "CONFIG_KSU_SUSFS_SUS_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_KSTAT=y"
  "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n"
  "CONFIG_KSU_SUSFS_TRY_UMOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SPOOF_UNAME=y"
  "CONFIG_KSU_SUSFS_ENABLE_LOG=y"
  "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y"
  "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y"
  "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y"
  "CONFIG_CRYPTO_LZ4HC=y"
  "CONFIG_CRYPTO_LZ4K=y"
  "CONFIG_CRYPTO_LZ4KD=y"
  "CONFIG_CRYPTO_842=y"
)

# 将配置项添加到 gki_defconfig
for CONFIG in "${CONFIGS[@]}"; do
  echo "$CONFIG" >> ./common/arch/arm64/configs/gki_defconfig
done

# 删除 check_defconfig
sudo sed -i 's/check_defconfig//' ./common/build.config.gki

# 提交更改到 Git
cd common
git add -A && git commit -a -m "BUILD Kernel"

# 检查 是否开启KPM
if [ "$KERNEL_KPM" = "1" ]; then
  # 进入工作目录
  cd ~/build_kernel/kernel_platform
  
  # 添加 KPM 配置项
  echo "CONFIG_KPM=y" >> ./common/arch/arm64/configs/gki_defconfig
  
  # 删除 check_defconfig
  sudo sed -i 's/check_defconfig//' ./common/build.config.gki
  
  # 提交更改到 Git
  cd common
  git add -A && git commit -a -m "BUILD Kernel"
else
  echo "KPM 配置未启用，跳过配置"
fi

# 修改内核名称
d ~/build_kernel/kernel_platform/ || exit
sed -i 's/res="\$res\$(cat "\$file")"/res="-android15-8-g013ec21bba94-abogki383916444"/g' ./common/scripts/setlocalversion
sudo sed -i "s/-android15-8-g013ec21bba94-abogki383916444/$KERNEL_NAME/g" ./common/scripts/setlocalversion

#!/bin/bash

# 检查是否启用 风驰
if [ "$KERNEL_SCX" == "1" ]; then
    # 进入目标目录
    cd ~/build_kernel/kernel_platform/ || exit

    # 克隆 sched_ext 仓库
    git clone https://github.com/HanKuCha/sched_ext.git

    # 复制文件到目标目录
    cp -r ./sched_ext/* ./common/kernel/sched

    # 删除 .git 目录
    rm -rf ./sched_ext/.git

    # 进入目标目录
    cd common/kernel/sched || exit
else
    echo "未启用 风驰内核，跳过添加 风驰内核"
fi

# 使用 date 命令将日期转换为 Unix 时间戳
SOURCE_DATE_EPOCH=$(date -d "$KERNEL_TIME" +%s)

#将时间戳设为环境变量
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}

# 进入工作目录
cd ~/build_kernel/kernel_platform || exit

# 执行构建命令
tools/bazel run --config=fast --config=stamp --lto=thin //common:kernel_aarch64_dist -- --dist_dir=dist


# 进入构建输出目录
cd ~/build_kernel/kernel_platform/dist/ || exit

# 下载并设置补丁工具
curl -LO https://github.com/ShirkNeko/SukiSU_KernelPatch_patch/releases/download/0.11-beta/patch_linux
chmod +x patch_linux

# 执行补丁工具
./patch_linux

# 删除旧的 Image 文件
rm -f Image

# 将 oImage 重命名为 Image
mv oImage Image

# 检查 AnyKernel3 文件夹是否存在，如果不存在则创建
if [ ! -d "./AnyKernel3" ]; then
  echo "AnyKernel3 文件夹不存在，正在创建..."
  mkdir ./AnyKernel3
else
  echo "AnyKernel3 文件夹已存在"
fi

# 克隆 AnyKernel3 仓库
git clone https://github.com/HanKuCha/AnyKernel3.git --depth=1

# 删除 AnyKernel3 中的 .git 目录和 push.sh 文件
rm -rf ./AnyKernel3/.git
rm -rf ./AnyKernel3/push.sh

# 将生成的内核镜像文件拷贝到 AnyKernel3 目录
cp ~/build_kernel/kernel_platform/dist/Image ./AnyKernel3/

# 上传 AnyKernel3 到存档
tar -czf SuKiSu_${KSUVER}_${FEIL}.tar.gz -C ./AnyKernel3 .

# 上传 Image 到存档
tar -czf Image_SuKiSu_${KSUVER}_${FEIL}.tar.gz -C ~/build_kernel/kernel_platform/dist Image

export DEST_PATH="/mnt/c/kernel"
mkdir -p "$DEST_PATH"
find ~/build_kernel/kernel_platform/dist/ -type f \( -iname "*img*" -o -iname "Image" -o -iname "*.img" -o -iname "*.tar" -o -iname "*.gz" \) -exec cp {} "$DEST_PATH" \;


echo "关于本次编译后的所有文件已导出到 C盘的 kernel 文件夹"
