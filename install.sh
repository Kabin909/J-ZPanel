#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_NAME='J&Z Panel'
REPO_URL="${JZ_REPO_URL:-https://github.com/Kabin909/J-ZPanel.git}"
REPO_TARBALL="${JZ_REPO_TARBALL:-https://github.com/Kabin909/J-ZPanel/archive/refs/heads/main.tar.gz}"
APP_DIR="${JZ_PANEL_DIR:-/var/www/jz-panel}"
WINGS_DIR="${JZ_WINGS_DIR:-/etc/pterodactyl}"
LOG_FILE="${JZ_INSTALL_LOG:-/var/log/jz-panel-install.log}"
NON_INTERACTIVE=false
INSTALL_PANEL=false
INSTALL_WINGS=false
WEB_SERVER="nginx"
SSL_MODE="http"
DOMAIN="${JZ_DOMAIN:-}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_DATABASE="${DB_DATABASE:-panel}"
DB_USERNAME="${DB_USERNAME:-pterodactyl}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_FIRST_NAME="${ADMIN_FIRST_NAME:-Admin}"
ADMIN_LAST_NAME="${ADMIN_LAST_NAME:-User}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
say(){ printf '%b\n' "${CYAN}${BOLD}$*${NC}"; }
ok(){ printf '%b\n' "${GREEN}[✓]${NC} $*"; }
warn(){ printf '%b\n' "${YELLOW}[!]${NC} $*"; }
die(){ printf '%b\n' "${RED}[✗]${NC} $*" >&2; exit 1; }
trap 'rc=$?; if [[ $rc -ne 0 ]]; then printf "%b\n" "${RED}[✗] Installation failed (exit $rc). Log: $LOG_FILE${NC}"; fi' EXIT

usage(){ cat <<USAGE
J&Z Panel installer

Usage: sudo bash install.sh [options]

Options:
  --panel               Install/configure J&Z Panel
  --wings               Install/configure Wings
  --panel-wings         Install Panel + Wings
  --non-interactive     Do not ask questions
  --domain DOMAIN       Panel hostname
  --dir PATH             Panel installation directory
  --web-server nginx|apache
  --ssl letsencrypt|existing|http
  --help                Show this help

Environment variables:
  JZ_DOMAIN, JZ_PANEL_DIR, JZ_REPO_URL, JZ_REPO_TARBALL
  DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD, DB_ROOT_PASSWORD
  ADMIN_EMAIL, ADMIN_USERNAME, ADMIN_FIRST_NAME, ADMIN_LAST_NAME, ADMIN_PASSWORD

Examples:
  sudo bash install.sh
  sudo bash install.sh --panel-wings
  sudo JZ_DOMAIN=panel.example.com ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='StrongPassword' bash install.sh --panel --non-interactive
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --panel) INSTALL_PANEL=true; shift;;
    --wings) INSTALL_WINGS=true; shift;;
    --panel-wings) INSTALL_PANEL=true; INSTALL_WINGS=true; shift;;
    --non-interactive) NON_INTERACTIVE=true; shift;;
    --domain) [[ $# -ge 2 ]] || die 'Missing domain'; DOMAIN="$2"; shift 2;;
    --dir) [[ $# -ge 2 ]] || die 'Missing panel directory'; APP_DIR="$2"; shift 2;;
    --web-server) [[ $# -ge 2 ]] || die 'Missing web server'; WEB_SERVER="$2"; shift 2;;
    --ssl) [[ $# -ge 2 ]] || die 'Missing SSL mode'; SSL_MODE="$2"; shift 2;;
    --help|-h) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

[[ $EUID -eq 0 ]] || die 'Run as root: sudo bash install.sh'
command -v apt-get >/dev/null || die 'This installer requires apt-get (Ubuntu/Debian).'
[[ -r /etc/os-release ]] || die 'Cannot detect operating system.'
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "Unsupported OS: ${PRETTY_NAME:-unknown}";; esac
ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
case "$ARCH" in amd64|arm64) ;; *) die "Unsupported architecture: $ARCH (supported: amd64, arm64)";; esac
case "$WEB_SERVER" in nginx|apache) ;; *) die 'Web server must be nginx or apache.';; esac
case "$SSL_MODE" in letsencrypt|existing|http) ;; *) die 'SSL must be letsencrypt, existing, or http.';; esac

