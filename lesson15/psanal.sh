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




