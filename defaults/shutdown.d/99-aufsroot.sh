#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-aufsroot.sh

for i in ro rw; do
    mkdir -p ${AUFS_MNT_ROOT}/$i
    mount -omove /oldroot${AUFS_MNT_ROOT}/$i ${AUFS_MNT_ROOT}/$i 2> /dev/null ||
      bad_msg "Failed to move /oldroot${AUFS_MNT_ROOT}/$i"
done

for i in `grep oldroot /proc/mounts | cut -d " " -f 2 | sed '1!G;h;$!d'`; do
    [ "$i" != "/oldroot" ] && umount "$i" 2> /dev/null
done

mkdir /run/oldrun
mount -omove /oldroot/run /run/oldrun

umount /oldroot

for i in ro rw; do
  umount ${AUFS_MNT_ROOT}/$i || bad_msg "Failed to unmount ${AUFS_MNT_ROOT}/$i"
done

