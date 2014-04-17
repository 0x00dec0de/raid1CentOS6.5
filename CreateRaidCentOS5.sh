#   Device Boot      Start         End      Blocks   Id  System
#/dev/sda1   *           1          13      104391   83  Linux                /boot
#/dev/sda2              14         274     2096482+  83  Linux                /tmp
#/dev/sda3             275         796     4192965   82  Linux swap / Solaris swap
#/dev/sda4             797      121454   969185385    5  Extended
#/dev/sda5             797      121454   969185353+  83  Linux               /root 


sfdisk -d /dev/sda | sfdisk -f /dev/sdb
sfdisk -d /dev/sda | sfdisk -f /dev/sdc
sfdisk -d /dev/sda | sfdisk -f /dev/sdd


modprobe linear
modprobe raid0
modprobe raid1


mdadm --create /dev/md0 --metadata=0.90 --level=1 --raid-devices=4 /dev/sdb1 /dev/sdc1 /dev/sdd1 missing
mdadm --create /dev/md1 --level=1 --raid-devices=4 /dev/sdb2 /dev/sdc2 /dev/sdd2 missing
mdadm --create /dev/md2 --level=1 --raid-devices=4 /dev/sdb5 /dev/sdc5 /dev/sdd5 missing

mkfs.ext2 /dev/md0
mkfs.ext3 /dev/md1
mkfs.ext3 /dev/md2

mkswap /dev/sdb3
mkswap /dev/sdc3
mkswap /dev/sdd3

mdadm --detail --scan > /etc/mdadm.conf

# edit /etc/fstab /boot/grub/grub.conf /etc/sysconfig/selinux


cd /tmp/
wget "http://wiki.centos.org/HowTos/Install_On_Partitionable_RAID1?action=AttachFile&do=get&target=mkinitrd-md_d0.patch" -O mkinitrd-md_d0.patch
cd /sbin/
cp mkinitrd mkinitrd.dist
patch -p0 < /tmp/mkinitrd-md_d0.patch
echo "exclude=mkinitrd*" >> /etc/yum.conf

mv /boot/initrd-$(uname -r).img /boot/initrd-$(uname -r).img.dist
mkinitrd /boot/initrd-$(uname -r).img $(uname -r)

mkdir /mnt/raid
mount /dev/md0 /mnt/raid
cd /boot; find . -depth | cpio -pmd /mnt/raid
touch /mnt/raid/.autorelabel
sync
umount /mnt/raid 

mount /dev/md2 /mnt/raid
cd / ; find . -depth -xdev | grep -v '^\./tmp/' | cpio -pmd /mnt/raid
chmod 777 /mnt/raid/tmp
sync
umount /mnt/raid


grub
  root (hd0,0)
  setup (hd0)
  root (hd1,0)
  setup (hd1)
  ...
  quit

reboot 

mdadm /dev/md0 -a /dev/sda1
mdadm /dev/md1 -a /dev/sda2
mdadm /dev/md2 -a /dev/sda5


# end if boot sync 
grub 
  root (hd0,0)
  setup (hd0)


