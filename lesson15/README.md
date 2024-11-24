# Administrator Linux. Professional

## Урок 15. Домашнее задание

Работа с процессами

### Описание домашнего задания

- Написать свою реализацию ps ax используя анализ /proc

### Выполнение

Скрипт будет анализировать файлы /proc/PID/stat, /proc/PID/comm и /proc/PID/cmdline по каждому процессу и получать необходимые данные.

Образец вывода ```ps ax```

```text
    PID TTY      STAT   TIME COMMAND
      1 ?        Ss     0:02 /sbin/init
      2 ?        S      0:00 [kthreadd]
      3 ?        I<     0:00 [rcu_gp]
      4 ?        I<     0:00 [rcu_par_gp]
      5 ?        I<     0:00 [slub_flushwq]
      6 ?        I<     0:00 [netns]
      8 ?        I<     0:00 [kworker/0:0H-events_highpri]
    316 ?        I<     0:00 [kworker/22:1H-kblockd]
    317 ?        I<     0:00 [kworker/21:1H-kblockd]
    d0-crtc1]
   1020 ?        S      0:00 [card0-crtc2]
   1805 ?        I      0:00 [kworker/17:2-events]
   1950 ?        Sl     0:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 9100 -container-ip 172.18.0.2 -container-port 9100
   2126 ?        Sl     0:00 /usr/bin/containerd-shim-runc-v2 -namespace moby -id fc6a474a567c745450c63df49608b4c9dbfb48338f08531202ddd25b39947ac2 -address /run/containerd/containerd.sock
   2127 ?        Sl     0:00 /usr/bin/containerd-shim-runc-v2 -namespace moby -id ad5bb1fc51719a886c1bd2e89d267b6ae058021e2d5d04f4b40f2bd7a6d64b4e -address /run/containerd/containerd.sock
   2128 ?        Sl     0:00 /usr/bin/containerd-shim-runc-v2 -namespace moby -id a8cf1274e949119f92e11c8eb720c69fa38cf27435609c043b69f44c0ae3a8de -address /run/containerd/containerd.sock
   2129 ?        Sl     0:00 /usr/bin/containerd-shim-runc-v2 -namespace moby -id 8c47532948912cb755b8db7a43cb30755b49d0e9ef4cff8d5ad84cc7a6dde075 -address /run/containerd/containerd.sock
   2200 ?        I      0:00 [kworker/16:2-events]
   2204 ?        Ssl    1:16 /bin/node_exporter
   2205 ?        Ssl    0:32 /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus
   2217 ?        Ss     0:00 nginx: master process nginx -g daemon off;
   2223 ?        Ssl    0:12 grafana server --homepath=/usr/share/grafana --config=/etc/grafana/grafana.ini --packaging=docker cfg:default.log.mode=console cfg:default.paths.data=/var/lib/grafana cfg:default.paths.logs=/var/log/grafana cfg:default.paths.plugins=/var/lib/grafana/pl
 
   2375 ?        S      0:00 nginx: worker process
   2505 ?        Ss     0:00 /usr/sbin/cron -f
   2512 ?        Ssl    0:00 /usr/bin/sddm
   2601 tty7     Ssl+   3:31 /usr/lib/xorg/Xorg -nolisten tcp -auth /var/run/sddm/{dfdcfbe7-3e31-4585-90db-1a988ebd8ac3} -background none -noreset -displayfd 17 -seat seat0 vt7
   2765 ?        Ss     0:00 /usr/sbin/exim4 -bd -q30m
   2806 ?        SNsl   0:00 /usr/libexec/rtkit-daemon
   2885 ?        Ssl    0:01 /usr/libexec/upowerd

```

Здесь

- PID - идентификатор процесса

- TTY - терминал, с которым связан данный процесс

- STAT - состояние, в котором на данный момент находится процесс

- TIME - процессорное время, занятое этим процессом

- COMMAND - имя команды, которая использовалась для запуска процесса

Эти данные будем получать следующим образом

PID - имя подкаталогов из каталога /proc
TTY - 7 параметр в файле /proc/PID/stat
STAT - 3 параметр в файле /proc/PID/stat
TIME - 14 параметр в файле /proc/PID/stat
COMMAND - из файла /proc/PID/cmdline для обычных процессов либо /proc/PID/comm для процессов ядра

[Cкрипт](https://github.com/anashoff/otus/blob/master/lesson15/psanal.sh)

```bash
#!/bin/bash
# отключим перенос при выводе длинных строк
    printf '\033[?7l'
#делаем цикл по содeржимому папки proc
for i in `ls -l /proc | grep "^d" | awk '{print $9}' | grep -P "[0-9]" | sort -n` 
do
# если нет в папке файла stat, то пропускаем эту папку
   if [ ! -f "/proc/$i/stat" ]; then 
      continue 
   fi
#  формируем текст название процесса, в зависимости от тоого, процесс ядра это или нет
   if [ $(sed 's/(.*)//' /proc/$i/stat | awk '{print $3}') -eq "2" ]; then
      cm=$(tr -d '\0' </proc/$i/comm | sed 's/.*/[&]/' ) 
   else
      cm=$(tr -d '\0' </proc/$i/cmdline)
   fi
# определяем TTY. вместо знака вопроса выводим -
   mj='-'   
   tty_nr=$(sed 's/(.*)//' /proc/$i/stat | awk '{print $6}')
   if [ $(( tty_nr >> 8 )) -eq 4 ]; then mj='tty'$(( tty_nr%256 ))
   fi
   if [ $(( tty_nr >> 8 )) -eq 136 ]; then mj='pts/'$(( tty_nr%256 ));
   fi
# выводим форматированную строку данных
    printf "%7s %-8s %1s %10(%M:%S)T %s" $i $mj $(sed 's/(.*)//' /proc/$i/stat | awk '{print $2}  ; {tmm = int($13/92) ;  print  tmm}')
    echo $cm 
done
# включим перенос при выводе длинных строк
   printf '\033[?7h'
```

Задание выполнено

Все файлы работы, использованные в задании, доступны на [github](https://github.com/anashoff/otus/blob/master/lesson15)
