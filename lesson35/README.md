# Administrator Linux. Professional

## Урок 35. Домашнее задание

VPN

### Описание домашнего задания

Часть 1. Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях

Часть 2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ

## Часть 1. TUN/TAP режимы VPN

### Подготовка среды выполнения

Для выполнения задания развернем 2 виртуальные машины. Установим на одной сервер OpenVPN, на второй - клиента OpenVPN.

#### Подготовка к развёртыванию vagrant

Подготовим [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson35/part1/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vim: set ft=ruby :
Vagrant.configure("2") do |config|
config.vm.box = "ubuntu/jammy64" 
config.vm.define "server" do |server| 
server.vm.hostname = "server.loc" 
	server.vm.network "private_network", ip: "192.168.56.10" 
end 

config.vm.define "client" do |client| 
client.vm.hostname = "client.loc" 
client.vm.network "private_network", ip: "192.168.56.20" 
end 
end
```
#### Подготовка плейбука ansible

Подготовим плейбук ansible для выполнения работы. Один плей будет развертывать с нуля сервер в режиме tap, второй - переключать его в режим tun.

Структура плейбука

```text
├── ansible.cfg
├── files
│   └── static.key
├── hosts.ini
├── templates
│   ├── openvpn@.service.j2
│   ├── server1.conf.j2
│   └── server.conf.j2
├── vpn_tap.yaml
└── vpn_tun.yaml
```

Файл конфигурации [ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson35/part1/ansible.cfg)

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

Файл настроек хостов [hosts.ini](https://github.com/anashoff/otus/blob/master/lesson35/part1/hosts.ini)

```ini
[all]
server ansible_port=2222 ansible_host=127.0.0.1 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/server/virtualbox/private_key
client ansible_port=2200 ansible_host=127.0.0.1 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/client/virtualbox/private_key
```

[template/hosts.j2](https://github.com/anashoff/otus/blob/master/lesson35/part1/templates/openvpn@.service.j2)

```jinja
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target
```

[template/hosts.j2](https://github.com/anashoff/otus/blob/master/lesson35/part1/templates/server.j2)

```jinja
dev tap
{% if remote_server %}
remote {{ remote_server }}
{% endif %}
ifconfig {{ server_ip }} 255.255.255.0
topology subnet
{% if inventory_hostname == "client" %}
route 10.10.10.0 255.255.255.0
{% endif %}
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

[template/hosts.j2](https://github.com/anashoff/otus/blob/master/lesson35/part1/templates/server.j2)

```jinja
dev tun
{% if remote_server %}
remote {{ remote_server }}
{% endif %}
ifconfig {{ server_ip }} 255.255.255.0
topology subnet
{% if inventory_hostname == "client" %}
route 10.10.10.0 255.255.255.0
{% endif %}
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

Файл плейбука [vpn_tap.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part1/templates/vpn_tap.yaml)

```yaml
---
- name: Настройка OpenVPN
  hosts: all
  gather_facts: true
  become: yes
  tasks:
    - name: Установка необходимых пакетов
      apt:
        name:
          - openvpn
          - iperf3
        update_cache: yes
        state: present
- name: Настройка сервера OpenVPN
  hosts: server
  gather_facts: true
  become: yes
  tasks:
    - name: Генерация статического ключа
      command: 
        cmd: openvpn --genkey secret /etc/openvpn/static.key
        creates: /etc/openvpn/static.key

    - name: Отправка ключа на управляющую машину
      fetch:
        src: /etc/openvpn/static.key
        dest: "{{ playbook_dir }}/files/static.key"
        flat: yes

    - name: Настройка конфигурации сервера
      template:
        src: server.conf.j2
        dest: /etc/openvpn/server.conf
      vars:
        server_ip: 10.10.10.1
        remote_server: ""

    - name: Копирование юнита systemd
      template:
        src: openvpn@.service.j2
        dest: /etc/systemd/system/openvpn@.service

    - name: Перезагрузка демона systemd
      systemd:
        daemon_reload: yes

    - name: Запуск сервиса OpenVPN
      systemd:
        name: openvpn@server
        enabled: yes
        state: started

- name: Настройка клиента OpenVPN
  hosts: client
  gather_facts: true
  become: yes
  tasks:
    - name: Копирование ключа с управляющей машины
      copy:
        src: "{{ playbook_dir }}/files/static.key"
        dest: /etc/openvpn/static.key
        mode: 0600

    - name: Настройка конфигурации клиента
      template:
        src: server.conf.j2
        dest: /etc/openvpn/server.conf
      vars:
        server_ip: 10.10.10.2
        remote_server: 192.168.56.10

    - name: Копирование юнита systemd
      template:
        src: openvpn@.service.j2
        dest: /etc/systemd/system/openvpn@.service

    - name: Перезагрузка демона systemd
      systemd:
        daemon_reload: yes

    - name: Запуск сервиса OpenVPN
      systemd:
        name: openvpn@server
        enabled: yes
        state: started
```

Файл плейбука [vpn_tun.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part1/templates/vpn_tun.yaml)

```yaml
---
- name: Настройка сервера OpenVPN
  hosts: server
  gather_facts: true
  become: yes
  tasks:
    - name: Настройка конфигурации сервера
      template:
        src: server1.conf.j2
        dest: /etc/openvpn/server.conf
      vars:
        server_ip: 10.10.10.1
        remote_server: ""

    - name: Перезагрузка демона systemd
      systemd:
        daemon_reload: yes

    - name: Перезапуск сервиса OpenVPN
      systemd:
        name: openvpn@server
        state: restarted

- name: Настройка клиента OpenVPN
  hosts: client
  gather_facts: true
  become: yes
  tasks:

    - name: Настройка конфигурации клиента
      template:
        src: server1.conf.j2
        dest: /etc/openvpn/server.conf
      vars:
        server_ip: 10.10.10.2
        remote_server: 192.168.56.10

    - name: Копирование юнита systemd
      template:
        src: openvpn@.service.j2
        dest: /etc/systemd/system/openvpn@.service

    - name: Перезагрузка демона systemd
      systemd:
        daemon_reload: yes

    - name: перезапуск сервиса OpenVPN
      systemd:
        name: openvpn@server
        state: restarted

```

### TAP режим VPN

Запускаем стенд командой 

```bash
┬─[anasha@otus:~/less35]─[09:09:25]
╰─o$ vagrant up
```

После запуска виртуальных машин переходим к настройке стенда в режиме сервера tap

Запускаем плейбук ansible 

```text
┬─[anasha@otus:~/less35]─[09:14:08]
╰─o$ ansible-playbook vpn_tap.yaml

PLAY [Настройка OpenVPN] *******************************************************************************************
.........................................

PLAY [Настройка сервера OpenVPN] *******************************************************************************************

........................................

TASK [Запуск сервиса OpenVPN] *******************************************************************************************
changed: [server]

PLAY [Настройка клиента OpenVPN] *******************************************************************************************

........................................

PLAY RECAP *******************************************************************************************
client                     :ok=8changed=5 unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server                     :ok=9changed=6 unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Заходим на сервер и запускаем ipref3 в режиме сервера

![pict1](part1\pict\server_tap.png)

На клиенте запускаем iperf3 врежиме клиента

![pict1](part1\pict\client_tap.png)


### TUN режим VPN

Запускаем плейбук ansible vpn_tun.yaml

```text
┬─[anasha@otus:~/less35]─[10:01:58]
╰─o$ ansible-playbook vpn_tun.yaml

PLAY [Настройка сервера OpenVPN] ******************************************************************************************

TASK [Gathering Facts] *******************************************************************************************
ok: [server]

TASK [Настройка конфигурации сервера] *******************************************************************************************
changed: [server]

TASK [Перезагрузка демона systemd] *******************************************************************************************
ok: [server]

TASK [Перезапуск сервиса OpenVPN] *******************************************************************************************
changed: [server]

PLAY [Настройка клиента OpenVPN] *******************************************************************************************

TASK [Gathering Facts] *******************************************************************************************
ok: [client]

TASK [Настройка конфигурации клиента] *******************************************************************************************
changed: [client]

TASK [Копирование юнита systemd] *******************************************************************************************
ok: [client]

TASK [Перезагрузка демона systemd] *******************************************************************************************
ok: [client]

TASK [перезапуск сервиса OpenVPN] *******************************************************************************************
changed: [client]

PLAY RECAP ****************************************************************************
client                     :ok=5changed=2 unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
server                     : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Заходим на сервер и запускаем ipref3 в режиме сервера

![pict1](part1\pict\server_tun.png)

На клиенте запускаем iperf3 врежиме клиента

![pict1](part1\pict\client_tun.png)

Получаем в режиме tap скорость ~ 170 Mbit/sec, в режиме tun - ~ 140 Mbit/sec.

Таким образом, TAP обеспечивает более высокую скорость благодаря упрощённой обработке на канальном уровне, меньшим накладным расходам и отсутствию сложных операций маршрутизации. Однако выбор между TAP и TUN зависит от задачи: TUN лучше подходит для маршрутизации между разными сетями, а TAP — для создания прозрачных мостов в локальных сетях.

## Часть 2. RAS на базе OpenVPN

### Подготовка среды выполнения

Для выполнения задания развернем 1 виртуальную машину. Установим на ней сервер OpenVPN
Клиента будем использовать нна хосте

#### Подготовка к развёртыванию vagrant

Подготовим [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson35/part2/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vim: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provider :virtualbox do |v|
    v.memory = 2048
    v.cpus = 2
  end
  boxes = [
    { :name => "server",
      :net => [
           ["192.168.56.10",  2, "255.255.255.0"],
            ]
    },
  ]
  boxes.each do |opts|
    config.vm.define opts[:name] do |config|
      config.vm.hostname = opts[:name]
      opts[:net].each do |ipconf|
        config.vm.network("private_network", ip: ipconf[0], adapter: ipconf[1], netmask: ipconf[2],virtualbox__intnet: ipconf[3])
      end
   end
  end
end
```
#### Подготовка плейбука ansible

Подготовим плейбук ansible для выполнения работы. Один плей будет развертывать с нуля сервер в режиме tap, второй - переключать его в режим tun.

Структура плейбука

```text
├── ansible.cfg
├── config
│   ├── ca.crt
│   ├── client.conf
│   ├── client.crt
│   └── client.key
├── group_vars
│   └── all.yaml
├── hosts.ini
├── ras_vpn.yaml
├── roles
│   └── openvpn
│       ├── handlers
│       │   └── main.yaml
│       ├── tasks
│       │   └── main.yaml
│       └── templates
│           ├── openvpn@.service.j2
│           └── server.conf.j2
```

Файл конфигурации [ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson35/part2/ansible.cfg)

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

Файл настроек хостов [hosts.ini](https://github.com/anashoff/otus/blob/master/lesson35/part2/hosts.ini)

```ini
[all]
ovpnserver ansible_port=2222 ansible_host=127.0.0.1 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/server/virtualbox/private_key
```

[template/hosts.j2](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/templates/openvpn@.service.j2)

```jinja
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target
```

[template/hosts.j2](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/templates/server.j2)

```jinja
port {{ vpn_port }}
proto udp
dev tun
ca {{ pki_dir }}/ca.crt
cert {{ pki_dir }}/issued/server.crt
key {{ pki_dir }}/private/server.key
dh {{ pki_dir }}/dh.pem
server {{ vpn_subnet }} {{ vpn_netmask }}
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir {{ client_conf_dir }}
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

[template/client.ovpn.j2](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/templates/client.ovpn.j2)

```jinja
dev tun
proto udp
remote 192.168.56.10 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
persist-key
persist-tun
comp-lzo
verb 3
```

Хендлеры [main.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/handlers/main.yaml)

```yaml
  - name: Restart OpenVPN
    systemd:
      name: openvpn@server
      state: restarted
```

Файл роли [ras_vpn.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part2/ras_vpn.yaml)

```yaml
---
- name: Развертывание OpenVPN сервера с TLS
  hosts: all
  gather_facts: true
  become: yes
  roles:
    - openvpn
```

Файл плей [main.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/tasks/main.yaml)

```yaml
---
- name: Установка зависимостей
  apt:
    update_cache: yes
    name:
      - openvpn
      - easy-rsa
    state: present

- name: Создание рабочих директорий
  file:
    path: "{{ item }}"
    state: directory
    mode: 0700
  loop:
    - "{{ pki_dir }}"
    - "{{ client_conf_dir }}"

- name: Инициализация PKI
  shell: |
    {{ easy_rsa_path }}/easyrsa --batch init-pki
  args:
    chdir: /etc/openvpn
    creates: "{{ pki_dir }}/private/ca.key"
  environment:
    EASYRSA_KEY_SIZE: "4096"
    EASYRSA_CA_EXPIRE: "3650"
    EASYRSA_CERT_EXPIRE: "3650"

- name: Генерация CA
  shell: |
    {{ easy_rsa_path }}/easyrsa --batch build-ca nopass
  args:
    chdir: /etc/openvpn
    creates: "{{ pki_dir }}/ca.crt"
  environment:
    EASYRSA_BATCH: "1"

- name: Генерация серверных сертификатов
  shell: |
    {{ easy_rsa_path }}/easyrsa --batch build-server-full server nopass
    {{ easy_rsa_path }}/easyrsa gen-dh
  args:
    chdir: /etc/openvpn
    creates: "{{ pki_dir }}/issued/server.crt"

- name: Генерация клиентских сертификатов
  shell: |
    {{ easy_rsa_path }}/easyrsa --batch build-client-full client nopass
  args:
    chdir: /etc/openvpn
    creates: "{{ pki_dir }}/issued/client.crt"

- name: Настройка конфигурации сервера
  template:
    src: server.conf.j2
    dest: /etc/openvpn/server.conf
    mode: 0600
  notify: Restart OpenVPN

- name: Настройка клиентского маршрута
  copy:
    dest: "{{ client_conf_dir }}/{{ client_name }}"
    content: "route {{ vpn_subnet }} {{ vpn_netmask }}"

- name: Копирование юнита systemd
  template:
    src: openvpn@.service.j2
    dest: /etc/systemd/system/openvpn@.service
- name: Перезагрузка демона systemd
  systemd:
    daemon_reload: yes

- name: Включение и запуск сервиса
  systemd:
    name: openvpn@server
    enabled: yes
    state: started

- name: Генерация клиентского конфига
  template:
    src: client.ovpn.j2
    dest: "/tmp/{{ client_name }}.ovpn"

- name: Отправка ключей и конфига на управляющую машину
  fetch:
    src: "{{ item.src }}"
    dest: "{{ item.dest }}"
    flat: yes
    mode: "{{ item.mode | default('0644') }}"
  loop: "{{ files_to_fetch }}"
  vars:
    files_to_fetch:
      - { src: '/etc/openvpn/pki/ca.crt', dest: '{{ playbook_dir }}/config/ca.crt' }
      - { src: '/etc/openvpn/pki/issued/client.crt', dest: '{{ playbook_dir }}/config/client.crt' }
      - { src: '/etc/openvpn/pki/private/client.key', dest: '{{ playbook_dir }}/config/client.key', mode: '0600' }
      - { src: '/tmp/{{ client_name }}.ovpn', dest: '{{ playbook_dir }}/config/{{ client_name }}.ovpn' }
```

Файл глобальных переменных [all.yaml](https://github.com/anashoff/otus/blob/master/lesson35/part2/roles/openvpn/group_vars/all.yaml)

```yaml
---
# Основные настройки OpenVPN
vpn_port: 1207
vpn_subnet: 10.10.10.0
vpn_netmask: 255.255.255.0
easy_rsa_path: /usr/share/easy-rsa

# Настройки сертификатов
ca_name: rasvpn
client_name: client
cert_validity_days: 3650

# Пути к файлам
pki_dir: /etc/openvpn/pki
client_conf_dir: /etc/openvpn/client
```

Запускаем стенд командой 

```bash
┬─[anasha@otus:~/less35-2]─[11:40:15]
╰─o$ vagrant up
```

После запуска виртуальных машин переходим к настройке 

```text
┬─[anasha@otus:~/less35-2]─[11:43:42]
╰─o$ ansible-playbook ras_vpn.yaml

PLAY [Развертывание OpenVPN сервера с TLS] *******************************************************************************************

TASK [Gathering Facts] *******************************************************************************************
ok: [ovpnserver]

TASK [openvpn : Установка зависимостей] *******************************************************************************************
changed: [ovpnserver]

TASK [openvpn : Создание рабочих директорий] *******************************************************************************************changed: [ovpnserver] => (item=/etc/openvpn/pki)
changed: [ovpnserver] => (item=/etc/openvpn/client)

TASK [openvpn : Инициализация PKI] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Генерация CA] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Генерация серверных сертификатов] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Генерация клиентских сертификатов] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Настройка конфигурации сервера] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Настройка клиентского маршрута] *******************************************************************************************changed: [ovpnserver]

