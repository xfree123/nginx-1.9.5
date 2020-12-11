#!/bin/bash
# Script by Xfree
# Script Date: 11/12/2020
# Apply For: Centos 8
# Install nginx 1.19.5 PCRE 8.44, Zlib 1.2.11, openssl 1.1.1g
apt update -y
addgroup nginx
adduser nginx --system --no-create-home --shell /bin/false --ingroup nginx
#Install build tools
apt install -y build-essential
#Install Dependencies
apt install -y unzip
apt install -y libxslt-dev libxml2-dev
apt install -y libgd-dev libgeoip-dev google-perftools
apt install -y libgoogle-perftools-dev
#Uncompress Source
tar zxvf nginx-1.19.5.tar.gz
tar zxvf zlib-*
tar zxvf openssl-*
tar zxvf pcre-8.44.tar.gz
unzip echo-nginx-module.zip
unzip ngx_cache_purge.zip
unzip set-misc-nginx-module.zip
unzip headers-more-nginx-module.zip
unzip ngx_devel_kit.zip
unzip nginx-module-vts.zip
unzip ngx_log_if.zip
cd nginx-1.19.5
#Begin configuration build nginx and install
./configure \
--prefix=/usr/share/nginx \
--sbin-path=/usr/sbin/nginx \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
--conf-path=/etc/nginx/nginx.conf \
--modules-path=/usr/share/nginx/modules \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--build=Ubuntu \
--user=nginx \
--group=nginx \
--with-pcre=../pcre-8.44 \
--with-pcre-jit \
--with-zlib=../zlib-1.2.11 \
--with-openssl=../openssl-1.1.1g \
--with-http_ssl_module \
--with-http_v2_module \
--with-threads \
--with-file-aio \
--with-http_stub_status_module \
--with-http_degradation_module \
--with-http_auth_request_module \
--with-http_geoip_module=dynamic \
--with-http_realip_module \
--with-http_secure_link_module \
--with-cpp_test_module \
--with-debug \
--with-google_perftools_module \
--with-mail=dynamic \
--with-mail_ssl_module \
--with-stream=dynamic \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-http_image_filter_module=dynamic \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_addition_module \
--with-http_random_index_module \
--with-http_slice_module \
--with-http_sub_module \
--with-http_xslt_module=dynamic \
--with-select_module \
--with-poll_module \
--with-compat \
--add-module=../ngx_devel_kit \
--add-dynamic-module=../set-misc-nginx-module \
--add-dynamic-module=../ngx_cache_purge \
--add-dynamic-module=../headers-more-nginx-module \
--add-dynamic-module=../echo-nginx-module \
--add-dynamic-module=../nginx-module-vts \
--add-dynamic-module=../ngx_log_if
make
make install
#Finish build & install
#now create configuration for nginx

rm -f /etc/systemd/system/nginx.service
cat > "/etc/systemd/system/nginx.service" << END
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable nginx.service
rm -fr /etc/nginx/conf.d
mkdir -p /etc/nginx/conf.d
rm -fr /etc/nginx/conf
mkdir -p /etc/nginx/conf
rm -fr /etc/nginx/nginx.conf
rm -fr /etc/nginx/modules
ln -s /usr/share/nginx/modules /etc/nginx/modules

cat > "/etc/nginx/nginx.conf" << END

# Server Global
user  			nginx;
worker_processes auto;
worker_rlimit_nofile 100000;
timer_resolution 100ms;
pcre_jit on;

pid	/var/run/nginx.pid;
# Load module 
load_module "/etc/nginx/modules/ngx_http_echo_module.so";
load_module "/etc/nginx/modules/ngx_http_geoip_module.so";
load_module "/etc/nginx/modules/ngx_http_headers_more_filter_module.so";
load_module "/etc/nginx/modules/ngx_http_image_filter_module.so";
load_module "/etc/nginx/modules/ngx_http_set_misc_module.so";
load_module "/etc/nginx/modules/ngx_http_vhost_traffic_status_module.so";
load_module "/etc/nginx/modules/ngx_http_xslt_filter_module.so";
load_module "/etc/nginx/modules/ngx_mail_module.so";
load_module "/etc/nginx/modules/ngx_stream_module.so";

# Worker Config
events {
	worker_connections 4000;
	use epoll;
	multi_accept on;
}

# Main Config
http {
	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log off;
	error_log /var/log/nginx/error.log crit;
# Mime settings
    include			/etc/nginx/mime.types;
    default_type		application/octet-stream;
 
	more_set_headers    "Server: Custom Nginx";
	more_set_headers "X-Powered-By: NGINX";
#config for websocket	
	map \$http_upgrade \$connection_upgrade {
							default upgrade;
							'' close;
	}
	
	# SSL complaint
	ssl_protocols	TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";

	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:50m;
	ssl_session_timeout 1d;
	ssl_session_tickets off;

	#Cross-site-Scriping & Iframe Restrict:
	#add_header X-Frame-Options SAMEORIGIN;
	#add_header X-Content-Type-Options nosniff;
	#add_header X-XSS-Protection: "1; mode=block, 1; mode=block";

    sendfile on;
    sendfile_max_chunk 512k;
    tcp_nopush on;
    tcp_nodelay on;
	types_hash_max_size 2048;
	server_tokens off;
	server_name_in_redirect off;
	server_names_hash_bucket_size 512;
	server_names_hash_max_size 512;
	variables_hash_max_size 1024;
	variables_hash_bucket_size 128;
	open_file_cache	max=20000 inactive=20s;
	open_file_cache_valid 30s;
	open_file_cache_min_uses 2;
	open_file_cache_errors off;
	open_log_file_cache max=10000 inactive=30s min_uses=2;
	output_buffers 	8 256k;
	postpone_output 1460;
	request_pool_size 32k;
    connection_pool_size 512;
	directio 4m;
    client_body_buffer_size 256k;
	client_body_timeout 1m;
	client_header_buffer_size 2k;
	client_body_in_file_only off;
	large_client_header_buffers 4 8k;
	client_header_timeout 15;
	ignore_invalid_headers on; 
	client_max_body_size 100m;
    
	keepalive_timeout 15 15;
	keepalive_requests 1000;
	keepalive_disable msie6;
	lingering_time 20s;
	lingering_timeout 5s;
	# allow the server to close connection on non responding client, this will free up memory
	reset_timedout_connection on;
	send_timeout 30;
# Compression
	gzip on;
	#gzip_static on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied expired no-cache no-store private auth;
	gzip_comp_level 1;
	#gzip_buffers 8 64k;
	gzip_min_length 10240;
	gzip_types 
		text/css
        text/javascript
        text/xml
        text/plain
        text/x-component
        application/javascript
        application/x-javascript
        application/json
        application/xml
        application/rss+xml
        application/atom+xml
        font/truetype
        font/opentype
        application/vnd.ms-fontobject
        image/svg+xml;
	
	# Cloudflare module cho nginx
	real_ip_header CF-Connecting-IP;

	include /etc/nginx/conf.d/*.conf;
}

END

echo "complete!"