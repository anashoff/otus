

# Administrator Linux. Professional

## Урок 37. Домашнее задание

LDAP

### Описание домашнего задания

Установить FreeIPA
Написать Ansible-playbook для конфигурации клиента

### Подготовка среды выполнения

Для выполнения задания развернем 3 виртуальные машины.

Подготовим [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson37/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vim: set ft=ruby :
```
#### Подготовка плейбука ansible

Подготовим плейбук ansible для выполнения работы

Структура плейбука

```text
├── ansible.cfg
├── hosts.ini
├── playbook.yaml
├── templates
│   ├── 50-cloud-init.yaml.j2
│   ├── ifcfg-bond0.j2
│   ├── ifcfg-eth1
│   ├── ifcfg-eth2
│   └── ifcfg-vlan1.j2
```

Файл конфигурации [ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson37/ansible.cfg)

```ini
[defaults]
#Отключение проверки ключа хоста
host_key_checking = false
#Указываем имя файла инвентаризации
inventory = hosts
#Отключаем игнорирование предупреждений
command_warnings= false
```

Файл настроек хостов [hosts.ini](https://github.com/anashoff/otus/blob/master/lesson37/hosts.ini)

```ini
```


[template/ifcfg-eth2](https://github.com/anashoff/otus/blob/master/lesson37/templates/ifcfg-eth2)

```jinja
Имя физического интерфейса
DEVICE=eth2
#Включать интерфейс при запуске системы
ONBOOT=yes
#Отключение DHCP-клиента
BOOTPROTO=none
#Указываем, что порт часть bond-интерфейса
MASTER=bond0
#Указываем роль bond
SLAVE=yes
NM_CONTROLLED=yes
USERCTL=no
```

Файл плейбука [playbook.yaml](https://github.com/anashoff/otus/blob/master/lesson37/templates/playbook.yaml)

```yaml
# Предварительная настройка
        reboot_timeout: 3600

```
Запускаем стенд командой 

```bash
┬─[anasha@otus:~/less37]─[16:09:25]
╰─o$ vagrant up
```

```
Стенд установлен и настроен

Проверим работу стенда

#### Установка FreeIPA сервера

Установим часовой пояс

```text
[root@ipa ~]# timedatectl set-timezone Europe/Moscow
```

Установим утилиту chrony

```text
[root@ipa ~]# dnf install chrony

```

Запустим chrony и добавим его в автозагрузку: 

```text
[root@ipa ~]# systemctl enable --now chronyd
```

Проверим работу chrony

```text
[root@ipa ~]# chronyc -N sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
=========================================================================
^- 2.centos.pool.ntp.org         2   6   377    20   +482us[ +482us] +/-   57ms
^- 2.centos.pool.ntp.org         2   6   377    59   +759us[ +759us] +/-   16ms
^* 2.centos.pool.ntp.org         2   6   377    60   -148us[ -399us] +/- 4676us
^- 2.centos.pool.ntp.org         2   6   377    60   +209us[  -41us] +/-   31ms
```

Останавливаем и отключаем firewalld

```text
[root@ipa ~]# systemctl disable --now firewalld.service
Removed /etc/systemd/system/multi-user.target.wants/firewalld.service.
Removed /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.
[root@ipa ~]#
```

Отключаем selinux

```text
[root@ipa ~]# setenforce 0
[root@ipa ~]# sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
```

Добавим в файл hosts ip ддрес хоста

```
[root@ipa ~]# echo "192.168.57.10 ipa.otus.lan ipa" >> /etc/hosts
```

Установим модуль DL1

```
[root@ipa ~]# yum install -y @idm:DL1
```

Установим FreeIPA-сервер: 

```
[root@ipa ~]# yum install -y ipa-server
```

Запустим скрипт установки: ipa-server-install
Получаем ошибку 

```
[root@ipa ~]# ipa-server-install
IPv6 stack is enabled in the kernel but there is no interface that has ::1 address assigned. Add ::1 address resolution to 'lo' interface. You might need to enable IPv6 on the interface 'lo' in sysctl.conf.
The ipa-server-install command failed. See /var/log/ipaserver-install.log for more information
```

Находим решение в интернете

```
[root@ipa ~]# echo "net.ipv6.conf.lo.disable_ipv6 = 0" >> /etc/sysctl.d/99-sysctl.conf
[root@ipa ~]# sysctl -p /etc/sysctl.d/99-sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
```

Снова запустим скрипт установки

```
[root@ipa ~]# ipa-server-install

The log file for this installation can be found in /var/log/ipaserver-install.log
==============================================================================
This program will set up the IPA Server.
Version 4.9.6

This includes:
  * Configure a stand-alone CA (dogtag) for certificate management
  * Configure the NTP client (chronyd)
  * Create and configure an instance of Directory Server
  * Create and configure a Kerberos Key Distribution Center (KDC)
  * Configure Apache (httpd)
  * Configure SID generation
  * Configure the KDC to enable PKINIT

To accept the default shown in brackets, press the Enter key.
Do you want to configure integrated DNS (BIND)? [no]:

Enter the fully qualified domain name of the computer
on which you're setting up server software. Using the form
<hostname>.<domainname>
Example: master.example.com.


Server host name [ipa.otus.lan]:


The domain name has been determined based on the host name.

Please confirm the domain name [otus.lan]:

The kerberos protocol requires a Realm name to be defined.
This is typically the domain name converted to uppercase.

Please provide a realm name [OTUS.LAN]:
Certain directory server operations require an administrative user.
This user is referred to as the Directory Manager and has full access
to the Directory for system management tasks and will be added to the
instance of directory server created for IPA.
The password must be at least 8 characters long.
Directory Manager password:
Password (confirm):

The IPA server requires an administrative user, named 'admin'.
This user is a regular system account used for IPA server administration.

IPA admin password:
Password (confirm):

Invalid IP address 127.0.1.1 for ipa.otus.lan: cannot use loopback IP address 127.0.1.1
Trust is configured but no NetBIOS domain name found, setting it now.
Enter the NetBIOS name for the IPA domain.
Only up to 15 uppercase ASCII letters, digits and dashes are allowed.
Example: EXAMPLE.


NetBIOS domain name [OTUS]:

Do you want to configure chrony with NTP server or pool address? [no]:

The IPA Master Server will be configured with:
Hostname:       ipa.otus.lan
IP address(es): 192.168.57.10
Domain name:    otus.lan
Realm name:     OTUS.LAN

The CA will be configured with:
Subject DN:   CN=Certificate Authority,O=OTUS.LAN
Subject base: O=OTUS.LAN
Chaining:     self-signed
Continue to configure the system with these values? [no]: yes

The following operations may take some minutes to complete.
Please wait until the prompt is returned.
Disabled p11-kit-proxy
Synchronizing time
No SRV records of NTP servers found and no NTP server or pool address was provided.
Using default chrony configuration.
Attempting to sync time with chronyc.
Time synchronization was successful.
Configuring directory server (dirsrv). Estimated time: 30 seconds
  [1/41]: creating directory server instance
  [2/41]: tune ldbm plugin
  [3/41]: adding default schema
  [4/41]: enabling memberof plugin
  [5/41]: enabling winsync plugin
  [6/41]: configure password logging
  [7/41]: configuring replication version plugin
  [8/41]: enabling IPA enrollment plugin
  [9/41]: configuring uniqueness plugin
  [10/41]: configuring uuid plugin
  [11/41]: configuring modrdn plugin
  [12/41]: configuring DNS plugin
  [13/41]: enabling entryUSN plugin
  [14/41]: configuring lockout plugin
  [15/41]: configuring topology plugin
  [16/41]: creating indices
  [17/41]: enabling referential integrity plugin
  [18/41]: configuring certmap.conf
  [19/41]: configure new location for managed entries
  [20/41]: configure dirsrv ccache and keytab
  [21/41]: enabling SASL mapping fallback
  [22/41]: restarting directory server
  [23/41]: adding sasl mappings to the directory
  [24/41]: adding default layout
  [25/41]: adding delegation layout
  [26/41]: creating container for managed entries
  [27/41]: configuring user private groups
  [28/41]: configuring netgroups from hostgroups
  [29/41]: creating default Sudo bind user
  [30/41]: creating default Auto Member layout
  [31/41]: adding range check plugin
  [32/41]: creating default HBAC rule allow_all
  [33/41]: adding entries for topology management
  [34/41]: initializing group membership
  [35/41]: adding master entry
  [36/41]: initializing domain level
  [37/41]: configuring Posix uid/gid generation
  [38/41]: adding replication acis
  [39/41]: activating sidgen plugin
  [40/41]: activating extdom plugin
  [41/41]: configuring directory to start on boot
Done configuring directory server (dirsrv).
Configuring Kerberos KDC (krb5kdc)
  [1/10]: adding kerberos container to the directory
  [2/10]: configuring KDC
  [3/10]: initialize kerberos container
  [4/10]: adding default ACIs
  [5/10]: creating a keytab for the directory
  [6/10]: creating a keytab for the machine
  [7/10]: adding the password extension to the directory
  [8/10]: creating anonymous principal
  [9/10]: starting the KDC
  [10/10]: configuring KDC to start on boot
Done configuring Kerberos KDC (krb5kdc).
Configuring kadmin
  [1/2]: starting kadmin
  [2/2]: configuring kadmin to start on boot
Done configuring kadmin.
Configuring ipa-custodia
  [1/5]: Making sure custodia container exists
  [2/5]: Generating ipa-custodia config file
  [3/5]: Generating ipa-custodia keys
  [4/5]: starting ipa-custodia
  [5/5]: configuring ipa-custodia to start on boot
Done configuring ipa-custodia.
Configuring certificate server (pki-tomcatd). Estimated time: 3 minutes
  [1/28]: configuring certificate server instance
  [2/28]: stopping certificate server instance to update CS.cfg
  [3/28]: backing up CS.cfg
  [4/28]: Add ipa-pki-wait-running
  [5/28]: secure AJP connector
  [6/28]: reindex attributes
  [7/28]: exporting Dogtag certificate store pin
  [8/28]: disabling nonces
  [9/28]: set up CRL publishing
  [10/28]: enable PKIX certificate path discovery and validation
  [11/28]: authorizing RA to modify profiles
  [12/28]: authorizing RA to manage lightweight CAs
  [13/28]: Ensure lightweight CAs container exists
  [14/28]: starting certificate server instance
  [15/28]: configure certmonger for renewals
  [16/28]: requesting RA certificate from CA
  [17/28]: publishing the CA certificate
  [18/28]: adding RA agent as a trusted user
  [19/28]: configure certificate renewals
  [20/28]: Configure HTTP to proxy connections
  [21/28]: updating IPA configuration
  [22/28]: enabling CA instance
  [23/28]: importing IPA certificate profiles
  [24/28]: migrating certificate profiles to LDAP
  [25/28]: adding default CA ACL
  [26/28]: adding 'ipa' CA entry
  [27/28]: configuring certmonger renewal for lightweight CAs
  [28/28]: deploying ACME service
Done configuring certificate server (pki-tomcatd).
Configuring directory server (dirsrv)
  [1/3]: configuring TLS for DS instance
  [2/3]: adding CA certificate entry
  [3/3]: restarting directory server
Done configuring directory server (dirsrv).
Configuring ipa-otpd
  [1/2]: starting ipa-otpd
  [2/2]: configuring ipa-otpd to start on boot
Done configuring ipa-otpd.
Configuring the web interface (httpd)
  [1/21]: stopping httpd
  [2/21]: backing up ssl.conf
  [3/21]: disabling nss.conf
  [4/21]: configuring mod_ssl certificate paths
  [5/21]: setting mod_ssl protocol list
  [6/21]: configuring mod_ssl log directory
  [7/21]: disabling mod_ssl OCSP
  [8/21]: adding URL rewriting rules
  [9/21]: configuring httpd
Nothing to do for configure_httpd_wsgi_conf
  [10/21]: setting up httpd keytab
  [11/21]: configuring Gssproxy
  [12/21]: setting up ssl
  [13/21]: configure certmonger for renewals
  [14/21]: publish CA cert
  [15/21]: clean up any existing httpd ccaches
  [16/21]: configuring SELinux for httpd
  [17/21]: create KDC proxy config
  [18/21]: enable KDC proxy
  [19/21]: starting httpd
  [20/21]: configuring httpd to start on boot
  [21/21]: enabling oddjobd
Done configuring the web interface (httpd).
Configuring Kerberos KDC (krb5kdc)
  [1/1]: installing X509 Certificate for PKINIT
Done configuring Kerberos KDC (krb5kdc).
Applying LDAP updates
Upgrading IPA:. Estimated time: 1 minute 30 seconds
  [1/10]: stopping directory server
  [2/10]: saving configuration
  [3/10]: disabling listeners
  [4/10]: enabling DS global lock
  [5/10]: disabling Schema Compat
  [6/10]: starting directory server
  [7/10]: upgrading server
  [8/10]: stopping directory server
  [9/10]: restoring configuration
  [10/10]: starting directory server
Done.
Restarting the KDC
Configuring SID generation
  [1/8]: creating samba domain object
  [2/8]: adding admin(group) SIDs
  [3/8]: adding RID bases
  [4/8]: updating Kerberos config
'dns_lookup_kdc' already set to 'true', nothing to do.
  [5/8]: activating sidgen task
  [6/8]: restarting Directory Server to take MS PAC and LDAP plugins changes into account
  [7/8]: adding fallback group
  [8/8]: adding SIDs to existing users and groups
This step may take considerable amount of time, please wait..
Done.
Configuring client side components
This program will set up IPA client.
Version 4.9.6

Using existing certificate '/etc/ipa/ca.crt'.
Client hostname: ipa.otus.lan
Realm: OTUS.LAN
DNS Domain: otus.lan
IPA Server: ipa.otus.lan
BaseDN: dc=otus,dc=lan

Configured sudoers in /etc/authselect/user-nsswitch.conf
Configured /etc/sssd/sssd.conf
Systemwide CA database updated.
Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub
Adding SSH public key from /etc/ssh/ssh_host_ed25519_key.pub
Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub
Could not update DNS SSHFP records.
SSSD enabled
Configured /etc/openldap/ldap.conf
Configured /etc/ssh/ssh_config
Configured /etc/ssh/sshd_config
Configuring otus.lan as NIS domain.
Client configuration complete.
The ipa-client-install command was successful

Please add records in this file to your DNS system: /tmp/ipa.system.records.on3kw6ee.db
==============================================================================
Setup complete

Next steps:
        1. You must make sure these network ports are open:
                TCP Ports:
                  * 80, 443: HTTP/HTTPS
                  * 389, 636: LDAP/LDAPS
                  * 88, 464: kerberos
                UDP Ports:
                  * 88, 464: kerberos
                  * 123: ntp

        2. You can now obtain a kerberos ticket using the command: 'kinit admin'
           This ticket will allow you to use the IPA tools (e.g., ipa user-add)
           and the web user interface.

Be sure to back up the CA certificates stored in /root/cacert.p12
These files are required to create replicas. The password for these
files is the Directory Manager password
The ipa-server-install command was successful
```

Проверим, что сервер Kerberos может выдать нам тикет

```
[root@ipa ~]# kinit admin
Password for admin@OTUS.LAN:
[root@ipa ~]# klist
Ticket cache: KCM:0
Default principal: admin@OTUS.LAN

Valid starting     Expires            Service principal
02/22/25 14:32:11  02/23/25 13:49:45  krbtgt/OTUS.LAN@OTUS.LAN
```


### Проверка подклбчения хоста

Заходим на хост 

```
┬─[anasha@otus:~/less38]─[19:55:11]
╰─o$ vagrant ssh client2.otus.lan
```
Проверяем получение тикета от Kerberos сервера

```
[root@client2 ~]# kinit admin
Password for admin@OTUS.LAN:
[root@client2 ~]# klist
Ticket cache: KCM:0
Default principal: admin@OTUS.LAN

Valid starting       Expires              Service principal
02/22/2025 19:55:46  02/23/2025 19:48:39  krbtgt/OTUS.LAN@OTUS.LAN
```

заходим на сервер и создаём пользователя otus-user c паролем Otus2025

```
[root@ipa ~]# ipa user-add otus-user --first=Otus --last=User --password
Password:
Введите Password ещё раз для проверки:
----------------------
Added user "otus-user"
----------------------
  User login: otus-user
  First name: Otus
  Last name: User
  Full name: Otus User
  Display name: Otus User
  Initials: OU
  Home directory: /home/otus-user
  GECOS: Otus User
  Login shell: /bin/sh
  Principal name: otus-user@OTUS.LAN
  Principal alias: otus-user@OTUS.LAN
  User password expiration: 20250222170020Z
  Email address: otus-user@otus.lan
  UID: 116400003
  GID: 116400003
  Password: True
  Member of groups: ipausers
  Kerberos keys available: True
```
заходим на client1 и пробуем подключиться к серверу

```
┬─[anasha@otus:~/less38]─[20:03:05]
╰─o$ vagrant ssh client1.otus.lan
Last login: Sat Feb 22 19:54:26 2025 from 192.168.57.1
[vagrant@client1 ~]$ sudo -i
[root@client1 ~]# kinit otus-user
Password for otus-user@OTUS.LAN:
Password expired.  You must change it now.
Enter new password:
Enter it again:
[root@client1 ~]#
```


































![pict1](pict/1.png)

VLAN1 настроен

#### Настройка VLAN2

Подключаемся к testClient2 и проверяем интерфейсы и ping

![pict2](pict/2.png)

VLAN2 настроен

#### Настройка LACP 

Подключаемся к хосту inetRouter (192.168.255.1) и запускаем ping до centralRouter (192.168.255.2)

```text
[vagrant@inetRouter ~]$ ping 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=0.610 ms
```

Затем в другом окне терминала на хосте inetRouter отключаем интерфейс eth1

![pict4](pict/4.png)

Ждем 10 секунд и включаем интерфейс eth1 обратно

![pict5](pict/5.png)

Возвращаемся, на первый терминал и убеждаемся, что пинг всё это время проходил без прерываний.

![pict3](pict/3.png)

Задание на этом выполнено.

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson37)

