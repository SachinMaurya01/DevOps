#!/bin/bash
${base_install}

# --- Backend: app runs in Docker on 127.0.0.1:8080, nginx fronts it on :80 --
# The container gets the bucket and queue names as environment variables.
# AWS credentials come from the instance role automatically (no keys on disk).
docker pull ${backend_image}
docker rm -f backend 2>/dev/null || true
docker run -d \
  --name backend \
  --restart unless-stopped \
  -p 127.0.0.1:8080:80 \
  -e AWS_REGION=${aws_region} \
  -e S3_BUCKET=${bucket_name} \
  -e SQS_QUEUE_URL=${queue_url} \
  ${backend_image}

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/backend <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }
}
NGINX
ln -sf /etc/nginx/sites-available/backend /etc/nginx/sites-enabled/backend

nginx -t
systemctl restart nginx
