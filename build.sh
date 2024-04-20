#!/bin/bash
#
# Compile script for uvite Kernel
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="spiderblood-surya-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$HOME/tc/clang-r498229"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="spiderblood_defconfig"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
	local message="$1"
	echo -e "$GREEN${message}$NC"
}

task() {
	local message="$1"
	echo -e "$YELLOW${message}$NC"
}

error() {
	local message="$1"
	echo -e "$RED${message}$NC"
}

clear
info "--- Kernel Build Script ---"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"

if ! [ -f "out/.config" ]; then
	task "\n[*] Creating config file..."
	mkdir -p out
	make O=out ARCH=arm64 $DEFCONFIG
else
	info "\n[i] Using existing config file!"
fi

if ! [ -d "$TC_DIR" ]; then
	task "\n[*] AOSP clang not found! Cloning to $TC_DIR...\n"
	if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		error "\nCloning failed! Aborting..."
		exit 1
	fi
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	info "\n[i] Successfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	info "\n[i] Successfully regenerated full defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

if [[ $1 = "-m" || $1 = "--menuconfig" ]]; then
	make O=out ARCH=arm64 menuconfig
fi

task "\n[*] Starting compilation...\n"
make -j$(nproc --all) O=out CCACHE=true ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz dtbo.img

task "\n[*] Installing modules...\n"
make -j$(nproc --all) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 modules
make -j$(nproc --all) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 modules_install

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
cpath=`pwd`

if [ -f "$kernel" ]; then
	info "\n[i] Kernel compiled succesfully! Zipping up...\n"

	if ! [ -d "$AK3_DIR" ]; then
		error "\n[!] No folder - $AK3_DIR"
		exit 1
	fi

	cp $kernel $dtbo $AK3_DIR
	rm -rf out/arch/arm64/boot
	cd $AK3_DIR
	zip -r9 "$ZIPNAME" * -x .git README.md *placeholder
	mv "$ZIPNAME" $cpath
	cd -
	info "\n[i] Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	info "\n[i] Generated $cpath/$ZIPNAME\n"
else
	error "\n[!] Compilation failed!"
	exit 1
fi