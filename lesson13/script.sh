#!/bin/bash
function dateval(){
text=$(awk -v x=$1 '{gsub(/[\[/]/," ",$4); sub(/:/," ",$4);if (NR==x)  print $4}' $logfile)
date --date="$text" +%s
}


ls trigger
if [ $? -eq 2 ]
then

touch trigger
echo запуск...
logfile=$1
lasttime=0
lasttime=$(cat last.tmp)
i=$(wc -l <$1)
j=0
while [ $(dateval $i) -gt $lasttime ] && [ $i -ge 0 ]
do
  ((i--))
  ((j++))
done

tail -n $j $1 >access.tmp
wc -l access.tmp

echo "Анализ работы web сервера" >result
echo "Начало анализа:" >>result
date --date @$lasttime >>result
echo "Окончание анализа:" >>result
date >>result
echo "1. Топ 20 адресов с наибольшим количеством запросов" >> result
echo "Кол-во     ip-адрес" >>result
awk '{print $1}' access.tmp | grep -P '^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)(\.(?!$)|$)){4}$' | sort | uniq -c | sort -n -r | sed 20q >>result
echo "2. Топ 20 запрашиваемых URL" >> result
echo "Кол-во     URL" >>result
awk '{print $7}' access.tmp | grep -v '\*' | sed -e 's/\?[^\?]*$//' | sort | uniq -c | sort -n -r | sed 20q >>result
echo "3. Ошибки сервера" >>result
echo "Кол-во  Код " >>result
awk '{print $9}' access.tmp | grep -P "(4|5)[0-9]{2}" | sort | uniq -c | sort -n -r >> result
echo "4. Коды HTTP ответа с указанием их кол-ва" >>result
echo "Кол-во  Код" >>result
awk '{print $9}' access.tmp | grep -P "[0-9]{3}" | sort | uniq -c | sort -n -r >>result
dateval $(wc -l <$1) > last.tmp 
echo выполнено.
cat result | mail -s "Анализ логов web сервера" a.sharov@test-p.ru
rm -f trigger
rm -f access.tmp
rm -f result

else
   echo занято
fi
