#!/bin/bash

# Informacaes de conexao da instancia de banco de dados."
DB_HOST=127.0.0.1
DB_PORTA=5432

# Obtem o IP do Servidor
IP=$(hostname -I | cut -f1 -d' ')

# Versoes
POSTGRES_VERSAO=13
VERSAO_IEDUCAR=2.6.5
VERSAO_IDIARIO=1.3.3

# Atribui Configuracao
sed_configuracao() {
	orig=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 1 | head -n 1)
	origparm=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 3 | head -n 1)
		if [[ -z $origparm ]];then
			origparm=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 2 | head -n 1)
		fi
	dest=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 1 | head -n 1)
	destparm=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 3 | head -n 1)
		if [[ -z $destparm ]];then
			destparm=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 2 | head -n 1)
		fi
case ${dest} in
	\#${orig})
			sed -i "/^$dest.*$destparm/c\\${1}" $2
		;;
	\;${orig})
			sed -i "/^$dest.*$destparm/c\\${1}" $2
		;;
	${orig})
			if [[ $origparm != $destparm ]]; then
				sed -i "/^$orig/c\\${1}" $2
				else 
					if [[ -z $(grep '[A-Z\_A-ZA-Z]$origparm' $2) ]]; then
						fullorigparm3=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 3 | head -n 1) 
						fullorigparm4=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 4 | head -n 1)
						fullorigparm5=$(echo $1 | tr -s ' ' '|' | cut -d '|' -f 5 | head -n 1)
						fulldestparm3=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 3 | head -n 1)
						fulldestparm4=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 4 | head -n 1)
						fulldestparm5=$(grep -E "^(#|\;|)$orig" $2 | tr -s ' ' '|' | cut -d '|' -f 5 | head -n 1)
						sed -i "/^$dest.*$fulldestparm3\ $fulldestparm4\ $fulldestparm5/c\\$orig\ \=\ $fullorigparm3\ $fullorigparm4\ $fullorigparm5" $2
					fi
			fi
		;;
		*)
			echo ${1} >> $2
		;;
	esac
}

clear
echo ""
echo "BEM VINDO AO GERENCIADOR DE INSTALACAO DO i-Educar e i-Diario"
echo ""
echo "1 - INSTALA SOMENTE O i-Educar"
echo "2 - INSTALA O i-Educar E O PACOTE DE RELATORIOS"
echo "3 - INSTALA SOMENTE O i-Diario"
echo "4 - INSTALA O i-Educar e o i-Diario"
echo "5 - INSTALA O i-Educar, PACOTE DE RELATORIOS E O i-Diario"
echo ""
read -p "SELECIONE A OPCAO E PRESSIONE ENTER! " OPC
echo ""

instalacao_Base() {
	sleep 2
	RELEASE=$(cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -c18-30)
	case "$RELEASE" in
		focal)
			echo "===> UBUNTU 20.04"
		sleep 2
		;;
		*)
			echo "===> RELEASE INVALIDA"
		sleep 2
		exit
		;;
	esac

	echo "===> ATUALIZANDO E INSTALANDO LIBS BASE DO SISTEMA OPERACIONAL"
	sleep 2
	sudo apt update -y
	sudo apt upgrade -y
	sudo apt install -y git wget curl zip unzip net-tools build-essential software-properties-common bash-completion
}

