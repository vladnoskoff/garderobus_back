# Пример nginx-конфига с раздельной админкой FastAPI

Ниже — готовый пример для хоста, где уже есть PHP-админка (`/adminpanel/`) и
основной FastAPI работает на `127.0.0.1:8000`. Добавлен отдельный блок `/admin/`
для отдельного FastAPI админ-сервиса (`api_admin.main`, например на `127.0.0.1:8100`).

```nginx
server {
    listen 80;
    server_name garderobus.tech www.garderobus.tech;
    client_max_body_size 20M;

    # ---------- ADMINPANEL (PHP в /home/garderobus/garderobus_back/web) ----------
    location /adminpanel/ {
        alias /home/garderobus/garderobus_back/web/;
        index index.php index.html;
        try_files $uri $uri/ /adminpanel/index.php?$query_string;
    }

    location ~ ^/adminpanel/(.+\.php)$ {
        alias /home/garderobus/garderobus_back/web/$1;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /home/garderobus/garderobus_back/web/$1;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    # ---------- статика картинок от API ----------
    location /clothes_images/ {
        alias /var/www/garderobus/clothes_images/;
    }

    location /mannequins/ {
        alias /var/www/garderobus/mannequins/;
    }

    # ---------- ОТДЕЛЬНАЯ FASTAPI-АДМИНКА (/admin/) ----------
    # Требуется запущенный api_admin.main (FastAPI админка), например через systemd на 127.0.0.1:8100
    # см. deploy/systemd/garderobus-admin.service
    location /admin/ {
        proxy_pass http://127.0.0.1:8100;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ---------- ВСЁ ОСТАЛЬНОЕ -> FASTAPI (основное API) ----------
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

> Если админка живёт на другом порту/хосте, поменяйте `proxy_pass` в блоке `/admin/`.
> Для HTTPS добавьте `listen 443 ssl;` и сертификаты по стандартной схеме nginx.
