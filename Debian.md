# Настройка Debian

## 1. Установка Debian

Стандартная установка Debian Minimal. Занимаем весь виртуальный диск. При установке отключаем графический интерфейс и ставим SSH сервер.

После установки заходим под root и устанавливаем `sudo`.
```bash
apt install sudo
usermod -aG sudo имя_пользователя
```

Перезаходим и дальше работаем под обычным пользователем.

## 2. Статический IP
Смотрим название сетевого интерфейса и устанавливаем resolvconf (для поддержки dns-nameservers):
```bash
ip addr
sudo apt install resolvconf
```
Редактируем настройки
```bash
sudo nano /etc/network/interfaces
```
Добавляем настройки:
```
auto enp0s3
iface enp0s3 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 77.88.8.8 8.8.8.8
```
Перезагружаемся:
```bash
sudo reboot
```

## 3. Установка Podman

> Мы будем использовать Podman вместо Docker в целях безопасности. Podman не требует запущенного демона для работы и по умолчанию нацелен на работу в rootless режиме, что нам очень интересно.

```bash
sudo apt install podman podman-compose
```

Добавляем загрузку контейнеров с параметром `restart: always` при загрузке системы
```bash
systemctl --user enable podman-restart.service
sudo loginctl enable-linger USER
```

## 4. Клонируем этот репозиторий для запуска сервисов

```bash
sudo apt install git
mkdir ~/services
cd ~/services
git clone https://github.com/StepanovPlaton/HomeServerServices .
```

## 5. Монтирование дисков

Смотрим список разделов с их UUID
```bash
sudo blkid
```
Создаём точку монтирования
```bash
mkdir ~/diskN
```
Добавляем запись в fstab 
```bash
sudo nano /etc/fstab
```
В конец добавляем
```
UUID=***-***-***-***-***  /home/USER/diskN  ext4  defaults,nofail  0  2
```
Монтируем диск
```bash
sudo systemctl daemon-reload
sudo mount -a
```


Для корректной работы с диском может потребоваться изменить права доступа. 
```bash
sudo chown -R 1000:1000 path/to/disk
podman unshare chown -R 1000:1000 path/to/disk
```

**Настройка сервисов описана в файле [Services.md](Services.md)**