# PostgreSQL
instalacao_Postgres() {

echo "===> INSTALANDO POSTGRESQL 13"
sleep 2
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | sudo tee  /etc/apt/sources.list.d/pgdg.list
sudo apt update -y

sudo apt install -y postgresql-$POSTGRES_VERSAO postgresql-client-$POSTGRES_VERSAO

echo "===> CONFIGURANDO POSTGRESQL"
sleep 2
pg_dropcluster --stop $POSTGRES_VERSAO main
pg_createcluster -u postgres -g postgres $POSTGRES_VERSAO main

echo "===> LIBERANDO AUTENTICACAO EXTERNA NO POSTGRESQL"
sleep 2
echo > /etc/postgresql/$POSTGRES_VERSAO/main/pg_hba.conf
cat << PG_HBA > /etc/postgresql/$POSTGRES_VERSAO/main/pg_hba.conf
local   all             postgres                                trust

local   all             all                                     trust
host    all             all             all            			trust
host    all             all             ::1/128                 trust

local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
PG_HBA

PGPATH=/etc/postgresql/$POSTGRES_VERSAO/main/postgresql.conf
sed_configuracao "listen_addresses = '*'" "$PGPATH"
sed_configuracao "max_connections = '250'" "$PGPATH"

echo "===> INICIANDO POSTGRESQL"
sleep 2
/etc/init.d/postgresql restart

sudo -u postgres psql postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sleep 2
}

