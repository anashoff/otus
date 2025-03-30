# Administrator Linux. Professional

## Сервер бекенда-2

Требования, предъявляемые к серверу

Виртуальная машина с установленным веб-сервером, обеспечивает функционал:

- Работа в качестве веб-серевера.
- Работа веб-приложений, написаных на php
- Работа с базами данных PostgreSQL
- Передача метрик и логов на центральный сервер сбора логов

### Описание сервера

В качестве сервера используется виртуальная машина с установленной Ubuntu 22.04.

Сервер разворачивается с помощью **vagrant и ansible**.

В качестве веб-сервера успользуется **angie**

Для работы с php используется установлены **php, php-fpm**

Для работы с базами данных PostreSQL установлен **php-pgsql**

Для сбора и передачи метрик используется **node exporter**, для сбора и передачи логов - **grafana alloy**

Веб-приложения разворачивается из архива.

### Развертывание среды выполнения

Виртуальная машина развертывается при выполнении [Vagrantfile](https://github.com/anashoff/otus/blob/master/project/Vagrantfile) в составе всего стенда или одельно.

Далее развертывание продолжается при выполнении роли ansible

 [angie1](https://github.com/anashoff/otus/blob/master/project/roles/angie1/tasks/main.yaml)

```yaml
---
##### Установка утилит
- include_tasks: ../../common/tasks/install_utils.yml
##### Настройка времени
- include_tasks: ../../common/tasks/setup_time.yml
##### Установка node exporter для мониторинга
- include_tasks: ../../common/tasks/install_node_exp.yml
  ignore_errors: true
##### Установка promtail для логгирования
- include_tasks: ../../common/tasks/install_alloy.yml
##### Установка ANGIE
- include_tasks: ../../common/tasks/install_angie.yml
- name: Отправка конфигурации angie
  template:
    src: "angie.conf.j2"
    dest: "/etc/angie/angie.conf"
    mode: 0644
- name: Отправка настроек сайта
  template:
    src: "default.conf.j2"
    dest: "/etc/angie/http.d/default.conf"
    mode: 0644
- name: Перезапуск Angie 
  systemd:
    name: angie
    state: restarted
    enabled: true
##### Установка САЙТА
- include_tasks: ../../common/tasks/deploy_site.yml
```

Задачи с директивами include tasks описаны в разделе [Общие задачи](https://github.com/anashoff/otus/tree/master/project/roles/common#readme) 

Функционал остальных задачи развертывания ясен по названию.

#### Файлы конфигурации веб-сервера angie

Конфигурация веб-сервера.

[angie.conf.j2](https://github.com/anashoff/otus/blob/master/project/templates/angie.conf.j2)

```jijna
#user  angie;
user www-data;
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

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/angie/http.d/*.conf;
}

#stream {
#    include /etc/angie/stream.d/*.conf;
#}

```

 Конфигурация HTTP загружается из дополнительного файла default.conf.

Конфигурация HTTP. 

[default.conf.j2](https://github.com/anashoff/otus/blob/master/project/templates/default.conf.j2)

```jinja

server {

    listen       80;
    server_name  _;

    access_log  /var/log/angie/host.access.log  main;
    access_log  syslog:server=127.0.0.1:55514,tag=angie_access,severity=info combined;
    error_log syslog:server=127.0.0.1:55515,tag=angie_error;

    location / {
        root   /usr/share/angie/html;
        index  index.html index.htm;
        allow 192.168.1.50;
        deny all;
 
    }

    location /status/ {
        api     /status/;
        allow   127.0.0.0;
        deny    all;
    }



    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/angie/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
        location ~ \.php$ {
        try_files      $uri =404;
        root           /usr/share/angie/html;
        fastcgi_pass   unix:/run/php/php-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with angie's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
```
Из особенностей 
- Настраивается логирование в локальные файлы и в сокет grafana alloy для передачи на сервер loki.
- Запрещены входящие подключения со всех хостов кроме прокси web.
- Подключен менеджер процессов FastCGI

```

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
       labels = { job = "backend_access" }
       syslog_format = "rfc3164"

     }

    listener {
       address = "127.0.0.1:55514"
       protocol = "udp"
       labels = { job = "backend_access" }
       syslog_format = "rfc3164"
    }
    listener {
       address = "127.0.0.1:55515"
       protocol = "tcp"
       labels = { job = "backend_error" }
       syslog_format = "rfc3164"

     }

    listener {
       address = "127.0.0.1:55515"
       protocol = "udp"
       labels = { job = "backend_error" }
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

```vagrant up angie2```

Настройка серера выполняеться в составе всего стенда или одельно по команде

```ansible-pleybook playbook.yml --tag an2```

Общее время развертывания сервера ~ 4 минуты.

Выключение сервера 

```vagrant halt angie2```

Стирание виртуальной машины

```vagrant destroy angie2```
