# Administrator Linux. Professional

## Урок 2. Домашнее задание

Vagrant-стенд для обновления ядра и создания образа системы

### Описание домашнего задания

1. Запустить ВМ с помощью Vagrant.
2. Обновить ядро ОС из репозитория ELRepo.
3. Оформить отчет в README-файле в GitHub-репозитории.

### Выполнение:

Создаем Vagrantfile

   `$ vagrant init`

и редактируем его как описано в методичке.

```ruby
MACHINES = {
  :"kernel-update" => {
              :box_name => "generic/centos8s",
              :box_version => "4.3.4",
              :cpus => 2,
              :memory => 1024,
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
    end
  end
end
```

С репозитория скачиваем образ ВМ CentOS 8

   `$ wget <https://app.vagrantup.com/generic/boxes/centos8s/versions/4.3.4/providers/virtualbox/amd64/vagrant.box>`

Добавлеям в vagrant

`$ vagrant box add geheric/centos8s vagrant.box`

Запускаем ВМ

`$ vagrant up`

После запуска заходим в ВМ

`$ vagrant ssh`

Проверяем версию ядра

` uname -r`

```text
6.10.7-1.el8.elrepo.x86_64
```
Далее выполняем обновление ядра по методичке, по окончанию перезагружаемся и проверяем версию ядра

`$ uname -r`

```text
6.10.9-1.el8.elrepo.x86_64
```

Ядро обновлено
