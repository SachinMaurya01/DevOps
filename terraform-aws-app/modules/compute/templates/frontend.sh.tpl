#!/bin/bash
${base_install}

# --- Frontend: serve static files, proxy /api/ to the private backend ------
mkdir -p /var/www/app
cat > /var/www/app/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>Frontend is up</title></head>
  <body>
    <h1>Frontend is up</h1>
    <p>Replace /var/www/app with your built frontend (for example from CI).</p>
    <p>API check: <a href="/api/">/api/</a></p>
  </body>
</html>
HTML

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/app <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/app;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://${backend_private_ip}:80/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
    }

    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }
}
NGINX
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app

nginx -t
systemctl restart nginx
