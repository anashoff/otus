# Administrator Linux. Professional

## Урок 8. Домашнее задание

Практические навыки работы с ZFS

### Описание домашнего задания

Подготовить стенд на Vagrant с предложенным образом (centos/7 1804.2)

Что нужно сделать?

1. Определить алгоритм с наилучшим сжатием:
   - определить какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
   - создать 4 файловых системы на каждой применить свой алгоритм сжатия;
   - для сжатия использовать либо текстовый файл, либо группу файлов.
2. Определить настройки пула.С помощью команды zfs import собрать pool ZFS.Командами zfs определить настройки:
   - размер хранилища;
   - тип pool;
   - значение recordsize;
   - какое сжатие используется;
   - какая контрольная сумма используется.
3. Работа со снапшотами:
   - скопировать файл из удаленной директории;
   - восстановить файл локально. zfs receive;
   - найти зашифрованное сообщение в файле secret_message.

### Выполнение

Загружаем предложенный в методическом пособии Vagrantfile
Запускаем ВМ и проверяем доступ по ssh

```[vagrant@zfs ~]$```

Доступ есть. Почти все команды требуют прав суперпользователя, поэтому сразу переходим в root:

```sudo -i```

Смотрим структуру дисков

```text
[root@zfs ~]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk
`-sda1   8:1    0   40G  0 part /
sdb      8:16   0  512M  0 disk
sdc      8:32   0  512M  0 disk
sdd      8:48   0  512M  0 disk
sde      8:64   0  512M  0 disk
sdf      8:80   0  512M  0 disk
sdg      8:96   0  512M  0 disk
sdh      8:112  0  512M  0 disk
sdi      8:128  0  512M  0 disk                     8:64   0    1G  0 disk
```

### Определить алгоритм с наилучшим сжатием

Создаем пулы

```text
[root@zfs ~]# zpool create mars1 mirror /dev/sdb /dev/sdc
The ZFS modules are not loaded.
Try running '/sbin/modprobe zfs' as root to load them.
```

Упс. что-то пошло не так. Исправляем

```text
[root@zfs ~]# /sbin/modprobe zfs
```

Содаем пулы

```text
[root@zfs ~]# zpool create mars1 mirror /dev/sdb /dev/sdc
[root@zfs ~]# zpool create bounty1 mirror /dev/sdd /dev/sde
[root@zfs ~]# zpool create picnic1 mirror /dev/sdf /dev/sdg
[root@zfs ~]# zpool create snickers1 mirror /dev/sdh /dev/sdi
```

И проверяем

```text
[root@zfs ~]# zpool list
NAME        SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
bounty1     480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
mars1       480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
picnic1     480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
snickers1   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
[root@zfs ~]# zpool status
  pool: bounty1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        bounty1     ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdd     ONLINE       0     0     0
            sde     ONLINE       0     0     0

errors: No known data errors

  pool: mars1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        mars1       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdb     ONLINE       0     0     0
            sdc     ONLINE       0     0     0

errors: No known data errors

  pool: picnic1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        picnic1     ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdf     ONLINE       0     0     0
            sdg     ONLINE       0     0     0

errors: No known data errors

  pool: snickers1
state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        snickers1   ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdh     ONLINE       0     0     0
            sdi     ONLINE       0     0     0

errors: No known data errors
```

Всё получилось
Зададим параметры сжатия для каждого пула

```text
[root@zfs ~]# zfs set compression=lzjb bounty1
[root@zfs ~]# zfs set compression=lz4 mars1
[root@zfs ~]# zfs set compression=gzip-9 picnic1
[root@zfs ~]# zfs set compression=zle snickers1
```

Проверяем

```text
[root@zfs ~]# zfs get all | grep compression
bounty1    compression           lzjb                   local
mars1      compression           lz4                    local
picnic1    compression           gzip-9                 local
snickers1  compression           zle                    local
```

Проверим степени компрессии. Скачиваем большой текст

```text
[root@zfs ~]# wget -P /bounty1 https://gutenberg.org/cache/epub/2600/pg2600.converter.log
[root@zfs ~]# 
```

Опять что-то пошло не так.

Переустановим wget

```text
[root@zfs ~]# yum remove wget
.....
Удалено:
  wget.x86_64 0:1.14-18.el7_6.1
  
Выполнено!
[root@zfs ~]# yum install wget
......
Установлено:
  wget.x86_64 0:1.14-18.el7_6.1

Выполнено!
```

Скачиваем большой текст

```text
[root@zfs ~]# wget -P /bounty1/ https://gutenberg.org/cache/epub/2600/pg2600.converter.log
--2024-10-01 17:10:45--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Распознаётся gutenberg.org (gutenberg.org)... 152.19.134.47
Подключение к gutenberg.org (gutenberg.org)|152.19.134.47|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа... 200 OK
Длина: 41080117 (39M) [text/plain]
Сохранение в: «/bounty1/pg2600.converter.log.1»

