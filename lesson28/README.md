# Administrator Linux. Professional

## Урок 28. Домашнее задание

Vagrant-стенд c сетевой лабораторией

### Описание домашнего задания

Развернуть Vagrant-стенд

Построить следующую сетевую архитектуру:

#### Сеть office1

- 192.168.2.0/26      - dev
- 192.168.2.64/26     - test servers
- 192.168.2.128/26    - managers
- 192.168.2.192/26    - office hardware

#### Сеть office2

- 192.168.1.0/25      - dev
- 192.168.1.128/26    - test servers
- 192.168.1.192/26    - office hardware

#### Сеть central

- 192.168.0.0/28     - directors
- 192.168.0.32/28    - office hardware
- 192.168.0.64/26    - wifi

Итого должны получиться следующие сервера:

- inetRouter
- centralRouter
- office1Router
- office2Router
- centralServer
- office1Server
- office2Server

![pict1](pict/1.png)

Выполнить теоретическую и практическую части

В теоретической части требуется:

- Найти свободные подсети
- Посчитать количество узлов в каждой подсети, включая свободные
- Указать Broadcast-адрес для каждой подсети
- Проверить, нет ли ошибок при разбиении

В практической части требуется:

- Соединить офисы в сеть согласно логической схеме и настроить роутинг
- Интернет-трафик со всех серверов должен ходить через inetRouter
- Все сервера должны видеть друг друга (должен проходить ping)
- У всех новых серверов отключить дефолт на NAT (eth0), который vagrant поднимает для связи
- Добавить дополнительные сетевые интерфейсы, если потребуется

### Теоретическая часть

На основании исходных данных составим таблицу, где будут перечислены все сети организации с указанием адреса сети, маски сети, количества узлов в сети, адреса первого и последнеого хота в сети и широковещательный адрес сети.


| Имя сети | Сеть | Маска сети | Кол-во узлов | Начальный адрес узла | Конечный адрес узла | Широковещательный адрес |
| ---  | --- | --- | --- | --- | --- | --- |
| Сеть Central |
| Directors | 192.168.0.0/28 | 255.255.255.240 | 14 | 192.168.0.1 | 192.168.0.14 | 192.168.0.15 |
| Office hardware | 192.168.0.32/28 | 255.255.255.240 | 14 | 192.168.0.33 | 192.168.0.46 | 192.168.0.47 |
| Wifi (mgt network) | 192.168.0.64/26 | 255.255.255.192 | 62 | 192.168.0.65 | 192.168.0.126 | 192.168.0.127 |
| Сеть Office1 |
| Dev | 192.168.2.0/26 | 255.255.255.192 | 62 | 192.168.2.1 | 192.168.2.62 | 192.168.2.63 |
| Test | 192.168.2.64/26 | 255.255.255.192 | 62 | 192.168.2.65 | 192.168.2.126 | 192.168.2.127 |
| Managers | 192.168.2.128/26 | 255.255.255.192 | 62 | 192.168.2.129 | 192.168.2.190 | 192.168.2.191 |
| Office hardware | 192.168.2.192/26 | 255.255.255.192 | 62 | 192.168.2.193 | 192.168.2.254 | 192.168.2.255 |
| Сеть Office2 |
| Dev | 192.168.1.0/25 | 255.255.255.128 | 126 | 192.168.1.1 | 192.168.1.126 | 192.168.1.127 |
| Test | 192.168.1.128/26 | 255.255.255.192 | 62 | 192.168.1.129 | 192.168.1.190 | 192.168.1.191 |
| Ofiice | 192.168.1.192/26 | 255.255.255.192 | 62 | 192.168.1.193 | 192.168.1.254 | 192.168.1.255 |
| Сеть inetRouter - centralRouter |
| Inet - central | 192.168.255.0/30 | 255.255.255.252 | 2 | 192.168.255.1 | 192.168.255.2 | 192.168.255.3 |

#### Свободные подсети

- 192.168.0.16/28
- 192.168.0.48/28
- 192.168.0.128/25

- 192.168.255.64/26
- 192.168.255.32/27
- 192.168.255.16/28
- 192.168.255.8/29
- 192.168.255.4/30

#### Количество узлов в каждой подсети

Указан в таблице 

#### Broadcast-адрес для каждой подсети

Указан в таблице

