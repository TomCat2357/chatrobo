# 基本イメージとしてUbuntuを使用
FROM ubuntu:22.04

# 必要なパッケージのインストール
RUN apt update && \
    apt install -y \
    apache2 wget vim libapache2-mod-auth-openidc cron
RUN DEBIAN_FRONTEND=noninteractive apt install -y \
    certbot python3-certbot-apache wget nano\
    && rm -rf /var/lib/apt/lists/*


# 必要なモジュールの有効化
RUN a2enmod proxy proxy_http proxy_wstunnel rewrite ssl auth_openidc

#CLOUDの種類をARGから持ってくる。
ARG CLOUD
ARG DOMAIN_NAME

# Apacheの設定ファイルを作成
RUN rm -f /etc/apache2/sites-available/default-sss.conf
RUN { \
     echo 'PassEnv DOMAIN_NAME'; \
     echo '<VirtualHost *:80>'; \
     echo '    ServerName ${DOMAIN_NAME}'; \
     echo '    Redirect permanent / https://${DOMAIN_NAME}'; \
     echo '</VirtualHost>'; \
     echo '<IfModule mod_ssl.c>'; \
     echo '<VirtualHost *:443>'; \
     echo '    ServerName ${DOMAIN_NAME}'; \
     echo '    SSLEngine on'; \
     echo '    Alias /auth /var/www/html/auth'; \
     echo '    Alias /logout /var/www/html/logout'; \
     echo '    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem'; \
     echo '    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem'; \
     echo '    ProxyPreserveHost On'; \
     echo '    RewriteEngine On'; \
     echo '    RewriteCond %{HTTP:Upgrade} websocket [NC]'; \
     echo '    RewriteCond %{HTTP:Connection} upgrade [NC]'; \
     echo '    RewriteRule /(.*) ws://streamlit:8501/$1 [P,L]'; \
     echo '    ProxyPass / http://streamlit:8501/'; \
     echo '    ProxyPassReverse / http://streamlit:8501/'; \
     echo '    <Location /settings>'; \
     echo '        RewriteEngine On'; \
     echo '        RewriteCond %{HTTP_REFERER} !^https://${DOMAIN_NAME}'; \
     echo '        RewriteRule ^ - [F]'; \
     echo '        ProxyPass http://flask:5000/f_settings'; \
     echo '        ProxyPassReverse http://flask:5000/f_settings'; \
     echo '    </Location>'; \
     echo '    <Location /save>'; \
     echo '        ProxyPass http://flask:5000/f_save'; \
     echo '        ProxyPassReverse http://flask:5000/f_save'; \
     echo '    </Location>'; \
     echo '    <Location /back>'; \
     echo '        ProxyPass http://flask:5000/f_back'; \
     echo '        ProxyPassReverse http://flask:5000/f_back'; \
     echo '    </Location>'; \
     echo '</VirtualHost>'; \
     echo '</IfModule>'; \
   } > /etc/apache2/sites-available/000-default.conf



# auth2.0用
RUN \
    if [ "${CLOUD}" = "AWS" ]; then \
        OIDCProviderMetadataURL='https://cognito-idp.${AWS_REGION_NAME}.amazonaws.com/${AWS_COGNITO_USERPOOL_ID}/.well-known/openid-configuration' && \
        LOGOUT_URL='https://${AWS_COGNITO_DOMAIN_NAME}.auth.${AWS_REGION_NAME}.amazoncognito.com/logout?client_id=${CLIENT_ID}&logout_uri=https://${DOMAIN_NAME}/logout' && \
        OIDCClientSecretLine='OIDCResponseType code'; \
    elif [ "${CLOUD}" = "Azure" ]; then \
        OIDCProviderMetadataURL='https://login.microsoftonline.com/${Azure_TENANT_ID}/v2.0/.well-known/openid-configuration' && \
        LOGOUT_URL='https://login.microsoftonline.com/${Azure_TENANT_ID}/oauth2/v2.0/logout?post_logout_redirect_uri=https://${DOMAIN_NAME}/logout_success'&& \
        OIDCClientSecretLine='OIDCClientSecret ${CLIENT_SECRET}'; \
    fi && \
    { \
    echo 'PassEnv Azure_TENANT_ID AWS_REGION_NAME AWS_COGNITO_DOMAIN_NAME AWS_COGNITO_USERPOOL_ID CLIENT_ID CLIENT_SECRET DOMAIN_NAME PASSPHRASE'; \
    echo 'ServerName ${DOMAIN_NAME}'; \
    echo "OIDCProviderMetadataURL ${OIDCProviderMetadataURL}"; \
    echo 'OIDCClientID ${CLIENT_ID}'; \
    echo "${OIDCClientSecretLine}"; \
    echo 'OIDCRedirectURI https://${DOMAIN_NAME}/auth'; \
    echo 'OIDCCryptoPassphrase ${PASSPHRASE}'; \
    echo '<Location />'; \
    echo '    AuthType openid-connect'; \
    echo '    Require valid-user'; \
    echo '</Location>'; \
   echo '<Location /logout>'; \
   echo '    AuthType openid-connect'; \
   echo '    OIDCUnAuthAction 401'; \
   echo "    RedirectMatch 302 ^/logout$ ${LOGOUT_URL}"; \
   echo '</Location>'; \
} >> /etc/apache2/apache2.conf

# /auth用のディレクトリとHTMLファイルの作成
RUN mkdir -p /var/www/html/auth && \
    echo "<html><body>認証されました</body></html>" > /var/www/html/auth/index.html

# /auth用のディレクトリとHTMLファイルの作成
RUN mkdir -p /var/www/html/logout && \
    echo "<html><body>ログアウトしました</body></html>" > /var/www/html/logout/index.html

#ENV DOMAIN_NAME=${DOMAIN_NAME}

# localhostのときだけ自己署名証明書を作る
RUN echo "${DOMAIN_NAME}"
RUN if [ "${DOMAIN_NAME}" = "localhost" ]; then \
    mkdir -p /etc/letsencrypt/live/${DOMAIN_NAME} && \
    openssl genrsa -out /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem 2048 && \
    openssl req -new -key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem -out /etc/letsencrypt/live/${DOMAIN_NAME}/csr.pem -subj "/CN=${DOMAIN_NAME}" && \
    openssl x509 -req -days 365 -in /etc/letsencrypt/live/${DOMAIN_NAME}/csr.pem -signkey /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem -out /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem ;\
    fi
    


# Certbotの自動更新設定
RUN echo "0 12 * * * root certbot renew --quiet --no-self-upgrade --post-hook 'apache2ctl graceful'" >> /etc/crontab

# 初期設定用のスクリプトを作成し、実行権限を付与
RUN echo '#!/bin/bash'"\n"\
'# Certbotの設定'"\n"\
#'certbot --apache --non-interactive --agree-tos --email ${EMAIL} -d ${DOMAIN_NAME} --redirect'"\n"\
'# cronデーモンの起動'"\n"\
#'cron'"\n"\
'# Apacheが既に実行中かどうかを確認'"\n"\
'if ! pidof apache2 > /dev/null; then'"\n"\
'    echo "Starting Apache..."'"\n"\
'    apache2ctl -D FOREGROUND'"\n"\
'else'"\n"\
'    echo "Apache is already running. Keeping it running."'"\n"\
'    tail -f /dev/null'"\n"\
'fi' > /init-setup.sh && chmod +x /init-setup.sh



# コンテナ起動時にinit.shスクリプトを実行
CMD ["/bin/bash", "-c", "/init-setup.sh"]
#CMD ["tail", "-f", "/dev/null"]
#CMD ["apache2ctl", "-D", "FOREGROUND"]
