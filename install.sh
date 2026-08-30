#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_NAME='J&Z Panel'
APP_DIR="${JZ_PANEL_DIR:-/var/www/jz-panel}"
WINGS_DIR="${JZ_WINGS_DIR:-/etc/pterodactyl}"
WINGS_BIN='/usr/local/bin/wings'
LOG_FILE="${JZ_INSTALL_LOG:-/var/log/jz-panel-install.log}"
REPO="https://github.com/Kabin909/J-ZPanel.git"
TARBALL="https://github.com/Kabin909/J-ZPanel/archive/refs/heads/main.tar.gz"

ORANGE='\033[38;5;208m'; WHITE='\033[1;37m'; GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; DIM='\033[2m'; NC='\033[0m'
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

say(){ printf '%b\n' "${ORANGE}${WHITE}$*${NC}"; }
ok(){ printf '%b\n' "${GREEN}✅${NC} $*"; }
warn(){ printf '%b\n' "${YELLOW}⚠️${NC} $*"; }
err(){ printf '%b\n' "${RED}❌${NC} $*" >&2; }
die(){ err "$*"; exit 1; }
step(){ printf '\n%b\n' "${ORANGE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; say "$1"; }
trap 'rc=$?; if ((rc)); then err "Installer stopped with exit code $rc"; warn "Log: $LOG_FILE"; fi' EXIT

banner(){
  printf '%b\n' "${ORANGE}╔════════════════════════════════════════════════════════════╗${NC}"
  printf '%b\n' "${ORANGE}║${WHITE}                     🚀 J&Z PANEL                          ${ORANGE}║${NC}"
  printf '%b\n' "${ORANGE}║${WHITE}             Minecraft Server Management                   ${ORANGE}║${NC}"
  printf '%b\n' "${ORANGE}║${WHITE}                  🟧 Panel + 🪽 Wings                      ${ORANGE}║${NC}"
  printf '%b\n' "${ORANGE}╚════════════════════════════════════════════════════════════╝${NC}"
}

usage(){ cat <<USAGE
${APP_NAME} installer

Usage:
  sudo bash install.sh
  sudo bash install.sh --panel
  sudo bash install.sh --wings
  sudo bash install.sh --panel-wings
  sudo bash install.sh --repair
  sudo bash install.sh --uninstall-panel
  sudo bash install.sh --uninstall-wings
  sudo bash install.sh --uninstall-all

Options:
  --domain DOMAIN
  --node-fqdn FQDN
  --node-ip IP
  --web-server nginx|apache
  --ssl letsencrypt|existing|http
  --non-interactive
  --repair
  --uninstall-panel
  --uninstall-wings
  --uninstall-all
  --help
USAGE
}

[[ $EUID -eq 0 ]] || die 'Run as root: sudo bash install.sh'
command -v apt-get >/dev/null || die 'Debian/Ubuntu with apt-get is required.'
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "Unsupported OS: ${PRETTY_NAME:-unknown}" ;; esac
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in amd64|arm64) ;; *) die "Unsupported architecture: $ARCH" ;; esac

INSTALL_PANEL=false; INSTALL_WINGS=false; NON_INTERACTIVE=false; REPAIR=false; UNINSTALL_PANEL=false; UNINSTALL_WINGS=false; UNINSTALL_ALL=false
DOMAIN="${JZ_DOMAIN:-}"; NODE_FQDN="${JZ_NODE_FQDN:-}"; NODE_IP="${JZ_NODE_IP:-}"; WEB_SERVER='nginx'; SSL_MODE='http'
DB_DATABASE="${DB_DATABASE:-panel}"; DB_USERNAME="${DB_USERNAME:-pterodactyl}"; DB_PASSWORD="${DB_PASSWORD:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"; ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"; ADMIN_FIRST_NAME="${ADMIN_FIRST_NAME:-Admin}"; ADMIN_LAST_NAME="${ADMIN_LAST_NAME:-User}"; ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
NODE_NAME="${JZ_NODE_NAME:-node-01}"; NODE_LOCATION="${JZ_NODE_LOCATION:-local}"; NODE_PORT="${JZ_NODE_PORT:-8080}"; NODE_SFTP="${JZ_NODE_SFTP:-2022}"

