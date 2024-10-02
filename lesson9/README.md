# Administrator Linux. Professional

## Урок 9. Домашнее задание

Vagrant стенд для NFS

### Описание домашнего задания

- vagrant up должен поднимать 2 настроенных виртуальных машины (сервер NFS и клиента) без дополнительных ручных действий;
- на сервере NFS должна быть подготовлена и экспортирована директория; 
- в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё; 
- экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
- монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.

### Выполнение

#### Установка и настройка среды выполнения

Подготовим Vagrantfile

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 1
  end

  ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip
  config.vm.define "nfss" do |nfss|
    nfss.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    nfss.vm.hostname = "nfss"
    nfss.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
    nfss.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
    nfss.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false

    #nfss.vm.provision "shell", path: "nfss_script.sh"
  end

  config.vm.define "nfsc" do |nfsc|
    nfsc.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "net1"
    nfsc.vm.hostname = "nfsc"
    nfsc.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
    nfsc.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
    nfsc.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false

    #nfsc.vm.provision "shell", path: "nfsc_script.sh"
  end
end
```

Запускаем на выполнение

```anasha@otus:~/less9$ vagrant up```

Смотрим какие порты получил ssh

```text
...
nfss: SSH address: 127.0.0.1:2222
...
nfsc: SSH address: 127.0.0.1:2200
...
```

Настройку установленных сервера и клиента сделаем плейбуком Ansible

```ansible.cfg```

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
```

```hosts.ini```  
В него прописываем полученные порты ssh

```ini
[all]
nfss ansible_port=2222 ansible_host=127.0.0.1 ansible_username=vagrant
nfsc ansible_port=2200 ansible_host=127.0.0.1 ansible_username=vagrant
```

```exports.j2```

```jinja
# /etc/exports: the access control list for filesystems which may be exported
#   to NFS clients.  See exports(5).
/srv/share   192.168.50.11/32(rw,sync,root_squash)
```

И сам плейбук
```playbook.yaml```

```yaml
- hosts: nfss
  gather_facts: true
  become: yes
  tasks:
    - name: install nfs server
      package:
        name: nfs-common, nfs-kernel-server
        state: present
    - name: Create a mountable directory 
      file:
        path: /srv/share/upload
        state: directory
        owner: nobody
        group: nogroup
        mode: '0777'
    - name: Copy exports file.
      template:
         src: exports.j2
         dest: /etc/exports
         owner: root
         group: root
         mode: 0644
    - name: reload_exportfs
      shell: "systemctl reload nfs;exportfs -r"
- hosts: nfsc
  gather_facts: true
  become: yes
  tasks:
    - name: install nfs client
      package:
        name: nfs-common
        state: present
    - name: Modify_fstab
      lineinfile:
        line: '192.168.50.10:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0'
        path: /etc/fstab
    - name: 
      systemd_service:
        state: restarted
        daemon_reload: true
        name: remote-fs.target

```

Запускаем плейбук

```text
anasha@otus:~/less9$ ansible-playbook playbook.yaml

PLAY [nfss] ************************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************************************************************************************************************************************************
The authenticity of host '[127.0.0.1]:2222 ([127.0.0.1]:2222)' can't be established.
ED25519 key fingerprint is SHA256:gG0YmFuELaLTkYBEX+5pY+1lWgsLK/NC/eXOnq9/RQA.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
ok: [nfss]

TASK [install nfs server] **********************************************************************************************************************************************************************************************************************************
changed: [nfss]

TASK [Create a mountable directory] ************************************************************************************************************************************************************************************************************************
changed: [nfss]

TASK [Copy exports file.] **********************************************************************************************************************************************************************************************************************************
changed: [nfss]

TASK [reload_exportfs] *************************************************************************************************************************************************************************************************************************************
changed: [nfss]

PLAY [nfsc] ************************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************************************************************************************************************************************************
The authenticity of host '[127.0.0.1]:2200 ([127.0.0.1]:2200)' can't be established.
ED25519 key fingerprint is SHA256:LxUu/9wLbCWp1UfV2Zapsp6FwFgZ8MDjU8aF0fVBglg.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
ok: [nfsc]

TASK [install nfs client] **********************************************************************************************************************************************************************************************************************************
changed: [nfsc]

TASK [Modify_fstab] ****************************************************************************************************************************************************************************************************************************************
changed: [nfsc]

TASK [systemd_service] *************************************************************************************************************************************************************************************************************************************
changed: [nfsc]

PLAY RECAP *************************************************************************************************************************************************************************************************************************************************
nfsc                       : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
nfss                       : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### Проверка работы NFS

Заходим на сервер. 

```zsh
anasha@otus:~/less9$ ssh vagrant@127.0.0.1 -p 2222
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Oct  2 18:11:14 UTC 2024

  System load:  0.05              Processes:               115
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 23%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Wed Oct  2 18:09:14 2024 from 10.0.2.2
vagrant@nfss:~$
```

Заходим в каталог /srv/share/upload.

```zsh
vagrant@nfss:~$ cd /srv/share/upload
```

Создаём тестовый файл touch check_file.

```zsh
vagrant@nfss:/srv/share/upload$ touch check_file
```

Заходим на клиент.

```zsh
anasha@otus:~/less9$ ssh vagrant@127.0.0.1 -p 2200
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Oct  2 18:12:10 UTC 2024

  System load:  0.2               Processes:               100
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 23%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Wed Oct  2 18:09:22 2024 from 10.0.2.2
vagrant@nfsc:~$
```

Заходим в каталог /mnt/upload. 
Проверяем наличие ранее созданного файла.

```zsh
vagrant@nfsc:~$ cd /mnt/upload
vagrant@nfsc:/mnt/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:11 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
```

Создаём тестовый файл touch client_file. 

```zsh
vagrant@nfsc:/mnt/upload$ touch client_file
```

Проверяем, что файл успешно создан на сервере.

```zsh
vagrant@nfss:/srv/share/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:12 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:14 client_file
```

Все вышеуказанные проверки прошли успешно, это значит, что проблем с правами нет.


Предварительно проверяем клиент:

- перезагружаем клиент;
- заходим на клиент;
- заходим в каталог /mnt/upload;
- проверяем наличие ранее созданных файлов.

```zsh
vagrant@nfsc:/mnt/upload$ sudo reboot
vagrant@nfsc:/mnt/upload$ Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
anasha@otus:~/less9$ ssh vagrant@127.0.0.1 -p 2200
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Oct  2 18:14:05 UTC 2024

  System load:  0.57              Processes:               102
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 18%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Wed Oct  2 18:12:10 2024 from 10.0.2.2
vagrant@nfsc:~$ cd /mnt/upload
vagrant@nfsc:/mnt/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:12 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:14 client_file

