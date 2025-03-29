# Administrator Linux. Professional

## Сервер фронтенда 

Требования, предъявляемые к серверу

Виртуальная машина с установленным веб-сервером, обеспечивает функционал:

- Проксирование и балансировка HTTP
- Проксирование запросов к базе данных
- Использование SSL - сертификата
- Файрвол
- передача метрик и логов на центральный сервер сбора логов

### Описание сервера

В качестве сервера используется виртуальная машина с установленной Ubuntu 22.04.

Сервер разворачивается с помощью vagrant и ansible.

В качестве веб-сервера, прокси, балансировщика HTTP и L4 используется angie

SSL-сертификат в данной работе испольуется самоподписной

На сервере включен файрвол

Для сбора и передачи метрик используется node exporter, для сбора и передачи логов - grafana alloy

### Развертывание среды выполнения

виртуальная машина развертывается при выполнении [Vagrantfile](https://github.com/anashoff/otus/blob/master/project/Vagrantfile) в составе всего стенда или одельно по команде

```vagrant up web```

Далее развертывание продолжается при выполнении роли ansible [web](https://github.com/anashoff/otus/blob/master/project/roles/web/tasks/main.yaml)


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
##### Установка angie для логгирования
- include_tasks: ../../common/tasks/install_angie.yml
##### Настройка UFW
- name: Включаем UFW
  community.general.ufw:
    state: enabled
    policy: allow
- name: Разрешаем порт SSH
  community.general.ufw:
    rule: allow
    port: 22
- name: Разрешаем порт HTTP
  community.general.ufw:
    rule: allow
    port: 80
- name: Разрешаем порт HTTPS
  community.general.ufw:
    rule: allow
    port: 443
- name: Разрешаем порт PostgreSQL
  community.general.ufw:
    rule: allow
    port: 5432
- name: Разрешаем порт 9100
  community.general.ufw:
    rule: allow
    port: 9100
- name: Заперщаем остальное
  community.general.ufw:
    policy: deny

##### Настройка балансировщика angie
- name: Создание каталога Angie для конфигурации сайтов
  file:
    path: "/etc/angie/site-enabled"
    state: directory
    mode: 0755
- name: Создание каталога Angie для конфигурации stream
  file:
    path: "/etc/angie/stream-enabled"
    state: directory
    mode: 0755
- name: Передача конфигурации Angie
  template:
    src: "angie.conf.j2"
    dest: "/etc/angie/angie.conf"
    mode: 0644
- name: Передача конфигурации прокси сайтов Angie
  template:
    src: "balance.conf.j2"
    dest: "/etc/angie/site-enabled/balance.conf"
    mode: 0644
- name: Передача конфигурации прокси L4
  template:
    src: "pgstream.conf.j2"
    dest: "/etc/angie/stream-enabled/pgstream.conf"
    mode: 0644

- name: Создание каталога для SSL  сертификата
  ansible.builtin.file:
    path: "{{ cert_path }}"
    state: directory
    mode: '0755'

- name: Генерация приватного SSL ключа
  community.crypto.openssl_privatekey:
    path: "{{ cert_path }}/selfsigned.key"
    type: RSA
    size: 2048
    mode: '0600'

- name: Генерация самоподписного сертификата
  community.crypto.x509_certificate:
    path: "{{ cert_path }}/selfsigned.crt"
    privatekey_path: "{{ cert_path }}/selfsigned.key"
    provider: selfsigned
    selfsigned_not_after: "+3650d"
    mode: '0644'

- name: Перезагрузка Angie
  systemd:
    name: angie
    state: reloaded
```

Задачи с директивами include tasks описаны в разделе [Общие задачи]()


### Выполнение работы

### Выводы
