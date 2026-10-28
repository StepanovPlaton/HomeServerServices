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

## 8️⃣ FileBrowser — простой веб-интерфейс для управления файлами

```bash
cd disk
cp .env.example .env && vim .env
touch filebrowser.db && podman unshare chown -R 1000:1000 filebrowser.db
podman-compose up -d
```

---

## 9️⃣ Memos — быстрые заметки

> Memos — это простой и быстрый способ создавать и управлять заметками через веб-интерфейс.

```bash
cd memos
cp .env.example .env && vim .env
podman-compose up -d
```

---

## 🔟 Matrix — собственный сервер для мессенджера Matrix

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

## 1️⃣1️⃣ NextCloud — личное многофункциональное облако

> NextCloud — полнофункциональное облачное хранилище с возможностью синхронизации файлов, календарем, контактами, задачами и многими другими функциями.

```bash
cd cloud
cp .env.example .env && vim .env
mkdir db
mkdir config && podman unshare chown -R 33:33 config
mkdir data && podman unshare chown -R 33:33 data
mkdir apps && podman unshare chown -R 33:33 apps
podman-compose up -d
```

> ⚠️ В docker-compose.yml есть переменные, которые можно указать при первом запуске, но они мешают если пересоздавать контейнер не с нуля.

Настраиваем NextCloud через веб-форму после запуска Nginx. Выбираем пользователя по умолчанию, БД. В разделе приложений можем установить дополнительные модули:

**Базовые модули:**
- Calendar — календарь
- Contacts — контакты
- Deck — доски задач
- Whiteboard — виртуальная доска
- Forms — формы

**Комплексные модули:**
- **NextCloud Office** — конфигурируется с Collabora Office, которая запускается на отдельном домене, его нужно указать в настройках
- **NextCloud Talk** — видеоконференции. Для доступа извне сети нужен модуль CoTurn, он запускается на отдельном домене
  > ⚠️ Для этого модуля нужно открыть UDP порты с SSL, что проблематично. Это я пока не настраивал

> Для работы NextCloud Office в `config/config.php` нужно добавить:
> ```php
> 'trusted_proxies' => ['10.89.0.1'],
> 'overwrite.cli.url' => 'https://cloud.domain.ru',
> 'overwriteprotocol' => 'https',
> 'overwritehost' => 'cloud.domain.ru',
> ```
> 
> `10.89.0.1` — это Gateway для Podman  
> `cloud.domain.ru` меняем на наш домен

**Настройка внешнего хранилища:**

Также устанавливаем модуль **External Storage Support** и в его настройках добавляем диск локального типа по пути `/var/www/external_storage` (это внешний диск, указанный в `.env`).

---

## 1️⃣2️⃣ Nginx Reverse Proxy (Entrypoint)

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

---

## 1️⃣3️⃣ Xray — VPN-доступ к домашней сети (VLESS + Reality)

> VLESS + Reality маскирует трафик под обычный HTTPS. Отдельный домен и SSL-сертификат не нужны, а порт можно пробросить снаружи. Подходит для доступа к домашней сети и как личный VPN.

```bash
cd xray
cp .env.example .env && vim .env
chmod +x setup.sh
./setup.sh
podman-compose up -d
```

`setup.sh` автоматически:

- генерирует UUID, ключевую пару X25519 и Short ID;
- создаёт `config/config.json` из шаблона;
- проверяет конфигурацию через `xray run -test`;
- выводит готовую ссылку `vless://...` для клиента.

> ⚠️ Файлы `.env` и `config/config.json` содержат секреты и исключены из Git. Ссылка подключения тоже является секретом — не публикуйте её.

> В конфигурации отключён XTLS Vision (`flow` не задаётся), чтобы работал UDP — это нужно для игр и Minecraft Bedrock. REALITY/TLS продолжают шифровать трафик. Если UDP не нужен и важна максимальная защита от TLS-in-TLS DPI, Vision можно вернуть, добавив `"flow": "xtls-rprx-vision"` в клиент и `flow=xtls-rprx-vision` в ссылку.

> После изменения `XRAY_PORT`, `XRAY_DEST` или `XRAY_SERVER_NAME` в `.env` запустите `./setup.sh` заново — он пересоберёт `config/config.json` и проверит его. Секреты при этом сохраняются.

### Проброс порта

В OPNsense: **Межсетевой экран > NAT > Переадресация портов**

- **Interface:** WAN
- **Protocol:** TCP
- **Destination:** WAN address
- **Destination port range:** `2053` (или ваш `XRAY_PORT`)
- **Redirect target IP:** IP вашего сервера с Podman
- **Redirect target port:** `2053` (или ваш `XRAY_PORT`)
- **Filter rule association:** Add associated filter rule

> В rootless Podman нельзя слушать порты ниже 1024, поэтому по умолчанию используется `2053`. Не занимайте `8443` — он уже используется nginx-proxy. При необходимости внешний порт можно сделать другим, но тогда клиент должен подключаться именно к внешнему порту.

> Предупреждение Xray о порте не-443 и выбранном `dest` относится к блокировкам GFW (Китай). Для домашнего сервера в России это не критично, но `dest` лучше выбирать из доступных вам крупных сайтов с TLS 1.3.

Если нужен стабильный адрес вместо IP, добавьте поддомен `vpn` в `proxy/ddns/domains.txt` и укажите в `.env`:

```ini
XRAY_PUBLIC_HOST=vpn.domain.ru
```

### Доступ к домашней сети

Сервер Xray не навязывает маршруты клиенту — маршрутизацию настраиваем в клиенте:

- **Только домашняя сеть:** оставьте интернет напрямую, а подсеть `192.168.0.0/16` (или `geoip:private`) направьте в proxy.
- **Полный туннель:** весь трафик (`0.0.0.0/0`) направьте в proxy.

> Xray — это proxy, а не L2 VPN. Broadcast/multicast (обнаружение устройств и LAN-серверов в играх) не переносится. Для игр используйте прямое подключение по IP; для полноценного LAN-обнаружения нужен ZeroTier/SoftEther.

Для доступа по именам добавьте локальные записи в клиент или используйте DNS домашней сети (например, AdGuard/OPNsense), направив DNS-запросы через туннель.

### Добавление устройства

Для каждого устройства лучше использовать отдельный UUID. Добавьте свой объект в `clients` внутри `config/config.json`:

```json
{
  "id": "новый-uuid"
}
```

После изменения перезапустите контейнер:

```bash
podman-compose restart xray
```

Сгенерировать новый UUID можно командой:

```bash
podman run --rm ghcr.io/xtls/xray-core:latest uuid
```

Ссылка для нового устройства строится по той же схеме, что вывел `setup.sh`: меняется только UUID в начале ссылки.