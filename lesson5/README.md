# Administrator Linux. Professional

## Урок 5. Домашнее задание

Работа с mdadm

### Описание домашнего задания

Подготовить стенд на Vagrant как минимум с одним сервером.

- добавить в Vagrantfile еще дисков
- собрать R0/R5/R10 на выбор
- прописать собранный рейд в конф, чтобы рейд собирался при загрузке
- сломать/починить raid
- создать GPT раздел и 5 партиций и смонтировать их на диск.

### Выполнение

Создаем Vagrantfile

   `$ vagrant init`

загружаем предложенный в методическом пособии Vagrantfile
и редактируем его под наши задачи

```ruby
 -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :otuslinux => {
        :box_name => "centos/7",
        :ip_addr => '192.168.11.101',
        :disks => {
                :sata1 => {
                        :dfile => './sata1.vdi',
                        :size => 250,
                        :port => 1
                        },
                :sata2 => {
                        :dfile => './sata2.vdi',
                        :size => 250, # Megabytes
                        :port => 2
                        },
                :sata3 => {
                        :dfile => './sata3.vdi',
                        :size => 250,
                        :port => 3
                },
                :sata4 => {
                        :dfile => './sata4.vdi',
                        :size => 250, # Megabytes
                        :port => 4
                        },
                :sata5=> {
                        :dfile => './sata5.vdi',
                        :size => 250,
                        :port => 5
                },
                :sata6 => {
                        :dfile => './sata6.vdi',
                        :size => 250, # Megabytes
                        :port => 6

                }
                }
  },
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

      config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s

          #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

          box.vm.network "public_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
               vb.customize ["modifyvm", :id, "--memory", "1024"]
                  needsController = false
                    boxconfig[:disks].each do |dname, dconf|
                      unless File.exist?(dconf[:dfile])
                      vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                                needsController =  true
                          end
                  end
                  if needsController == true
                     vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                     boxconfig[:disks].each do |dname, dconf|
                         vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                     end
                  end
          end

          ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip
          box.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
          box.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
          box.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false
          box.vm.provision 'shell', inline: "sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "yum update -y"
          box.vm.provision 'shell', inline: "yum upgrade -y"

      end
  end
end
```

Что изменили в файле:

- Добавили еще 2 диска, согласно заданию

```ruby
                :sata5 => {
                        :dfile => './sata5.vdi',
                        :size => 250,
                        :port => 5
                },
                :sata6 => {
                        :dfile => './sata6.vdi',
                        :size => 250, # Megabytes
                        :port => 6
                }
```

- Изменили ссылки на репозиторий на рабочие и обновили пакеты

```ruby
          box.vm.provision 'shell', inline: "sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo"
          box.vm.provision 'shell', inline: "yum update -y"
          box.vm.provision 'shell', inline: "yum upgrade -y"
```

Запускаем ВМ

`$ vagrant up`

После запуска проверяем доступ по ssh

`$ ssh vagrant@127.0.0.1 -p 2222`

```text
vagrant@otuslinux:~$ 
```

Доступ есть

### Переходим к выполнению работы

Смотрим диски

`[root@otuslinux ~]# lsblk`

```ini
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
`-sda1   8:1    0   40G  0 part /
sdb      8:16   0  250M  0 disk 
sdc      8:32   0  250M  0 disk 
sdd      8:48   0  250M  0 disk 
sde      8:64   0  250M  0 disk 
sdf      8:80   0  250M  0 disk 
sdg      8:96   0  250M  0 disk 

```

***/dev/sda***  - системный диск с root

***/dev/sdb .../dev/sdg*** - пустые диски c которыми будем работать

Для выполнения задания создадим плейбук ansible.

### Создадим роль

```yaml
- name: Raid mdadm lesson 5
  hosts: otuslinux
  gather_facts: true
  become: yes
  roles:
    - prepare_server
    - array_create
    - fs_create
    - mdraid_replace_disk
```

#### Создадим структуру каталогов роли

```text
└── roles
    ├── array_create
    │   ├── defaults
    │   ├── tasks
    │   └── vars
    ├── fs_create
    │   ├── tasks
    │   └── vars
    ├── mdraid_replace_disk
    │   ├── tasks
    │   └── vars
    └── prepare_server
        └── tasks
