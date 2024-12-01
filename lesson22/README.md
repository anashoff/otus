# Administrator Linux. Professional

## Урок 22. Домашнее задание

Vagrant-стенд c PAM

### Описание домашнего задания

 Запретить всем пользователям кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников

### Подготовка среды выполнения

Подготовим [Vagrant](https://github.com/anashoff/otus/blob/master/lesson22/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

MACHINES = {
  :"pam" => {
              :box_name => "ubuntu/jammy64",
              :cpus => 2,
              :memory => 1024,
              :ip => "192.168.57.10",
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.network "private_network", ip: boxconfig[:ip]
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s

      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
          sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*.conf
          systemctl restart sshd.service
  	  SHELL
    end
  end
end
```

#### Подготовка плейбука ansible

Подготовим плейбук ansible для выполнения работы

Файл [ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson22/ansible.cfg)

```ini
[defaults]
inventory = hosts.ini
remote_user = vagrant
host_key_checking = false
```

Файл [hosts.ini](https://github.com/anashoff/otus/blob/master/lesson22/hosts.ini)

```ini
[all]
pam ansible_port=22 ansible_host=192.168.57.10 ansible_username=vagrant ansible_password=vagrant
```

Файл [script.j2](https://github.com/anashoff/otus/blob/master/lesson22/script.j2)

```bash
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
```

Файл [playbook.yaml](https://github.com/anashoff/otus/blob/master/lesson22/playbook.yaml)

```yaml
---
- hosts: pam
  gather_facts: true
  become: yes
  tasks:
  - name: Create group admin
    group: 
      name: admin
      state: present
  - name: Create user otusadm and add it to group admin
    user: 
      name: otusadm
      create_home: yes
      shell: /bin/bash
      groups: admin
      append: yes
      password: "$6$rounds=656000$mysecretsalt$04wVf1FbaGRszgZJRYTZw/STBfYl3vioDMj9iN8W6vFPH7V1vNqb3BQkZoS.diohjkix6EKU5AR5wYXt5oVnz1"
  - name: Create user otus
    user: 
      name: otus
      create_home: yes
      shell: /bin/bash
      password: "$6$rounds=656000$mysecretsalt$04wVf1FbaGRszgZJRYTZw/STBfYl3vioDMj9iN8W6vFPH7V1vNqb3BQkZoS.diohjkix6EKU5AR5wYXt5oVnz1"
  - name: Add user root to group admin
    user:
      name: root
      groups: admin
      append: yes
  - name: Add user vagrant to group admin
    user:
      name: vagrant
      groups: admin
      append: yes 
  - name: write script
    ansible.builtin.template:
       src: script.j2
       dest: /usr/local/bin/login.sh
       mode: 755
  - name: Modify config file
    lineinfile:
      line: 'auth required pam_exec.so debug /usr/local/bin/login.sh'
      path: /etc/pam.d/sshd
```

Плейбук выполняет следующие команды

- Создает группу admin
- Создает пользователей otus и otusadm. Пользователь otusadm входит в группу admin. Пароль для пользователей ***Otus2022!***. Для использования в плейбуке создадим парольною строку при помощи команды

```ansible all -i localhost, -m debug -a "msg={{ 'Otus2022!' | password_hash('sha512', 'mysecretsalt') }}"```

- Создает скрипт /usr/local/bin/login.sh, назначает права на выполнение
- Добавляет в конфигурационный файл /ets/pam.d/sshd строку вызова скрипта при аутентификации в ssh

#### Выполнение работы

Запускаем виртуальную машину

```zsh
┬─[anasha@otus:~/less22]─[12:05:49]
╰─o$ vagrant up
Bringing machine 'pam' up with 'virtualbox' provider...
==> pam: Importing base box 'ubuntu/jammy64'...
==> pam: Matching MAC address for NAT networking...
==> pam: Setting the name of the VM: less22_pam_1733044629580_30889
==> pam: Clearing any previously set network interfaces...
==> pam: Preparing network interfaces based on configuration...
    pam: Adapter 1: nat
    pam: Adapter 2: hostonly
==> pam: Forwarding ports...
    pam: 22 (guest) => 2222 (host) (adapter 1)
==> pam: Running 'pre-boot' VM customizations...
==> pam: Booting VM...
==> pam: Waiting for machine to boot. This may take a few minutes...
    pam: SSH address: 127.0.0.1:2222
    pam: SSH username: vagrant
    pam: SSH auth method: private key
    pam: 
    pam: Vagrant insecure key detected. Vagrant will automatically replace
    pam: this with a newly generated keypair for better security.
    pam: 
    pam: Inserting generated public key within guest...
    pam: Removing insecure key from the guest if it's present...
    pam: Key inserted! Disconnecting and reconnecting using new SSH key...
==> pam: Machine booted and ready!
==> pam: Checking for guest additions in VM...
    pam: The guest additions on this VM do not match the installed version of
    pam: VirtualBox! In most cases this is fine, but in rare cases it can
    pam: prevent things such as shared folders from working properly. If you see
    pam: shared folder errors, please make sure the guest additions within the
    pam: virtual machine match the version of VirtualBox you have installed on
    pam: your host and reload your VM.
    pam: 
    pam: Guest Additions Version: 6.0.0 r127566
    pam: VirtualBox Version: 7.0
==> pam: Setting hostname...
==> pam: Configuring and enabling network interfaces...
==> pam: Running provisioner: shell...
    pam: Running: inline script
```

Затем плейбук

```
┬─[anasha@otus:~/less22]─[12:17:41]
╰─o$ ansible-playbook playbook.yaml

PLAY [pam] ******************************************************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [pam]

TASK [Create group admin] **************************************************************************************************************
ok: [pam]

TASK [Create user otusadm and add it to group admin] **************************************************************************************************************
changed: [pam]

TASK [Create user otus] **************************************************************************************************************
changed: [pam]

TASK [Add user root to group admin] **************************************************************************************************************
changed: [pam]

TASK [Add user vagrant to group admin] **************************************************************************************************************
changed: [pam]

TASK [write script] **************************************************************************************************************
changed: [pam]

TASK [Modify config file] **************************************************************************************************************
changed: [pam]

PLAY RECAP **************************************************************************************************************
pam                        : ok=8    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Проверяем работу. 

Сегодня воскресение, так что пользователь otusadm должен зайти в сеанс, а пользователь otus - нет.

```
┬─[anasha@otus:~/less22]─[12:18:06]
╰─o$ ssh otus@192.168.57.10
otus@192.168.57.10's password: 
Permission denied, please try again.
```

Пользователь otus не может войти

```
┬─[anasha@otus:~/less22]─[12:20:38]
╰─o$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password: 
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-119-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sun Dec  1 09:20:49 UTC 2024

  System load:  0.02              Processes:               106
  Usage of /:   3.7% of 38.70GB   Users logged in:         0
  Memory usage: 22%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


The list of available updates is more than a week old.
To check for new updates run: sudo apt update
New release '24.04.1 LTS' available.
Run 'do-release-upgrade' to upgrade to it.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

otusadm@pam:~$ 
```
Пользовател otusadm зашел. Посмотрим лог авторизации ssh

```zsh
otusadm@pam:~$ sudo cat /var/log/auth.log
[sudo] password for otusadm: 

........

Dec  1 09:20:17 ubuntu-jammy sshd[2377]: pam_exec(sshd:auth): Calling /usr/local/bin/login.sh ...
Dec  1 09:20:17 ubuntu-jammy sshd[2375]: pam_exec(sshd:auth): /usr/local/bin/login.sh failed: exit code 1
Dec  1 09:20:19 ubuntu-jammy sshd[2375]: Failed password for otus from 192.168.57.1 port 58176 ssh2
Dec  1 09:20:38 ubuntu-jammy sshd[2375]: Connection closed by authenticating user otus 192.168.57.1 port 58176 [preauth]
Dec  1 09:20:49 ubuntu-jammy sshd[2384]: pam_exec(sshd:auth): Calling /usr/local/bin/login.sh ...
Dec  1 09:20:49 ubuntu-jammy sshd[2382]: Accepted password for otusadm from 192.168.57.1 port 52448 ssh2
Dec  1 09:20:49 ubuntu-jammy sshd[2382]: pam_unix(sshd:session): session opened for user otusadm(uid=1002) by (uid=0)
Dec  1 09:20:49 ubuntu-jammy systemd-logind[692]: New session 6 of user otusadm.
Dec  1 09:20:49 ubuntu-jammy systemd: pam_unix(systemd-user:session): session opened for user otusadm(uid=1002) by (uid=0)

.........

otusadm@pam:~$ 
```

По логам видно, что скрипт не разрешает вход пользователю otus, так как он не входит в группу admin, и пускает пользователя otusadm.

Задание на этом выполнено.

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson22)
