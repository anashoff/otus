Занятие 23. Настраиваем центральный сервер для сбора логов

Описание домашнего задания:

1. В вагранте поднимаем 2 машины web и log
2. На web поднимаем nginx
3. На log настраиваем центральный лог сервер на rsyslog;
4. Настроить аудит изменений конфигов nginx
5. Создать третью виртуальную машину, настроить rsyslog на отправку всех логов на центральный сервер логов.  

Все логи с nginx должны уходить на удаленный сервер (локально только критичные).

Логи аудита должны также уходить на удаленную систему.




Выполнение:

Создаем Vagrantfile

   vagrant init

и редактируем его как описано в методичке

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


С репозитория был скачан образ ВМ CentOS 8

   wget https://app.vagrantup.com/generic/boxes/centos8s/versions/4.3.4/providers/virtualbox/amd64/vagrant.box

Добавлен в vagrant 

   vagrant box add geheric/centos8s vagrant.box

Запускаем ВМ

   vagrant up

После запуска заходим в ВМ

   vagrant ssh

Проверяем версию ядра

   uname -r

6.10.7-1.el8.elrepo.x86_64

Далее выполняем обновление ядра по методичке, по окончанию перезагружаемся и проверяем версию ядра

  $ uname -r

6.10.9-1.el8.elrepo.x86_64

Ядро обновлено





Этот Vagrantfile был получен в результате выполнения ДЗ №1 по курсу Administrator Linux. Professional
На хост машину Debian 12.6 били установлены Visual Studio Code, VirtualBox, vagrant, ansible, git и несколько рабочих утилит.
В связи с санкциями со стороны разработчика vagrant он был установлен с зеркала yandexcloud.net
Остальные программы и утилиты были установлены с официальных репозиториев разработчиков
После установки была настроена и развернута виртукальная машина ubuntu 22.04 с параметрами, указанными в методическом пособии. 
Был настроен git.
На github был выложен Vagrantfile и данный файл README.md
Описание домашнего задания
1) Запустить ВМ с помощью Vagrant.
2) Обновить ядро ОС из репозитория ELRepo.
3) Оформить отчет в README-файле в GitHub-репозитории.
