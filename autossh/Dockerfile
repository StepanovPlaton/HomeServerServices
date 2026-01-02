FROM jnovack/autossh:2.1.0

# Устанавливаем sshpass для работы с паролями
RUN apk add --no-cache sshpass

# Переопределяем входную точку, чтобы использовать sshpass
ENTRYPOINT ["/usr/bin/sshpass", "-e", "autossh"]