TASK [openvpn : Копирование юнита systemd] *******************************************************************************************
changed: [ovpnserver]

TASK [openvpn : Перезагрузка демона systemd] *******************************************************************************************
ok: [ovpnserver]

TASK [openvpn : Включение и запуск сервиса] *******************************************************************************************
changed: [ovpnserver]

TASK [openvpn : Генерация клиентского конфига] *******************************************************************************************
changed: [ovpnserver]

TASK [openvpn : Отправка ключей и конфига на управляющую машину] *******************************************************************************************
changed: [ovpnserver] => (item={'src': '/etc/openvpn/pki/ca.crt', 'dest': '/home/anasha/less35-2/config/ca.crt'})
changed: [ovpnserver] => (item={'src': '/etc/openvpn/pki/issued/client.crt', 'dest': '/home/anasha/less35-2/config/client.crt'})
changed: [ovpnserver] => (item={'src': '/etc/openvpn/pki/private/client.key', 'dest': '/home/anasha/less35-2/config/client.key', 'mode': '0600'})
changed: [ovpnserver] => (item={'src': '/tmp/client.ovpn', 'dest': '/home/anasha/less35-2/config/client.ovpn'})

RUNNING HANDLER [openvpn : Restart OpenVPN] *******************************************************************************************
changed: [ovpnserver]

PLAY RECAP *******************************************************************************************
ovpnserver                 :ok=15changed=13 unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Переходим в каталог с ключами и конфигурацией **config** и запускаем OpenVPN клиента в фоновом режиме

```text
┬─[anasha@otus:~/less35-2]─[11:58:12]
╰─o$ cd config/
┬─[anasha@otus:~/l/config]─[11:58:38]
╰─o$ sudo openvpn --config client.ovpn --daemon
2025-02-23 11:58:42 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
```

Проверяем прохождение пинга до сервера

```text
┬─[anasha@otus:~/l/config]─[11:58:42]
╰─o$ ping -c 4 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.807 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.840 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.838 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=0.859 ms

--- 10.10.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3057ms
rtt min/avg/max/mdev = 0.807/0.836/0.859/0.018 ms
```

Задание на этом выполнено.

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson35)