```

#### Создадим конфигурацию роли и файл хостов

```ansible.cfg```

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

```hosts.ini```

```ini
[all]
otuslinux ansible_port=2222 ansible_host=127.0.0.1 ansible_username=vagrant
```

### Подготовка сервера

#### Роль prepare_server

Создаем ```prepare_server/tasks/main.yaml```

```yaml
- name: install mdadm and tools
  package:
    name: mdadm, smartmontools, hdparm, gdisk
    state: present
```

Задачи в роли:

- install mdadm and tools - устанавливаем mdadm и утилиты

### Собираем рейд на выбор (raid6) и прописываем в конфигурацию

#### Роль array_create

Создаем ```array_create/defaults/main.yaml```

```yaml
mdadm_conf_path: '/etc/mdadm.conf'
```

Создаем ```array_create/vars/main.yaml```

```yaml
array_device: /dev/md0
array_disks: 
  - /dev/sdb
  - /dev/sdc
  - /dev/sdd
  - /dev/sde
  - /dev/sdf
array_level: 6 
array_filesystem: ext4
array_mountpoint: /mnt/raid
```

Создаем ```array_create/tasks/main.yaml```

```yaml
- name: Prepare disks
  shell: "mdadm --zero-superblock --force {{ array_disks | join(' ') }}"
- name: Create Raid
  shell: "yes | mdadm --create {{ array_device }} --level={{ array_level }} --raid-devices={{ array_disks | count }} {{ array_disks | join(' ') }}"
- name: Create config
  shell: "echo DEVICE partitions > {{mdadm_conf_path}} && mdadm --verbose --detail --scan | awk '/ARRAY/ {print}' >> {{mdadm_conf_path}}"
```

Задачи в роли:

- Prepare disks - зануляем суперблоки
- Create raid - собираем рейд 6 уровня из 5 дисков
- Create config - создаем и записываем файл /etc/mdadm.conf

### Создаем раздел gpt, 5 разделов и файловую систему

#### Роль fs_create

Создаем файл ```fs_create/vars/main.yaml```

```yaml
partitions:
  - number: 1
    start: "0"
    end: "20"
  - number: 2
    start: "20"
    end: "40"
  - number: 3
    start: "40"
    end: "60"
  - number: 4
    start: "60"
    end: "80"
  - number: 5
    start: "80"
    end: "100"
```

А вот с задачами у меня возникла проблема.
Первоначально планировалось использовать модуль ```community.general.parted```
и такой вид задач:

```yaml
- name: GPT Create
  parted: 
    device: /dev/md0
    label: gpt
    name: GPT
    number: 1
    state: present

- name: Partition create
  parted:
    device: /dev/md0
    number: "{{ item.number }}"
    part_start: "{{ item.start }}%"
    part_end: "{{ item.end }}%"
    part_type: primary
    fs_type: ext4
    state: present
  loop: "{{ partitions }}"
```

Но при выполнении задачи **Partition create** из-за ошибки в модуле ```community.general.parted``` тип раздела **gpt** менялся на **msdos** и соответственно 5 раздел не создавался.

Поэтому задачи были выполнены через shell

Файл ```fs_create/tasks/main.yaml

```yaml
- name: GPT Create
  shell: " parted -s /dev/md0 mklabel gpt"
- name: Create partitions
  shell: "parted -s /dev/md0 mkpart primary ext4 {{ item.start }}% {{ item.end }}%"
  loop: "{{ partitions }}"
- name: Make FS
  filesystem:
    fstype: ext4
    device: "/dev/md0p{{ item.number }}"
    state: present
  loop: "{{ partitions }}"
- name: Create mountpoints
  file: 
    path: "/mnt/part{{ item.number }}"
    state: directory
  loop: "{{ partitions }}"
- name: Mount 
  mount:
   src: "/dev/md0p{{ item.number }}"
   path: "/mnt/part{{ item.number }}"
   fstype: ext4
   state: present
  loop: "{{ partitions }}"
```

Задачи в роли:

- GPT Create - создание раздела gpt
- Create partitions - создание 5 разделов размером по 20% в цикле
- Make FS -  создание файловых систем на разделах
- Create mountpoints - создание точек монтирования
- Mount - монтирование разделов

### Сломаем/починим рейд

#### Pоль mdraid_replace_disk

