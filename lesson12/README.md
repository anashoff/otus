# Administrator Linux. Professional

## Урок 12. Домашнее задание

Systemd — создание unit-файла

### Описание домашнего задания

- Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default)
- Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта
- Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

### Выполнение

#### Установка и настройка среды выполнения

Подготовим [Vagrant](https://github.com/anashoff/otus/blob/master/lesson12/Vagrantfile)

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

  config.vm.define "serv" do |serv|
    serv.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    serv.vm.hostname = "serv"
    serv.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
    serv.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
    serv.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false

  end
end
```

Создаем ВМ

```anasha@otus:~/less12$ vagrant up```

Выполнение ДЗ будет проходить с помощью ролей Ansible. Создадим необходимые файлы

Структура ролей

```text
├── roles
│   ├── create_service
│   │   ├── tasks
│   │   │   └── main.yml
│   │   └── templates
│   │       ├── conf.j2
│   │       ├── log.j2
│   │       ├── script.j2
│   │       ├── service.j2
│   │       └── timer.j2
│   ├── create_unit
│   │   ├── tasks
│   │   │   └── main.yml
│   │   └── templates
│   │       ├── fcgi.j2
│   │       └── service.j2
│   └── modify_nginx
│       ├── tasks
│       │   └── main.yml
│       └── templates
│           ├── conf1.j2
│           ├── conf2.j2
│           └── service.j2
├── site.yaml
├── ansible.cfg
├── hosts.ini
```

Файлы

[ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson12/ansible.cfg)

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

[hosts.ini](https://github.com/anashoff/otus/blob/master/lesson12/hosts.ini)

```ini
[all]
serv ansible_port=2222 ansible_host=127.0.0.1 ansible_username=vagrant
```

[site.yaml](https://github.com/anashoff/otus/blob/master/lesson12/site.yaml)

```yaml
---
- name: Systemd lesson
  hosts: serv
  gather_facts: true
  become: yes
  roles:
    - create_service
    - create_unit
    - modify_nginx
...
```

[create_service/tasks/main.yml](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/tasks/main.yml)

```yaml
---
  - name: write config using jinja2
    ansible.builtin.template:
       src: templates/conf.j2
       dest: /etc/default/watchlog
  - name: create log file
    ansible.builtin.template:
       src: templates/log.j2
       dest: /var/log/watchlog.log 
  - name: write script using jinja2
    ansible.builtin.template:
       src: templates/script.j2
       dest: /opt/watchlog.sh
       mode: 0777
  - name: write service jinja2
    ansible.builtin.template:
       src: templates/service.j2
       dest: /etc/systemd/system/watchlog.service
  - name: write timer using jinja2
    ansible.builtin.template:
       src: templates/timer.j2
       dest: /etc/systemd/system/watchlog.timer
  - name: reload
    systemd: 
      daemon_reload: yes
  - name: start service
    systemd: 
      name: watchlog.timer
      state: started
```

[create_service/template/conf.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/templates/conf.j2)

```ini
---
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log

```

[create_service/template/log.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/templates/log.j2)

```jinja
Font directories:
        /usr/share/fonts
        /usr/local/share/fonts
        /usr/share/fonts/X11
        /usr/share/fonts/cMap
        /usr/share/fonts/cmap
        /usr/share/fonts/opentype
        /usr/share/fonts/truetype
        /usr/share/fonts/type1
        /usr/share/fonts/xscreensaver
        /usr/share/fonts/X11/100dpi
        /usr/share/fonts/X11/75dpi
        /usr/share/fonts/X11/Type1
        /usr/share/fonts/X11/encodings
        /usr/share/fonts/X11/misc
        /usr/share/fonts/X11/util
        /usr/share/fonts/cmap/adobe-cns1
        /usr/share/fonts/cmap/adobe-gb1
        /usr/share/fonts/cmap/adobe-japan1
        /usr/share/fonts/cmap/adobe-japan2
        /usr/share/fonts/cmap/adobe-korea1
        /usr/share/fonts/opentype/cantarell
        /usr/share/fonts/opentype/mathjax
        /usr/share/fonts/opentype/noto
        /usr/share/fonts/opentype/urw-base35
        /usr/share/fonts/truetype/ancient-scripts
        /usr/share/fonts/truetype/dejavu
        /usr/share/fonts/truetype/droid
        /usr/share/fonts/truetype/hack
        /usr/share/fonts/truetype/liberation
        /usr/share/fonts/truetype/liberation2
        /usr/share/fonts/truetype/libreoffice
        /usr/share/fonts/truetype/noto
        /usr/share/fonts/truetype/open-sans
        /usr/share/fonts/truetype/quicksand
        /usr/share/fonts/type1/urw-base35
        /usr/share/fonts/X11/encodings/large
/usr/share/fonts: skipping, existing cache is valid: 0 fonts, 7 dirs
ALERT
/usr/share/fonts/X11: skipping, existing cache is valid: 0 fonts, 6 dirs
/usr/share/fonts/X11/100dpi: skipping, existing cache is valid: 358 fonts, 0 dirs
/usr/share/fonts/X11/75dpi: skipping, existing cache is valid: 358 fonts, 0 dirs
/usr/share/fonts/X11/Type1: skipping, existing cache is valid: 80 fonts, 0 dirs
/usr/share/fonts/X11/encodings: skipping, existing cache is valid: 0 fonts, 1 dirs
/usr/share/fonts/X11/encodings/large: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/X11/misc: skipping, existing cache is valid: 89 fonts, 0 dirs
/usr/share/fonts/X11/util: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cMap: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cmap: skipping, existing cache is valid: 0 fonts, 5 dirs
/usr/share/fonts/cmap/adobe-cns1: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cmap/adobe-gb1: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cmap/adobe-japan1: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cmap/adobe-japan2: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/cmap/adobe-korea1: skipping, existing cache is valid: 0 fonts, 0 dirs
/usr/share/fonts/opentype: skipping, existing cache is valid: 0 fonts, 4 dirs
/usr/share/fonts/opentype/cantarell: skipping, existing cache is valid: 5 fonts, 0 dirs
/usr/share/fonts/opentype/mathjax: skipping, existing cache is valid: 24 fonts, 0 dirs
/usr/share/fonts/opentype/noto: skipping, existing cache is valid: 80 fonts, 0 dirs
/usr/share/fonts/opentype/urw-base35: skipping, existing cache is valid: 35 fonts, 0 dirs
/usr/share/fonts/truetype: skipping, existing cache is valid: 0 fonts, 10 dirs
/usr/share/fonts/truetype/ancient-scripts: skipping, existing cache is valid: 1 fonts, 0 dirs
/usr/share/fonts/truetype/dejavu: skipping, existing cache is valid: 22 fonts, 0 dirs
/usr/share/fonts/truetype/droid: skipping, existing cache is valid: 1 fonts, 0 dirs
/usr/share/fonts/truetype/hack: skipping, existing cache is valid: 4 fonts, 0 dirs
/usr/share/fonts/truetype/liberation: skipping, existing cache is valid: 16 fonts, 0 dirs
/usr/share/fonts/truetype/liberation2: skipping, existing cache is valid: 12 fonts, 0 dirs
/usr/share/fonts/truetype/libreoffice: skipping, existing cache is valid: 1 fonts, 0 dirs
/usr/share/fonts/truetype/noto: skipping, existing cache is valid: 2380 fonts, 0 dirs
```

[create_service/template/script.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/templates/script.j2)

```ini
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi

```

[create_service/template/service.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/templates/service.j2)

```ini
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

[create_service/template/timer.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_service/templates/timer.j2)

```ini
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```

[create_unit/tasks/main.yml](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_unit/tasks/main.yml)

```yaml
---
# tasks file for create_unit
  - name: install fspawn-fcgi and tools
    package:
      name: spawn-fcgi,php,php-cgi,php-cli,apache2,libapache2-mod-fcgid
      state: present
  - name: create dir
    file:
      name: /etc/spawn-fcgi/
      state: directory
  - name: create config
    ansible.builtin.template:
       src: templates/fcgi.j2
       dest: /etc/spawn-fcgi/fcgi.conf
  - name: create log file
    ansible.builtin.template:
       src: templates/service.j2
       dest: /etc/systemd/system/spawn-fcgi.service
  - name: start service
    systemd:
       name: spawn-fcgi
       state: started
```

[create_unit/template/fcgi.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_unit/templates/fcgi.j2)

```ini
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

[create_unit/template/service.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/create_unit/templates/service.j2)

```ini
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

[modify_nginx/tasks/main.yml](https://github.com/anashoff/otus/blob/master/lesson12/roles/modify_nginx/tasks/main.yml)

```yaml
---
# tasks file for modify_nginx
  - name: install nginx
    package:
      name: nginx
      state: present
  - name: create service
    ansible.builtin.template:
      src: templates/service.j2
      dest: /etc/systemd/system/nginx@.service
  - name: create conf1
    ansible.builtin.template:
      src: templates/conf1.j2
      dest: /etc/nginx/nginx-first.conf
  - name: create conf1
    ansible.builtin.template:
      src: templates/conf2.j2
      dest: /etc/nginx/nginx-second.conf
  - name: start nginx1
    systemd:
      name: nginx@first
      state: started
  - name: start nginx2
    systemd:
      name: nginx@second
      state: started
```

[modify_nginx/template/conf1.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/modify_nginx/templates/conf1.j2)

```ini
user www-data;
worker_processes auto;
pid /run/nginx-first.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

http {


server {
             listen 9001;
       }
     
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        gzip on;



##        include /etc/nginx/conf.d/*.conf;
##        include /etc/nginx/sites-enabled/*;
}
```

[modify_nginx/template/conf2.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/modify_nginx/templates/conf2.j2)

```ini
user www-data;
worker_processes auto;
pid /run/nginx-second.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

http {


        server {
             listen 9002;
       }

        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        gzip on;



##        include /etc/nginx/conf.d/*.conf;
##        include /etc/nginx/sites-enabled/*;
}
```

[modify_nginx/template/service.j2](https://github.com/anashoff/otus/blob/master/lesson12/roles/modify_nginx/templates/service.j2)

```ini
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```

Запускаем роли Ansible

```text
anasha@otus:~/less12$ ansible-playbook site.yaml

┬─[anasha@otus:~/less12]─[10:37:30]─[G:(8e2c3df9)]
╰─>$ ansible-playbook site.yaml

PLAY [Systemd lesson] *********************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************
ok: [serv]

TASK [create_service : write config using jinja2] *****************************************************************************************
changed: [serv]

TASK [create_service : create log file] ***************************************************************************************************
changed: [serv]

TASK [create_service : write script using jinja2] *****************************************************************************************
changed: [serv]

TASK [create_service : write service jinja2] **********************************************************************************************
changed: [serv]

TASK [create_service : write timer using jinja2] ******************************************************************************************
changed: [serv]

TASK [create_service : reload] ************************************************************************************************************
ok: [serv]

TASK [create_service : start service] *****************************************************************************************************
changed: [serv]
TASK [create_unit : update apt] **********************************************************************************************************
changed: [serv]

TASK [create_unit : install fspawn-fcgi and tools] ***************************************************************************************
changed: [serv]

TASK [create_unit : create dir] **********************************************************************************************************
changed: [serv]

TASK [create_unit : create config] *******************************************************************************************************
changed: [serv]

TASK [create_unit : create log file] *****************************************************************************************************
changed: [serv]

TASK [create_unit : start service] *******************************************************************************************************
changed: [serv]

TASK [modify_nginx : install nginx] ******************************************************************************************************
changed: [serv]

TASK [modify_nginx : create service] *****************************************************************************************************
changed: [serv]

TASK [modify_nginx : create conf1] *******************************************************************************************************
changed: [serv]

TASK [modify_nginx : create conf1] *******************************************************************************************************
changed: [serv]

TASK [modify_nginx : start nginx1] *******************************************************************************************************
changed: [serv]

TASK [modify_nginx : start nginx2] *******************************************************************************************************
changed: [serv]

PLAY RECAP *******************************************************************************************************************************
serv                       : ok=20   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

#### Проверка работы

Заходим на сервер и проверяем запуск по таймеру

```zsh
anasha@otus:~/less12$ ssh vagrant@127.0.0.1 -p 2222
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Oct 12 08:06:41 UTC 2024

  System load:  0.0               Processes:               138
  Usage of /:   4.3% of 38.70GB   Users logged in:         0
  Memory usage: 26%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

37 updates can be applied immediately.
28 of these updates are standard security updates.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Sat Oct 12 08:00:54 2024 from 10.0.2.2
vagrant@serv:~$ sudo tail -n 1000 /var/log/syslog  | grep word
Oct 12 07:28:39 ubuntu-jammy kernel: [    3.663584] systemd[1]: Started Forward Password Requests to Wall Directory Watch.
Oct 12 08:03:23 ubuntu-jammy root: Sat Oct 12 08:03:23 UTC 2024: I found word, Master!
Oct 12 08:04:18 ubuntu-jammy root: Sat Oct 12 08:04:18 UTC 2024: I found word, Master!
Oct 12 08:05:21 ubuntu-jammy root: Sat Oct 12 08:05:21 UTC 2024: I found word, Master!
Oct 12 08:06:01 ubuntu-jammy root: Sat Oct 12 08:06:01 UTC 2024: I found word, Master!
Oct 12 08:06:36 ubuntu-jammy root: Sat Oct 12 08:06:36 UTC 2024: I found word, Master!
vagrant@serv:~$ 
```

Таймер работает
Проверяем spawn-fcgi

```zsh
vagrant@serv:~$ sudo systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: enabled)
     Active: active (running) since Sat 2024-10-12 07:58:41 UTC; 9min ago
   Main PID: 12159 (php-cgi)
      Tasks: 33 (limit: 1102)
     Memory: 14.2M
        CPU: 20ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─12159 /usr/bin/php-cgi
             ├─12160 /usr/bin/php-cgi
             ├─12161 /usr/bin/php-cgi
             ├─12162 /usr/bin/php-cgi
             ├─12163 /usr/bin/php-cgi
             ├─12164 /usr/bin/php-cgi
             ├─12165 /usr/bin/php-cgi
             ├─12166 /usr/bin/php-cgi
             ├─12167 /usr/bin/php-cgi
             ├─12168 /usr/bin/php-cgi
             ├─12169 /usr/bin/php-cgi
             ├─12170 /usr/bin/php-cgi
             ├─12171 /usr/bin/php-cgi
             ├─12172 /usr/bin/php-cgi
             ├─12173 /usr/bin/php-cgi
             ├─12174 /usr/bin/php-cgi
             ├─12175 /usr/bin/php-cgi
             ├─12176 /usr/bin/php-cgi
             ├─12177 /usr/bin/php-cgi
             ├─12178 /usr/bin/php-cgi
             ├─12179 /usr/bin/php-cgi
             ├─12180 /usr/bin/php-cgi
             ├─12181 /usr/bin/php-cgi
             ├─12182 /usr/bin/php-cgi
             ├─12183 /usr/bin/php-cgi
             ├─12184 /usr/bin/php-cgi
             ├─12185 /usr/bin/php-cgi
             ├─12186 /usr/bin/php-cgi
             ├─12187 /usr/bin/php-cgi
             ├─12188 /usr/bin/php-cgi
             ├─12189 /usr/bin/php-cgi
             ├─12190 /usr/bin/php-cgi
             └─12191 /usr/bin/php-cgi

Oct 12 07:58:41 serv systemd[1]: Started Spawn-fcgi startup service by Otus.
Oct 12 07:58:45 serv systemd[1]: /etc/systemd/system/spawn-fcgi.service:7: PIDFile= references a path below legacy directory /var/run/, updating /var/run/spawn-fcgi.pid → /run/spawn-fcgi.pid; please update the unit file accordingly.
Oct 12 07:58:46 serv systemd[1]: /etc/systemd/system/spawn-fcgi.service:7: PIDFile= references a path below legacy directory /var/run/, updating /var/run/spawn-fcgi.pid → /run/spawn-fcgi.pid; please update the unit file accordingly.
Oct 12 07:58:46 serv systemd[1]: /etc/systemd/system/spawn-fcgi.service:7: PIDFile= references a path below legacy directory /var/run/, updating /var/run/spawn-fcgi.pid → /run/spawn-fcgi.pid; please update the unit file accordingly.
vagrant@serv:~$ 
```

Служба запущена.
Проверяем запуск двух служб nginx

```zsh

vagrant@serv:~$ sudo ss -tnulp | grep nginx
tcp   LISTEN 0      511             0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=12849,fd=6),("nginx",pid=12848,fd=6))                                                                                                                                           
tcp   LISTEN 0      511             0.0.0.0:9002      0.0.0.0:*    users:(("nginx",pid=12879,fd=6),("nginx",pid=12878,fd=6))                                                                                                                                           
vagrant@serv:~$ 
```

Два экземпляра nginx работают на заданных портах

Задание выполнено

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson12)
