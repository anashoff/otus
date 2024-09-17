# Administrator Linux. Professional

## Урок 3. Домашнее задание

Первые шаги с Ansible

### Описание домашнего задания

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере, используя Ansible необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt
- конфигурационный файлы должны быть взяты из шаблона jinja2 с переменными
- после установки nginx должен быть в режиме enabled в systemd
- должен быть использован notify для старта nginx после установки
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible

### Выполнение

Установим Ansible и проверим версию

`$ ansible --version`

```text
ansible [core 2.14.16]
  config file = None
  configured module search path = ['/home/anasha/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /home/anasha/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.11.2 (main, Aug 26 2024, 07:20:54) [GCC 12.2.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
```

Создаем Vagrantfile

   `$ vagrant init`

и редактируем его согласно методическому пособию. И чуть поравим под локальные условия

```ruby
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :nginx => {
        :box_name => "generic/ubuntu2204",
        :vm_name => "nginx",
        :net => [
           ["192.168.11.150", 2 , "255.255.255.0", "mynet"],
        
        ]
  }
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

    config.vm.define boxname do |box|

      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]

      box.vm.provider "virtualbox" do |v|
        v.memory = 768
        v.cpus = 1
       end

      boxconfig[:net].each do |ipconf|
        box.vm.network("public_network", ip: ipconf[0], adapter: ipconf[1], netmask: ipconf[2])
      end

      if boxconfig.key?(:public)
        box.vm.network "public_network", boxconfig[:public]
      end

      box.vm.provision "shell", inline: <<-SHELL
        mkdir -p ~root/.ssh
        cp ~vagrant/.ssh/auth* ~root/.ssh
        sudo sed -i 's/\#PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        systemctl restart sshd
      SHELL
    end
  end
end
```

Запускаем ВМ

`$ vagrant up`

После запуска проверяем доступ по ssh

`$ ssh vagrant@127.0.0.1 -p 2222`

```text
vagrant@nginx:~$ 
```

Доступ есть

### Переходим к работе с Ansible

Создаем файл ***hosts***

```ini
[web]
  nginx ansible_host=127.0.0.1 ansible_port=2222
  ansible_private_key_file=/home/anasha/less3/.vagrant/machines/nginx/virtualbox/private_key
```

Создаем файл ***ansible.cfg***

```ini
[defaults]
inventory = staging/hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

Проверяем доступность хоста

```text
$ ansible nginx -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

#### Начинаем писать playbook

Создаем файл ***nginx.yaml***

```yaml
 name: NGINX | Imstall and configure NGINX
  hosts: nginx
  become: true

  tasks:
    - name: update
      apt: 
        update_cache=yes

    - name: NGINX | Install NGINX
      apt: 
        name: nginx
        state: latest
```

Проверяем

`$ ansible-playbook nginx.yml`

```text

LAY [NGINX | Imstall and configure NGINX] **************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [nginx]

TASK [update] **************************************************************************************************************
changed: [nginx]

TASK [NGINX | Install NGINX] **************************************************************************************************************
ok: [nginx]

PLAY RECAP **************************************************************************************************************
nginx                      : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

#### Добавлям шаблон для конфига NGINX и модуль, который будет копировать этот шаблон на хост

```yaml
    - name: NGINX | Create NGINX config file from template
      template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
      tags: 
        - nginx-configuration
```

#### Пропишем переменную, чтобы NGINX слушал на 8080 порту

```yaml
  vars:
    nginx_listen_port:8080
```

Шаблон добавляем в templates/nginx.conf.j2

```yaml
# {{ ansible_managed }}
events {
    worker_connections 1024;
}

http {
    server {
        listen       {{ nginx_listen_port }} default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
```

Добавляем handler

```yaml
handlers:
- name: restart nginx
  systemd:
    name: nginx
    state: restarted
    enabled: yes
- name: reload nginx
  systemd:
   name: nginx
   state: reloaded
```

и notify

### Получаем результирующий файл playbook ***nignx.yml***

```yaml
- name: NGINX | Imstall and configure NGINX
  hosts: nginx
  become: true
  vars:
    nginx_listen_port: 8080

  tasks:
    - name: update
      apt: 
        update_cache=yes
      tags:
        -update apt

    - name: NGINX | Install NGINX
      apt: 
        name: nginx
        state: latest
      notify:
        - restart nginx
      tags: 
        -nginx-package

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify:
        - reload nginx
      tags: 
        - nginx-configuration

  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
```

После выполнения заходим на http://192.168.11.150:8080

```html
$ curl http://192.168.1.120:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

На github выложен [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson3/Vagrantfile), 
файлы плейбука Ansible


использованный в этом задании.