printf '%b\n' "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
printf '%b\n' "${CYAN}${BOLD}║                 J&Z PANEL INSTALLER                     ║${NC}"
printf '%b\n' "${CYAN}${BOLD}║          Advanced Minecraft Server Management           ║${NC}"
printf '%b\n' "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
ok "System: ${PRETTY_NAME:-unknown} / $ARCH"
ok "Log: $LOG_FILE"

if ! $INSTALL_PANEL && ! $INSTALL_WINGS; then
  if $NON_INTERACTIVE; then INSTALL_PANEL=true; else
    printf '\n1) Panel\n2) Wings\n3) Panel + Wings\n4) Exit\n\n'
    read -r -p 'Select [1-4]: ' choice
    case "$choice" in 1) INSTALL_PANEL=true;; 2) INSTALL_WINGS=true;; 3) INSTALL_PANEL=true; INSTALL_WINGS=true;; *) exit 0;; esac
  fi
fi

if ! $NON_INTERACTIVE && $INSTALL_PANEL; then
  read -r -p "Panel domain (blank for IP/HTTP): " DOMAIN
  read -r -p 'Web server [nginx/apache] (default nginx): ' x; WEB_SERVER="${x:-nginx}"
  read -r -p 'HTTPS [letsencrypt/existing/http] (default http): ' x; SSL_MODE="${x:-http}"
fi

export DEBIAN_FRONTEND=noninteractive
say 'Preparing base packages'
apt-get update -y
apt-get install -y ca-certificates curl gnupg unzip tar openssl rsync jq lsb-release software-properties-common apt-transport-https

# Never require git: raw curl installs and broken git/dpkg states are common on VPS images.
source_dir=''
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/composer.json" && -f "$SCRIPT_DIR/package.json" ]]; then
  source_dir="$SCRIPT_DIR"
else
  say 'Downloading J&Z Panel source from GitHub'
  TMP_SRC="$(mktemp -d /tmp/jz-panel-src.XXXXXX)"
  trap 'rm -rf "${TMP_SRC:-}" 2>/dev/null || true' EXIT
  curl -fL --retry 3 --connect-timeout 15 "$REPO_TARBALL" -o "$TMP_SRC/source.tar.gz"
  tar -xzf "$TMP_SRC/source.tar.gz" -C "$TMP_SRC"
  source_dir="$(find "$TMP_SRC" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [[ -f "$source_dir/composer.json" ]] || die 'Downloaded source does not contain composer.json.'
fi

php_version_ok(){ command -v php >/dev/null 2>&1 && php -r 'exit(version_compare(PHP_VERSION,"8.2","<") || version_compare(PHP_VERSION,"8.4",">=") ? 1 : 0);'; }
php_fpm_pkg(){ if apt-cache show php8.3-fpm >/dev/null 2>&1; then echo php8.3-fpm; else echo php8.2-fpm; fi; }
php_pkg_ver(){ local base; base="$(php_fpm_pkg)"; echo "${base#php}"; }

