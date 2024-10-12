# Administrator Linux. Professional

## Урок 10. Домашнее задание

Размещаем свой RPM в своем репозитории

### Описание домашнего задания

- Создать свой RPM пакет (можно взять свое приложение, либо собрать, например,Apache с определенными опциями).
- Создать свой репозиторий и разместить там ранее собранный RPM.

### Выполнение

#### Установка и настройка среды выполнения

Подготовим [Vagrant](https://github.com/anashoff/otus/blob/master/lesson10/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
  config.vm.box = "almalinux/9"
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 2
  end

  ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip

  config.vm.define "rpmtest" do |rpmtest|
    rpmtest.vm.network "public_network", ip: "192.168.1.138"
    rpmtest.vm.hostname = "rpmtest"
    rpmtest.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
    rpmtest.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
    rpmtest.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false
  end
end
```

Создаем ВМ

```ini
┬─[anasha@otus:~/less10]─[15:52:28]─[G:(8e2c3df9)]
╰─>$ vagrant up
```

Выполнение ДЗ будет проходить с помощью Ansible. Создадим необходимые файлы

Файлы

[ansible.cfg](https://github.com/anashoff/otus/blob/master/lesson10/ansible.cfg)

```ini
[defaults]
inventory=hosts.ini
remote_user=vagrant
log_path=logfile
```

[hosts.ini](https://github.com/anashoff/otus/blob/master/lesson10/hosts.ini)

```ini
[all]
rpmtest ansible_port=2222 ansible_host=127.0.0.1 ansible_username=vagrant
```

[/template/repo.j2](https://github.com/anashoff/otus/blob/master/lesson10/templates/repo.j2)

```ini
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1

```

Согласно методическому пособию подготовим два файла плейбуков ansible

Первый плейбук создает rpm пакет и использует его при развертывании nginx

[playbook1.yml](https://github.com/anashoff/otus/blob/master/lesson10/playbook1.yml)

```yaml
---
--
- hosts: rpmtest
  gather_facts: true
  become: yes
  tasks:
    - name: install tools
      package:
        name: wget, rpmdevtools, rpm-build, createrepo, yum-utils, cmake, gcc, git, nano
        state: present
    - name: select derectory
      command: "chdir=/root ls"
    - name: make folder
      file:
        path: /root/rpm/
        state: directory
    - name: get nginx srpm
      command: "yumdownloader --source nginx"
    - name: rpm nginx
      command: "rpm -Uvh nginx*.src.rpm"
    - name: yum-builddep
      command: "yum-builddep -y nginx"
    - name: 
      git: 
        repo: https://github.com/google/ngx_brotli
        clone: true
        recursive: true
        dest: /root/ngx_brotli
        force: true
    - name: mkdir out
      file:
        path: "/root/ngx_brotli/deps/brotli/out/"
        state: directory
    - name: cmake ngx_brotli
      command: "chdir=/root/ngx_brotli/deps/brotli/out cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS=\"-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections\" -DCMAKE_CXX_FLAGS=\"-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections\" -DCMAKE_INSTALL_PREFIX=./installed .."
    - name: cmake brotlienc
      command: "chdir=/root/ngx_brotli/deps/brotli/out cmake --build . --config Release -j 2 --target brotlienc"
    - name: modify SPEC
      lineinfile:
        path: /root/rpmbuild/SPECS/nginx.spec
        line: '    --add-module=/root/ngx_brotli \'
        insertafter: ./configure
        state: present
    - name: build RPM
      command: chdir=/root/rpmbuild/SPECS/ rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
    - name: copy
      copy: 
        src: /root/rpmbuild/RPMS/noarch/
        dest: /root/rpmbuild/RPMS/x86_64
        remote_src: true
    - name: Find all rpm files in folder
      find:
        paths: "/root/rpmbuild/RPMS/x86_64"
        patterns: "*.rpm"
      register: rpm_files
    - name: Setting rpm_list
      set_fact:
         rpm_list: "{{ rpm_files.files | map(attribute='path') | list}}"
    - name: installing the rpm files
      yum:
        name: "{{rpm_list}}"
        disable_gpg_check: true
        state: present
    - name: start nginx
      systemd: 
        name: nginx
        state: started
      tags: last  
```

И второй файл - создадим свой репозиторий и разместим там свой пакет

[playbook2.yml](https://github.com/anashoff/otus/blob/master/lesson10/playbook2.yml)

```yaml
---
---
- hosts: rpmtest
  gather_facts: true
  become: yes
  tasks:
    - name: create repo
      file:
        path: /usr/share/nginx/html/repo
        state: directory
        mode: '0755'
    - name: copy rpms
      copy:
        src: /root/rpmbuild/RPMS/x86_64/
        dest: /usr/share/nginx/html/repo
        remote_src: true
    - name: create repo
      command: createrepo /usr/share/nginx/html/repo/
    - name: modify nginx.conf
      lineinfile:
        path: /etc/nginx/nginx.conf
        line: 'autoindex on;'
        insertafter: server_name
        firstmatch: true
        state: present
    - name: modify nginx.conf
      lineinfile:
        path: /etc/nginx/nginx.conf
        line: 'index index.html index.htm;'
        insertbefore: autoindex
        firstmatch: true
        state: present
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
    - name: create config
      ansible.builtin.template:
        src: templates/repo.j2
        dest: /etc/yum.repos.d/otus.repo
    - name: add rpm
      command: "chdir=/usr/share/nginx/html/repo/ wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm"
    - name: update repo
      command: createrepo /usr/share/nginx/html/repo/
      tags: last
    - name: update yum cache
      command: yum makecache
      tags: last
    - name: installing the rpm files
      yum:
        name: percona-release.noarch
        disable_gpg_check: true
        state: present
      tags: last
```

Запускаем первый плейбук

```text
┬─[anasha@otus:~/less10]─[16:05:13]─[G:(8e2c3df9)]
╰─>$ ansible-playbook playbook1.yaml

PLAY [rpmtest] ****************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************
The authenticity of host '[127.0.0.1]:2222 ([127.0.0.1]:2222)' can't be established.
ED25519 key fingerprint is SHA256:CVLis4If1GQi+aQQ9VXVPB3I6UCHdMXKiq1uKRGWb7I.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
ok: [rpmtest]

TASK [install tools] **********************************************************************************************************************
changed: [rpmtest]

TASK [select derectory] *******************************************************************************************************************
changed: [rpmtest]

TASK [make folder] ************************************************************************************************************************
changed: [rpmtest]

TASK [get nginx srpm] *********************************************************************************************************************
changed: [rpmtest]

TASK [rpm nginx] **************************************************************************************************************************
changed: [rpmtest]

TASK [yum-builddep] ***********************************************************************************************************************
changed: [rpmtest]

TASK [git] ********************************************************************************************************************************
changed: [rpmtest]

TASK [mkdir out] **************************************************************************************************************************
changed: [rpmtest]

TASK [cmake ngx_brotli] *******************************************************************************************************************
changed: [rpmtest]

TASK [cmake brotlienc] ********************************************************************************************************************
changed: [rpmtest]

TASK [modify SPEC] ************************************************************************************************************************
changed: [rpmtest]

TASK [build RPM] **************************************************************************************************************************
changed: [rpmtest]

TASK [copy] *******************************************************************************************************************************
changed: [rpmtest]

TASK [Find all rpm files in folder] *******************************************************************************************************
ok: [rpmtest]

TASK [Setting rpm_list] *******************************************************************************************************************
ok: [rpmtest]

TASK [installing the rpm files] ***********************************************************************************************************
changed: [rpmtest]

TASK [start nginx] ************************************************************************************************************************
changed: [rpmtest]

PLAY RECAP ********************************************************************************************************************************
rpmtest                    : ok=18   changed=15   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

┬─[anasha@otus:~/less10]─[16:09:59]─[G:(8e2c3df9)]
╰─>$ 
```

#### Проверка работы

Заходим на сервер и проверяем

```zsh
┬─[anasha@otus:~]─[16:16:39]─[G:(8e2c3df9)]
╰─>$ ssh vagrant@127.0.0.1 -p 2222
Last login: Sat Oct 12 13:09:58 2024 from 10.0.2.2
[vagrant@rpmtest ~]$ systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2024-10-12 13:09:59 UTC; 7min ago
    Process: 40962 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 40978 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 41027 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 41048 (nginx)
      Tasks: 3 (limit: 11131)
     Memory: 4.9M
        CPU: 48ms
     CGroup: /system.slice/nginx.service
             ├─41048 "nginx: master process /usr/sbin/nginx"
             ├─41049 "nginx: worker process"
             └─41050 "nginx: worker process"
[vagrant@rpmtest ~]$ sudo ls -lah /root/rpmbuild/RPMS/x86_64/
total 2.0M
drwxr-xr-x. 2 root root  4.0K Oct 12 13:09 .
drwxr-xr-x. 4 root root    34 Oct 12 13:09 ..
-rw-r--r--. 1 root root   36K Oct 12 13:09 nginx-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root  6.8K Oct 12 13:09 nginx-all-modules-1.20.1-16.el9.1.noarch.rpm
-rw-r--r--. 1 root root 1008K Oct 12 13:09 nginx-core-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root  7.9K Oct 12 13:09 nginx-filesystem-1.20.1-16.el9.1.noarch.rpm
-rw-r--r--. 1 root root  742K Oct 12 13:09 nginx-mod-devel-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root   19K Oct 12 13:09 nginx-mod-http-image-filter-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root   30K Oct 12 13:09 nginx-mod-http-perl-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root   18K Oct 12 13:09 nginx-mod-http-xslt-filter-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root   53K Oct 12 13:09 nginx-mod-mail-1.20.1-16.el9.1.x86_64.rpm
-rw-r--r--. 1 root root   79K Oct 12 13:09 nginx-mod-stream-1.20.1-16.el9.1.x86_64.rpm
[vagrant@rpmtest ~]$ 
```

Пакеты созданы nginx работает

Запускаем второй плейбук

```zsh
┬─[anasha@otus:~/less10]─[16:19:42]─[G:(8e2c3df9)]
╰─>$ ansible-playbook playbook2.yaml

PLAY [rpmtest] ****************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************
ok: [rpmtest]

TASK [create repo] ************************************************************************************************************************
changed: [rpmtest]

TASK [copy rpms] **************************************************************************************************************************
changed: [rpmtest]

TASK [create repo] ************************************************************************************************************************
changed: [rpmtest]

TASK [modify nginx.conf] ******************************************************************************************************************
changed: [rpmtest]

TASK [modify nginx.conf] ******************************************************************************************************************
changed: [rpmtest]

TASK [restart nginx] **********************************************************************************************************************
changed: [rpmtest]

TASK [create config] **********************************************************************************************************************
changed: [rpmtest]

TASK [add rpm] ****************************************************************************************************************************
changed: [rpmtest]

TASK [update repo] ************************************************************************************************************************
changed: [rpmtest]

TASK [update yum cache] *******************************************************************************************************************
changed: [rpmtest]

TASK [installing the rpm files] ***********************************************************************************************************
changed: [rpmtest]

PLAY RECAP ********************************************************************************************************************************
rpmtest                    : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

┬─[anasha@otus:~/less10]─[16:20:49]─[G:(8e2c3df9)]
╰─>$ 
```

Проверяем выполнение

```zsh
[vagrant@rpmtest ~]$ curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          12-Oct-2024 13:20                   -
<a href="nginx-1.20.1-16.el9.1.x86_64.rpm">nginx-1.20.1-16.el9.1.x86_64.rpm</a>                   12-Oct-2024 13:20               35859
<a href="nginx-all-modules-1.20.1-16.el9.1.noarch.rpm">nginx-all-modules-1.20.1-16.el9.1.noarch.rpm</a>       12-Oct-2024 13:20                6925
<a href="nginx-core-1.20.1-16.el9.1.x86_64.rpm">nginx-core-1.20.1-16.el9.1.x86_64.rpm</a>              12-Oct-2024 13:20             1031433
<a href="nginx-filesystem-1.20.1-16.el9.1.noarch.rpm">nginx-filesystem-1.20.1-16.el9.1.noarch.rpm</a>        12-Oct-2024 13:20                8032
<a href="nginx-mod-devel-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-devel-1.20.1-16.el9.1.x86_64.rpm</a>         12-Oct-2024 13:20              759263
<a href="nginx-mod-http-image-filter-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-http-image-filter-1.20.1-16.el9.1.x86..&gt;</a> 12-Oct-2024 13:20               18964
<a href="nginx-mod-http-perl-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-http-perl-1.20.1-16.el9.1.x86_64.rpm</a>     12-Oct-2024 13:20               30468
<a href="nginx-mod-http-xslt-filter-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-http-xslt-filter-1.20.1-16.el9.1.x86_..&gt;</a> 12-Oct-2024 13:20               17752
<a href="nginx-mod-mail-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-mail-1.20.1-16.el9.1.x86_64.rpm</a>          12-Oct-2024 13:20               53410
<a href="nginx-mod-stream-1.20.1-16.el9.1.x86_64.rpm">nginx-mod-stream-1.20.1-16.el9.1.x86_64.rpm</a>        12-Oct-2024 13:20               80015
<a href="percona-release-latest.noarch.rpm">percona-release-latest.noarch.rpm</a>                  04-Jul-2024 09:46               27900
</pre><hr></body>
</html>
[vagrant@rpmtest ~]$ 
```

Видим локальный репозиторий,  в том числе с пакетом percona-release-latest.noarch.rpm

Задание выполнено

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson10)