#### Проверить, нет ли ошибок при разбиении
 
Ошибок нет


### Практическая часть

Схема сети

![pict2](pict/2.png)

#### Подготовка среды выполнения

Будем разворачивать 7 ВМ на ОС Ubuntu 22.04

Подготовим [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson28/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
      :inetRouter => {
        :box_name => "bento/ubuntu-22.04",
        :vm_name => "inetRouter",
        #:public => {:ip => '10.10.10.1', :adapter => 1},
        :net => [
                    ["192.168.255.1", 2, "255.255.255.252",  "router-net"], 
                    ["192.168.50.10", 8, "255.255.255.0"],
                ]
  },

      :centralRouter => {
        :box_name => "bento/ubuntu-22.04",
        :vm_name => "centralRouter",
        :net => [
                   ["192.168.255.2",  2, "255.255.255.252",  "router-net"],
                   ["192.168.0.1",    3, "255.255.255.240",  "dir-net"],
                   ["192.168.0.33",   4, "255.255.255.240",  "hw-net"],
                   ["192.168.0.65",   5, "255.255.255.192",  "mgt-net"],
                   ["192.168.255.9",  6, "255.255.255.252",  "office1-central"],
                   ["192.168.255.5",  7, "255.255.255.252",  "office2-central"],
                   ["192.168.50.11",  8, "255.255.255.0"],
                ]
  },
  
      :centralServer => {
        :box_name => "bento/ubuntu-22.04",
        :vm_name => "centralServer",
        :net => [
                   ["192.168.0.2",    2, "255.255.255.240",  "dir-net"],
                   ["192.168.50.12",  8, "255.255.255.0"],

                ]
  },
      :office1Router => {
        :box_name => "bento/ubuntu-22.04",
        :vm_name => "office1Router",
        :net => [
                   ["192.168.255.10",  2,  "255.255.255.252",  "office1-central"],
                   ["192.168.2.1",     3,  "255.255.255.192",  "dev1-net"],
                   ["192.168.2.65",    4,  "255.255.255.192",  "test1-net"],
                   ["192.168.2.129",   5,  "255.255.255.192",  "managers-net"],
                   ["192.168.2.193",   6,  "255.255.255.192",  "office1-net"],
                   ["192.168.50.20",   8,  "255.255.255.0"],
                ]
  },

      :office1Server => {
        :box_name => "bento/ubuntu-22.04",
        :vm_name => "office1Server",
        :net => [
                   ["192.168.2.130",  2,  "255.255.255.192",  "managers-net"],
                   ["192.168.50.21",  8,  "255.255.255.0"],
                ]
  },

     :office2Router => {
       :box_name => "bento/ubuntu-22.04",
       :vm_name => "office2Router",
       :net => [
                   ["192.168.255.6",  2,  "255.255.255.252",  "office2-central"],
                   ["192.168.1.1",    3,  "255.255.255.128",  "dev2-net"],
                   ["192.168.1.129",  4,  "255.255.255.192",  "test2-net"],
                   ["192.168.1.193",  5,  "255.255.255.192",  "office2-net"],
                   ["192.168.50.30",  8,  "255.255.255.0"],
               ]
  },

     :office2Server => {
       :box_name => "bento/ubuntu-22.04",
       :vm_name => "office2Server",
       :net => [
                  ["192.168.1.2",    2,  "255.255.255.128",  "dev2-net"],
                  ["192.168.50.31",  8,  "255.255.255.0"],
               ]
  }
}
ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.define boxname do |box|
        box.vm.box = boxconfig[:box_name]
        box.vm.host_name = boxconfig[:vm_name]
        box.vm.provider "virtualbox" do |v|
          v.memory = 1024
          v.cpus = 1
        end

        boxconfig[:net].each do |ipconf|
          box.vm.network("private_network", ip: ipconf[0], adapter: ipconf[1], netmask: ipconf[2], virtualbox__intnet: ipconf[3])
        end
        
        if boxconfig.key?(:public)
          box.vm.network "public_network", boxconfig[:public]
        end

      box.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
      box.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
      box.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false

        
      end

  end
  
