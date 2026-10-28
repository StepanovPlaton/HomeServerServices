#!/bin/sh
set -eu

cd "$(dirname "$0")"

ENGINE="${CONTAINER_ENGINE:-podman}"
IMAGE="${XRAY_IMAGE:-ghcr.io/xtls/xray-core:latest}"

if ! command -v "$ENGINE" >/dev/null 2>&1; then
  echo "Ошибка: не найден $ENGINE. Установите Podman или задайте CONTAINER_ENGINE=docker." >&2
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Создан .env из .env.example"
fi

# Убираем CRLF, если файл редактировали в Windows
sed -i 's/\r$//' .env 2>/dev/null || true

# shellcheck disable=SC1091
. ./.env

: "${XRAY_PORT:?Укажите XRAY_PORT в .env}"
: "${XRAY_DEST:?Укажите XRAY_DEST в .env}"
: "${XRAY_SERVER_NAME:?Укажите XRAY_SERVER_NAME в .env}"

LOG_LEVEL="${XRAY_LOG_LEVEL:-warning}"
PUBLIC_HOST="${XRAY_PUBLIC_HOST:-YOUR_SERVER_IP}"

set_env() {
  key="$1"
  value="$2"
  awk -v k="$key" -v v="$value" '
    BEGIN { FS = "="; OFS = "=" }
    $1 == k { print k, v; next }
    { print }
  ' .env > .env.tmp
  mv .env.tmp .env
}

gen_uuid() {
  out="$("$ENGINE" run --rm "$IMAGE" uuid)" || return 1
  printf '%s' "$out" | tr -d '\r\n'
}

gen_x25519() {
  out="$("$ENGINE" run --rm "$IMAGE" x25519)" || return 1
  printf '%s' "$out" | tr -d '\r'
}

gen_short_id() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 8 | tr -d '\r\n'
  else
    od -An -N8 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

if [ -z "${XRAY_UUID:-}" ]; then
  echo "Генерация UUID..."
  XRAY_UUID="$(gen_uuid)"
  set_env XRAY_UUID "$XRAY_UUID"
fi

if [ -z "${XRAY_PRIVATE_KEY:-}" ]; then
  echo "Генерация ключевой пары X25519..."
  KEYS="$(gen_x25519)"
  XRAY_PRIVATE_KEY="$(printf '%s\n' "$KEYS" | sed -n -E 's/^(PrivateKey|Private key):[[:space:]]*//p' | head -n 1)"
  XRAY_PUBLIC_KEY="$(printf '%s\n' "$KEYS" | sed -n -E 's/^(Password \(PublicKey\)|PublicKey|Public key):[[:space:]]*//p' | head -n 1)"
  if [ -z "$XRAY_PRIVATE_KEY" ] || [ -z "$XRAY_PUBLIC_KEY" ]; then
    echo "Не удалось разобрать вывод xray x25519:" >&2
    printf '%s\n' "$KEYS" >&2
    exit 1
  fi
  set_env XRAY_PRIVATE_KEY "$XRAY_PRIVATE_KEY"
  set_env XRAY_PUBLIC_KEY "$XRAY_PUBLIC_KEY"
elif [ -z "${XRAY_PUBLIC_KEY:-}" ]; then
  echo "Вычисление публичного ключа..."
  KEYS="$("$ENGINE" run --rm "$IMAGE" x25519 -i "$XRAY_PRIVATE_KEY")" || {
    echo "Не удалось вычислить публичный ключ из XRAY_PRIVATE_KEY." >&2
    exit 1
  }
  KEYS="$(printf '%s' "$KEYS" | tr -d '\r')"
  XRAY_PUBLIC_KEY="$(printf '%s\n' "$KEYS" | sed -n -E 's/^(Password \(PublicKey\)|PublicKey|Public key):[[:space:]]*//p' | head -n 1)"
  if [ -z "$XRAY_PUBLIC_KEY" ]; then
    echo "Не удалось вычислить публичный ключ из XRAY_PRIVATE_KEY." >&2
    exit 1
  fi
  set_env XRAY_PUBLIC_KEY "$XRAY_PUBLIC_KEY"
fi

if [ -z "${XRAY_SHORT_ID:-}" ]; then
  echo "Генерация Short ID..."
  XRAY_SHORT_ID="$(gen_short_id)"
  set_env XRAY_SHORT_ID "$XRAY_SHORT_ID"
fi

mkdir -p config
sed \
  -e "s|__LOG_LEVEL__|$LOG_LEVEL|g" \
  -e "s|__PORT__|$XRAY_PORT|g" \
  -e "s|__UUID__|$XRAY_UUID|g" \
  -e "s|__DEST__|$XRAY_DEST|g" \
  -e "s|__SERVER_NAME__|$XRAY_SERVER_NAME|g" \
  -e "s|__PRIVATE_KEY__|$XRAY_PRIVATE_KEY|g" \
  -e "s|__SHORT_ID__|$XRAY_SHORT_ID|g" \
  config/config.json.example > config/config.json.tmp
mv config/config.json.tmp config/config.json

echo "Проверка конфигурации..."
"$ENGINE" run --rm -v "$(pwd)/config:/usr/local/etc/xray:ro,Z" "$IMAGE" run -test -confdir /usr/local/etc/xray

LINK="vless://${XRAY_UUID}@${PUBLIC_HOST}:${XRAY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${XRAY_SERVER_NAME}&fp=chrome&pbk=${XRAY_PUBLIC_KEY}&sid=${XRAY_SHORT_ID}&type=tcp&headerType=none&spx=%2F#Xray-Home"

cat <<EOF

Готово.
Конфиг:            config/config.json
Публичный ключ:    $XRAY_PUBLIC_KEY
Short ID:          $XRAY_SHORT_ID

Ссылка для клиента (замените $PUBLIC_HOST на реальный адрес, если нужно):
$LINK

Не публикуйте эту ссылку: она даёт доступ к вашему серверу.
EOF
