#!/bin/bash
#

SECONDS=0
TC_DIR="$(pwd)/tc/clang-r450784e"
AK3_DIR="$(pwd)/android/AnyKernel3"

DFLT="\033[0m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

echo -e "$YELLOW Enter the device name:$DFLT"
read DEVICE

DEFCONFIG="${DEVICE}_defconfig"

ZIPNAME="Mimir-$DEVICE-$(date '+%Y%m%d-%H%M').zip"

echo -e "$YELLOW Enable latest stable KernelSU? (y/n)$DFLT"
read RESPONSE

if [ "$RESPONSE" == "y" ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
    sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/' arch/arm64/configs/$DEFCONFIG
        echo -e "$GREEN KernelSU Enabled!$DFLT"
    else
        echo -e "$RED KernelSU Disabled!$DFLT"
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "$GREEN\nStarting compilation...\n$DFLT"
if [ "$DEVICE" == "lake" ]; then
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz-dtb dtbo.img
kernel="out/arch/arm64/boot/Image.gz-dtb"
dtbo="out/arch/arm64/boot/dtbo.img"
else
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz-dtb
kernel="out/arch/arm64/boot/Image.gz-dtb"
fi

if [ -f "$kernel" ]; then
	echo -e "$GREEN\nKernel compiled succesfully! Zipping up...\n$DFLT"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/SHAND-stuffs/AnyKernel3 -b $DEVICE; then
		echo -e "$RED\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting...$DFLT"
		exit 1
	fi
  if [ "$DEVICE" == "lake" ] && [ -f "$dtbo" ]; then
	cp $kernel $dtbo AnyKernel3
    else
	cp $kernel AnyKernel3
  fi
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout $DEVICE &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3 out KernelSU
	git restore arch/arm64/configs/$DEFCONFIG drivers/Kconfig
	echo -e "$GREEN\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !$DFLT"
	echo -e "$YELLOW Zip: $ZIPNAME$DFLT"
else
	echo -e "$RED\nCompilation failed!$DFLT"
	exit 1
fi
