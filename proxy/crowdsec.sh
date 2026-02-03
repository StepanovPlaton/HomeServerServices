# Получить API ключ
docker exec crowdsec cscli bouncers add firewall-bouncer

# Посмотреть статистику в реальном времени:
docker exec crowdsec cscli metrics

# Добавить IP в белый список (локально):
docker exec crowdsec cscli whitelists add --ip 192.168.1.5
# Посмотреть белые списки:
docker exec crowdsec cscli parsers list | grep whitelist

# Список всех активных банов:
docker exec crowdsec cscli decisions list
# Забанить IP вручную (на 24 часа по умолчанию):
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 24h --reason "Причина"
# Забанить целую подсеть:
docker exec crowdsec cscli decisions add --range 1.2.3.0/24
# Удалить вообще все активные баны:
docker exec crowdsec cscli decisions delete --all

# Список последних событий:
docker exec crowdsec cscli alerts list
# Посмотреть подробности конкретного алерта (по ID):
docker exec crowdsec cscli alerts inspect <ID>

# Посмотреть, что установлено:
docker exec crowdsec cscli hub list
# Обновить базу правил (как apt update):
docker exec crowdsec cscli hub update
# Установить новую коллекцию (например, для защиты SSH):
docker exec crowdsec cscli collections install crowdsecurity/sshd

# Список подключенных баунсеров (исполнителей, блокировщиков):
docker exec crowdsec cscli bouncers list