#!/bin/bash
#

SECONDS=0
ZIPNAME="Mimir-beckham-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-r450784e"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="beckham_defconfig"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

read -p "You want KernelSU? (y/n): " RESPONSE

if [ "$RESPONSE" == "y" ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
    sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/' arch/arm64/configs/$DEFCONFIG
        echo "KernelSU Enabled!"
    else
        echo "KernelSU Disabled!"
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz-dtb

kernel="out/arch/arm64/boot/Image.gz-dtb"

if [ -f "$kernel" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/SHAND-stuffs/AnyKernel3 -b beckham; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
	cp $kernel AnyKernel3
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout beckham &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3 out KernelSU
	git restore arch/arm64/configs/$DEFCONFIG drivers/Kconfig
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