100%[==================================================================================================================================================================================================================>] 41 080 117   729KB/s   за 40s

2024-10-01 17:11:26 (996 KB/s) - «/bounty1/pg2600.converter.log.1» сохранён [41080117/41080117]
```

Получилось. Повторяем для остальных пулов и смотрим результат

```text
[root@zfs ~]# zfs list
NAME        USED  AVAIL     REFER  MOUNTPOINT
bounty1    21,7M   330M     21,6M  /bounty1
mars1      17,7M   334M     17,6M  /mars1
picnic1    10,8M   341M     10,7M  /picnic1
snickers1  39,3M   313M     39,2M  /snickers1
[root@zfs ~]# zfs get all | grep compressratio | grep -v ref
bounty1    compressratio         1.82x                      -
mars1      compressratio         2.23x                      -
picnic1    compressratio         3.66x                      -
snickers1  compressratio         1.00x                      -
```

Победил **gzip-9**

### Определить настройки пула

Скачиваем архив и распаковываем его

```text
root@zfs ~]# wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
--2024-10-01 16:24:34--  https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download
Распознаётся drive.usercontent.google.com (drive.usercontent.google.com)... 64.233.163.132
Подключение к drive.usercontent.google.com (drive.usercontent.google.com)|64.233.163.132|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа... 200 OK
Длина: 7275140 (6,9M) [application/octet-stream]
Сохранение в: «archive.tar.gz»

65% [==========================================================================================================================================>                                                                        ] 4 800 428   7,60MB/s             
100%[==================================================================================================================================================================================================================>] 7 275 140   8,20MB/s   за 0,8s   

2024-10-01 16:24:44 (8,20 MB/s) - «archive.tar.gz» сохранён [7275140/7275140]

[root@zfs ~]# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

Проверим, можно ли импортировать каталог в пул

```text
[root@zfs ~]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 action: The pool can be imported using its name or numeric identifier.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
```

Можно. Импортируем

```text
[root@zfs ~]# zpool import -d zpoolexport/ otus
[root@zfs ~]# zpool status
  pool: bounty1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        bounty1     ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdd     ONLINE       0     0     0
            sde     ONLINE       0     0     0

errors: No known data errors

  pool: mars1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        mars1       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdb     ONLINE       0     0     0
            sdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus
 state: ONLINE
  scan: none requested
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: picnic1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        picnic1     ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdf     ONLINE       0     0     0
            sdg     ONLINE       0     0     0
errors: No known data errors

  pool: snickers1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        snickers1   ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdh     ONLINE       0     0     0
            sdi     ONLINE       0     0     0

errors: No known data errors
```

Получилось

Теперь определим настройки

```text
[root@zfs ~]# zpool get all otus
NAME  PROPERTY                       VALUE                          SOURCE
otus  size                           480M                           -
otus  capacity                       0%                             -
otus  altroot                        -                              default
otus  health                         ONLINE                         -
otus  guid                           6554193320433390805            -
otus  version                        -                              default
otus  bootfs                         -                              default
otus  delegation                     on                             default
otus  autoreplace                    off                            default
otus  cachefile                      -                              default
otus  failmode                       wait                           default
otus  listsnapshots                  off                            default
otus  autoexpand                     off                            default
otus  dedupditto                     0                              default
otus  dedupratio                     1.00x                          -
otus  free                           478M                           -
otus  allocated                      2,09M                          -
otus  readonly                       off                            -
otus  ashift                         0                              default
otus  comment                        -                              default
otus  expandsize                     -                              -
otus  freeing                        0                              -
otus  fragmentation                  0%                             -
otus  leaked                         0                              -
otus  multihost                      off                            default
otus  checkpoint                     -                              -
otus  load_guid                      5662447842317203966            -
otus  autotrim                       off                            default
otus  feature@async_destroy          enabled                        local
otus  feature@empty_bpobj            active                         local
otus  feature@lz4_compress           active                         local
otus  feature@multi_vdev_crash_dump  enabled                        local
otus  feature@spacemap_histogram     active                         local
otus  feature@enabled_txg            active                         local
otus  feature@hole_birth             active                         local
otus  feature@extensible_dataset     active                         local
otus  feature@embedded_data          active                         local
otus  feature@bookmarks              enabled                        local
otus  feature@filesystem_limits      enabled                        local
otus  feature@large_blocks           enabled                        local
otus  feature@large_dnode            enabled                        local
otus  feature@sha512                 enabled                        local
otus  feature@skein                  enabled                        local
otus  feature@edonr                  enabled                        local
otus  feature@userobj_accounting     active                         local
otus  feature@encryption             enabled                        local
otus  feature@project_quota          active                         local
otus  feature@device_removal         enabled                        local
otus  feature@obsolete_counts        enabled                        local
otus  feature@zpool_checkpoint       enabled                        local
otus  feature@spacemap_v2            active                         local
otus  feature@allocation_classes     enabled                        local
otus  feature@resilver_defer         enabled                        local
otus  feature@bookmark_v2            enabled                        local

```

