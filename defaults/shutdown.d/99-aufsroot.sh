#!/bin/sh

. /etc/initrd.d/00-common.sh

for i in mnt ro rw; do
  mkdir -p /mnt/aufs/$i
  mount -omove /newroot/mnt/root/$i /mnt/aufs/$i || bad_msg "Failed to move /newroot/mnt/root/$i"
done

umount /newroot

for i in mnt ro rw; do
  umount /mnt/aufs/$i || bad_msg "Failed to unmount /mnt/aufs/$i"
done