Создаем файл ```mdraid_replace_disk/tasks/main.yaml```

```yaml
- name: Set disk as faulty
  shell: "mdadm -f {{ array_name }} {{ fail_disk }}"
  tags: service
- name: Remove faulty disk\
  shell: "mdadm -r {{ array_name }} {{ fail_disk }}"
  tags: service
- name: Add new disk
  shell: "mdadm -a {{ array_name }} {{ good_disk }}"
  tags: service
```

## Переходим к исполнению плейбука

Сначала создадим рейд массив, разделы и файловые системы

```$ ansible-playbook site.yaml --skip-tags service```

```ini
anasha@otus:~/less5$ ansible-playbook site.yaml --skip-tags service

PLAY [Raid install] ************************************************************************************

TASK [Gathering Facts] ************************************************************************************
ok: [otuslinux]

TASK [prepare_server : install mdadm and tools] ************************************************************************************
changed: [otuslinux]

TASK [array_create : Prepare disks] ************************************************************************************
changed: [otuslinux]

TASK [array_create : Create Raid] ************************************************************************************
changed: [otuslinux]

TASK [array_create : Create config] ************************************************************************************
changed: [otuslinux]

TASK [fs_create : GPT Create] ************************************************************************************
changed: [otuslinux]

TASK [fs_create : Create partitions] ************************************************************************************
changed: [otuslinux] => (item={'number': 1, 'start': '0', 'end': '20'})
changed: [otuslinux] => (item={'number': 2, 'start': '20', 'end': '40'})
changed: [otuslinux] => (item={'number': 3, 'start': '40', 'end': '60'})
changed: [otuslinux] => (item={'number': 4, 'start': '60', 'end': '80'})
changed: [otuslinux] => (item={'number': 5, 'start': '80', 'end': '100'})

TASK [fs_create : Make FS] ************************************************************************************
changed: [otuslinux] => (item={'number': 1, 'start': '0', 'end': '20'})
changed: [otuslinux] => (item={'number': 2, 'start': '20', 'end': '40'})
changed: [otuslinux] => (item={'number': 3, 'start': '40', 'end': '60'})
changed: [otuslinux] => (item={'number': 4, 'start': '60', 'end': '80'})
changed: [otuslinux] => (item={'number': 5, 'start': '80', 'end': '100'})

TASK [fs_create : Create mountpoints] ************************************************************************************
changed: [otuslinux] => (item={'number': 1, 'start': '0', 'end': '20'})
changed: [otuslinux] => (item={'number': 2, 'start': '20', 'end': '40'})
changed: [otuslinux] => (item={'number': 3, 'start': '40', 'end': '60'})
changed: [otuslinux] => (item={'number': 4, 'start': '60', 'end': '80'})
changed: [otuslinux] => (item={'number': 5, 'start': '80', 'end': '100'})

TASK [fs_create : Mount] ************************************************************************************
changed: [otuslinux] => (item={'number': 1, 'start': '0', 'end': '20'})
changed: [otuslinux] => (item={'number': 2, 'start': '20', 'end': '40'})
changed: [otuslinux] => (item={'number': 3, 'start': '40', 'end': '60'})
changed: [otuslinux] => (item={'number': 4, 'start': '60', 'end': '80'})
changed: [otuslinux] => (item={'number': 5, 'start': '80', 'end': '100'})

PLAY RECAP ************************************************************************************
otuslinux                  : ok=10   changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

заходим на ВМ и проверяем результат

Выполним ```lsblk```, ```cat/proc/mdstat``` и ```df -hT```

```text
[vagrant@otuslinux ~]$ lsblk
NAME      MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
sda         8:0    0    40G  0 disk  
└─sda1      8:1    0    40G  0 part  /
NAME      MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
sda         8:0    0    40G  0 disk  
└─sda1      8:1    0    40G  0 part  /
sdb         8:16   0   250M  0 disk  
└─md0       9:0    0   744M  0 raid6 
  ├─md0p1 259:0    0   147M  0 md    /mnt/part1
  ├─md0p2 259:1    0 148,5M  0 md    /mnt/part2
  ├─md0p3 259:2    0   150M  0 md    /mnt/part3
  ├─md0p4 259:3    0 148,5M  0 md    /mnt/part4
  └─md0p5 259:4    0   147M  0 md    /mnt/part5
