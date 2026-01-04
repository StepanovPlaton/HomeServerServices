#!/bin/bash

# Проверяем наличие необходимых переменных
if [ -z "$DDNS_TOKEN" ] || [ -z "$DDNS_DOMAINS" ]; then
    echo "Ошибка: Переменные DDNS_TOKEN или DDNS_DOMAINS не заданы."
    exit 1
fi

while true; do
    echo "Определяем внешний IPv4..."
    CURRENT_IP=$(curl -s https://ifconfig.me)

    if [ -z "$CURRENT_IP" ]; then
        echo "Не удалось получить IP. Повтор через 30 секунд..."
        sleep 30
        continue
    fi

    echo "Ваш IP: $CURRENT_IP. Начинаем обновление доменов..."
    
    ALL_SUCCESS=true

    for DOMAIN in $DDNS_DOMAINS; do
        echo "Обновляю домен: $DOMAIN"
        
        # Выполняем запрос PUT согласно вашему формату
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X 'PUT' "https://cloud.alviy.com/api/v1/ddns/domain/$DOMAIN" \
            -H 'accept: application/json' \
            -H "Authorization: Bearer $DDNS_TOKEN" \
            -H 'Content-Type: application/json' \
            -d "{ \"ipv4\": [ \"$CURRENT_IP\" ] }")

        if [ "$RESPONSE" == "200" ]; then
            echo "Успешно обновлено: $DOMAIN"
        else
            echo "Ошибка обновления $DOMAIN. Код ответа: $RESPONSE"
            ALL_SUCCESS=false
        fi
    done

    if [ "$ALL_SUCCESS" = true ]; then
        echo "Все задачи выполнены успешно. Завершаю работу контейнера."
        exit 0
    else
        echo "Некоторые домены не обновились. Повторная попытка через 60 секунд..."
        sleep 60
    fi
done
