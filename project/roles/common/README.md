# Administrator Linux. Professional

## Модуль  общих задач 

В данном модуле собраны плейбуки, используемые для решения общих задач.

### Описание модуля

В модуль входит 9 плейбуков

- deploy_site.yml - развертывание сайта из архива
- install_alloy.yml - установка сборщика логов Grafana Alloy
- install_angie.yml - установка веб-сервера Angie
- install_node_exp.yml - установка экспортера метрик Node Exporter
- install_pgsql_common.yml - установка СУБД PostgresSQL 
- install_pgsql_master.yml - настройка PostgreSQL в режиме мастера 
- install_pgsql_slave.yml - настрока PostgreSQL  в режиме реплики, копирование данных с мастера и запуск репликации
- install_utils.yml - установка общесистемных и вспомогательных утилит
- setup_time.yml - настройка часового пояса и синхронизации времени
  
В модуль входит также файл с глобальными переменными.

### Описание плейбуков

Развертывание сайта из архива

[deploy_site.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/deploy_site.yml)

```yaml
- name: Копирование архива на целевой хост
  copy:
    src: templates/html.tar.gz  # Путь к архиву относительно playbook
    dest: /tmp/html.tar.gz
- name: Распаковка архива
  unarchive:
    src: /tmp/html.tar.gz
    dest: /usr/share/angie/html
    remote_src: yes
- name: Назначение www-data владельцем каталога с сайтом
  file:
    path: /usr/share/angie/html
    owner: www-data
    group: www-data
    recurse: yes
- name: Перезапуск сервиса Angie
  systemd:
    name: angie
    state: restarted
```

Установка сборщика логов Grafana Alloy

[install_alloy.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_alloy.yml)

```yaml
- name: Скачивание deb-пакета Alloy
  get_url:
    url: "{{ alloy_deb_url }}"
    dest: "/tmp/alloy-{{ alloy_version }}.deb"
    mode: "0644"
    timeout: 30
  register: download_result
  until: download_result is succeeded
  retries: 3
  delay: 10

- name: Установка Alloy из пакета
  apt:
    deb: "/tmp/alloy-{{ alloy_version }}.deb"
    state: present
    install_recommends: no

- name: Создание конфигурационного каталога Alloy 
  file:
    path: "/etc/alloy"
    state: directory
    mode: 0755

- name: Передача конфигурации Alloy
  template:
    src: "alloy_config.alloy.j2"
    dest: "{{ alloy_config_path }}"
    mode: 0644

- name: Передача конфигурации сервиса  Alloy
  template:
    src: "alloy.j2"
    dest: "/etc/default/alloy"
    mode: 0644

- name: Включение и запуск сервиса Alloy
  systemd:
    name: alloy
    state: started
    enabled: yes
    daemon_reload: yes
```

Установка веб-сервера Angie

[install_angie.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_angie.yml)

```yaml
- name: Загрузка GPG-ключа Angie
  get_url:
    url: https://angie.software/keys/angie-signing.gpg
    dest: /etc/apt/trusted.gpg.d/angie-signing.gpg
    mode: 0644
- name: Добавление репозитория Angie
  copy:
    dest: /etc/apt/sources.list.d/angie.list
    content: "deb https://download.angie.software/angie/{{ ansible_distribution | lower }}/{{ ansible_distribution_version }} {{ ansible_distribution_release }} main"
    owner: root
    group: root
    mode: 0644
- name: Обновление кеша после добавления репозитория
  apt:
    update_cache: yes
- name: Установка пакета Angie, php, php-fpm и прочих утилит
  apt:
    name: 
      - angie
      - php
      - php-fpm
      - php-mbstring
      - php-pgsql
    state: present
```

Установка экспортера метрик Node Exporter

[install_node_exp.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_node_exp.yml)

```yaml
- name: If shit
  block:
  - name: Установка Node Exporter из cloudalchemy
    include_role:
      name: cloudalchemy.node-exporter
    vars:
      node_exporter_textfile_directory: /var/lib/node_exporter/textfile_collector
  rescue: 
  - name: happened 
    ansible.builtin.debug:
      msg: "always erro in second try"
```

Установка СУБД PostgresSQL 

[install_pgsql_common.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_pgsql_common.yml)

```yaml
- name: Установка Postgresql
  apt:
    update_cache: yes
    name:
      - acl
      - postgresql
      - postgresql-contrib
      - barman-cli
      - locales
    state: present
- name: Управление сервисом
  service:
    name: postgresql
    state: started
    enabled: true
- name: Установка утилит для управление Postgresql
  apt:
    name:
      - python3-psycopg2
#      - libpq-dev
    state: present
    update_cache: true
- name: Generate ru_RU.UTF-8 locale
  command: locale-gen ru_RU.UTF-8
  changed_when: false

- name: Создание каталога для хранения данных PostgreSQL
  file:
    path: "{{ pg_data_dir }}"
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'

- name: Остановка сервиса PostgreSQL
  service:
    name: postgresql
    state: stopped

- name: Удаление существующего кластера (при наличии)
  command: pg_dropcluster {{ pg_version }} {{ pg_cluster }} --stop
  ignore_errors: yes
  register: drop_cluster
  changed_when: drop_cluster.rc == 0
```

Настройка PostgreSQL в режиме мастера 

[install_pgsql_master.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_pgsql_master.yml)

