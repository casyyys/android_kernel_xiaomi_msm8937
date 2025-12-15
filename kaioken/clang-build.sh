#!/bin/bash

# ./build.sh -d <defconfig_used> -p <compiler_binary_path> -v <kaioken_version>
while getopts d:p:v: flag
do
    case "${flag}" in
        d) defconfigs=${OPTARG};;
        p) compiler=${OPTARG};;
        v) version=${OPTARG};;
    esac
done

KERNEL_DIR=$(pwd)
KAIOKEN_VERSION=$version
BUILD_USER=Kaioxen
BUILD_HOST=CircleCI
DEFCONFIG=$defconfigs
TOOLCHAIN_PATH_CLANG=$compiler

KERNEL_BUILD_VERSION=1
ZIP_NAME="Kaioken-Kernel-${KAIOKEN_VERSION}-k4.9-$(date +%d%m)-$(date +%H%M)-ulysse.zip"

# Color
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NOCOL='\033[0m'

clang_build() {
    echo "#${CIRCLE_BUILD_NUM:-1} Kaioken Build Started!"
    make PATH=${TOOLCHAIN_PATH_CLANG}:${PATH} -j12 \
    ARCH=arm64 \
    O=out \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJDUMP=llvm-objdump \
    OBJCOPY=llvm-objcopy \
    STRIP=llvm-strip
}

export KBUILD_BUILD_USER=${BUILD_USER}
export KBUILD_BUILD_HOST=${BUILD_HOST}
export KERNEL_BUILD_VERSION=$KERNEL_BUILD_VERSION
echo -e " "
echo -e "Build started...$NOCOL"

date1=$(date +"%s")
make ARCH=arm64 O=out $DEFCONFIG
clang_build
if [ $? -ne 0 ]; then
    echo "Build failed"
    echo "Kaioken Kernel Build Failed!"
    exit 1
else
    date2=$(date +"%s")
    diff=$(($date2-$date1))
    kernel_ver=$(cat out/.config | grep -oP '(?<=Linux/arm64 )[^ ]*')
    echo "Build completed in : $(($diff / 3600 )) hours $((($diff % 3600) / 60)) minutes $(($diff % 60)) seconds"
    commit=$(git log --pretty=format:'%h %s' -1)
    if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
        cp out/arch/arm64/boot/Image.gz-dtb ../AK3/
        pushd ../AK3
        zip -r9 ../upload/${ZIP_NAME} ./* -x *.zip*
        popd
        echo " "
        echo "Upload Success - Artifact stored at ../upload/${ZIP_NAME}"
        echo "Build Details:"
        echo "====================================="
        echo "Kernel: Kaioken Kernel"
        echo "Version: ${KAIOKEN_VERSION}"
        echo "Build Number: ${CIRCLE_BUILD_NUM:-1}"
        echo "Build Time: $((($diff % 3600) / 60)) minutes $(($diff % 60)) seconds"
        echo "Kernel Version: $kernel_ver"
        echo "Latest Commit: $commit"
        echo "Defconfig: $DEFCONFIG"
        echo "Builder: $BUILD_USER"
        echo "====================================="
        exit 0
    fi
fi

echo " "
echo "Build completed with warnings"
exit 0