Ой. Немного не то, но тоже интересно. Исправляем

```text
[root@zfs ~]# zfs get all otus
NAME  PROPERTY              VALUE                      SOURCE
otus  type                  filesystem                 -
otus  creation              Пт май 15  4:00 2020  -
otus  used                  2,04M                      -
otus  available             350M                       -
otus  referenced            24K                        -
otus  compressratio         1.00x                      -
otus  mounted               yes                        -
otus  quota                 none                       default
otus  reservation           none                       default
otus  recordsize            128K                       local
otus  mountpoint            /otus                      default
otus  sharenfs              off                        default
otus  checksum              sha256                     local
otus  compression           zle                        local
otus  atime                 on                         default
otus  devices               on                         default
otus  exec                  on                         default
otus  setuid                on                         default
otus  readonly              off                        default
otus  zoned                 off                        default
otus  snapdir               hidden                     default
otus  aclinherit            restricted                 default
otus  createtxg             1                          -
otus  canmount              on                         default
otus  xattr                 on                         default
otus  copies                1                          default
otus  version               5                          -
otus  utf8only              off                        -
otus  normalization         none                       -
otus  casesensitivity       sensitive                  -
otus  vscan                 off                        default
otus  nbmand                off                        default
otus  sharesmb              off                        default
otus  refquota              none                       default
otus  refreservation        none                       default
otus  guid                  14592242904030363272       -
otus  primarycache          all                        default
otus  secondarycache        all                        default
otus  usedbysnapshots       0B                         -
otus  usedbydataset         24K                        -
otus  usedbychildren        2,01M                      -
otus  usedbyrefreservation  0B                         -
otus  logbias               latency                    default
otus  objsetid              54                         -
otus  dedup                 off                        default
otus  mlslabel              none                       default
otus  sync                  standard                   default
otus  dnodesize             legacy                     default
otus  refcompressratio      1.00x                      -
otus  written               24K                        -
otus  logicalused           1020K                      -
otus  logicalreferenced     12K                        -
otus  volmode               default                    default
otus  filesystem_limit      none                       default
otus  snapshot_limit        none                       default
otus  filesystem_count      none                       default
otus  snapshot_count        none                       default
otus  snapdev               hidden                     default
otus  acltype               off                        default
otus  context               none                       default
otus  fscontext             none                       default
otus  defcontext            none                       default
otus  rootcontext           none                       default
otus  relatime              off                        default
otus  redundant_metadata    all                        default
otus  overlay               off                        default
otus  encryption            off                        default
otus  keylocation           none                       default
otus  keyformat             none                       default
otus  pbkdf2iters           0                          default
otus  special_small_blocks  0                          default
```

Определим конкретные значения:

- размер хранилища;

```text
[root@zfs ~]# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
```

- тип pool

```text
[root@zfs ~]# zfs get type otus
NAME  PROPERTY  VALUE       SOURCE
otus  type      filesystem  -
```

- значение recordsize

```text
[root@zfs ~]# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
```

- какое сжатие используется

```text
[root@zfs ~]# zfs get compression otus
NAME  PROPERTY     VALUE     SOURCE
otus  compression  zle       local
```

- какая контрольная сумма используется

```text
[root@zfs ~]# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```

### Работа со снапшотами

Скачиваем файл

```text
[root@zfs ~]# wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
[1] 15461
[root@zfs ~]# --2024-10-01 16:30:50--  https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI
Распознаётся drive.usercontent.google.com (drive.usercontent.google.com)... 64.233.162.132
Подключение к drive.usercontent.google.com (drive.usercontent.google.com)|64.233.162.132|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа... 200 OK
Длина: 5432736 (5,2M) [application/octet-stream]
Сохранение в: «otus_task2.file»

100%[==================================================================================================================================================================================================================>] 5 432 736   8,70MB/s   за        
0,6s   

2024-10-01 16:30:58 (8,70 MB/s) - «otus_task2.file» сохранён [5432736/5432736]


[1]+  Done                    wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI
```

Восстановим файловую систему из снапшота

```text
[root@zfs ~]# zfs receive otus/test@today <otus_task2.file
```

Ищем файл **secret_nessage**

```text
[root@zfs ~]# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
```

Смотрим содержимое

```text
[root@zfs ~]# cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/

```

По ссылке открываетсчя курс "Инфраструктура высоконагруженных систем"
Задание выполнено

На github выложен [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson8/Vagrantfile), использованный в задании
