#!/bin/bash

# Save WEB EC2 Private IP in "WEB_PRIVATE_IP" variable
echo "WEB EC2 Private IP 주소를 조회 중입니다..."
WEB_PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-edu-ec2-web" \
  --query "Reservations[*].Instances[*].PrivateIpAddress" \
  --output text)
if [ $? -ne 0 ]; then
    echo "[Error] 인스턴스 정보를 가져오는데 실패했습니다."
    exit 1
fi
if [ -z "$WEB_PRIVATE_IP" ]; then
    echo "WEB EC2 인스턴스 IP 정보를 가져오는데 실패했습니다."
    echo "Name TAG 중 'lab-edu-ec2-web' 값을 가진 인스턴스가 있는지 확인해주세요."
    exit 1
fi
echo "WEB EC2 Private IP 주소 조회 완료: $WEB_PRIVATE_IP"

# Install Nginx
echo "Nginx를 설치하고 있습니다..."
echo "---"
sudo yum install nginx -y
echo "---"
echo "Nginx 설치 완료"

# Nginx Settings
echo "Nginx 설정 파일을 생성하고 있습니다..."
echo "user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
                      '\$status \$body_bytes_sent \"\$http_referer\" '
                      '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
                   
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        location / { 
            proxy_pass http://$WEB_PRIVATE_IP:80;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_cache_bypass '\$http_upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

            proxy_buffering off;
            proxy_cache off;
            chunked_transfer_encoding on;
        }

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }

        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    }
}" | sudo tee /etc/nginx/nginx.conf > /dev/null
echo "Nginx 설정 파일 생성 완료"

# Nginx Config TEST
echo "Nginx 설정을 테스트하고 있습니다..."
sudo nginx -t

# Nginx Start 
if [ $? -eq 0 ]; then
    echo "Nginx를 시작하고 있습니다..."
    sudo systemctl start nginx
    echo "Nginx를 시스템 시작 시 자동으로 실행되도록 설정하고 있습니다..."
    sudo systemctl enable nginx
    echo "nginx가 성공적으로 설정되고 시작되었습니다."
else
    echo "nginx 설정에 문제가 있습니다. 설정을 확인해주세요."
fi