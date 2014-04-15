# CentOS Raid 1

sfdisk -d /dev/sda | sfdisk -f /dev/sdb

modprobe linear
modprobe raid0
modprobe raid1

mdadm --create /dev/md0 --metadata=0.90 --level=1 --raid-devices=2 /dev/sdb1 missing
mdadm --create /dev/md1 --level=1 --raid-devices=2 /dev/sdb2 missing
mdadm --create /dev/md2 --level=1 --raid-devices=2 /dev/sdb3 missing

mkfs.ext2 /dev/md0
mkfs.ext4 /dev/md1
mkfs.ext4 /dev/md2
mkswap /dev/sdb5

blkid

mdadm --detail --scan > /etc/mdadm.conf

cp /boot/grub/grub.conf /boot/grub/grub.conf.bk
cp /etc/fstab /etc/fstab.bk

# edit fstab

# edit grub.cfg add uuid and selinux=0 enforcing=0

# edit /etc/syscondig/selinux

mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old
dracut --mdadmconf --force /boot/initramfs-$(uname -r).img $(uname -r)

mkdir /mnt/raid
mount /dev/md0 /mnt/raid
cd /boot; find . -depth | cpio -pmd /mnt/raid
# touch /mnt/raid/.autorelabel
sync
umount /mnt/raid

mount /dev/md1 /mnt/raid
cd / ; find . -depth -xdev | grep -v '^\./tmp/' | cpio -pmd /mnt/raid
chmod 777 /mnt/raid/tmp
sync
umount /mnt/raid

grub
  root (hd0,0)
  setup (hd0)
  root (hd1,0)
  setup (hd1)
  quit

reboot

mdadm /dev/md0 -a /dev/sda1
mdadm /dev/md1 -a /dev/sda2
mdadm /dev/md2 -a /dev/sda3