end
```

#### Подготовка плейбука ansible

Подготовим плейбук ansible для выполнения работы

Структура плейбука

```text
├── ansible
│   ├── ansible.cfg
│   ├── hosts
│   ├── provision.yml
│   └── templates
│       ├── 00-installer-config.yaml
│       ├── 50-vagrant_centralRouter.yaml
│       ├── 50-vagrant_centralServer.yaml
│       ├── 50-vagrant_inetRouter.yaml
│       ├── 50-vagrant_office1Router.yaml
│       ├── 50-vagrant_office1Server.yaml
│       ├── 50-vagrant_office2Router.yaml
│       ├── 50-vagrant_office2Server.yaml
│       ├── iptables_restore
│       └── iptables_rules.ipv4
```

Файл конфигурации [ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson28/ansible.cfg)

```ini
[defaults]
host_key_checking = false
inventory = hosts
command_warnings= false
```

Файл настроек хостов [hosts](https://github.com/anashoff/otus/blob/master/lesson28/hosts)

```ini
[routers]
inetRouter ansible_host=192.168.50.10 ansible_user=vagrant  
centralRouter ansible_host=192.168.50.11 ansible_user=vagrant  
office1Router ansible_host=192.168.50.20 ansible_user=vagrant  
office2Router ansible_host=192.168.50.30 ansible_user=vagrant 
[servers]
centralServer ansible_host=192.168.50.12 ansible_user=vagrant
office1Server ansible_host=192.168.50.21 ansible_user=vagrant
office2Server ansible_host=192.168.50.31 ansible_user=vagrant
```
Файл 



Файл шаблона конфигурации FRR template/frr.conf.j2

```jinja
```

Файл плейбука provision.yml

```yaml
---
#Начало файла provision.yml
- name: OSPF
  #Указываем имя хоста или группу, которые будем настраивать
  hosts: all
  #Параметр выполнения модулей от root-пользователя
  become: yes
  #Указание файла с дополнителыми переменными (понадобится при добавлении темплейтов)
  vars_files:
    - defaults/main.yml
  tasks:
  # Обновление пакетов и установка vim, traceroute, tcpdump, net-tools
  - name: install base tools
    apt:
      name:
        - vim
        - traceroute
        - tcpdump
        - net-tools
      state: present
      update_cache: true
  #Отключаем UFW и удаляем его из автозагрузки
  - name: disable ufw service
    service:
      name: ufw
      state: stopped
      enabled: false
  # Добавляем gpg-key репозитория
  - name: add gpg frrouting.org
    apt_key:
      url: "https://deb.frrouting.org/frr/keys.asc"
      state: present
  # Добавляем репозиторий https://deb.frrouting.org/frr
  - name: add frr repo
    apt_repository:
      repo: 'deb https://deb.frrouting.org/frr {{ ansible_distribution_release }} frr-stable'
      state: present
  # Обновляем пакеты и устанавливаем FRR
  - name: install FRR packages
    apt:
      name: 
        - frr
        - frr-pythontools
      state: present
      update_cache: true
  # Включаем маршрутизацию транзитных пакетов
  - name: set up forward packages across routers
    sysctl:
      name: net.ipv4.conf.all.forwarding
      value: '1'
      state: present
  # Копируем файл daemons на хосты, указываем владельца и права
  - name: base set up OSPF 
    template:
      src: template/daemons
      dest: /etc/frr/daemons
      owner: frr
      group: frr
      mode: 0640
  # Копируем файл frr.conf на хосты, указываем владельца и права
  - name: set up OSPF 
    template:
      src: template/frr.conf.j2
      dest: /etc/frr/frr.conf
      owner: frr
      group: frr
      mode: 0640
    tags:
      - setup_ospf
  # Перезапускам FRR и добавляем в автозагрузку
  - name: restart FRR
    service:
      name: frr
      state: restarted
      enabled: true
    tags:
      - setup_ospf
```

## Выполнение работы

### Настроить OSPF между машинами

Запускаем Vagrantfile

```zsh
┬─[anasha@otus:~/less28]─[15:36:28]
╰─o$ vagrant up
Bringing machine 'inetRouter' up with 'virtualbox' provider...
Bringing machine 'centralRouter' up with 'virtualbox' provider...
Bringing machine 'centralServer' up with 'virtualbox' provider...
Bringing machine 'office1Router' up with 'virtualbox' provider...
Bringing machine 'office1Server' up with 'virtualbox' provider...
Bringing machine 'office2Router' up with 'virtualbox' provider...
Bringing machine 'office2Server' up with 'virtualbox' provider...

