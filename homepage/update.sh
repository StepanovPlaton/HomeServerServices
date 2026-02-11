cd src
git pull
cd ..
podman-compose down
podman-compose up -d --build
cd ../proxy
podman-compose restart nginx-proxy