```yaml
- name: Создание нового кластера PostgreSQL
  command: pg_createcluster {{ pg_version }} {{ pg_cluster }} --datadir={{ pg_data_dir }} --locale=ru_RU.UTF-8 --port=5432 
  register: create_cluster
- name: Передача конфигурации PostgreSQL
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/{{ pg_version }}/{{ pg_cluster }}/postgresql.conf
    mode: 0644
- name: Передача конфигурации доступов hba
  template:
    src: pg_hba.conf.j2
    dest: /etc/postgresql/{{ pg_version }}/{{ pg_cluster }}/pg_hba.conf
    mode: 0644
- name: Запуск кластера PostgreSQL
  service:
    name: postgresql
    state: started
    enabled: yes

- name: Ожидание запуска кластера PostgreSQL
  wait_for:
    port: 5432
    delay: 5
    timeout: 60

- name: Создание пользователя с ролью SUPERUSER
  become_user: postgres
  postgresql_user:
    name: "{{ db_user }}"
    password: "{{ db_password }}"
    role_attr_flags: SUPERUSER

- name: Создание базы с локалью  ru_RU.UTF-8
  become_user: postgres
  postgresql_db:
    name: "{{ db_name }}"
    encoding: UTF8

- name: Создание пользователя для репликации
  become_user: postgres
  postgresql_user:
    name: repluser
    password: "qq1qq2qq3"
    role_attr_flags: REPLICATION
  ignore_errors: true

```

Настрока PostgreSQL  в режиме реплики, копирование данных с мастера и запуск репликации

[install_pgsql_slave.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_pgsql_slave.yml)

```yaml
- name: Создание нового кластера PostgreSQL с нашими настройками
  command: pg_createcluster {{ pg_version }} {{ pg_cluster }} --datadir={{ pg_data_dir }} --locale=ru_RU.UTF-8 --port=5432
  register: create_cluster
- name: Остановка сервиса PostgreSQL
  service:
    name: postgresql
    state: stopped
- name: Очищаем каталог с данными
  file:
    path: "{{ pg_data_dir }}"
    state: absent
- name: Копируем данные с мастера db1 на реплику db2. Процесс занимает около 4 минут. Спасибо за понимание.
  become_user: postgres
  expect:
    command: 'pg_basebackup -h 192.168.1.53 -U repluser -p 5432 -D "{{ pg_data_dir }}" -R -P -v'
    responses:
      '[Pp]assword.*:': "{{ replicator_password }}"
    timeout: 3600
  when: (ansible_hostname == "db2")
  ignore_errors: true

- name: Копируем данные с мастера db2 на реплику db1. Процесс занимает около 4 минут. Спасибо за понимание.
  become_user: postgres
  expect:
    command: 'pg_basebackup -h 192.168.1.54 -U repluser -p 5432 -D "{{ pg_data_dir }}" -R -P -v'
    responses:
      '[Pp]assword.*:': "{{ replicator_password }}"
    timeout: 3600
  when: (ansible_hostname == "db1")
  ignore_errors: true

- name: Копируем конфигурационный файл postgresql.conf
  template:
    src: postgresql.conf.j2
    dest:  /etc/postgresql/14/main/postgresql.conf
    owner: postgres
    group: postgres
    mode: '0600'

- name: Копируем конфигурационный файл pg_hba.conf
  template:
    src: pg_hba.conf.j2
    dest:  /etc/postgresql/14/main/pg_hba.conf
    owner: postgres
    group: postgres
    mode: '0600'

- name: Запускаем службу PostgreSQL
  service:
    name: postgresql
    state: started

```

Установка общесистемных и вспомогательных утилит

[install_utils.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/install_utils.yml)

```yaml
- name: Установка вспомогательных утилит 
  apt:
    name:
      - net-tools
      - htop
      - mc
      - wget
      - unzip
      - apt-transport-https
      - software-properties-common
      - curl
      - gpg
      - ca-certificates
      - auditd
    update_cache: true
    state: latest
```

Настройка часового пояса и синхронизации времени

[setup_time.yml](https://github.com/anashoff/otus/blob/master/project/roles/common/tasks/setup_time.yml)

```yaml
---
- name: Установка часового пояса
  timezone:
    name: "Europe/Moscow"

- name:  Включение синхронизации времени NTP 
  command: timedatectl set-ntp true
```

Глабальные переменные проекта

[all.yaml](https://github.com/anashoff/otus/blob/master/project/group_vars/all.yaml)

```yaml
alloy_version: "1.7.1"
alloy_deb_url: "https://github.com/grafana/alloy/releases/download/v{{ alloy_version }}/alloy-{{ alloy_version }}-1.amd64.deb"
alloy_config_path: "/etc/alloy/config.alloy"
loki_endpoint: "http://192.168.1.56:3100/loki/api/v1/push"
pg_version: 14
pg_cluster: main
pg_data_dir: /storage/postgres
pg_port: 5432
db_name: ********
db_user: *******
db_password: *******
replicator_password: *******
domain: 192.168.1.50
country_code: RU 
organization: "IL Test-Puschino"
ssl_days: 3650
cert_path: /etc/angie/certs
ssl_conf_file: default.conf
```

### Развертывание среды выполнения

Плейбуки используются при выполнении ролей во время настройки серверов. Из ролей плейбуки вызываются командой **include_tasks**