# i-Educar
instalacao_iEducar() {

echo "===> INSTALANDO LIBS BASE i-Educar"
sleep 2
sudo apt install -y openjdk-8-jre

DB_BASE_IEDUCAR=ieducar
DB_USUARIO_IEDUCAR=ieducar
DB_PASSWORD_IEDUCAR=$(openssl passwd -crypt $DB_USUARIO_IEDUCAR)

echo "===> CRIANDO DATABASE DO i-Educar"
sleep 2
psql -U postgres -c "CREATE ROLE $DB_USUARIO_IEDUCAR WITH LOGIN PASSWORD '$DB_PASSWORD_IEDUCAR';"
psql -U postgres -c "CREATE DATABASE $DB_BASE_IEDUCAR OWNER $DB_USUARIO_IEDUCAR"
psql -U postgres -c "GRANT postgres TO $DB_USUARIO_IEDUCAR;"
psql -U postgres -c "ALTER USER $DB_USUARIO_IEDUCAR WITH SUPERUSER;"

echo "===> FAZENDO DOWNLOAD DO PACOTE DO i-Educar"
sleep 2
wget https://github.com/portabilis/i-educar/releases/download/$VERSAO_IEDUCAR/ieducar-$VERSAO_IEDUCAR.tar.gz -O /tmp/ieducar-$VERSAO_IEDUCAR.tar.gz

echo "===> CONFIGURANDO USUARIO SSH"
sleep 2
IEDUCAR_SSH_PASSWORD=$(openssl passwd -crypt ieducar)
sudo useradd -d /home/ieducar -g www-data -G sudo,www-data -k /etc/skel -m -s /bin/bash -p $IEDUCAR_SSH_PASSWORD ieducar

echo "===> INSTALANDO PHP 7.4"
sleep 2
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update -y
sudo apt install -y php7.4-fpm php7.4-common php7.4-zip php7.4-pgsql php7.4-curl php7.4-xml php7.4-xmlrpc php7.4-json php7.4-pdo php7.4-gd php7.4-imagick php7.4-ldap php7.4-imap php7.4-mbstring php7.4-intl php7.4-cli php7.4-tidy php7.4-bcmath php7.4-opcache

echo "===> CONFIGURANDO PHP 7.4"
sleep 2
PHP_PATH=/etc/php/7.4/fpm/php.ini
sed_configuracao "upload_max_filesize = '2048M'" "$PHP_PATH"
sed_configuracao "post_max_size = '2048M'" "$PHP_PATH"
sed_configuracao "max_execution_time = '300'" "$PHP_PATH"

PHP_WWW_PATH=/etc/php/7.4/fpm/pool.d/www.conf
sed_configuracao "request_terminate_timeout = '300'" "$PHP_WWW_PATH"

echo "===> INSTALANDO NGNIX"
sleep 2
sudo apt install -y nginx

echo "===> CONFIGURANDO VIRTUAL HOST i-Educar"
sleep 2
echo > /etc/nginx/conf.d/ieducar.conf
cat << NGNIX_IEDUCAR > /etc/nginx/conf.d/ieducar.conf
server {

    listen 80;

    server_name default_server;

    root /var/www/ieducar/public;
    index index.php index.html;

    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;

    location ~ ^/intranet/?$ {
        rewrite ^.*$ /intranet/index.php redirect;
    }

    location ~ /module/(.*)/(styles|scripts|imagens)/(.*) {
        rewrite ^/module/(.*)/(imagens|scripts|styles)/(.*)$ /intranet/$2/$3 break;
    }

    location ~ /module/(.*)/(.*) {
        rewrite ^/module/(.*/)(.*intranet/.*)$ /$2 redirect;
        rewrite ^/module/(.*/)(.*index\.php)$ /$2 redirect;
        rewrite ^/module/(.*/)(.*logof\.php)$ /intranet/logof.php redirect;
        rewrite ^/module/(.*/)(.*meusdados\.php)$ /intranet/meusdados.php redirect;
        rewrite ^/module/(.*/)(.*_xml.*)(\.php)$ /intranet/$2.php redirect;
        rewrite ^/module/(.*/)(.*erro_banco\.php)$ /intranet/erro_banco.php redirect;
        rewrite ^/module/(.*/)(.*educar_pesquisa_cliente_lst\.php)$ /intranet/educar_pesquisa_cliente_lst.php redirect;
        rewrite ^/module/(.*/)(.*educar_pesquisa_obra_lst\.php)$ /intranet/educar_pesquisa_obra_lst.php redirect;
        rewrite ^/module/(.*)$ /module/index.php last;
    }

    location ~ ^(/intranet.*\.php|/modules.*\.php|/module/) {
        rewrite ^(.*)$ /index.php$1;
    }

    location ~ \.php {
        fastcgi_read_timeout 300;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}
NGNIX_IEDUCAR

echo > /etc/nginx/conf.d/upstream.conf
cat << NGNIX_UPSTREAM_IEDUCAR > /etc/nginx/conf.d/upstream.conf
upstream php-fpm {
    server unix:/run/php/php7.4-fpm.sock;
}
NGNIX_UPSTREAM_IEDUCAR

sudo rm -v /etc/nginx/sites-enabled/default
sudo service nginx restart

echo "===> EXTRAINDO PACOTE DO i-Educar"
sleep 2
[ -d /var/www ] || mkdir -p /var/www
tar -zxf /tmp/ieducar-$VERSAO_IEDUCAR.tar.gz -C /var/www/
mv /var/www/ieducar-$VERSAO_IEDUCAR /var/www/ieducar

echo "===> REINICIANDO SERVICO DO PHP7.4-FPM"
sleep 2
sudo service php7.4-fpm restart

echo "===> INSTALANDO COMPOSER"
cd /tmp
curl -sS https://getcomposer.org/installer -o composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

echo "===> AJUSTANDO PERMISSOES DO i-Educar"
sleep 2
sudo chown -R www-data:www-data /var/www/ieducar

echo "===> CONFIGURANDO ARQUIVO ENVIROMENT DO i-Educar"
sleep 2

sudo cat << ENV > /var/www/ieducar/.env
APP_NAME=i-Educar
APP_ENV=production
APP_KEY=base64:DjkHU/qQgA2pJUKjClLssG2NDiK37/Ff+U0G8SB38Eg=
APP_DEBUG=false
APP_URL=http://localhost
APP_TIMEZONE=America/Sao_Paulo
APP_TRACK_ERROR=false
APP_DEFAULT_HOST=ieducar.com.br

API_ACCESS_KEY=
API_SECRET_KEY=

LEGACY_CODE=true
LEGACY_DISPLAY_ERRORS=false
LEGACY_PATH=ieducar

LOG_CHANNEL=stack

TELESCOPE_ENABLED=false

DB_CONNECTION=pgsql
DB_HOST=`echo $DB_HOST`
DB_PORT=`echo $DB_PORTA`
DB_DATABASE=`echo $DB_BASE_IEDUCAR`
DB_USERNAME=`echo $DB_USUARIO_IEDUCAR`
DB_PASSWORD=`echo $DB_PASSWORD_IEDUCAR`

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"

HONEYBADGER_API_KEY=

GOOGLE_TAG_MANAGER=

FILESYSTEM_DRIVER=local

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=
AWS_BUCKET=

MIX_SOCKET_SERVER=127.0.0.1
MIX_SOCKET_PORT=6001

ENV

echo "===> INSTALANDO i-Educar"
cd /var/www/ieducar
	yes | composer new-install
}

# i-Educar - Pacote de Relatorios
instalacao_PacoteRelatorios_iEducar() {
	echo "===> INSTALANDO PACOTE DE RELATORIOS no i-Educar"
	cd /var/www/ieducar && rm -rf packages/portabilis/i-educar-reports-package
	git clone https://github.com/portabilis/i-educar-reports-package.git packages/portabilis/i-educar-reports-package
	yes | composer update --plug-and-play
	php artisan reports:install
}

# i-Diario
instalacao_iDiario() {
echo "===> INSTALANDO LIBS BASE i-Diario"
sleep 2
sudo apt install -y libpq-dev redis-server nodejs npm cmdtest

#if [ ! -d /etc/nginx ]
#then
#	echo "===> INSTALANDO NGNIX"
#	sleep 2
#	sudo apt install -y nginx
#else
#	echo "===> NGNIX JA INSTALADO"
#fi
#
#echo "===> CONFIGURANDO VIRTUAL HOST i-Di�rio"
#sleep 2
#echo > /etc/nginx/conf.d/idiario.conf
#cat << NGNIX_IDIARIO > /etc/nginx/conf.d/idiario.conf
#server {
#  listen 81;
#  server_name `echo $IP`;
#  passenger_enabled on;
#  root /var/www/idiario;
#}
#NGNIX_IDIARIO

echo "===> INSTALANDO GERENCIADOR DE VERSOES RUBY"
sleep 2
curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
rvm requirements

echo "===> INSTALANDO RUBY 2.4.10"
sleep 2
rvm install 2.4.10

echo "===> FAZENDO DOWNLOAD DO PACOTE DO i-Diario"
wget https://github.com/portabilis/i-diario/archive/refs/tags/$VERSAO_IDIARIO.tar.gz -O /tmp/i-diario-$VERSAO_IDIARIO.tar.gz

echo "===> EXTRAINDO PACOTE DO i-Diario"
sleep 2
[ -d /var/www ] || mkdir -p /var/www
tar -zxf /tmp/i-diario-$VERSAO_IDIARIO.tar.gz -C /var/www/
mv /var/www/i-diario-$VERSAO_IDIARIO /var/www/idiario
cd /var/www/idiario

echo "===> CONFIGURANDO USUARIO SSH"
sleep 2
IDIARIO_SSH_PASSWORD=$(openssl passwd -crypt idiario)
sudo useradd -d /home/idiario -g www-data -G sudo,www-data -k /etc/skel -m -s /bin/bash -p $IDIARIO_SSH_PASSWORD idiario

#echo "===> INSTALANDO A GEM PASSENGER"
#sleep 2
#gem install passenger
#
#echo "===> INSTALANDO CONFIGURACAO NECESSARIA DO PASSENGER"
#sleep 2
#rvmsudo passenger-install-nginx-module

echo "===> INSTALANDO A GEM BUNDLER"
sleep 2
gem install bundler -v '1.17.3'

echo "===> INSTALANDO AS GEMS"
sleep 2
bundle install

echo "===> INSTALANDO YARN"
sleep 2
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sleep 2
sudo apt update -y
sudo apt install -y yarn
sudo yarn install --check-files

echo "===> GERANDO CHAVE SECRETA"
sleep 2
CHAVE_SECRETA_PRODUCTION=$(bundle exec rake secret)
CHAVE_SECRETA_DEVELOPMENT=$(bundle exec rake secret)
CHAVE_SECRETA_TEST=$(bundle exec rake secret)

echo "===> CRIANDO ARQUIVO DE SECRETS"
sleep 2
sudo cat << CONFIG_SECRETS > /var/www/idiario/config/secrets.yml
production:
  secret_key_base: $CHAVE_SECRETA_PRODUCTION
  SMTP_ADDRESS: SMTP_ADDRESS
  SMTP_PORT: SMTP_PORT
  SMTP_DOMAIN: SMTP_DOMAIN
  SMTP_USER_NAME: SMTP_USER_NAME
  SMTP_PASSWORD: SMTP_PASSWORD
  NO_REPLY_ADDRESS: NO_REPLY_ADDRESS
  EMAIL_SKIP_DOMAINS: EMAIL_SKIP_DOMAINS
  STUDENT_DOMAIN: STUDENT_DOMAIN

development:
  secret_key_base: $CHAVE_SECRETA_DEVELOPMENT
  SMTP_ADDRESS: SMTP_ADDRESS
  SMTP_PORT: SMTP_PORT
  SMTP_DOMAIN: SMTP_DOMAIN
  SMTP_USER_NAME: SMTP_USER_NAME
  SMTP_PASSWORD: SMTP_PASSWORD
  NO_REPLY_ADDRESS: NO_REPLY_ADDRESS
  EMAIL_SKIP_DOMAINS: EMAIL_SKIP_DOMAINS
  STUDENT_DOMAIN: STUDENT_DOMAIN

test:
  secret_key_base: $CHAVE_SECRETA_TEST
  SMTP_ADDRESS: SMTP_ADDRESS
  SMTP_PORT: SMTP_PORT
  SMTP_DOMAIN: SMTP_DOMAIN
  SMTP_USER_NAME: SMTP_USER_NAME
  SMTP_PASSWORD: SMTP_PASSWORD
  NO_REPLY_ADDRESS: NO_REPLY_ADDRESS
  EMAIL_SKIP_DOMAINS: EMAIL_SKIP_DOMAINS
  STUDENT_DOMAIN: STUDENT_DOMAIN
CONFIG_SECRETS

#Para usar AWS S3, basta colocar no secrets as seguintes chaves, alterando para valores reais:
#
#AWS_ACCESS_KEY_ID: 'xxx'
#AWS_SECRET_ACCESS_KEY: 'xxx'
#AWS_REGION: 'us-east-1'
#AWS_BUCKET: 'bucket_name'
#
#Se quiser customizar para onde vai o upload de documentos, caso queira mandar para um lugar diferente das imagens pode usar as secrets abaixo:
#
#DOC_UPLOADER_AWS_ACCESS_KEY_ID: 'xxx'
#DOC_UPLOADER_AWS_SECRET_ACCESS_KEY: 'xxx'
#DOC_UPLOADER_AWS_REGION: 'us-east-1'
#DOC_UPLOADER_AWS_BUCKET: 'bucket_name'

DB_BASE_IDIARIO=idiario
DB_USUARIO_IDIARIO=idiario
DB_PASSWORD_IDIARIO=$(openssl passwd -crypt $DB_USUARIO_IDIARIO)

echo "===> CRIANDO DATABASE DO i-Diario"
sleep 2
psql -U postgres -c "CREATE ROLE $DB_USUARIO_IDIARIO WITH LOGIN PASSWORD '$DB_PASSWORD_IDIARIO';"
psql -U postgres -c "GRANT postgres TO $DB_USUARIO_IDIARIO;"
psql -U postgres -c "ALTER USER $DB_USUARIO_IDIARIO WITH SUPERUSER;"
sleep 2

echo "===> CRIANDO ARQUIVO DE CONFIGURACAO DE BANCO DE DADOS DO i-Diario"
sleep 2
sudo cat << CONFIG_DATABASE > /var/www/idiario/config/database.yml
default: &default
  adapter: postgresql
  encoding: utf8
  pool: 20
  timeout: 5000
  username: $DB_USUARIO_IDIARIO
  password: $DB_PASSWORD_IDIARIO
  host: $DB_HOST
  port: $DB_PORTA

production:
  <<: *default
  database: idiario_production

development:
  <<: *default
  database: idiario_development

test:
  <<: *default
  database: idiario_test

CONFIG_DATABASE

echo "===> CRIANDO BANCO DE DADOS"
sleep 2
bundle exec rake db:create

echo "===> POPULANDO BANCO DE DADOS"
sleep 2
bundle exec rake db:migrate

echo "===> CRIANDO PAGINAS 400 E 500 CONFORME MODELO"
sleep 2
cp public/404.html.sample public/404.html
cp public/500.html.sample public/500.html

ENTITY=prefeitura
ADMIN_PORTAL_SENHA_IDIARIO=123456789

echo "===> bundle exec rake entity:setup"
sleep 2
bundle exec rake entity:setup NAME=$ENTITY DOMAIN=$IP DATABASE=$DB_BASE_IDIARIO
bundle exec rake entity:admin:create NAME=$ENTITY ADMIN_PASSWORD=$ADMIN_PORTAL_SENHA_IDIARIO

#echo "===> CRIANDO ARQUIVO DE APOIO A CRIACAO DO USUARIO DE ADMINISTRACAO"
#sleep 2
#ADMIN_PORTAL_USUARIO_IDIARIO=admin.idiario@domain.com.br
#sudo cat << CONFIG_USER_ADMINISTRATOR > /tmp/config-user-administrator.rb
#Entity.last.using_connection {
#  User.create!(
#    email: '$ADMIN_PORTAL_USUARIO_IDIARIO',
#    password: '$ADMIN_PORTAL_SENHA_IDIARIO',
#    password_confirmation: '$ADMIN_PORTAL_SENHA_IDIARIO',
#    status: 'active',
#    kind: 'employee',
#    admin: true,
#    first_name: 'Admin'
#  )
#}
#CONFIG_USER_ADMINISTRATOR

#echo "===> CRIANDO O USUARIO DE ADMINISTRACAO"
#sleep 2
#bundle exec rails runner /tmp/config-user-administrator.rb

# TODO
# alias restart_rails='kill -9 `cat tmp/pids/server.pid`; rails server -d'

#echo "===> CRIANDO SCRIPT DE INICIALIZACAO DO i-Diario"
#echo > /etc/init.d/idiario.sh
#cat << STARTUP_IDIARIO > /etc/init.d/idiario.sh
##!/bin/bash
#### BEGIN INIT INFO
## Provides: APPLICATION
## Required-Start: $all
## Required-Stop: $network $local_fs $syslog
## Default-Start: 2 3 4 5
## Default-Stop: 0 1 6
## Short-Description: Start the APPLICATION unicorns at boot
## Description: Enable APPLICATION at boot time.
#### END INIT INFO
##
## Use this as a basis for your own Unicorn init script.
## Change APPLICATION to match your app.
## Make sure that all paths are correct.
#
#set -u
#set -e
#
## Change these to match your app:
#USER_NAME=$USER_NAME
#APP_NAME=idiario
#APP_ROOT="/var/www/$APP_NAME/current"
#PID="/var/www/$APP_NAME/tmp/pids/server.pid"
#ENV=production
#
#GEM_HOME="/home/$USER_NAME/.rvm/gems/ruby-1.9.3-p194"
#
#APP_OPTS="-d -b 0.0.0.0 -D -E $ENV -c $APP_ROOT/config/server.pid"
#
#APP_PATH="cd $APP_ROOT; rvm use 1.9.3; export GEM_HOME=$GEM_HOME"
#CMD="$APP_PATH; bundle exec server $APP_OPTS"
#
#old_pid="$PID.oldbin"
#
#cd $APP_ROOT || exit 1
#
#sig () {
#test -s "$PID" && kill -$1 `cat $PID`
#}
#
#oldsig () {
#test -s $old_pid && kill -$1 `cat $old_pid`
#}
#
#case ${1-help} in
#start)
#sig 0 && echo >&2 "Already running" && exit 0
#su - $USER_NAME -c "$CMD"
#;;
#stop)
#sig QUIT && exit 0
#echo >&2 "Not running"
#;;
#force-stop)
#sig TERM && exit 0
#echo >&2 "Not running"
#;;
#restart|reload)
#sig HUP && echo reloaded OK && exit 0
#echo >&2 "Couldn't reload, starting '$CMD' instead"
#su - $USER_NAME -c "$CMD"
#;;
#upgrade)
#sig USR2 && exit 0
#echo >&2 "Couldn't upgrade, starting '$CMD' instead"
#su - $USER_NAME -c "$CMD"
#;;
#rotate)
#sig USR1 && echo rotated logs OK && exit 0
#echo >&2 "Couldn't rotate logs" && exit 1
#;;
#*)
#  echo >&2 "Usage: $0 <start|stop|restart|upgrade|rotate|force-stop>"
#  exit 1
#  ;;
#esac
#STARTUP_IDIARIO

echo "===> INICIANDO O i-Diario"
sleep 2
bundle exec rails server -d -b 0.0.0.0

# Processo 1 (Responsavel pela sincronizacao com o i-educar)
echo "===> INICIANDO PROCESSO DE SINCRONIZACAO COM O i-Educar"
sleep 2
bundle exec sidekiq -q synchronizer_enqueue_next_job -c 1 -d --logfile log/sidekiq.log

# Processo 2 (Responsavel pelos outros jobs)
echo "===> INICIANDO PROCESSO RESPONSAVEL PELOS OUTROS JOBS"
sleep 2
bundle exec sidekiq -c 10 -d --logfile log/sidekiq.log

echo "===> GERANDO KEYS PARA API DE INTEGRACAO"
sleep 2
API_ACCESS_KEY=$(bundle exec rake secret)
sleep 2
API_SECRET_KEY=$(bundle exec rake secret)
}

alteraSenhaMestrePostgres() {
	DB_PASSWORD_POSTGRES=$(openssl passwd -crypt postgres)
	echo "===> DEFININDO SENHA PARA O USUARIO postgres"
	sleep 2
	psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$DB_PASSWORD_POSTGRES';"
	
echo > /etc/postgresql/$POSTGRES_VERSAO/main/pg_hba.conf
cat << PG_HBA > /etc/postgresql/$POSTGRES_VERSAO/main/pg_hba.conf
local   all             postgres                                md5

local   all             all                                     md5
host    all             all             all               		md5
host    all             all             ::1/128                 md5

local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
PG_HBA

echo "===> REINICIANDO POSTGRESQL"
sleep 2
/etc/init.d/postgresql restart

}

echoIEducar() {
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++ i-Educar ++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "INSTALACAO TERMINADA."
echo "    ACESSE: http://"`echo $IP`"/login"
echo ""
echo "    Apos concluir o processo (para a opcao sem pacote de relatorios), acesse o servidor na raiz da instalacao, "
echo "     ou seja: /var/www/ieducar e executar o comando: php artisan db:seed --force "
echo ""
echo "    Isso se faz necessario devido ao processo de instalacao ter um bug que nao executa as seeds."
echo "    A execucao do comando serve para popular as tabelas de configuracoes iniciais da aplicacao."
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "INFORMACOES DE ACESSO AO BANCO DE DADOS"
echo "    HOST: " `echo $IP`
echo "    PORTA: " `echo $DB_PORTA`
echo "    DB_BASE_IEDUCAR: " `echo $DB_BASE_IEDUCAR`
echo "    DB_USUARIO_IEDUCAR: " `echo $DB_USUARIO_IEDUCAR`
echo "    DB_PASSWORD_IEDUCAR: " `echo $DB_PASSWORD_IEDUCAR`
echo ""
echo "SENHA do usuario postgres: " `echo $DB_PASSWORD_POSTGRES`
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "GUARDE AS CREDENCIAIS DE ACESSO DO ADMINISTRADOR DO PORTAL i-Educar: "
echo "    USUARIO: admin"
echo "    SENHA: 123456789"
echo ""
echo "GUARDE A SENHA SSH PARA USUARIO ieducar: " `echo $IEDUCAR_SSH_PASSWORD`
echo ""
}

echoIDiario() {
echo "++++++++++++++++++++++++++++++++++++++++++++++++++ i-Diario ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "INSTALACAO TERMINADA."
echo "    ACESSE: http://"`echo $IP`":3000"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "INFORMACOES DE ACESSO AO BANCO DE DADOS"
echo "    HOST: " `echo $IP`
echo "    PORTA: " `echo $DB_PORTA`
echo "    DB_BASE_IDIARIO: " `echo $DB_BASE_IDIARIO`
echo "    DB_USUARIO_IDIARIO: " `echo $DB_USUARIO_IDIARIO`
echo "    DB_PASSWORD_IDIARIO: " `echo $DB_PASSWORD_IDIARIO`
echo ""
echo "GUARDE AS CREDENCIAIS DE ACESSO DO ADMINISTRADOR DO PORTAL i-Diario: "
echo "    USUARIO: admin@domain.com.br"
echo "    SENHA: 123456789"
echo ""
echo "GUARDE AS CREDENCIAIS DA API DE INTEGRACAO DO i-Diario COM i-Educar: "
echo "    API_ACCESS_KEY: " `echo $API_ACCESS_KEY`
echo "    API_SECRET_KEY: " `echo $API_SECRET_KEY`
echo ""
echo "GUARDE A SENHA SSH PARA USUARIO idiario: " `echo $IDIARIO_SSH_PASSWORD`
echo ""
echo "INFORMACAO: Sempre que for fazer deploy, deve-se parar o sidekiq e depois reinicia-lo."
echo "    ps -ef | grep sidekiq | grep -v grep | awk '{print $2}' | xargs kill -TERM && sleep 20"
echo ""
echo "COMANDO PARA INICIAR O SIDEKIQ"
echo "    Processo 1 (Responsavel pela sincronizacao com o i-educar)"
echo "    bundle exec sidekiq -q synchronizer_enqueue_next_job -c 1 -d --logfile log/sidekiq.log"
echo ""
echo "    Processo 2 (Responsavel pelos outros jobs)"
echo "    bundle exec sidekiq -c 10 -d --logfile log/sidekiq.log"
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

# Fluxo Condicional de Instalacao
while read -r -t 0; do read -r; done
case "$OPC" in
    1)
	  instalacao_Base
	  instalacao_Postgres
      instalacao_iEducar
	  alteraSenhaMestrePostgres
	  echoIEducar
    ;;
    2)
	  instalacao_Base
	  instalacao_Postgres
      instalacao_iEducar
	  instalacao_PacoteRelatorios_iEducar
	  echoIEducar
    ;;
    3)
	  instalacao_Base
	  instalacao_Postgres
      instalacao_iDiario
	  alteraSenhaMestrePostgres
	  echoIDiario
    ;;
    4)
	  instalacao_Base
	  instalacao_Postgres
	  instalacao_iEducar
      instalacao_iDiario
	  alteraSenhaMestrePostgres
	  echoIEducar
	  echoIDiario
    ;;
    5)
	  instalacao_Base
	  instalacao_Postgres
      instalacao_iEducar
      instalacao_iDiario
	  alteraSenhaMestrePostgres
	  instalacao_PacoteRelatorios_iEducar
	  echoIEducar
	  echoIDiario
    ;;
    *)
      echo "===> OPCAO INVALIDA. FINALIZANDO A EXECUCAO DO SCRIPT."
	  exit 0
    ;;
esac
