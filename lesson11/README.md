# Administrator Linux. Professional

## Урок 11. Домашнее задание

Работа с загрузчиком

### Описание домашнего задания

- Включить отображение меню Grub.
- Попасть в систему без пароля несколькими способами.
- Установить систему с LVM, после чего переименовать VG.


### Выполнение

#### Установка и настройка среды выполнения

Подготовим [Vagrant](https://github.com/anashoff/otus/blob/master/lesson11/Vagrantfile)

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "dkd/ubuntu-1804-lvm"

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 1
  end

  ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip

  config.vm.define "bootdemo" do |bootdemo|
    bootdemo.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    bootdemo.vm.hostname = "bootdemo"
    bootdemo.vm.provision 'shell', inline: 'mkdir -p /root/.ssh'
    bootdemo.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /root/.ssh/authorized_keys"
    bootdemo.vm.provision 'shell', inline: "echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys", privileged: false

  end

end
```

Создаем ВМ

```anasha@otus:~/less11$ vagrant up```

### Включить отображение меню Grub.

Заходим на ВМ, выполняем

```vagrant@bootdemo:~$ sudo nano /etc/default/grub```

И редактируем 

![pict1](pict/1.png)

Сохраняем файл, выходим из редактора и обновляем конфтгурацию загрузчика

![pict2](pict/2.png)

Перезагружаем ВМ.
В окне VirtualBox видим меню загрузчика

![pict3](pict/3.png)

### Попасть в систему без пароля несколькими способами

1 способ. Нажимаем 'E' и в окне в конец строки, начинаюшейся с linux дописываем init=/bin/bash. 

![pict4](pict/4.png)

Нажимаем CTRL-X и попадаем в систему.

Для изменения переводим файловую систему в режим r/w и меняем пароль командой passwd

![pict5](pict/5.png)

2 способ. 

При загрузке машины выбираем меню Advanced options for Ubuntu. Попадаем в Recovery menu.

Выбираем сначала network для монтирования файловой системы в режиме r/w, затем root.

Попадаем в консоль.

![pict7](pict/7.png)

### Установить систему с LVM, после чего переименовать VG.

После загрузкм ВМ входим в консоль, смотрим название Volume Group - vg0

![pict91](pict/91.png)

Редактируем /boot/grub/grub.cfg - меняем встречающиеся vg0-root на vg--otus-root

![pict8](pict/8.png)

Потом перезагружаемся и проверяем новое название

![pict92](pict/92.png)

Задание выполнено

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson11)
