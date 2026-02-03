# ⚙️ Настройка сервисов

> Этот гайд описывает настройку и запуск всех сервисов в контейнерах.

---

## 1️⃣ Portainer — WebUI для управления контейнерами

> Для запуска Portainer требуется активный Docker сокет. В Podman по умолчанию его нет, так как это является потенциальным вектором атаки. Запускайте сокет только для конкретного пользователя (не root!)

```bash
cd portainer
cp .env.example .env && vim .env
systemctl --user enable --now podman.socket
podman-compose up -d
```

---

## 2️⃣ Grafana — Dashboard со статистикой загруженности сервера

> Proxmox предоставляет достаточно информации об использовании ресурсов системы, но если вы ставите Debian как контейнер сервисов отдельно, вам может потребоваться Grafana

```bash
cd grafana
cp .env.example .env && vim .env
podman-compose up -d
```

---

## 3️⃣ AutoSSH — SSH туннель, проброс портов

```bash
cd autossh
cp .env.example .env && vim .env
podman-compose up -d --build
```

---

## 4️⃣ Samba — сетевой диск в локальной сети

```bash
cd samba
cp .env.example .env && vim .env
podman-compose up -d
```

> Samba работает на 139 и 445 порту, для доступа к ним нужны root права. Чтобы не запускать контейнер от имени root, пробросим порты из контейнера на 1139 и 1445 порты соответственно, и добавим правила в iptables для переадресации трафика:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 139 -j REDIRECT --to-ports 1139
sudo iptables -t nat -A PREROUTING -p tcp --dport 445 -j REDIRECT --to-ports 1445
sudo iptables -t nat -L -n -v # Посмотреть список правил

# Для сохранения правил iptables после перезагрузки
sudo apt install iptables-persistent
sudo netfilter-persistent save # сохранить текущие iptables
```

---

## 5️⃣ Transmission — BitTorrent клиент

```bash
cd transmission
cp .env.example .env && vim .env
podman-compose up -d
```

> В настройках клиента указанная в `.env` папка доступна по пути `/downloads`. Можно подключиться с помощью [Transmission Remote GUI](https://github.com/transmission-remote-gui/transgui) или [Transmission Qt](https://transmissionbt.com/download.html)

---

## 6️⃣ Syncthing — синхронизация файлов между устройствами

```bash
cd syncthing
cp .env.example .env && vim .env
mkdir config && podman unshare chown -R 1000:1000 config
podman-compose up -d
```

---

## 7️⃣ Gitea — Git-сервер

```bash
cd gitea
cp .env.example .env && vim .env
mkdir config && podman unshare chown -R 1000:1000 config
mkdir data && podman unshare chown -R 1000:1000 data
mkdir db && podman unshare chown -R 1000:1000 db
podman-compose up -d
```

> Gitea конфигурируется позже, уже в веб-форме. Обязательно **отключаем самостоятельную регистрацию** и создаём администратора (пользователя по умолчанию). Остальное не трогаем, уже сконфигурировано в `.env`

---

## 8️⃣ Cloud (FileBrowser) — веб-интерфейс для управления файлами

```bash
cd cloud
cp .env.example .env && vim .env
touch filebrowser.db && podman unshare chown -R 1000:1000 filebrowser.db
podman-compose up -d
```

---

## 9️⃣ Matrix — собственный сервер для мессенджера Matrix

```bash
cd matrix
mkdir data && podman unshare chown -R 1000:1000 data
podman run -it --rm -v "$(pwd)/data:/data" -e SYNAPSE_SERVER_NAME=MATRIX.DOMAIN.ru -e SYNAPSE_REPORT_STATS=no docker.io/matrixdotorg/synapse:latest generate
```
> ⚠️ Замените `MATRIX.DOMAIN.ru` на ваш домен для Matrix сервера.

Меняем базу данных на PostgreSQL и прописываем БД, пользователя, пароль:

```yaml
database:
  name: psycopg2
  args:
    user: user
    password: passw0rd
    database: db
    host: matrix-db
    cp_min: 5
    cp_max: 10
```

```bash
mkdir db && podman unshare chown -R 1000:1000 db
cp .env.example .env && vim .env
podman-compose up -d
```

Создаём пользователя:

```bash
podman exec -it matrix-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

---

## 🔟 Nginx Reverse Proxy (Entrypoint)

```bash
cd proxy
cp .env.example .env && vim .env
```

### Создание конфига для DynDNS

```bash
cp ddns/domains.txt.example ddns/domains.txt && vim ddns/domains.txt
```

> Нужно указать ресурсные записи `@` и `www` для доступа к домену второго уровня напрямую. Также нужно добавить домены 3-го уровня для: gitea, cloud (filebrowser), matrix server (synapse), matrix client (element).

### Первоначальная настройка SSL

В первый раз SSL сертификаты нужно создать вручную.

Запускаем DDNS скрипт и HTTP сервер для Let's Encrypt:

```bash
podman-compose -f init-compose.yml up -d --build
```

Проверяем по логам в portainer и в личном кабинете рег.ру, что ресурсные записи обновились. Ожидаем, пока DNS обновит информацию о наших поддоменах (занимает от 15 минут до 24 часов).

Затем создаём SSL сертификаты на каждый домен(-ы) с помощью команды:

```bash
podman-compose run --rm --entrypoint "certbot" certbot certonly --webroot --webroot-path=/var/www/certbot --email your-email@gmail.com --agree-tos --no-eff-email -d domain.com -d domain2.com
```

> ⚠️ Замените `your-email@gmail.com` на ваш email и `domain.com`, `domain2.com` на ваши домены.

### Настройка Nginx

```bash
cd nginx/conf.d
cp default.conf.example default.conf
vim default.conf
```

### Запуск основного контейнера

```bash
podman-compose -f init-compose.yml down
podman-compose up -d --build
```