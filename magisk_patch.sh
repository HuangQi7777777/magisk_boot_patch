#!/usr/bin/env sh

CPU_ABI=$1
KEEPFORCEENCRYPT=$2
KEEPVERITY=$3

if [ ! -d magisk ];then
    echo "magisk not found"
    exit 1
fi

if [ ! -d magisk/lib/$CPU_ABI ];then
    echo "magisk for cpu_abi:"$CPU_ABI" not found"
    exit 1
fi

eval $(cat magisk/assets/util_functions.sh|grep MAGISK_VER=)
echo $MAGISK_VER

adb wait-for-device

echo device found

adb push magisk/lib/x86_64/libmagiskboot.so /data/local/tmp/magiskboot

_bits=32
if grep -q "64" <<< "$CPU_ABI"; then _bits=64; fi
for _fn in "magiskinit" "magisk${_bits}"; do
    adb push "magisk/lib/$CPU_ABI/lib${_fn}.so" "/data/local/tmp/${_fn}"
    adb shell chmod 0755 "/data/local/tmp/${_fn}"
done

echo "Try: leave kernel patch."
sed -ie 's/0092CFC2C9CEC0DB00$/0092CFC2C9CEC0DB00 \&\& PATCHEDKERNEL=true/g' magisk/assets/boot_patch.sh
grep -HC3 0092CFC2C9CEC0DB00 magisk/assets/boot_patch.sh
adb push magisk/assets/boot_patch.sh /data/local/tmp/
adb shell chmod 755 /data/local/tmp/boot_patch.sh

adb push magisk/assets/stub.apk /data/local/tmp/
#adb push stub.apk /data/local/tmp/

echo "Fix: magisk/assets/util_functions.sh"
sed -ie 's/]$/]; then/g' magisk/assets/util_functions.sh
head -n 335 magisk/assets/util_functions.sh | tail
adb push magisk/assets/util_functions.sh /data/local/tmp/

for bootimage in `find imgs -name boot.img -o -name init_boot.img`;do
    bootdirname=`dirname $bootimage`
    bootpartname=`basename $bootimage`
    bootpartname=${bootpartname%%.*}
    magiskbootname=magisk-$bootpartname-$MAGISK_VER.img
    adb push $bootimage /data/local/tmp/boot.img
    adb shell KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT KEEPVERITY=$KEEPVERITY sh /data/local/tmp/boot_patch.sh /data/local/tmp/boot.img
    adb pull /data/local/tmp/new-boot.img $bootdirname/$magiskbootname
    python3 avbtool.py erase_footer --image $bootdirname/$magiskbootname
    bash resign.sh $bootdirname/$magiskbootname $bootimage
    adb shell /data/local/tmp/magiskboot cleanup
    adb shell ls /data/local/tmp/
    adb shell rm /data/local/tmp/*.img
    adb shell rm /data/local/tmp/kernel
    adb shell rm /data/local/tmp/kernel_dtb
    adb shell rm /data/local/tmp/ramdisk.cpio
    adb shell rm /data/local/tmp/second
    adb shell rm /data/local/tmp/dtb
    adb shell rm /data/local/tmp/extra
    adb shell rm /data/local/tmp/recovery_dtbo
    echo stock boot
    python3 avbtool.py info_image  --image $bootimage
    echo magisk boot
    python3 avbtool.py info_image  --image $bootdirname/$magiskbootname
done