add_php_repo(){
  if [[ "$ID" == ubuntu ]]; then
    apt-get install -y software-properties-common
    if ! grep -Rqs '^deb .*ondrej/php' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      add-apt-repository -y ppa:ondrej/php
      apt-get update -y
    fi
  elif [[ "$ID" == debian ]]; then
    apt-get install -y ca-certificates lsb-release apt-transport-https
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(. /etc/os-release; echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/sury-php.list
    apt-get update -y
  fi
}

install_php(){
  add_php_repo
  local v; v="$(php_pkg_ver)"
  apt-get install -y "php${v}" "php${v}-cli" "php${v}-common" "php${v}-mysql" "php${v}-gd" "php${v}-curl" "php${v}-mbstring" "php${v}-bcmath" "php${v}-xml" "php${v}-zip" "php${v}-intl" "php${v}-redis" "php${v}-fpm"
}

if $INSTALL_PANEL; then
  say 'Installing panel runtime'
  if ! php_version_ok; then install_php; fi
  php_version_ok || die 'PHP 8.2 or 8.3 is required by composer.json.'
  PHP_VERSION_MAJOR_MINOR="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  # Ensure the extensions/FPM matching the installed PHP are present even when a valid PHP version already exists.
  add_php_repo
  apt-get install -y "php${PHP_VERSION_MAJOR_MINOR}-cli" "php${PHP_VERSION_MAJOR_MINOR}-common" "php${PHP_VERSION_MAJOR_MINOR}-mysql" "php${PHP_VERSION_MAJOR_MINOR}-gd" "php${PHP_VERSION_MAJOR_MINOR}-curl" "php${PHP_VERSION_MAJOR_MINOR}-mbstring" "php${PHP_VERSION_MAJOR_MINOR}-bcmath" "php${PHP_VERSION_MAJOR_MINOR}-xml" "php${PHP_VERSION_MAJOR_MINOR}-zip" "php${PHP_VERSION_MAJOR_MINOR}-intl" "php${PHP_VERSION_MAJOR_MINOR}-redis" "php${PHP_VERSION_MAJOR_MINOR}-fpm"
  PHP_FPM_SERVICE="php${PHP_VERSION_MAJOR_MINOR}-fpm"
  PHP_FPM_SOCK="/run/php/php${PHP_VERSION_MAJOR_MINOR}-fpm.sock"
  systemctl enable --now "$PHP_FPM_SERVICE"
  ok "PHP $(php -r 'echo PHP_VERSION;')"

  if ! command -v composer >/dev/null; then
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    EXPECTED="$(curl -fsSL https://composer.github.io/installer.sig)"
    ACTUAL="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    [[ "$EXPECTED" == "$ACTUAL" ]] || die 'Composer installer signature verification failed.'
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
  fi
  composer --version | head -1

  if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(parseInt(process.versions.node) < 22 ? 1 : 0)'; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
  fi
  node -e 'process.exit(parseInt(process.versions.node) < 22 ? 1 : 0)' || die 'Node.js 22+ is required.'
  npm install -g yarn@1.22.22
  ok "Node $(node --version), Yarn $(yarn --version)"

  say 'Installing MariaDB and Redis'
  apt-get install -y mariadb-server mariadb-client redis-server
  systemctl enable --now mariadb redis-server
  [[ -n "$DB_PASSWORD" ]] || DB_PASSWORD="$(openssl rand -hex 24)"

  if mysql -uroot -e 'SELECT 1' >/dev/null 2>&1; then MYSQL_ROOT=(mysql -uroot)
  elif [[ -n "$DB_ROOT_PASSWORD" ]] && mysql -uroot -p"$DB_ROOT_PASSWORD" -e 'SELECT 1' >/dev/null 2>&1; then MYSQL_ROOT=(mysql -uroot -p"$DB_ROOT_PASSWORD")
  else die 'Cannot authenticate to MariaDB root. Set DB_ROOT_PASSWORD or use a fresh MariaDB install.'; fi
  # SQL literals are escaped for single quotes.
  sql_escape(){ printf '%s' "$1" | sed "s/'/''/g"; }
  DBP_ESC="$(sql_escape "$DB_PASSWORD")"
  DBU_ESC="$(sql_escape "$DB_USERNAME")"
  "${MYSQL_ROOT[@]}" -e "CREATE DATABASE IF NOT EXISTS \\`$DB_DATABASE\\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '$DBU_ESC'@'127.0.0.1' IDENTIFIED BY '$DBP_ESC'; ALTER USER '$DBU_ESC'@'127.0.0.1' IDENTIFIED BY '$DBP_ESC'; GRANT ALL PRIVILEGES ON \\`$DB_DATABASE\\`.* TO '$DBU_ESC'@'127.0.0.1'; FLUSH PRIVILEGES;"

  say 'Installing J&Z Panel application'
  mkdir -p "$APP_DIR"
  rsync -a --delete --exclude='.git' --exclude='node_modules' --exclude='vendor' "$source_dir/" "$APP_DIR/"
  cd "$APP_DIR"
  [[ -f composer.json && -f package.json && -f artisan ]] || die 'J&Z Panel source is incomplete.'
  cp -n .env.example .env 2>/dev/null || true
  [[ -f .env ]] || die 'Unable to create .env.'

  set_env(){
    local k="$1" v="$2"; python3 - "$k" "$v" <<'PY'
import sys
from pathlib import Path
p=Path('.env'); key=sys.argv[1]; value=sys.argv[2]
lines=p.read_text().splitlines(); out=[]; found=False
for line in lines:
    if line.startswith(key+'='):
        out.append(key+'='+value); found=True
    else: out.append(line)
if not found: out.append(key+'='+value)
p.write_text('\n'.join(out)+'\n')
PY
  }
  apt-get install -y python3
  APP_URL='http://localhost'; [[ -n "$DOMAIN" ]] && APP_URL="https://$DOMAIN"
  set_env APP_NAME '"J&Z Panel"'; set_env APP_ENV production; set_env APP_DEBUG false; set_env APP_URL "$APP_URL"
  set_env DB_HOST "$DB_HOST"; set_env DB_PORT "$DB_PORT"; set_env DB_DATABASE "$DB_DATABASE"; set_env DB_USERNAME "$DB_USERNAME"; set_env DB_PASSWORD "$DB_PASSWORD"
  set_env CACHE_STORE redis; set_env QUEUE_CONNECTION redis

  php artisan key:generate --force
  composer install --no-dev --optimize-autoloader --no-interaction
  yarn install --frozen-lockfile
  yarn run build:production
  php artisan migrate --seed --force
  php artisan storage:link || true
  php artisan optimize:clear
  php artisan optimize

  chown -R www-data:www-data "$APP_DIR"
  chmod -R ug+rwx "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"

  cat > /etc/systemd/system/jz-panel-worker.service <<SERVICE
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
  cat > /etc/systemd/system/jz-panel-scheduler.service <<SERVICE
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

  say 'Configuring web server'
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
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
    }
    location ~ /\. { deny all; }
}
NGINX
    ln -sfn /etc/nginx/sites-available/jz-panel.conf /etc/nginx/sites-enabled/jz-panel.conf
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl enable --now nginx
  else
    apt-get install -y apache2
    a2enmod rewrite headers >/dev/null
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
    apachectl configtest
    systemctl enable --now apache2
  fi

  if [[ "$SSL_MODE" == letsencrypt ]]; then
    [[ -n "$DOMAIN" ]] || die 'Let’s Encrypt requires --domain.'
    apt-get install -y certbot
    if [[ "$WEB_SERVER" == nginx ]]; then
      apt-get install -y python3-certbot-nginx
      certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
    else
      apt-get install -y python3-certbot-apache
      certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
    fi
  elif [[ "$SSL_MODE" == existing ]]; then
    warn 'Existing SSL selected: install your certificate/key and configure the vhost manually.'
  fi

  if [[ -n "$ADMIN_EMAIL" && -n "$ADMIN_PASSWORD" ]]; then
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first="$ADMIN_FIRST_NAME" --name-last="$ADMIN_LAST_NAME" --password="$ADMIN_PASSWORD" --admin || warn 'Admin creation failed; create it manually with php artisan p:user:make.'
  else
    warn 'No admin credentials supplied. Create an administrator with: php artisan p:user:make'
  fi

  cat > /usr/local/bin/jz-panel <<CLI
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR='$APP_DIR'
case "\${1:-status}" in
  status) systemctl --no-pager --full status jz-panel-worker jz-panel-scheduler wings nginx apache2 2>/dev/null || true ;;
  health) cd "\$APP_DIR"; php artisan p:info ;;
  update) cd "\$APP_DIR"; composer install --no-dev --optimize-autoloader --no-interaction; yarn install --frozen-lockfile; yarn run build:production; php artisan migrate --force; php artisan optimize:clear; php artisan optimize; systemctl restart jz-panel-worker jz-panel-scheduler; ;;
  backup) tar --exclude='\$APP_DIR/storage/logs' --exclude='\$APP_DIR/node_modules' --exclude='\$APP_DIR/vendor' -czf "/root/jz-panel-backup-\$(date +%Y%m%d-%H%M%S).tar.gz" "\$APP_DIR/.env" "\$APP_DIR/storage"; echo 'Backup created under /root.' ;;
  repair) cd "\$APP_DIR"; php artisan optimize:clear; php artisan storage:link || true; chown -R www-data:www-data storage bootstrap/cache; chmod -R ug+rwx storage bootstrap/cache; systemctl restart jz-panel-worker jz-panel-scheduler; ;;
  logs) journalctl -u jz-panel-worker -u jz-panel-scheduler -n 200 --no-pager ;;
  *) echo 'Usage: jz-panel {status|health|update|backup|repair|logs}'; exit 2 ;;