while [[ $# -gt 0 ]]; do
 case "$1" in
  --panel) INSTALL_PANEL=true; shift;;
  --wings) INSTALL_WINGS=true; shift;;
  --panel-wings) INSTALL_PANEL=true; INSTALL_WINGS=true; shift;;
  --repair) REPAIR=true; shift;;
  --uninstall-panel) UNINSTALL_PANEL=true; shift;;
  --uninstall-wings) UNINSTALL_WINGS=true; shift;;
  --uninstall-all) UNINSTALL_ALL=true; shift;;
  --non-interactive) NON_INTERACTIVE=true; shift;;
  --domain) DOMAIN="${2:?Missing domain}"; shift 2;;
  --node-fqdn) NODE_FQDN="${2:?Missing node FQDN}"; shift 2;;
  --node-ip) NODE_IP="${2:?Missing node IP}"; shift 2;;
  --web-server) WEB_SERVER="${2:?Missing web server}"; shift 2;;
  --ssl) SSL_MODE="${2:?Missing SSL mode}"; shift 2;;
  --help|-h) usage; exit 0;;
  *) die "Unknown option: $1";;
 esac
done

banner
ok "System: ${PRETTY_NAME:-unknown} / ${ARCH}"
ok "Log: $LOG_FILE"

is_installed(){ [[ -d "$APP_DIR" && -f "$APP_DIR/artisan" ]]; }

repair_panel(){
 step '🛠️  Repairing J&Z Panel'
 [[ -f "$APP_DIR/artisan" ]] || die "Panel not found at $APP_DIR"
 cd "$APP_DIR"
 php artisan optimize:clear || true
 php artisan storage:link || true
 mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache
 chown -R www-data:www-data storage bootstrap/cache
 chmod -R ug+rwx storage bootstrap/cache
 php artisan optimize || true
 systemctl daemon-reload
 systemctl restart jz-panel-worker jz-panel-scheduler 2>/dev/null || true
 systemctl restart php8.3-fpm php8.2-fpm 2>/dev/null || true
 systemctl restart nginx apache2 2>/dev/null || true
 ok 'Panel repair completed.'
}

