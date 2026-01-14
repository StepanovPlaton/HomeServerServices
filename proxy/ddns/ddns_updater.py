import schedule
import requests
import json
import time
import argparse
import logging
import sys

parser = argparse.ArgumentParser(description="DDNS for reg.ru")
parser.add_argument("login", help="Почта на reg.ru")
parser.add_argument("password", help="Пароль на reg.ru")
parser.add_argument("-d", dest="delay", default=30, type=int,
                    help="Задержка между проверкой ip в минутах")

logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] - %(message)s',
    datefmt='%d-%b-%y %H:%M:%S',
    handlers=[
        logging.FileHandler("logs.txt"),
        logging.StreamHandler(sys.stdout)
    ]
)

# Отключаем лишние логи от requests
logging.getLogger("urllib3").setLevel(logging.WARNING)

def get_external_ip():
    """Пробует получить внешний IP через разные HTTP сервисы"""
    services = [
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://ident.me",
        "https://icanhazip.com"
    ]
    
    for service in services:
        try:
            logging.debug(f"Запрос IP через {service}...")
            response = requests.get(service, timeout=10)
            if response.status_code == 200:
                ip = response.text.strip()
                if ip:
                    return ip
        except Exception as e:
            logging.warning(f"Сервис {service} недоступен: {e}")
            continue
    return None

def cheker():
    logging.info("--- Проверка внешнего IP ---")
    cur_ip = get_external_ip()
    
    if not cur_ip:
        logging.error("Не удалось определить внешний IP ни через один сервис!")
        return

    logging.info(f"Ваш текущий IP: {cur_ip}")
    
    res = update_ip(cur_ip)
    
    if res is not True:
        code, message = res
        logging.error(f"Ошибка API: {code} - {message}")

def update_ip(ip):
    try:
        with open("domains.txt", "r") as file:
            content = file.read().strip()
            
        if not content:
            logging.warning("Файл domains.txt пуст.")
            return True
        
        auth_data = {
            "username": args.login,
            "password": args.password,
            "output_content_type": "json"
        }

        groups = [g for g in content.split("\n\n") if g.strip()]
        
        for group in groups:
            lines = [line.strip() for line in group.split("\n") if line.strip()]
            if len(lines) < 2: continue
            
            domain_name = lines[0]
            aliases = lines[1:]
            
            logging.info(f"Проверка домена {domain_name}...")
            
            # Получаем текущие записи
            input_data = {**auth_data, "domains": [{"dname": domain_name}]}
            params = {"input_data": json.dumps(input_data), "input_format": "json"}
            
            resp = requests.post("https://api.reg.ru/api/regru2/zone/get_resource_records", data=params).json()
            
            if resp.get("result") == "error":
                return resp.get("error_code"), resp.get("error_text")
            
            current_rrs = resp["answer"]["domains"][0].get("rrs", [])

            for sub in aliases:
                already_correct = False
                outdated_records = []

                for rr in current_rrs:
                    if rr.get("rectype") == "A" and rr.get("subname") == sub:
                        if rr.get("content") == ip:
                            already_correct = True
                        else:
                            outdated_records.append(rr)

                if already_correct:
                    logging.info(f"  [{sub}.{domain_name}] Пропуск: IP уже актуален ({ip})")
                else:
                    logging.info(f"  [{sub}.{domain_name}] Обновление записи...")
                    # Удаляем старые
                    for old_rr in outdated_records:
                        remove_old_record(auth_data, domain_name, old_rr)
                    # Создаем новую
                    add_new_record(auth_data, domain_name, sub, ip)

    except FileNotFoundError:
        logging.error("Файл domains.txt не найден!")
    except Exception as e:
        return "UNKNOWN_ERROR", str(e)
    return True

def remove_old_record(auth, domain, rr):
    logging.info(f"    Удаление старой записи: {rr['subname']} -> {rr['content']}")
    data = {
        **auth,
        "domains": [{"dname": domain}],
        "subdomain": rr["subname"],
        "content": rr["content"],
        "record_type": "A"
    }
    requests.post("https://api.reg.ru/api/regru2/zone/remove_record", data={"input_data": json.dumps(data), "input_format": "json"})

def add_new_record(auth, domain, sub, ip):
    logging.info(f"    Создание новой записи: {sub} -> {ip}")
    data = {
        **auth,
        "domains": [{"dname": domain}],
        "subdomain": sub,
        "ipaddr": ip
    }
    res = requests.post("https://api.reg.ru/api/regru2/zone/add_alias", data={"input_data": json.dumps(data), "input_format": "json"}).json()
    if res.get("result") == "error":
        logging.error(f"    Ошибка API при добавлении: {res.get('error_text')}")

if __name__ == '__main__':
    args = parser.parse_args()
    logging.info("==========================================")
    logging.info("Запуск контейнера DDNS")
    logging.info("Ожидание 30 секунд (загрузка сети/роутера)...")
    logging.info("==========================================")
    
    time.sleep(30)
    
    logging.info("Начинаю работу...")
    
    cheker()

    schedule.every(args.delay).minutes.do(cheker)

    while True:
        schedule.run_pending()
        time.sleep(1)
