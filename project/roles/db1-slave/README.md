# Administrator Linux. Professional

## Сервер базы данных-1 в режиме реплики

### Требования, предъявляемые к серверу

Виртуальная машина с установленным сервером баз данных, обеспечивает функционал:

- СУБД для работы веб-сервера
- Обеспечение резервирования базы данных 
- Передача метрик и логов на центральный сервер сбора логов

### Описание сервера

В качестве сервера используется виртуальная машина с установленной Ubuntu 22.04.

Сервер разворачивается с помощью **vagrant и ansible**.

В качестве СУБД используется **PostgreSQL 14**

Для резервирования базы данных настроена физическая репликация базы со второго сервера БД

Для сбора и передачи метрик используется **node exporter**, для сбора и передачи логов - **grafana alloy**

Сервер БД запускается в режиме реплики

### Развертывание среды выполнения

Виртуальная машина развертывается при выполнении [Vagrantfile](https://github.com/anashoff/otus/blob/master/project/Vagrantfile) в составе всего стенда или одельно.

Далее развертывание продолжается при выполнении роли ansible

 [db2](https://github.com/anashoff/otus/blob/master/project/roles/db2-slave/tasks/main.yaml)

```yaml
---
##### Установка утилит
- include_tasks: ../../common/tasks/install_utils.yml
##### Настройка времени
- include_tasks: ../../common/tasks/setup_time.yml
##### Установка node exporter для мониторинга
- include_tasks: ../../common/tasks/install_node_exp.yml
  ignore_errors: true
##### Установка alloy для логгирования
- include_tasks: ../../common/tasks/install_alloy.yml
##### Установка PostgreSQL
- include_tasks: ../../common/tasks/install_pgsql_common.yml
##### Настраиваем реплику
- include_tasks: ../../common/tasks/install_pgsql_slave.yml 
```

Задачи с директивами include tasks описаны в разделе [Общие задачи](https://github.com/anashoff/otus/tree/master/project/roles/common#readme) 

#### Файлы конфигурации сервера БД

Конфигурация PostgreSQL.

[postgresql.conf.j2](https://github.com/anashoff/otus/blob/master/project/templates/postgresql.conf.j2)


```conf
# -----------------------------
# PostgreSQL configuration file
# -----------------------------
#------------------------------------------------------------------------------
# FILE LOCATIONS
#------------------------------------------------------------------------------

data_directory = '/storage/postgres'		# use data in another directory
					# (change requires restart)
hba_file = '/etc/postgresql/14/main/pg_hba.conf'	# host-based authentication file
					# (change requires restart)
ident_file = '/etc/postgresql/14/main/pg_ident.conf'	# ident configuration file
					# (change requires restart)
# If external_pid_file is not explicitly set, no extra PID file is written.
external_pid_file = '/var/run/postgresql/14-main.pid'			# write an extra PID file
					# (change requires restart)

#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------
# - Connection Settings -
listen_addresses = '*'   		# what IP address(es) to listen on;
					# (change requires restart)
port = 5432				# (change requires restart)
max_connections = 100			# (change requires restart)
#superuser_reserved_connections = 3	# (change requires restart)
unix_socket_directories = '/var/run/postgresql'	# comma-separated list of directories
					# (change requires restart)
password_encryption = scram-sha-256	# scram-sha-256 or md5
#db_user_namespace = off
#------------------------------------------------------------------------------
# RESOURCE USAGE (except WAL)
#------------------------------------------------------------------------------

# - Memory -

shared_buffers = 256MB			# min 128kB
					# (change requires restart)

#------------------------------------------------------------------------------
# WRITE-AHEAD LOG
#------------------------------------------------------------------------------

# - Settings -

wal_level = replica			# minimal, replica, or logical
					# (change requires restart)
max_wal_size = 1GB
min_wal_size = 80MB
#------------------------------------------------------------------------------
# REPLICATION
#------------------------------------------------------------------------------
max_wal_senders = 2	# max number of walsender processes
				# (change requires restart)
max_replication_slots = 2 	# max number of replication slots
				# (change requires restart)
hot_standby = on			# "off" disallows queries during recovery
					# (change requires restart)
hot_standby_feedback = on		# send info from standby to prevent
					# query conflicts
```
 Приведены настройки отличные от дефолтных 
 Из особенностей 
 - настраивается путь к базе данных и файлам конфигурации
 - в этом стенде входящие подключения допускаются со всех узлов
 - кол-во shared_buffers = 25% RAM
 - WAL в режиме репликации
 - заданы мин. и макс. размеры WAL
 - задано макс кол-во серверов реплик и слотов для репликации
 - Разрешили read-only запросы к СУБД во время процесса восстановления
 - включили обратную связь от реплики к мастеру для предотвращения конфликтов запросов
 - 
Конфигурация доступа к хосту PostgresQL. 

[pg_hba.conf.j2](https://github.com/anashoff/otus/blob/master/project/templates/pg_hba.conf.j2)

```conf
# PostgreSQL Client Authentication Configuration File
# ===================================================
# Database administrative login by Unix domain socket
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             192.168.1.0/24	          scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
host    replication     repluser        192.168.1.53/32         scram-sha-256
host    replication     repluser        192.168.1.54/32         scram-sha-256
```
Включен доступ с узлов локальной сети по паролю.
Для задач репликации добавлен доступ для пользователя репликации с узлов PostgreSQL


Конфигурация grafana alloy. 

```jinja
local.file_match "audit_files" {
     path_targets = [{ "__path__" = "/var/log/audit/audit.log"}]
     sync_period = "5s"
 }

loki.source.file "audit" {
    targets    = local.file_match.audit_files.targets
    forward_to = [loki.process.audit.receiver]
    tail_from_end = true
  }

loki.process "audit" {
    forward_to =  [loki.write.loki.receiver]

    stage.static_labels {
      values = {
        job  = "audit",
        service_name = "audit",
    }
  }
}

loki.source.file "postgres" {
    targets    = [{ "__path__" = "/var/log/postgresql/postgresql-14-main.log"}]
    forward_to = [loki.process.postgres.receiver]
    tail_from_end = true
  }

loki.process "postgres" {
    forward_to =  [loki.write.loki.receiver]

    stage.static_labels {
      values = {
        job  = "postgres",
        service_name = "postgres",
    }
  }
}

loki.write "loki" {
        endpoint {
                url = "http://192.168.1.56:3100/loki/api/v1/push"
        }
}
```
Первый поток обрабатывает файл аудита - выполняет поиск файла audit.log, чтение из него записей, добавление меток и предача на сервер Loki
Второй поток обрабатывает файл логов PostgreSQL - выполняет чтение из файла записей, добавление меток и предача на сервер Loki

### Работа с сервером

Запуск сервера выполняется для восстановления работоспособности стенда после устранения сбоя сервера баз данных DB-1. При этом сервер DB-2 работает в режиме мастера. 

Дла запеска сервера выполняется команда

```vagrant up db1```

Настройка серера выполняеться по команде

```ansible-pleybook start_db1_as_slave.yaml```

Общее время развертывания сервера ~ 7 минут.

Выключение сервера 

```vagrant halt db1```

Стирание виртуальной машины

```vagrant destroy db1```
