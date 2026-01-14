docker compose run --rm --entrypoint "certbot" certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email your-email@gmail.com \
  --agree-tos \
  --no-eff-email \
  -d domain.com -d domain2.com
