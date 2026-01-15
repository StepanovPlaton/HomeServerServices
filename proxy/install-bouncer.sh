curl -s https://api.github.com/repos/crowdsecurity/cs-firewall-bouncer/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
tar xzvf crowdsec-firewall-bouncer-linux-amd64.tgz
cd crowdsec-firewall-bouncer-v*/
sudo ./install.sh

# Получаем API KEY
sudo docker exec crowdsec cscli bouncers add firewall-bouncer


# Прописываем ключ в конфиге
# Указваем так же API_URL (см docker-compose.yml, по умолчанию меняем на 8081)
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