uninstall_panel(){
 step '🗑️  Uninstall J&Z Panel'
 warn "This removes the J&Z Panel application and panel services."
 if $NON_INTERACTIVE; then DELETE_DB=false; else read -r -p 'Delete the J&Z database too? [y/N]: ' a; [[ "$a" =~ ^[Yy]$ ]] && DELETE_DB=true || DELETE_DB=false; fi
 systemctl disable --now jz-panel-worker jz-panel-scheduler 2>/dev/null || true
 rm -f /etc/systemd/system/jz-panel-worker.service /etc/systemd/system/jz-panel-scheduler.service
 systemctl daemon-reload
 rm -f /usr/local/bin/jz-panel
 rm -f /etc/nginx/sites-enabled/jz-panel.conf /etc/nginx/sites-available/jz-panel.conf
 rm -f /etc/apache2/sites-enabled/jz-panel.conf /etc/apache2/sites-available/jz-panel.conf
 systemctl reload nginx 2>/dev/null || true; systemctl reload apache2 2>/dev/null || true
 if $DELETE_DB && command -v mysql >/dev/null; then
   mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_DATABASE\`; DROP USER IF EXISTS '$DB_USERNAME'@'127.0.0.1'; FLUSH PRIVILEGES;" || warn 'Database removal failed; check MariaDB manually.'
 fi
 if [[ -d "$APP_DIR" ]]; then
   if $NON_INTERACTIVE; then rm -rf "$APP_DIR"; else read -r -p "Delete $APP_DIR? [y/N]: " b; [[ "$b" =~ ^[Yy]$ ]] && rm -rf "$APP_DIR"; fi
 fi
 ok 'Panel uninstall completed.'
}

uninstall_wings(){
 step '🗑️  Uninstall Wings'
 systemctl disable --now wings 2>/dev/null || true
 rm -f /etc/systemd/system/wings.service
 systemctl daemon-reload
 rm -f "$WINGS_BIN"
 if $NON_INTERACTIVE; then DELETE_WINGS_DATA=false; else read -r -p "Delete Wings config/data directory $WINGS_DIR? [y/N]: " c; [[ "$c" =~ ^[Yy]$ ]] && DELETE_WINGS_DATA=true || DELETE_WINGS_DATA=false; fi
 $DELETE_WINGS_DATA && rm -rf "$WINGS_DIR"
 ok 'Wings uninstall completed. Docker was intentionally left installed.'
}

if $UNINSTALL_ALL; then UNINSTALL_PANEL=true; UNINSTALL_WINGS=true; fi
if $REPAIR; then repair_panel; exit 0; fi
if $UNINSTALL_PANEL; then uninstall_panel; fi
if $UNINSTALL_WINGS; then uninstall_wings; fi
if $UNINSTALL_PANEL || $UNINSTALL_WINGS; then exit 0; fi

if ! $INSTALL_PANEL && ! $INSTALL_WINGS; then
 if $NON_INTERACTIVE; then INSTALL_PANEL=true; else
  echo
  printf '%b\n' "${WHITE}1) 🟧 Panel${NC}"
  printf '%b\n' "${WHITE}2) 🪽 Wings${NC}"
  printf '%b\n' "${WHITE}3) 🚀 Panel + Wings${NC}"
  printf '%b\n' "${WHITE}4) 🗑️  Uninstall${NC}"
  printf '%b\n' "${WHITE}5) 🛠️  Repair${NC}"
  read -r -p 'Select [1-5]: ' c
  case "$c" in 1) INSTALL_PANEL=true;; 2) INSTALL_WINGS=true;; 3) INSTALL_PANEL=true; INSTALL_WINGS=true;; 4) UNINSTALL_ALL=true; uninstall_panel; uninstall_wings; exit 0;; 5) repair_panel; exit 0;; *) exit 0;; esac
 fi
fi

if ! $NON_INTERACTIVE; then
 if $INSTALL_PANEL; then
  read -r -p '🌐 Panel domain (example: panel.example.com, blank = VPS IP): ' DOMAIN
  read -r -p '🌍 Web server [nginx/apache] (default nginx): ' x; WEB_SERVER="${x:-nginx}"
  read -r -p '🔐 HTTPS [letsencrypt/existing/http] (default http): ' x; SSL_MODE="${x:-http}"
  if [[ "$SSL_MODE" == letsencrypt && -z "$DOMAIN" ]]; then die 'LetsEncrypt requires a domain.'; fi
 fi
 if $INSTALL_WINGS; then
  read -r -p '🖥️  Node public IP (example: 203.0.113.10): ' NODE_IP
  read -r -p '🔗 Wings FQDN (example: node.example.com, blank = IP): ' NODE_FQDN
  read -r -p '📛 Node name (default node-01): ' x; NODE_NAME="${x:-node-01}"
  read -r -p '📍 Node location short code (default local): ' x; NODE_LOCATION="${x:-local}"
  read -r -p '🪽 Wings API port (default 8080): ' x; NODE_PORT="${x:-8080}"
  read -r -p '📦 SFTP port (default 2022): ' x; NODE_SFTP="${x:-2022}"
 fi
fi

case "$WEB_SERVER" in nginx|apache) ;; *) die 'Web server must be nginx or apache.';; esac
case "$SSL_MODE" in letsencrypt|existing|http) ;; *) die 'SSL mode must be letsencrypt, existing, or http.';; esac

step '📦 Preparing base system'
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg unzip tar openssl rsync jq lsb-release git sudo mariadb-server mariadb-client redis-server
systemctl enable --now mariadb redis-server

# Remove duplicate PHP repository entries created by older J&Z installer versions.
if [[ -f /etc/apt/sources.list.d/php.list && -f /etc/apt/sources.list.d/sury-php.list ]] && cmp -s /etc/apt/sources.list.d/php.list /etc/apt/sources.list.d/sury-php.list; then rm -f /etc/apt/sources.list.d/php.list; fi

install_php(){
 apt-get install -y lsb-release ca-certificates apt-transport-https curl gnupg
 install -d -m 0755 /etc/apt/keyrings
 curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/keyrings/sury-php.gpg
 echo "deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(. /etc/os-release && echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/sury-php.list
 rm -f /etc/apt/sources.list.d/php.list
 apt-get update -y
 apt-get install -y php8.3 php8.3-cli php8.3-fpm php8.3-common php8.3-mysql php8.3-gd php8.3-curl php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-zip php8.3-intl php8.3-redis
 systemctl enable --now php8.3-fpm
}

if $INSTALL_PANEL; then
 step '🐘 Installing PHP / Composer / Node'
 if ! command -v php >/dev/null || ! php -r 'exit(version_compare(PHP_VERSION,"8.2","<") || version_compare(PHP_VERSION,"8.4",">=") ? 1 : 0);'; then install_php; fi
 if ! command -v composer >/dev/null; then curl -fsSL https://getcomposer.org/installer -o /tmp/composer.php; php /tmp/composer.php --install-dir=/usr/local/bin --filename=composer; rm -f /tmp/composer.php; fi
 if ! command -v node >/dev/null || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; apt-get install -y nodejs; fi
 command -v yarn >/dev/null || npm install -g yarn
 ok "PHP $(php -r 'echo PHP_VERSION;') | Node $(node -v) | Yarn $(yarn -v)"

 step '📥 Downloading J&Z Panel source'
 TMP_SRC="$(mktemp -d)"
 trap 'rm -rf "${TMP_SRC:-}"' RETURN
 curl -fL "$TARBALL" -o "$TMP_SRC/jz.tar.gz"
 tar -xzf "$TMP_SRC/jz.tar.gz" -C "$TMP_SRC"
 SRC_DIR="$(find "$TMP_SRC" -mindepth 1 -maxdepth 1 -type d | head -1)"
 [[ -f "$SRC_DIR/composer.json" && -f "$SRC_DIR/package.json" ]] || die 'GitHub archive does not contain composer.json and package.json.'
 mkdir -p "$APP_DIR"
 rsync -a --delete --exclude='.git' --exclude='node_modules' --exclude='vendor' "$SRC_DIR/" "$APP_DIR/"
 cd "$APP_DIR"

 step '🗄️  Configuring MariaDB / Redis'
 [[ -n "$DB_PASSWORD" ]] || DB_PASSWORD="$(openssl rand -hex 24)"
 MYSQL=(mysql -uroot)
 "${MYSQL[@]}" -e 'SELECT 1' >/dev/null 2>&1 || die 'MariaDB root login failed. Fix MariaDB root authentication and rerun.'
 # Deliberately use single-quoted shell variables and SQL identifier escaping without double escaping.
 DBQ="${DB_DATABASE//\`/\`\`}"
 "${MYSQL[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DBQ\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD'; ALTER USER '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON \`$DBQ\`.* TO '$DB_USERNAME'@'127.0.0.1'; FLUSH PRIVILEGES;"

 step '⚙️  Configuring application'
 cp -n .env.example .env || true
 php artisan key:generate --force
 export APP_URL_VALUE="${DOMAIN:+https://$DOMAIN}"
 [[ -n "$DOMAIN" ]] || APP_URL_VALUE="http://${NODE_IP:-127.0.0.1}"
 php -r '$p=".env"; $s=file_get_contents($p); $r=["APP_NAME"=>"J&Z Panel","APP_ENV"=>"production","APP_DEBUG"=>"false","APP_URL"=>getenv("APP_URL_VALUE"),"DB_HOST"=>"127.0.0.1","DB_PORT"=>"3306","DB_DATABASE"=>getenv("DB_DATABASE"),"DB_USERNAME"=>getenv("DB_USERNAME"),"DB_PASSWORD"=>getenv("DB_PASSWORD")]; foreach($r as $k=>$v){$s=preg_replace("/^".preg_quote($k,"/")."=.*/m",$k."=".str_replace(["\\n","\\r"],"",$v),$s,1,$n); if(!$n)$s.="\\n$k=$v";} file_put_contents($p,$s);' DB_DATABASE="$DB_DATABASE" DB_USERNAME="$DB_USERNAME" DB_PASSWORD="$DB_PASSWORD" APP_URL_VALUE="$APP_URL_VALUE"
 composer install --no-dev --optimize-autoloader --no-interaction
 yarn install --frozen-lockfile
 yarn run build:production
 php artisan migrate --seed --force
 php artisan storage:link || true
 php artisan optimize:clear
 php artisan optimize
 chown -R www-data:www-data "$APP_DIR"
 chmod -R ug+rwx "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"

 step '👤 Creating administrator'
 if [[ -z "$ADMIN_PASSWORD" ]]; then
   if $NON_INTERACTIVE; then ADMIN_PASSWORD="$(openssl rand -base64 24)"; else read -r -s -p '🔑 Admin password (leave blank to generate): ' ADMIN_PASSWORD; echo; [[ -n "$ADMIN_PASSWORD" ]] || ADMIN_PASSWORD="$(openssl rand -base64 24)"; fi
 fi
 if [[ -z "$ADMIN_EMAIL" ]]; then
   if $NON_INTERACTIVE; then ADMIN_EMAIL='admin@example.com'; else read -r -p '📧 Admin email: ' ADMIN_EMAIL; fi
 fi
 if php artisan list --raw | grep -q '^p:user:make'; then
   php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first="$ADMIN_FIRST_NAME" --name-last="$ADMIN_LAST_NAME" --password="$ADMIN_PASSWORD" --admin=1 || warn 'Admin may already exist; continuing.'
 else
   warn 'p:user:make is not available in this build. Create the admin from the supported application CLI.'
 fi

 step '🌐 Configuring web server'
 PHP_FPM_SOCK="$(find /run/php -maxdepth 1 -type s -name 'php*-fpm.sock' | sort -V | tail -1)"
 [[ -S "$PHP_FPM_SOCK" ]] || die 'Could not find PHP-FPM socket.'
 if [[ "$WEB_SERVER" == nginx ]]; then
   apt-get install -y nginx
   cat > /etc/nginx/sites-available/jz-panel.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN:-_};
    root ${APP_DIR}/public;
    index index.php;
    client_max_body_size 100m;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:${PHP_FPM_SOCK}; }
    location ~ /\.(?!well-known).* { deny all; }
}
NGINX
   ln -sfn /etc/nginx/sites-available/jz-panel.conf /etc/nginx/sites-enabled/jz-panel.conf
   rm -f /etc/nginx/sites-enabled/default
   nginx -t && systemctl enable --now nginx
 else
   apt-get install -y apache2 "libapache2-mod-php8.3"
   a2enmod rewrite headers ssl >/dev/null
   cat > /etc/apache2/sites-available/jz-panel.conf <<APACHE
<VirtualHost *:80>
 ServerName ${DOMAIN:-localhost}
 DocumentRoot ${APP_DIR}/public
 <Directory ${APP_DIR}/public>
  AllowOverride All
  Require all granted
 </Directory>
</VirtualHost>
APACHE
   a2dissite 000-default.conf >/dev/null 2>&1 || true
   a2ensite jz-panel.conf >/dev/null
   apachectl configtest && systemctl enable --now apache2
 fi
 if [[ "$SSL_MODE" == letsencrypt ]]; then
   apt-get install -y certbot
   if [[ "$WEB_SERVER" == nginx ]]; then apt-get install -y python3-certbot-nginx; certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect; else apt-get install -y python3-certbot-apache; certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect; fi
 fi

 step '⚙️  Installing Panel services'
 cat >/etc/systemd/system/jz-panel-worker.service <<SERVICE
[Unit]
Description=J&Z Panel Queue Worker
After=network.target redis-server.service
[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/php $APP_DIR/artisan queue:work --sleep=3 --tries=3 --timeout=90
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SERVICE
 cat >/etc/systemd/system/jz-panel-scheduler.service <<SERVICE
[Unit]
Description=J&Z Panel Scheduler
After=network.target
[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/php $APP_DIR/artisan schedule:work
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SERVICE
 systemctl daemon-reload
 systemctl enable --now jz-panel-worker jz-panel-scheduler

 cat >/usr/local/bin/jz-panel <<'CLI'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR='__APP_DIR__'
case "${1:-status}" in
 status) systemctl --no-pager --full status jz-panel-worker jz-panel-scheduler wings 2>/dev/null || true;;
 health) cd "$APP_DIR"; php artisan p:info;;
 repair) exec /usr/local/bin/jz-installer --repair;;
 backup) tar --exclude=storage/logs --exclude=node_modules --exclude=vendor -czf "/root/jz-panel-backup-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$APP_DIR" .env storage 2>/dev/null; echo 'Backup created in /root/';;
 logs) journalctl -u jz-panel-worker -u jz-panel-scheduler -n 200 --no-pager;;
 update) exec /usr/local/bin/jz-installer --panel;;
 uninstall) exec /usr/local/bin/jz-installer --uninstall-panel;;
 *) echo 'Usage: jz-panel {status|health|repair|backup|logs|update|uninstall}'; exit 2;;
esac
CLI
 sed -i "s#__APP_DIR__#$APP_DIR#g" /usr/local/bin/jz-panel
 chmod 755 /usr/local/bin/jz-panel
 ok "Panel ready: ${DOMAIN:+https://$DOMAIN}${DOMAIN:-http://${NODE_IP:-127.0.0.1}}"
fi

if $INSTALL_WINGS; then
 step '🪽 Installing Wings + Docker'
 apt-get install -y docker.io curl ca-certificates
 systemctl enable --now docker
 mkdir -p "$WINGS_DIR" /var/lib/pterodactyl/volumes
 case "$ARCH" in amd64) WA=amd64;; arm64) WA=arm64;; esac
 curl -fL "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WA}" -o "$WINGS_BIN"
 chmod 755 "$WINGS_BIN"
 cat >/etc/systemd/system/wings.service <<SERVICE
[Unit]
Description=J&Z Wings
After=docker.service
Requires=docker.service
[Service]
User=root
WorkingDirectory=$WINGS_DIR
ExecStart=$WINGS_BIN
Restart=on-failure
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
SERVICE
 systemctl daemon-reload

 if [[ -z "$NODE_IP" ]]; then NODE_IP="$(curl -4fsS https://api.ipify.org || true)"; fi
 [[ -n "$NODE_IP" ]] || warn 'Could not automatically detect public IP.'
 ok "Node IP: ${NODE_IP:-not detected}"
 ok "Wings FQDN: ${NODE_FQDN:-${NODE_IP:-not set}}"
 ok "Wings API: ${NODE_PORT} | SFTP: ${NODE_SFTP}"

 # Same-server automatic node setup when the panel CLI supports it.
 if $INSTALL_PANEL && [[ -f "$APP_DIR/artisan" ]] && php artisan list --raw | grep -q '^p:node:make'; then
   step '🔗 Creating Wings node in J&Z Panel'
   if ! php artisan list --raw | grep -q '^p:node:configuration'; then
     warn 'Node configuration command is unavailable; use the Panel node Configuration page.'
   else
     # Ensure a local location exists; ignore duplicate errors.
     php artisan p:location:make --short="$NODE_LOCATION" --long='J&Z local node location' >/tmp/jz-location.out 2>&1 || true
     LOCATION_ID="$(php artisan p:location:list --format=json 2>/dev/null | jq -r --arg s "$NODE_LOCATION" '.[] | select(.short==$s) | .id' | head -1)" || true
     if [[ -z "$LOCATION_ID" || "$LOCATION_ID" == 'null' ]]; then LOCATION_ID='1'; warn 'Could not discover location ID; using 1. Verify it in the Panel.'; fi
     TOTAL_MEM="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
     TOTAL_DISK="$(df -Pm / | awk 'NR==2 {print $4}')"
     SCHEME='http'; [[ "$SSL_MODE" == letsencrypt || "$DOMAIN" == https* ]] && SCHEME='https'
     FQDN="${NODE_FQDN:-$NODE_IP}"
     if php artisan p:node:make --name="$NODE_NAME" --description='J&Z Wings node' --locationId="$LOCATION_ID" --fqdn="$FQDN" --public=1 --scheme="$SCHEME" --proxy=0 --maintenance=0 --maxMemory="$TOTAL_MEM" --overallocateMemory=0 --maxDisk="$TOTAL_DISK" --overallocateDisk=0 --uploadSize=100 --daemonListeningPort="$NODE_PORT" --daemonSFTPPort="$NODE_SFTP" --daemonBase=/var/lib/pterodactyl/volumes >/tmp/jz-node-create.out 2>&1; then
       NODE_ID="$(grep -oE 'id of [0-9]+' /tmp/jz-node-create.out | awk '{print $3}' | tail -1)"
       if [[ -n "$NODE_ID" ]]; then
         php artisan p:node:configuration "$NODE_ID" > "$WINGS_DIR/config.yml"
         chmod 600 "$WINGS_DIR/config.yml"
         systemctl enable --now wings
         ok "Wings node $NODE_ID created and configured automatically."
       else
         warn 'Node was created but its ID could not be parsed. Run: php artisan p:node:list'
       fi
     else
       warn 'Automatic node creation failed. Create the node in the Panel and run the Wings auto-configure command shown there.'
       cat /tmp/jz-node-create.out || true
     fi
   fi
 elif [[ -f "$WINGS_DIR/config.yml" ]]; then
   chmod 600 "$WINGS_DIR/config.yml"
   systemctl enable --now wings
 else
   systemctl enable wings
   warn 'Wings is installed but has no config.yml yet.'
   warn "Create the node in J&Z Panel using FQDN ${NODE_FQDN:-$NODE_IP}, API ${NODE_PORT}, SFTP ${NODE_SFTP}."
   warn "Then run the generated Wings configuration command or place it at $WINGS_DIR/config.yml."
 fi

 if command -v ufw >/dev/null 2>&1; then
   ufw allow "$NODE_PORT/tcp" >/dev/null 2>&1 || true
   ufw allow "$NODE_SFTP/tcp" >/dev/null 2>&1 || true
 fi
fi

step '🩺 Final health check'
$INSTALL_PANEL && { systemctl is-active --quiet "$WEB_SERVER" 2>/dev/null && ok "$WEB_SERVER active" || warn "$WEB_SERVER not active"; systemctl is-active --quiet jz-panel-worker && ok 'Panel worker active' || warn 'Panel worker not active'; systemctl is-active --quiet jz-panel-scheduler && ok 'Panel scheduler active' || warn 'Panel scheduler not active'; }
$INSTALL_WINGS && { "$WINGS_BIN" --version || true; systemctl is-active --quiet docker && ok 'Docker active' || warn 'Docker not active'; systemctl is-active --quiet wings && ok 'Wings active' || warn 'Wings waiting for configuration'; }
printf '\n%b\n' "${ORANGE}╔════════════════════════════════════════════════════════════╗${NC}"
printf '%b\n' "${ORANGE}║${WHITE} 🎉 J&Z installation finished                            ${ORANGE}║${NC}"
printf '%b\n' "${ORANGE}║${WHITE} 📄 Log: $LOG_FILE${ORANGE}"
printf '%b\n' "${ORANGE}╚════════════════════════════════════════════════════════════╝${NC}"
