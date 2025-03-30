# Administrator Linux. Professional

## Сервер мониторинга и сбора логов

Требования, предъявляемые к серверу

Виртуальная машина обеспечивает функционал:

- Централизованный сбор метрик и логов
- передачу алертов в Telegram
- Отображение метрик и логов на дашбордах

### Описание сервера

В качестве сервера используется виртуальная машина с установленной Ubuntu 22.04. 

Сервер разворачивается с помощью **vagrant и ansible**.

Для сбора метрик использовется связка **Prometheus - Node Exporter**

Алерты выполняет **alertmanager**

Для сбора логов используется **Loki**

Для отображения дашбордов используется **Grafana**. Для автоматической настройки Grafana используется провижионинг настроек источников данных Prometheus, Loki, Postgresql, и преднастроенного дашборда.

Все необходимые сервисы развертываются в docker с помощью docker compose, что в основном обусловлено доступностью нужных приложений в РФ.

### Развертывание среды выполнения

Виртуальная машина развертывается при выполнении [Vagrantfile](https://github.com/anashoff/otus/blob/master/project/Vagrantfile) в составе всего стенда или одельно.

Далее развертывание продолжается при выполнении роли ansible

 [monilog](https://github.com/anashoff/otus/blob/master/project/roles/monilog/tasks/main.yaml)

```yaml
---
##### Установка утилит
- include_tasks: ../../common/tasks/install_utils.yml
##### Настройка времени
- include_tasks: ../../common/tasks/setup_time.yml

#####  Установка docker
- name: Очистка старых версий Docker
  apt:
    name: "{{ item }}"
    state: absent
    purge: yes
  loop:
    - docker.io
    - docker-doc
    - docker-compose
    - podman-docker
    - containerd
    - runc
  ignore_errors: yes
- name: Установка вспомогательных утилит
  apt:
    name:
      - gnupg
    state: present
    update_cache: yes
- name: Создание каталога для ключа репозитория
  file:
    path: /etc/apt/keyrings
    state: directory
    mode: '0755'
- name: Загрузка ключа  Docker GPG
  ansible.builtin.get_url:
    url: https://download.docker.com/linux/ubuntu/gpg
    dest: /etc/apt/keyrings/docker.asc
    mode: '0644'
- name: Добавление репозитория Docker
  apt_repository:
    repo: >-
      deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc]
      https://download.docker.com/linux/ubuntu
      {{ ansible_facts.lsb.codename }}
      stable
    state: present
    filename: docker
    update_cache: yes
- name: Установка Docker
  apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    state: latest
    update_cache: yes
- name: Запуск сервиса Docker  
  service:
    name: docker
    state: started
    enabled: yes

##### Установка Prometheus, Grafana...
- name: Создание каталога для docker compose
  file:
    path: "{{ compose_dir }}"
    state: directory
    mode: 0755

- name: Передача настроек Prometheus
  template:
    src: prometheus.yml.j2
    dest: "{{ compose_dir }}/{{ prometheus_config }}"
    mode: 0644

- name: Передача настроек источников данных  Prometheus
  template:
    src: datasource.yml.j2
    dest: "{{ compose_dir }}/datasource.yml"
    mode: 0644

- name: Передача настроек Alertmanager
  template:
    src: alertmanager.yml.j2
    dest: "{{ compose_dir }}/{{ alertmanager_config }}"
    mode: 0644

- name: Передача настроек бота Telegram
  template:
    src: telegram.tmpl.j2
    dest: "{{ compose_dir }}/{{ telegram_template }}"
    mode: 0644

- name: Передача настроек правил алертов
  template:
    src: alert.rules.yml.j2
    dest: "{{ compose_dir }}/{{ alert_rules }}"
    mode: 0644

- name: Передача настроек Loki
  template:
    src: loki-config.yaml.j2
    dest: "{{ compose_dir }}/loki-config.yaml"
    mode: 0644

- name: Передача настроек провиженинга дашборда Grafana
  template:
    src: dashboard.yml.j2
    dest: "{{ compose_dir }}/dashboard.yml"
    mode: 0644  

- name: Передача дашборда Grafana
  template:
    src: dashboard.json.j2
    dest: "{{ compose_dir }}/dashboard.json"
    mode: 0644  

##### Запуск docker compose
- name: Передача файла Docker Compose
  template:
    src: docker-compose.yml.j2
    dest: "{{ compose_dir }}/docker-compose.yml"
    mode: 0644
  notify: Restart stack

- name: Запуск контейнеров Docker Compose
  command: docker compose -f docker-compose.yml up -d
  args:
    chdir: "{{ compose_dir }}"
  register: compose_output
  changed_when:
    - "'Creating' in compose_output.stdout"
    - or "'Recreating' in compose_output.stdout"
```

Задачи с директивами include tasks описаны в разделе [Общие задачи](https://github.com/anashoff/otus/tree/master/project/roles/common#readme) 

Функционал остальных задачи развертывания ясен по названию.

#### Файлы конфигурации веб-сервера angie

Конфигурация веб-сервера.

[angie.conf.j2](https://github.com/anashoff/otus/blob/master/project/roles/web/templates/angie.conf.j2)

```jijna
user  angie;
worker_processes  auto;
worker_rlimit_nofile 65536;

error_log  /var/log/angie/error.log notice;
pid        /run/angie.pid;

events {
    worker_connections  65536;
}


http {
    include       /etc/angie/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    log_format extended '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" rt="$request_time" '
                        '"$http_user_agent" "$http_x_forwarded_for" '
                        'h="$host" sn="$server_name" ru="$request_uri" u="$uri" '
                        'ucs="$upstream_cache_status" ua="$upstream_addr" us="$upstream_status" '
                        'uct="$upstream_connect_time" urt="$upstream_response_time"';

    access_log  /var/log/angie/access.log  main;
    access_log  syslog:server=127.0.0.1:55514,tag=angie_access,severity=info combined;
    error_log syslog:server=127.0.0.1:55515,tag=angie_error;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/angie/site-enabled/*.conf;
}
stream {
    include /etc/angie/stream-enabled/*.conf;
}
```

 Из особенностей - настраивается логирование в локальные файлы и в сокет grafana alloy для передачи на сервер loki. Конфигурация HTTP и stream загружается из дополнительных файлов, находящихся в отдельных каталогах.

Конфигурация HTTP. 

[balance.conf.j2](https://github.com/anashoff/otus/blob/master/project/roles/web/templates/balance.conf.j2)

```jinja
upstream backend {
    server 192.168.1.51:80 weight=1;
    server 192.168.1.52:80 weight=1;
}

server {

    listen 443 ssl;
    server_name {{ domain }};

    ssl_certificate {{ cert_path }}/selfsigned.crt;
    ssl_certificate_key {{ cert_path }}/selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256; 

    location / {
        # Основные настройки проксирования
        proxy_pass http://backend;

        # Передача оригинальных заголовков
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Настройки кэширования (раскомментируйте при необходимости)
        # proxy_cache one;
        proxy_cache_valid 200 1h;
        proxy_cache_lock on;
        proxy_cache_use_stale updating error timeout invalid_header http_500 http_502 http_504;
        proxy_cache_background_update on;

        # Передача URI без изменений
        proxy_redirect off;
        proxy_buffering off;
    }

    location /stat {
        include uwsgi_params;
        uwsgi_pass localhost:81;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
```

Включена балансировка на 2 бекенд сервера  (round-robin) c одинаковыми весами. 
Принимаются запросы по 443 порту с использование самоподписного сертификата. Соединения по 80 порту редиректятся на 443.

Конфигурация потокового модуля.

[pgstream.conf.j2](https://github.com/anashoff/otus/blob/master/project/roles/web/templates/pgstream.conf.j2)

```jinja
    upstream postgres_servers {
        server 192.168.1.53:5432;    # Активный сервер (работает по умолчанию)
        server 192.168.1.54:5432 down; # Резервный (отключен)
    }

    server {
        listen 192.168.1.50:5432;
        proxy_pass postgres_servers;
    }

```

 Запросы к Postgresql по порту 5432 пренаправляются на активный в данный момент сервер DB1 или DB2. 

Процесс выбора описан в основной части документации.

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

loki.source.syslog "angie" {
    listener {
       address = "127.0.0.1:55514"
       protocol = "tcp"
       labels = { job = "frontend_access" }
       syslog_format = "rfc3164"

     }

    listener {
       address = "127.0.0.1:55514"
       protocol = "udp"
       labels = { job = "frontend_access" }
       syslog_format = "rfc3164"
    }
    listener {
       address = "127.0.0.1:55515"
       protocol = "tcp"
       labels = { job = "frontend_error" }
       syslog_format = "rfc3164"

     }

    listener {
       address = "127.0.0.1:55515"
       protocol = "udp"
       labels = { job = "frontend_error" }
       syslog_format = "rfc3164"
    }

     forward_to = [loki.write.loki.receiver]
}


loki.write "loki" {
        endpoint {
                url = "http://192.168.1.56:3100/loki/api/v1/push"
        }
}
```
Первый поток обрабатывает файл аудита - выполняет поиск файла audit.log, чтение из него записей, добавление меток и предача на сервер Loki

Блок local.file_match находит файлы в локальной файловой системе с помощью шаблонов поиска, в нашем случае файл audit.log

Блок loki.source.file считывает записи журнала из найденного файла audit.log и пересылает их следующему компоненту для обработки, в нашем случае в блок loki.process

Блок loki.process ставит на записи лога кастомные метки - это нам пригодится для удобного представления логов в grafana, и передает их дальше в блок write.recierver для отправки в loki. 

Второй поток - выполняет чтение syslog и передача данных на сервер Loki

Блок loki.source.syslog прослушивает сообщения системного журнала по заданным TCP и UDP сокетам и пересылает их в блок write.recierver для отправки в loki. Сокеты создаются при запуске сервиса alloy. Эти сокеты мы указывали в конфигурации angie для отправки в них логов. Передаваемые сообщения настрены на соответствие протоколу системного журнала BSD RFC3164. Также настроены метки angie_access и angie_error для для удобного представления логов в grafana.

И наконец блок loki.write пересылает все направленные в него логи по заданному адресу, в нашем случае на сервер Loki

### Работа с сервером

Запуск сервера происходит при выполнении [Vagrantfile](https://github.com/anashoff/otus/blob/master/project/Vagrantfile) в составе всего стенда или отдельно по команде

```vagrant up web```

Настройка серера выполняеться в составе всего стенда или одельно по команде

```ansible-pleybook playbook.yml --tag web```

Общее время развертывания сервера ~ 5 минут.

Выключение сервера 

```vagrant halt web```

Стирание виртуальной машины

```vagrant destroy web```