...........................................................

```

Затем плейбук

```ini
┬─[anasha@otus:~/l/ansible]─[15:43:54]
╰─o$ ansible-playbook provision.yml

PLAY [network lab] **************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [inetRouter]
ok: [office2Router]
ok: [centralServer]
ok: [office1Router]
ok: [centralRouter]
ok: [office1Server]
ok: [office2Server]

TASK [install base tools] **************************************************************************************************************
changed: [centralRouter]
changed: [inetRouter]
changed: [centralServer]
changed: [office2Router]
changed: [office1Router]
changed: [office1Server]
changed: [office2Server]

TASK [disable ufw service] **************************************************************************************************************
skipping: [centralRouter]
skipping: [office1Router]
skipping: [office2Router]
skipping: [centralServer]
skipping: [office1Server]
skipping: [office2Server]
changed: [inetRouter]

TASK [Set up NAT on inetRouter] ***********************************************************************************************************
skipping: [centralRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [centralRouter] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [centralRouter]
skipping: [office1Router] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office1Router] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [office1Router]
skipping: [office2Router] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office2Router] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [centralServer] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office2Router]
skipping: [centralServer] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [centralServer]
skipping: [office1Server] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office1Server] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [office1Server]
skipping: [office2Server] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office2Server] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'}) 
skipping: [office2Server]
changed: [inetRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'})
changed: [inetRouter] => (item={'src': 'iptables_restore', 'dest': '/etc/network/if-pre-up.d/iptables', 'mode': '0755'})

TASK [set up forward packages across routers] *********************************************************************************************
skipping: [centralServer]
skipping: [office1Server]
skipping: [office2Server]
changed: [centralRouter]
changed: [inetRouter]
changed: [office2Router]
changed: [office1Router]

TASK [disable default route] **************************************************************************************************************
skipping: [inetRouter]
changed: [office1Router]
changed: [centralRouter]
changed: [office2Router]
changed: [office1Server]
changed: [centralServer]
changed: [office2Server]

TASK [add default gateway for centralRouter] **********************************************************************************************
changed: [inetRouter]
changed: [office1Router]
changed: [centralRouter]
changed: [centralServer]
changed: [office2Router]
changed: [office1Server]
changed: [office2Server]

TASK [restart all hosts] **************************************************************************************************************
changed: [centralRouter]
changed: [office2Router]
changed: [office1Router]
changed: [inetRouter]
changed: [office2Server]
changed: [office1Server]
changed: [centralServer]

PLAY RECAP *************************************************************************************************************
centralRouter              : ok=6    changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
centralServer              : ok=5    changed=4    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
inetRouter                 : ok=7    changed=6    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
office1Router              : ok=6    changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
office1Server              : ok=5    changed=4    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
office2Router              : ok=6    changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
office2Server              : ok=5    changed=4    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

┬─[anasha@otus:~/l/ansible]─[15:47:01]

```

Проверим работу сетевой лаборатории

Подключаемся к  router_1 и проверяем сервис FRR

![pict2](pict/r1_0.png)

Сервис запущен

Проверяем прохождение пинга по сетям

![pict2](pict/r1_1.png)

Видим, что все сети доступны

Посмотрим маршруты до 192.168.30.0 сети с включенным и выключенным интерфейсом enp0s9

![pict2](pict/r1_2.png)

Видим, что при отключении интерфейса марштрут изменяется

Посмотрим таблицу маршрутов роутера

![pict2](pict/r1_3.png)

Убеждаемся, что все маршгруты построены верно

Аналогично проверяем router_2 и router_3

Подключаемся к  router_2 и проверяем сервис FRR

![pict2](pict/r2_0.png)

Сервис запущен

Проверяем прохождение пинга по сетям

![pict2](pict/r2_1.png)

Видим, что все сети доступны

Посмотрим маршруты до 192.168.30.0 сети с включенным и выключенным интерфейсом enp0s9

![pict2](pict/r2_2.png)

Видим, что при отключении интерфейса марштрут изменяется

Посмотрим таблицу маршрутов роутера

![pict2](pict/r2_3.png)

Убеждаемся, что все маршгруты построены верно

Подключаемся к  router_3 и проверяем сервис FRR

![pict2](pict/r3_0.png)

Сервис запущен

Проверяем прохождение пинга по сетям

![pict2](pict/r3_1.png)

Видим, что все сети доступны

Посмотрим маршруты до 192.168.10.0 сети с включенным и выключенным интерфейсом enp0s9

![pict2](pict/r3_2.png)

Видим, что при отключении интерфейса марштрут изменяется

Посмотрим таблицу маршрутов роутера

![pict2](pict/r3_3.png)

Убеждаемся, что все маршгруты построены верно

### Изобразить ассиметричный роутинг

Добавим в плейбук натройку ассиметричного роутинга

```yaml
 # Отключаем запрет ассиметричного роутинга 
  - name: set up asynchronous routing
    sysctl:
      name: net.ipv4.conf.all.rp_filter
      value: '0'
      state: present
```

В файле шаблона frr.conf.j2 изменяем настроки интерфейса enp0s8, добавляем условие

```jinja
{% if ansible_hostname == 'router1' %}
 ip ospf cost 1000
{% else %}
 !ip ospf cost 450
{% endif %}
```

Запускаем плейбук

```zsh
┬─[anasha@otus:~/less33]─[16:32:55]
╰─o$ ansible-playbook -i ansible/hosts -l all ansible/provision.yml -e "host_key_checking=false"

PLAY [OSPF] **************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [router1]
ok: [router2]
ok: [router3]

...............................................

TASK [set up asynchronous routing] ********************************************************************************************************
changed: [router1]
changed: [router3]
changed: [router2]

TASK [set up OSPF] **************************************************************************************************************
ok: [router2]
ok: [router3]
changed: [router1]

TASK [restart FRR] **************************************************************************************************************
changed: [router3]
changed: [router1]
changed: [router2]

PLAY RECAP **************************************************************************************************************
router1                    : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
router2                    : ok=11   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
router3                    : ok=11   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Проверяем работу маршрутизаторов

Заходим на router_1 и запускаем ping от 192.168.10.1 до 192.168.20.1

![pict2](pict/r1_4.png)

Заходим на router_2 и запускаем tcpdump на интерфейсе enp0s9

![pict2](pict/r2_4.png)

А затем на интерфейсе enp0s8

![pict2](pict/r2_5.png)

Видим, что интерфейс enp0s9 только получает трафик с адреса 192.168.10.1, а интерфейс enp0s8 - только отправляет трафик на адрес 192.168.10.1

Таким образом мы видим  ассиметричный роутинг

### Сделать один из линков "дорогим", но что бы при этом роутинг был симметричным

Снова изменим шаблон настроек frr.conf.j2, поменяв условие

```jinja
{% if ansible_hostname == 'router1' %}
 !ip ospf cost 1000
{% elif ansible_hostname == 'router2' and symmetric_routing == true %}
 !ip ospf cost 1000
{% else %}
 !ip ospf cost 450
{% endif %}
```

В файл переменных плейбука добавим переменную **symmetric_routing**. Для включения симметричного роутинга присвоим ей значение **true**

Чтобы не выполнять весь плейбук запустим его с тегом **setup_ospf**, благодаря котоому будет выполнени только перенастройка и перезапуск FRR

```zsh
┬─[anasha@otus:~/less33]─[16:48:10]
╰─o$ ansible-playbook -i ansible/hosts -l all ansible/provision.yml -e "host_key_checking=false" -t setup_ospf

PLAY [OSPF] **************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [router2]
ok: [router1]
ok: [router3]

TASK [set up OSPF] **************************************************************************************************************
ok: [router1]
ok: [router3]
changed: [router2]

TASK [restart FRR] **************************************************************************************************************
changed: [router3]
changed: [router1]
changed: [router2]

PLAY RECAP **************************************************************************************************************
router1                    : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
router2                    : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
router3                    : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Запускаем ping на router_1 от 192.168.10.1 до 192.168.20.1

![pict2](pict/r1_5.png)

Заходим на router_2 и запускаем tcpdump на интерфейсе enp0s9

![pict2](pict/r2_6.png)

Видим, что интерфейс enp0s9 и получает трафик с адреса 192.168.10.1, и отправляет трафик на него же

Трафик между роутерами ходит симметрично

Задание на этом выполнено.

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson33)