esac
CLI
  chmod 755 /usr/local/bin/jz-panel
  ok 'J&Z Panel installed'
fi

if $INSTALL_WINGS; then
  say 'Installing Wings + Docker'
  apt-get install -y docker.io
  systemctl enable --now docker
  mkdir -p "$WINGS_DIR"
  case "$ARCH" in amd64) WINGS_ARCH=amd64;; arm64) WINGS_ARCH=arm64;; esac
  WINGS_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
  curl -fL --retry 3 "$WINGS_URL" -o /usr/local/bin/wings
  chmod 755 /usr/local/bin/wings
  cat > /etc/systemd/system/wings.service <<SERVICE
[Unit]
Description=J&Z Wings Service
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
User=root
WorkingDirectory=$WINGS_DIR
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
  if [[ -f "$WINGS_DIR/config.yml" ]]; then systemctl enable --now wings; ok 'Wings configuration found; Wings started.'
  else systemctl enable wings; warn "Wings installed but $WINGS_DIR/config.yml is missing. Create the node in J&Z Panel, install its generated config, then run: systemctl start wings"; fi
  /usr/local/bin/wings --version || true
fi

say 'Final health check'
if $INSTALL_PANEL; then
  systemctl is-active --quiet mariadb && ok 'MariaDB active' || warn 'MariaDB inactive'
  systemctl is-active --quiet redis-server && ok 'Redis active' || warn 'Redis inactive'
  systemctl is-active --quiet jz-panel-worker && ok 'Queue worker active' || warn 'Queue worker inactive'
  systemctl is-active --quiet jz-panel-scheduler && ok 'Scheduler active' || warn 'Scheduler inactive'
  if [[ "$WEB_SERVER" == nginx ]]; then systemctl is-active --quiet nginx && ok 'Nginx active' || warn 'Nginx inactive'; else systemctl is-active --quiet apache2 && ok 'Apache active' || warn 'Apache inactive'; fi
fi
if $INSTALL_WINGS; then systemctl is-active --quiet docker && ok 'Docker active' || warn 'Docker inactive'; systemctl is-active --quiet wings && ok 'Wings active' || warn 'Wings is waiting for config.yml'; fi

printf '\n%b\n' "${GREEN}${BOLD}J&Z Panel installation finished.${NC}"
printf '%b\n' "${YELLOW}Log: ${LOG_FILE}${NC}"