```

Проверяем сервер:

- заходим на сервер в отдельном окне терминала;
- перезагружаем сервер;
- заходим на сервер;
- проверяем наличие файлов в каталоге /srv/share/upload/;

```zsh
vagrant@nfss:/srv/share/upload$ sudo reboot
vagrant@nfss:/srv/share/upload$ Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
anasha@otus:~/less9$ ssh vagrant@127.0.0.1 -p 2222
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Oct  2 18:15:38 UTC 2024

  System load:  0.85              Processes:               113
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 19%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Wed Oct  2 18:11:15 2024 from 10.0.2.2
vagrant@nfss:~$ cd /srv/share/upload
vagrant@nfss:/srv/share/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:12 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:14 client_file
```

- проверяем экспорты exportfs -s;

```zsh
vagrant@nfss:/srv/share/upload$ sudo exportfs -s
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

- проверяем работу RPC showmount -a 192.168.50.10.

```zsh
vagrant@nfss:/srv/share/upload$ showmount -a 192.168.50.10
All mount points on 192.168.50.10:
192.168.50.11:/srv/share
```

Проверяем клиент: 

- возвращаемся на клиент;
- перезагружаем клиент;
- заходим на клиент;
- проверяем работу RPC showmount -a 192.168.50.10;

```zsh
vagrant@nfsc:/mnt/upload$ sudo reboot
vagrant@nfsc:/mnt/upload$ Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
anasha@otus:~/less9$ ssh vagrant@127.0.0.1 -p 2200
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Oct  2 18:17:42 UTC 2024

  System load:  0.75              Processes:               104
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 19%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Wed Oct  2 18:14:06 2024 from 10.0.2.2
vagrant@nfsc:~$ showmount -a 192.168.50.10
All mount points on 192.168.50.10:
192.168.50.11:/srv/share
```

- заходим в каталог /mnt/upload;
- проверяем статус монтирования mount | grep mnt;
- проверяем наличие ранее созданных файлов;

```zsh
vagrant@nfsc:~$ cd /mnt/upload
vagrant@nfsc:/mnt/upload$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=60,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=15706)
192.168.50.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=59629,mountproto=udp,local_lock=none,addr=192.168.50.10)
nsfs on /run/snapd/ns/lxd.mnt type nsfs (rw)
vagrant@nfsc:/mnt/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:12 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:14 client_file
```

- создаём тестовый файл touch final_check;

```zsh
vagrant@nfsc:/mnt/upload$ touch final_check
```

- проверяем, что файл успешно создан.

```zsh
vagrant@nfss:/srv/share/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 Oct  2 18:18 ./
drwxrwxrwx 3 nobody  nogroup 4096 Oct  2 18:09 ../
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:11 check_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:14 client_file
-rw-rw-r-- 1 vagrant vagrant    0 Oct  2 18:18 final_check
vagrant@nfss:/srv/share/upload$
```

Все вышеуказанные проверки прошли успешно, это значит, что демонстрационный стенд работоспособен и готов к работе.

Задание выполнено

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson9)
