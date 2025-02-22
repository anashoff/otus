# Administrator Linux. Professional

## Урок 44. Домашнее задание

Репликация MySQL

### Описание домашнего задания

В материалах приложены ссылки на Vagrantfile для репликации и дамп базы bet.dmp

Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:

```text
| bookmaker          |
| competition        |
| market             |
| odds               |
| outcome            |
```

Настроить GTID репликацию

### Подготовка среды выполнения

Для выполнения задания развернём 2 виртуальныe машины.

Используем [Vagrantfile](https://github.com/anashoff/otus/blob/master/lesson44/Vagrantfile)

```ruby
Vagrant.configure(2) do |config|

    N = 2
    (1..N).each do |i|
      config.vm.define "mysql#{i}" do |node|
        node.vm.box = "bento/ubuntu-22.04"
        node.vm.synced_folder ".", "/vagrant", disabled: true
        node.vm.hostname = "mysql#{i}"
        node.vm.network "private_network", ip:"10.0.26.10#{i}"
        node.vm.provider "virtualbox" do |vb|
          vb.memory = "1024"
          vb.name = "mysql#{i}"
          vb.cpus = 2
        end
      end
    end
 
end
```

#### Подготовка плейбука ansible

Для развертывания стенда используем [плейбук ansible](https://github.com/anashoff/otus/blob/master/lesson44/provision/playbooks/environment.yml)

Разворачиваем среду выполнения

```$ vagrant up```

```$ cd provision```

```$ ansible-playbook playbooks/environment.yml```


#### Настраиваем хост mysql1


```$ vagrant ssh mysql1```

Подготовим файлы конфигурации для mysql

### 01-master.cnt

```ini
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog_format = row
gtid-mode=ON
enforce-gtid-consistency
log-replica-updates
```

### 05-binlog.cnf

```ini
[mysqld]
log-bin = mysql-bin
expire-logs-days = 7
max-binlog-size = 16M
binlog-format = "MIXED"
# GTID replication config
log-slave-updates = On
gtid-mode = On
enforce-gtid-consistency = On
```

Кладём их в ***/etc/mysql/conf.d/***

Перезапускаем mysql 

```systemctl restart mysql```


Заходим в mysql.

Проверяем server-id и что GTID включен

![pict16](pict/16.png)

Создаём базу данных ```bet_odds```

![pict10](pict/10.png)

Загружаем базу из дампа

![pict11](pict/11.png)

![pict12](pict/12.png)

Создадим пользователя для репликации и даем ему права на репликацию

![pict13](pict/13.png)

![pict14](pict/14.png)

Сделаем дамп базы для первоначального залива ее на slave, игнорирую таблицы по заданию

![pict15](pict/15.png)

Переносим дамп на mysql2

![picta](pict/a.png)


#### Настраиваем хост mysql2


```$ vagrant ssh mysql2```

Подготовим файлы конфигурации для mysql

### 02-slave.cnt

```ini
[mysqld]
server-id = 2
log-bin = mysql-bin
relay-log = relay-log-server
read-only = ON
gtid-mode=ON
enforce-gtid-consistency
log-replica-updates
```

### 05-binlog.cnf

```ini
[mysqld]
log-bin = mysql-bin
expire-logs-days = 7
max-binlog-size = 16M
binlog-format = "MIXED"
# GTID replication config
log-slave-updates = On
gtid-mode = On
enforce-gtid-consistency = On
# Эта часть только для слэйва - исключаем репликацию таблиц
replicate-ignore-table=bet_odds.events_on_demand
replicate-ignore-table=bet_odds.v_same_event
```

Кладём их в ***/etc/mysql/conf.d/***

Перезапускаем mysql 

```systemctl restart mysql```

Заходим в mysql.

Проверяем server-id и что GTID включен

![pict20](pict/20.png)

Создаем базу и заливаем туда дамп с mysql1

![pict21](pict/21.png)

![pict22](pict/22.png)

Проверям, что в базе только нужные таблицы

![pict23](pict/23.png)

Подключаем slave и запускаем репликацию

![pict24](pict/24.png)

Проверяем статус репликации ```mysql> SHOW SLAVE STATUS\G``` и видим ошибку

![pict25](pict/25.png)

для исправления ошибки в интернетах советуют использовать команду

```CHANGE MASTER TO GET_MASTER_PUBLIC_KEY=1;```

останавливаем репликацию, исправляем ошибку и запускаем репликацию

![pict26](pict/26.png)

проверяем 

![pict27_1](pict/27_1.png)

Видим, что репликация заработала, таблицы events_on_demand  и v_same_event игнорируются

![pict28](pict/28.png)

### Проверка репликации

На master добавим в таблицу bookmaker записи

![pict18](pict/18.png)

Проверяем на slave

![pict29-2](pict/29-2.png)

Видим, что таблица реплицировалась.

Посмотрим binlog


![pict31](pict/31.png)

![pict32](pict/32.png)

```text
.............................
```

![pict30](pict/30.png)

Видим команду **INSERT INTO bookmaker (id,bookmaker_name) VALUES(11,'boom-boom-booooooommm-1xbet');**

Задание на этом выполнено.

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson44)
