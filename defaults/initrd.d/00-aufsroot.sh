#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-splash.sh

is_aufs_root() {
	if [ -b "${AUFS_ROOT}" ]; then
		return 0
	else
		return 1
	fi
}

aufs_root_init() {
	is_aufs_root || return 0

	good_msg "Mounting overlay file system ${AUFS_ROOT}"

	mkdir -p /mnt/aufs/rw /mnt/aufs/ro /mnt/aufs/mnt

	mount -t tmpfs none /mnt/aufs/mnt
	mkdir -p /mnt/aufs/mnt/mnt/root/ro /mnt/aufs/mnt/mnt/root/rw /mnt/aufs/mnt/mnt/root/mnt

	mount -oremount,rw /newroot
	mount -omove /newroot /mnt/aufs/rw

	mount "${AUFS_ROOT}" /mnt/aufs/ro

	mount -t aufs none /newroot -o dirs=/mnt/aufs/rw=rw:/mnt/aufs/ro=ro:/mnt/aufs/mnt=ro

	mount -omove /mnt/aufs/mnt /newroot/mnt/root/mnt
	mount -omove /mnt/aufs/ro /newroot/mnt/root/ro
	mount -omove /mnt/aufs/rw /newroot/mnt/root/rw

  aufs_root_install_shutdown_hook
}

aufs_root_install_shutdown_hook() {
    echo <<EOF > /run/initramfs/shutdown.d/99-aufsroot.sh
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
EOF

    chmod ugo+x /run/initramfs/shutdown.d/99-aufsroot.sh
}