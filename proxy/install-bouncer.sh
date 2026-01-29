curl -s https://api.github.com/repos/crowdsecurity/cs-firewall-bouncer/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
tar xzvf crowdsec-firewall-bouncer-linux-amd64.tgz
cd crowdsec-firewall-bouncer-v*/
# Выбираем nftables
sudo ./install.sh

# Получаем API KEY
sudo docker exec crowdsec cscli bouncers add firewall-bouncer

# Прописываем ключ в конфиге
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
# Указваем так же API_URL (см docker-compose.yml, по умолчанию меняем на 8081)
# В разделе nftables ipv4 (и ipv6) добавляем параметр hook: prerouting

# nftables:
#   ipv4:
#     enabled: true
#     set-only: false
#     table: crowdsec
#     chain: crowdsec-chain
#     priority: -10
#     hook: prerouting
#   ipv6:
#     enabled: true
#     set-only: false
#     table: crowdsec6
#     chain: crowdsec6-chain
#     priority: -10
#     hook: prerouting

# Создаём список исключений
sudo docker exec crowdsec cscli allowlists create my_vps -d "Allow list for my vps"
# Добавляем туда IP нашего VPS сервера для AutoSSH сервиса
sudo docker exec crowdsec cscli allowlists add my_vps 1.2.3.4