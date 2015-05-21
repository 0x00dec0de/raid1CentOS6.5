
==================================================================
root@localhost:~ # gpart show
=>        34  1953525101  ada0  GPT  (931G)
          34           6        - free -  (3.0k)
          40        1024     1  freebsd-boot  (512k)
        1064         984        - free -  (492k)
        2048     2097152     2  freebsd-ufs  (1.0G)
     2099200     8388608     3  freebsd-swap  (4.0G)
    10487808    16777216     4  freebsd-ufs  (8.0G)
    27265024     4194304     5  freebsd-ufs  (2.0G)
    31459328  1922065800     6  freebsd-ufs  (916G)
  1953525128           7        - free -  (3.5k)

root@localhost:~ # ls -1 /dev/ada0p? 
/dev/ada0p1 
/dev/ada0p2 
/dev/ada0p3 
/dev/ada0p4 
/dev/ada0p5 
/dev/ada0p6 

# mount
/dev/ada0p2 on / (ufs, local)                         
devfs on /dev (devfs, local, multilabel)
/dev/ada0p4 on /var (ufs, local, soft-updates)
/dev/ada0p5 on /tmp (ufs, local, soft-updates)
/dev/ada0p6 on /usr (ufs, local, soft-updates)


# сопоставим 

/dev/ada0p1 freebsd-boot
/dev/ada0p2 freebsd-ufs  /
/dev/ada0p3 freebsd-swap
/dev/ada0p4 freebsd-ufs  /var
/dev/ada0p5 freebsd-ufs  /tmp
/dev/ada0p6 freebsd-ufs  /usr


================================================================

Копируем разметку

gpart backup ada0 > ada0.gpt
gpart restore -F /dev/ada1 < ada0.gpt
gpart restore -F /dev/ada2 < ada0.gpt
gpart restore -F /dev/ada3 < ada0.gpt


Загрузчик

gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ada1
gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ada2
gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ada3


Создаем raid массивы (количество зависит от разбивки)

gmirror label -vb round-robin boot /dev/ada1p1
gmirror label -vb round-robin root /dev/ada1p2
gmirror label -vb round-robin swap /dev/ada1p3
gmirror label -vb round-robin var  /dev/ada1p4
gmirror label -vb round-robin tmp  /dev/ada1p5

# the first pair
gmirror label -vb round-robin rst  /dev/ada1p6

# the second pair
gmirror label -vb round-robin rst1 /dev/ada2p6 /dev/ada3p6


Включем gmirror и stripe массивы в текущей системе:

kldload geom_stripe
gmirror load
echo geom_mirror_load="YES" >> /boot/loader.conf
echo geom_stripe_load="YES" >> /boot/loader.conf


# Create a mirror with two pairs
gstripe label -v st0 /dev/mirror/rst /dev/mirror/rst1

## 
ls -1 /dev/mirror/*
/dev/mirror/boot
/dev/mirror/root

/dev/mirror/rst
/dev/mirror/rst1

/dev/mirror/swap
/dev/mirror/tmp
/dev/mirror/var


newfs -U /dev/mirror/boot
newfs -U /dev/mirror/root
newfs -U /dev/mirror/tmp
newfs -U /dev/mirror/var
bsdlabel -w /dev/stripe/st0
newfs -U /dev/stripe/st0a


cp /etc/fstab /etc/fstab.bk
vi /etc/fstab

root@localhost:~ # cat /etc/fstab
#Device              Mountpoint          FSType     Options     Dump    Pass#
/dev/mirror/root              /                  ufs          rw        1        1
/dev/mirror/swap           none                 swap          sw        0        0
/dev/mirror/var            /var                  ufs          rw        2        2
/dev/mirror/tmp            /tmp                  ufs          rw        2        2
/dev/stripe/st0a           /usr                  ufs          rw        2        2

mkdir /mnt/raid

mount /dev/mirror/root /mnt/raid/
cd / ; find . -depth -xdev | grep -v '^\./tmp/' | cpio -pmd /mnt/raid
sync
umount /mnt/raid/

mount /dev/mirror/var /mnt/raid/
cd /var ; find . -depth -xdev | grep -v '^\./tmp/' | cpio -pmd /mnt/raid
sync
umount /mnt/raid/

mount /dev/stripe/st0a /mnt/raid 
cd /usr ; find . -depth -xdev | grep -v '^\./tmp/' | cpio -pmd /mnt/raid
sync
umount /mnt/raid


reboot 

sysctl kern.geom.debugflags=16

root@localhost:~ # gmirror status 
       Name    Status  Components
mirror/boot  COMPLETE  ada1p1 (ACTIVE)
mirror/root  COMPLETE  ada1p2 (ACTIVE)
mirror/swap  COMPLETE  ada1p3 (ACTIVE)
 mirror/var  COMPLETE  ada1p4 (ACTIVE)
 mirror/tmp  COMPLETE  ada1p5 (ACTIVE)
 mirror/rst  COMPLETE  ada1p6 (ACTIVE)
mirror/rst1  COMPLETE  ada2p6 (ACTIVE)
                       ada3p6 (ACTIVE)

# gmirror label -vb round-robin rst  /dev/ada1p6


gmirror insert boot /dev/ada0p1
gmirror insert root /dev/ada0p2
gmirror insert swap /dev/ada0p3
gmirror insert var  /dev/ada0p4
gmirror insert tmp  /dev/ada0p5

gmirror insert boot /dev/ada2p1
gmirror insert root /dev/ada2p2
gmirror insert swap /dev/ada2p3
gmirror insert var  /dev/ada2p4
gmirror insert tmp  /dev/ada2p5

gmirror insert boot /dev/ada3p1
gmirror insert root /dev/ada3p2
gmirror insert swap /dev/ada3p3
gmirror insert var  /dev/ada3p4
gmirror insert tmp  /dev/ada3p5

gmirror insert rst /dev/ada0p6


root@localhost:~ # gmirror status 
       Name    Status  Components
mirror/boot  COMPLETE  ada1p1 (ACTIVE)
                       ada0p1 (ACTIVE)
                       ada2p1 (ACTIVE)
                       ada3p1 (ACTIVE)
mirror/root  DEGRADED  ada1p2 (ACTIVE)
                       ada0p2 (ACTIVE)
                       ada2p2 (SYNCHRONIZING, 42%)
                       ada3p2 (SYNCHRONIZING, 13%)
mirror/swap  DEGRADED  ada1p3 (ACTIVE)
                       ada0p3 (ACTIVE)
                       ada2p3 (SYNCHRONIZING, 9%)
                       ada3p3 (SYNCHRONIZING, 2%)
 mirror/var  DEGRADED  ada1p4 (ACTIVE)
                       ada0p4 (ACTIVE)
                       ada2p4 (SYNCHRONIZING, 4%)
                       ada3p4 (SYNCHRONIZING, 0%)
 mirror/tmp  DEGRADED  ada1p5 (ACTIVE)
                       ada0p5 (ACTIVE)
                       ada2p5 (SYNCHRONIZING, 12%)
                       ada3p5 (SYNCHRONIZING, 2%)
 mirror/rst  DEGRADED  ada1p6 (ACTIVE)
                       ada0p6 (SYNCHRONIZING, 1%)
mirror/rst1  COMPLETE  ada2p6 (ACTIVE)
                       ada3p6 (ACTIVE)



root@localhost:~ # gstripe status
      Name  Status  Components
stripe/st0      UP  mirror/rst
                    mirror/rst1

