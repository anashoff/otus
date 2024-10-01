# Administrator Linux. Professional

## Урок 6. Домашнее задание

Работа с LVM

### Описание домашнего задания

Подготовить стенд на Vagrant с предложенным образом (centos/7 1804.2)

на имеющемся образе  
/dev/mapper/VolGroup00-LogVol00 38G 738M 37G 2% /

- уменьшить том под / до 8G
- выделить том под /home
- выделить том под /var (/var - сделать в mirror)
- для /home - сделать том для снэпшотов
- прописать монтирование в fstab (попробовать с разными опциями и разными файловыми системами на выбор)
- Работа со снапшотами:
  - сгенерировать файлы в /home/
  - снять снэпшот
  - удалить часть файлов
  - восстановиться со снэпшота

### Выполнение

Загружаем предложенный в методическом пособии Vagrantfile
и исправляем пути к репозиториям для работы yum

```ruby
  sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
  sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
  sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
```

Запускаем ВМ и проверяем доступ по ssh

```[vagrant@lvm ~]$```

Доступ есть. Почти все команды требуют прав суперпользователя, поэтому сразу переходим в root:

```sudo -i```

Смотрим структуру дисков

```text
[vagrant@lvm ~]$ lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

### Уменьшить том под / до 8 Gb

В лоб эту задачу не решить, план действий такой:

1. Создаем временный раздел XFS на новом томе LVM. Переносим корневой раздел на временный том и загружаемся с него.
2. Уменьшаем исходный том до нужного размера, возвращаем на него данные. Загружаемся с нового раздела.
3. Удаляем временный том.

Установим нужные утилиты

```yum install lvm2 xfsdump```

Создаем PV

```text
[root@lvm ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
```

Создаем VG

```text
[root@lvm ~]# vgcreate vg_t_r /dev/sdb
  Volume group "vg_t_r" successfully created
```

Создаем временный LV

```text
[root@lvm ~]# lvcreate -n lv_t_r -l +100%FREE /dev/vg_t_r
  Logical volume "lv_t_r" created.
```

Создаем ФС

```text
[root@lvm ~]# mkfs.xfs /dev/vg_t_r/lv_t_r
meta-data=/dev/vg_t_r/lv_t_r     isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

Монтируем временный раздел

```text
[root@lvm ~]# mount /dev/vg_t_r/lv_t_r /mnt
```

Сделаем дамп нашего корневого раздела во временный

```text
[root@lvm ~]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
```

В конце вывода должно быть

```text
xfsrestore: Restore Status: SUCCESS
```

Сымитируем текущий root, сделаем в него chroot и обновим grub:

```text
[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done

[root@lvm ~]# chroot /mnt/

[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
```

Обновляем образы загрузки:

```text
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```

В конфигурационном файле grub меняем ссылки старого тома VolGroup00/LogVol00 на временный vg_t_r/lv_t_r

Выходим из chroot и перезагружаемся.

Заходим под root
Смотрим структуру дисков

```text
[root@lvm ~]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm
sdb                       8:16   0   10G  0 disk
└─vg_t_r-lv_t_r         253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

Видим, что временый раздел стал /

Удаляем логический том LogVol00

```text
[root@lvm ~]# lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed
```

Создаем новый том LogVol00 размером 8Gb

```text
[root@lvm ~]# lvcreate -n LogVol00 -L 8G VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
[root@lvm ~]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0    8G  0 lvm
sdb                       8:16   0   10G  0 disk
└─vg_t_r-lv_t_r         253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

Создаем файловую систему и монтируем том

```text
[root@lvm ~]# mkfs.xfs /dev/VolGroup00/LogVol00
meta-data=/dev/VolGroup00/LogVol00 isize=512    agcount=4, agsize=524288 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2097152, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm ~]# mount /dev/VolGroup00/LogVol00 /mnt
```

Переносим root обратно на том LogVol00 аналогично проделанному выше

```text
[root@lvm ~]# xfsdump -J - /dev/vg_t_r/lv_t_r | xfsrestore -J - /mnt
......
xfsrestore: Restore Status: SUCCESS
[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm ~]# chroot /mnt/
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```

В файле grub меняем ссылки с временного тома vg_t_r/lv_t_r на новый VolGroup00/LogVol00

Выходим из окружения chroot и перезагружаем компьютер

Смотрим разделы

```text
root@lvm ~]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0    8G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk
└─vg_t_r-lv_t_r         253:2    0   10G  0 lvm
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

Удалаяем временный том

```text
[root@lvm ~]# lvremove /dev/vg_t_r/lv_t_r
Do you really want to remove active logical volume vg_t_r/lv_t_r? [y/n]: y
  Logical volume "lv_t_r" successfully removed
[root@lvm ~]# vgremove /dev/vg_t_r
  Volume group "vg_t_r" successfully removed
[root@lvm ~]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```

### Выделить том под /home

Для полного доступа к /home нужно зайти в систему как root, не под sudo.

Создадим новый раздел

```text
[root@lvm ~]# lvcreate -n LogVol02 -L 10G VolGroup00
  Logical volume "LogVol02" created.
[root@lvm ~]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol02 253:3    0   10G  0 lvm
sdb                       8:16   0   10G  0 disk
└─vg_t_r-lv_t_r         253:2    0   10G  0 lvm
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

Создаем файловую систему и монтируем том

```text
[root@lvm ~]# mkfs.xfs /dev/VolGroup00/LogVol02
meta-data=/dev/VolGroup00/LogVol02 isize=512    agcount=4, agsize=655360 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2621440, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm ~]# mount /dev/VolGroup00/LogVol02 /mnt/
```

Копируем все содержимое /home на новый том

```text
[root@lvm ~]# cp -aR /home/* /mnt
```

Очищаем /home и монтируем новый том как /home

```text
[root@lvm ~]# rm -rf /home/*
[root@lvm ~]# umount /mnt
[root@lvm ~]# mount /dev/VolGroup00/LogVol02 /home
[root@lvm ~]# ls /home
vagrant
```

Добавим в fstab новую точку монтирования.

```text
[root@lvm ~]# echo "`blkid | grep Home | awk '{print $2}'` \
 /home xfs defaults 0 0" >> /etc/fstab
```

### Выделить том под /var (/var - сделать в mirror)

Создаем зеркало на дисках sdd и sde

```text
[root@lvm ~]# pvcreate /dev/sdd /dev/sde
  Physical volume "/dev/sdd" successfully created.
  Physical volume "/dev/sde" successfully created.
[root@lvm ~]# vgcreate vg_var /dev/sdd /dev/sde
  Volume group "vg_var" successfully created
[root@lvm ~]# lvcreate -n lv_var -l 100%FREE -m1 vg_var
WARNING: ext4 signature detected on /dev/vg_var/lv_var_rmeta_0 at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/vg_var/lv_var_rmeta_0.
  Logical volume "lv_var" created.
[root@lvm ~]# lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                        8:0    0   40G  0 disk
├─sda1                     8:1    0    1M  0 part
├─sda2                     8:2    0    1G  0 part /boot
└─sda3                     8:3    0   39G  0 part
  ├─VolGroup00-LogVol00  253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol02  253:3    0   10G  0 lvm  /home
sdb                        8:16   0   10G  0 disk
sdc                        8:32   0    2G  0 disk
sdd                        8:48   0    1G  0 disk
├─vg_var-lv_var_rmeta_0  253:4    0    4M  0 lvm
│ └─vg_var-lv_var        253:8    0 1016M  0 lvm
└─vg_var-lv_var_rimage_0 253:5    0 1016M  0 lvm
  └─vg_var-lv_var        253:8    0 1016M  0 lvm
sde                        8:64   0    1G  0 disk
├─vg_var-lv_var_rmeta_1  253:6    0    4M  0 lvm
│ └─vg_var-lv_var        253:8    0 1016M  0 lvm
└─vg_var-lv_var_rimage_1 253:7    0 1016M  0 lvm
  └─vg_var-lv_var        253:8    0 1016M  0 lvm  
```

Создаем файловую систему ext4

```text
[root@lvm ~]# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
65024 inodes, 260096 blocks
13004 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=266338304
8 block groups
32768 blocks per group, 32768 fragments per group
8128 inodes per group
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

Монтируем новый том

Копируем содержимое /var на новый том

```text
[root@lvm ~]# mount /dev/vg_var/lv_var /mnt
[root@lvm ~]# cp -aR /var/* /mnt
[root@lvm ~]# umount /mnt
```

Переименовываем /var в /var1 и монтируем новый том как /var

```text
[root@lvm ~]# mv /var /var1
[root@lvm ~]# mkdir /var
[root@lvm ~]# mount /dev/vg_var/lv_var /var
[root@lvm ~]# ls /var
adm  cache  db  empty  games  gopher  kerberos  lib  local  lock  log  lost+found  mail  nis  opt  preserve  run  spool  tmp  yp
```

Добавляем новую точку монтирования в fstab

```text
[root@lvm boot]# echo "`blkid | grep var: | awk '{print $2}'` \
 /var ext4 defaults 0 0" >> /etc/fstab
```

Перезагружаемся

Удаляем /var1

[root@lvm ~]# rm -rf /var1

```text
[root@lvm /]# lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                        8:0    0   40G  0 disk
├─sda1                     8:1    0    1M  0 part
├─sda2                     8:2    0    1G  0 part /boot
└─sda3                     8:3    0   39G  0 part
  ├─VolGroup00-LogVol00  253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol02  253:6    0   10G  0 lvm  /home
sdb                        8:16   0   10G  0 disk
sdc                        8:32   0    2G  0 disk
sdd                        8:48   0    1G  0 disk
├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm
│ └─vg_var-lv_var        253:8    0 1016M  0 lvm  /var
└─vg_var-lv_var_rimage_0 253:4    0 1016M  0 lvm
  └─vg_var-lv_var        253:8    0 1016M  0 lvm  /var
sde                        8:64   0    1G  0 disk
├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm
│ └─vg_var-lv_var        253:8    0 1016M  0 lvm  /var
└─vg_var-lv_var_rimage_1 253:7    0 1016M  0 lvm
  └─vg_var-lv_var        253:8    0 1016M  0 lvm  /var
```

### Для /home - сделать том для снэпшотов. Работа со снэпшотами

- сгенерировать файлы в /home/
- снять снэпшот
- удалить часть файлов
- восстановиться со снэпшота

Создадим в /home файлы для демонстрации

```text
[root@lvm /]# touch /home/foo{1..25}.txt
[root@lvm /]# ls /home
foo10.txt  foo12.txt  foo14.txt  foo16.txt  foo18.txt  foo1.txt   foo21.txt  foo23.txt  foo25.txt  foo3.txt  foo5.txt  foo7.txt  foo9.txt
foo11.txt  foo13.txt  foo15.txt  foo17.txt  foo19.txt  foo20.txt  foo22.txt  foo24.txt  foo2.txt   foo4.txt  foo6.txt  foo8.txt  vagrant
```

Создадим снэпшот

```text
[root@lvm ~]# lvcreate -l 100%FREE -s -n lv_home_snap /dev/VolGroup00/LogVol02
  Reducing COW size <19.47 GiB down to maximum usable size 10.06 GiB.
  Logical volume "lv_home_snap" created.
```

Удалим часть файлов в /home

```text
[root@lvm ~]# rm -f /home/foo{11..20}.txt
[root@lvm ~]# ls /home
foo1.txt  foo10.txt  foo2.txt  foo21.txt  foo22.txt  foo23.txt  foo24.txt  foo25.txt  foo3.txt  foo4.txt  foo5.txt  foo6.txt  foo7.txt  foo8.txt  foo9.txt  vagrant
```

Восстановим из снэпшота удаленные файлы

```text
[root@lvm ~]# umount /home
[root@lvm ~]# lvconvert --merge /dev/VolGroup00/lv_home_snap
  Merging of volume VolGroup00/lv_home_snap started.
  VolGroup00/LogVol02: Merged: 100.00%
[root@lvm ~]# mount /dev/VolGroup00/LogVol02 /home
[root@lvm ~]# ls /home
foo1.txt   foo11.txt  foo13.txt  foo15.txt  foo17.txt  foo19.txt  foo20.txt  foo22.txt  foo24.txt  foo3.txt  foo5.txt  foo7.txt  foo9.txt
foo10.txt  foo12.txt  foo14.txt  foo16.txt  foo18.txt  foo2.txt   foo21.txt  foo23.txt  foo25.txt  foo4.txt  foo6.txt  foo8.txt  vagrant
```
Задание выполнено