sdc         8:32   0   250M  0 disk  
└─md0       9:0    0   744M  0 raid6 
  ├─md0p1 259:0    0   147M  0 md    /mnt/part1
  ├─md0p2 259:1    0 148,5M  0 md    /mnt/part2
  ├─md0p3 259:2    0   150M  0 md    /mnt/part3
  ├─md0p4 259:3    0 148,5M  0 md    /mnt/part4
  └─md0p5 259:4    0   147M  0 md    /mnt/part5 
sdd         8:48   0   250M  0 disk  
└─md0       9:0    0   744M  0 raid6 
  ├─md0p1 259:0    0   147M  0 md    /mnt/part1
  ├─md0p2 259:1    0 148,5M  0 md    /mnt/part2
  ├─md0p3 259:2    0   150M  0 md    /mnt/part3
  ├─md0p4 259:3    0 148,5M  0 md    /mnt/part4
  └─md0p5 259:4    0   147M  0 md    /mnt/part5    
sde         8:64   0   250M  0 disk  
└─md0       9:0    0   744M  0 raid6 
  ├─md0p1 259:0    0   147M  0 md    /mnt/part1
  ├─md0p2 259:1    0 148,5M  0 md    /mnt/part2
  ├─md0p3 259:2    0   150M  0 md    /mnt/part3
  ├─md0p4 259:3    0 148,5M  0 md    /mnt/part4
  └─md0p5 259:4    0   147M  0 md    /mnt/part5  
sdf         8:80   0   250M  0 disk  
└─md0       9:0    0   744M  0 raid6 
  ├─md0p1 259:0    0   147M  0 md    /mnt/part1
  ├─md0p2 259:1    0 148,5M  0 md    /mnt/part2
  ├─md0p3 259:2    0   150M  0 md    /mnt/part3
  ├─md0p4 259:3    0 148,5M  0 md    /mnt/part4
  └─md0p5 259:4    0   147M  0 md    /mnt/part5   
sdg         8:96   0   250M  0 disk  
[vagrant@otuslinux ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
[vagrant@otuslinux ~]$ df -hT
Файловая система Тип      Размер Использовано  Дост Использовано% Cмонтировано в
devtmpfs         devtmpfs   489M            0  489M            0% /dev
tmpfs            tmpfs      496M            0  496M            0% /dev/shm
tmpfs            tmpfs      496M         6,8M  489M            2% /run
tmpfs            tmpfs      496M            0  496M            0% /sys/fs/cgroup
/dev/sda1        xfs         40G         5,5G   35G           14% /
tmpfs            tmpfs      100M            0  100M            0% /run/user/1000
/dev/md0p1       ext4       139M         1,6M  127M            2% /mnt/part1
/dev/md0p2       ext4       140M         1,6M  128M            2% /mnt/part2
/dev/md0p3       ext4       142M         1,6M  130M            2% /mnt/part3
/dev/md0p4       ext4       140M         1,6M  128M            2% /mnt/part4
/dev/md0p5       ext4       139M         1,6M  127M            2% /mnt/part5
tmpfs            tmpfs      100M            0  100M            0% /run/user/0

```
Видим созданный рейд-массив, разделы, файловые системы

#### Теперь выполним замену диска sdd на sdg

```$ ansible-playbook site.yaml -t service```

```ini
PLAY [Raid install] ************************************************************************************

TASK [Gathering Facts] ************************************************************************************
ok: [otuslinux]

TASK [mdraid_replace_disk : Set disk as faulty] ************************************************************************************
changed: [otuslinux]

TASK [mdraid_replace_disk : Remove faulty disk] ************************************************************************************
changed: [otuslinux]

TASK [mdraid_replace_disk : Add new disk] ************************************************************************************
changed: [otuslinux]

PLAY RECAP ************************************************************************************
otuslinux                  : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

Заходи на ВМ и проверяем результат

```text
[vagrant@otuslinux ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sdg[5] sdf[4] sde[3] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
```

Видим, что вместо диска **sdd** в рейд включен диск **sdg**

Все задачи выполнены

На github выложен [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson5/Vagrantfile),
[плейбук Ansible](https://github.com/anashoff/otus/blob/master/lesson5/mdadm_playbook), использованные в этом задании.
