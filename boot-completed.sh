#!/system/bin/sh
#
# Copyright (C) 2025 utkustnr
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# wait until storage is decrypted
while [ ! -d "/storage/emulated/0/Android" ]; do
    sleep 1
done

# binary locations
SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"
RESPROP_BIN="/data/adb/ksu/bin/resetprop"
AVB_BIN="/data/adb/ksu/bin/miniavb"
# https://github.com/utkustnr/miniavb

# default paths
$SUSFS_BIN add_sus_mount /data/adb/modules
$SUSFS_BIN add_sus_mount /debug_ramdisk
$SUSFS_BIN add_sus_mount /system/etc/hosts
$SUSFS_BIN add_try_umount /system/etc/hosts 1

# hide modules.img
for device in $(ls -Ld /proc/fs/jbd2/loop*8 | sed 's|/proc/fs/jbd2/||; s|-8||'); do
    $SUSFS_BIN add_sus_path "/proc/fs/jbd2/${device}-8"
    $SUSFS_BIN add_sus_path "/proc/fs/ext4/${device}"
done

# lsposed paths
P1="/data/adb/modules/zygisk_lsposed/bin"
P2="/system/apex/com.android.art/bin"
P3="/apex/com.android.art/bin"
[ -f $P1/dex2oat ] && \
    $SUSFS_BIN add_sus_mount $P1/dex2oat && \
    $SUSFS_BIN add_sus_mount $P1/dex2oat32 && \
    $SUSFS_BIN add_sus_mount $P1/dex2oat64
[ -f $P2/dex2oat ] && \
    $SUSFS_BIN add_sus_mount $P2/dex2oat && \
    $SUSFS_BIN add_sus_mount $P2/dex2oat32 && \
    $SUSFS_BIN add_sus_mount $P2/dex2oat64 && \
    $SUSFS_BIN add_try_umount $P2/dex2oat 1 && \
    $SUSFS_BIN add_try_umount $P2/dex2oat32 1 && \
    $SUSFS_BIN add_try_umount $P2/dex2oat64 1
[ -f $P3/dex2oat ] && \
    $SUSFS_BIN add_sus_mount $P3/dex2oat && \
    $SUSFS_BIN add_sus_mount $P3/dex2oat32 && \
    $SUSFS_BIN add_sus_mount $P3/dex2oat64 && \
    $SUSFS_BIN add_try_umount $P3/dex2oat 1 && \
    $SUSFS_BIN add_try_umount $P3/dex2oat32 1 && \
    $SUSFS_BIN add_try_umount $P3/dex2oat64 1

# general paths
$SUSFS_BIN add_sus_mount /
$SUSFS_BIN add_sus_mount /system
$SUSFS_BIN add_sus_mount /vendor
$SUSFS_BIN add_sus_mount /data/adb/modules/zygisksu/module.prop
$SUSFS_BIN add_sus_mount /data/adb/rezygisk

# cmdline fixups
[ ! -d "/data/adb/ksu/log/" ] && mkdir -p "/data/adb/ksu/log/"
FAKE_CMDLINE="/data/adb/ksu/log/fake_proc_cmdline.txt"
cat /proc/cmdline > $FAKE_CMDLINE
sed -i 's/androidboot.verifiedbootstate=orange/androidboot.verifiedbootstate=green/g' $FAKE_CMDLINE
sed -i 's/androidboot.vbmeta.device_state=unlocked/androidboot.vbmeta.device_state=locked/g' $FAKE_CMDLINE
sed -i 's/androidboot.warranty_bit=1/androidboot.warranty_bit=0/g' $FAKE_CMDLINE
$SUSFS_BIN set_cmdline_or_bootconfig $FAKE_CMDLINE

# susussy
$SUSFS_BIN sus_su 2

# vbmeta
if [ -z $VBMETASIZE ]; then
    if [ -f $AVB_BIN ]; then
        VBMETASIZE=$($AVB_BIN /dev/block/by-name/vbmeta | grep "Total Block Size" | awk '{print $4}')
    else
        VBMETASIZE="9152"
    fi
fi
$RESPROP_BIN -n ro.boot.vbmeta.size $VBMETASIZE
# https://android.googlesource.com/platform/external/avb/+/88b13e12a0ebe3c5195dbb5f48ba00ec896d1517
$RESPROP_BIN -n ro.boot.vbmeta.digest $(dd if=/dev/block/by-name/vbmeta bs=1 count=$VBMETASIZE 2>/dev/null | sha256sum | awk '{print $1}')
$RESPROP_BIN -n ro.boot.vbmeta.hash_alg sha256
$RESPROP_BIN -n ro.boot.vbmeta.avb_version 1.0
if [[ "$(getprop ro.unica.version | cut -d'-' -f1)" < "2.5.5" ]]; then
    # kanged from un1ca
    $RESPROP_BIN -n ro.boot.vbmeta.device_state locked
    $RESPROP_BIN -n ro.boot.flash.locked 1
    $RESPROP_BIN -n ro.boot.verifiedbootstate green
    $RESPROP_BIN -n ro.boot.veritymode enforcing
    $RESPROP_BIN -n ro.boot.warranty_bit 0
fi
$RESPROP_BIN -n ro.boot.vbmeta.invalidate_on_error yes

# fucking youtube...
# have to find the randomised path first
# modify package name for music or other revanced apps, this is for main youtube app
youtube=""
timeout=30
elapsed=0
while [ ! -f "$youtube" ] && [ $elapsed -lt $timeout ]; do
    youtube=$(find /data/app -type f -name "base.apk" -path "*com.google.android.youtube*")
    sleep 1
    elapsed=$((elapsed + 1))
done
if [ -f $youtube ]; then $SUSFS_BIN add_sus_mount $youtube; fi
