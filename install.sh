#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

APP_NAME="J&Z Panel"
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

say() { printf "%b\n" "${CYAN}${BOLD}$*${NC}"; }
ok() { printf "%b\n" "${GREEN}[✓]${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}[!]${NC} $*"; }
die() { printf "%b\n" "${RED}[✗]${NC} $*" >&2; exit 1; }

cleanup() {
    local code=$?
    if [[ $code -ne 0 ]]; then
        printf "%b\n" "${RED}[✗] Installation stopped at exit code ${code}.${NC}"
        printf "%b\n" "${YELLOW}Log: ${LOG_FILE}${NC}"
    fi
}
trap cleanup EXIT

usage() {
    cat <<USAGE
J&Z Panel installer

Usage: sudo bash install.sh [options]

Options:
  --panel               Install/configure J&Z Panel
  --wings               Install/configure Wings binary and service
  --panel-wings         Install both Panel and Wings
  --non-interactive     Do not ask questions; use JZ_*/DB_*/ADMIN_* environment variables
  --domain DOMAIN       Panel hostname
  --dir PATH            Panel installation directory
  --web-server nginx|apache
  --ssl letsencrypt|existing|http
  --help                Show this help

Examples:
  sudo bash install.sh
  sudo bash install.sh --panel-wings
  sudo JZ_DOMAIN=panel.example.com ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='...' bash install.sh --panel --non-interactive
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --panel) INSTALL_PANEL=true ;;
        --wings) INSTALL_WINGS=true ;;
        --panel-wings) INSTALL_PANEL=true; INSTALL_WINGS=true ;;
        --non-interactive) NON_INTERACTIVE=true ;;
        --domain) : ;; # parsed below for compatibility with simple callers
        --help|-h) usage; exit 0 ;;
    esac
done

# Parse options that carry values.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN="${2:?Missing domain}"; shift 2 ;;
        --dir) APP_DIR="${2:?Missing panel directory}"; shift 2 ;;
        --web-server) WEB_SERVER="${2:?Missing web server}"; shift 2 ;;
        --ssl) SSL_MODE="${2:?Missing SSL mode}"; shift 2 ;;
        --panel) INSTALL_PANEL=true; shift ;;
        --wings) INSTALL_WINGS=true; shift ;;
        --panel-wings) INSTALL_PANEL=true; INSTALL_WINGS=true; shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

[[ $EUID -eq 0 ]] || die "Run this installer as root (for example: sudo bash install.sh)."

command -v apt-get >/dev/null 2>&1 || die "This installer currently supports Debian-family systems with apt-get."
[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
. /etc/os-release
case "${ID:-}" in
    ubuntu|debian) ;;
    *) die "Unsupported operating system: ${PRETTY_NAME:-unknown}. J&Z Panel targets supported Debian-family systems." ;;
esac

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in amd64|arm64) ;; *) die "Unsupported architecture: $ARCH. Supported installer architectures: amd64 and arm64." ;; esac

printf '%b\n' "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
printf '%b\n' "${CYAN}${BOLD}║                 J&Z PANEL INSTALLER                     ║${NC}"
printf '%b\n' "${CYAN}${BOLD}║          Advanced Minecraft Server Management            ║${NC}"
printf '%b\n' "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
printf '\n'
ok "System detected: ${PRETTY_NAME:-unknown} / ${ARCH}"
ok "Installer log: ${LOG_FILE}"

if ! $INSTALL_PANEL && ! $INSTALL_WINGS; then
    if $NON_INTERACTIVE; then
        INSTALL_PANEL=true
    else
        cat <<MENU

1) Panel
2) Wings
3) Panel + Wings
4) Exit
MENU
        read -r -p "Select [1-4]: " choice
        case "$choice" in
            1) INSTALL_PANEL=true ;;
            2) INSTALL_WINGS=true ;;
            3) INSTALL_PANEL=true; INSTALL_WINGS=true ;;
            *) exit 0 ;;
        esac
    fi
fi

if ! $NON_INTERACTIVE; then
    if $INSTALL_PANEL; then
        read -r -p "Panel domain (leave blank for HTTP/IP): " DOMAIN
        read -r -p "Web server [nginx/apache] (default nginx): " input_ws
        WEB_SERVER="${input_ws:-nginx}"
        read -r -p "HTTPS [letsencrypt/existing/http] (default http): " input_ssl
        SSL_MODE="${input_ssl:-http}"
    fi
fi

case "$WEB_SERVER" in nginx|apache) ;; *) die "Web server must be nginx or apache." ;; esac
case "$SSL_MODE" in letsencrypt|existing|http) ;; *) die "SSL mode must be letsencrypt, existing, or http." ;; esac

export DEBIAN_FRONTEND=noninteractive
say "1. Checking requirements"
apt-get update -y
apt-get install -y ca-certificates curl gnupg git unzip tar sudo openssl rsync jq lsb-release software-properties-common

php_version_ok() {
    command -v php >/dev/null 2>&1 || return 1
    php -r '$v=PHP_VERSION; exit(version_compare($v,"8.2","<") || version_compare($v,"8.4",">=") ? 1 : 0);'
}

install_php() {
    say "Installing PHP and required extensions"
    apt-get install -y php8.3 php8.3-cli php8.3-fpm php8.3-common php8.3-mysql php8.3-gd php8.3-curl php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-zip php8.3-intl php8.3-redis
}

if $INSTALL_PANEL; then
    if ! php_version_ok; then install_php; fi
    php_version_ok || die "PHP 8.2/8.3 is required by the supplied composer manifest."
    ok "PHP $(php -r 'echo PHP_VERSION;')"

    if ! command -v composer >/dev/null 2>&1; then
        say "Installing Composer"
        curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
        php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm -f /tmp/composer-setup.php
    fi
    ok "Composer $(composer --version | head -1)"

    if ! command -v node >/dev/null 2>&1 || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)'; then
        say "Installing Node.js 22"
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    fi
    node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 22 ? 1 : 0)' || die "Node.js 22+ is required by the supplied package manifest."
    ok "Node $(node --version)"

    if ! command -v yarn >/dev/null 2>&1; then npm install -g yarn; fi
    ok "Yarn $(yarn --version)"

    say "2. Installing database/cache dependencies"
    apt-get install -y mariadb-server mariadb-client redis-server
    systemctl enable --now mariadb redis-server

    if [[ -z "$DB_PASSWORD" ]]; then DB_PASSWORD="$(openssl rand -hex 24)"; fi
    if [[ -z "$ADMIN_PASSWORD" && "$NON_INTERACTIVE" == true ]]; then ADMIN_PASSWORD="$(openssl rand -hex 20)"; fi

    if ! mysql -uroot -e 'SELECT 1' >/dev/null 2>&1; then
        [[ -n "$DB_ROOT_PASSWORD" ]] || die "MariaDB root authentication requires DB_ROOT_PASSWORD on this system."
        mysql -uroot -p"$DB_ROOT_PASSWORD" -e 'SELECT 1' >/dev/null 2>&1 || die "Cannot authenticate to MariaDB as root."
        MYSQL_ROOT=(mysql -uroot -p"$DB_ROOT_PASSWORD")
    else
        MYSQL_ROOT=(mysql -uroot)
    fi
    "${MYSQL_ROOT[@]}" -e "CREATE DATABASE IF NOT EXISTS \\`$DB_DATABASE\\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    "${MYSQL_ROOT[@]}" -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD'; ALTER USER '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON \\`$DB_DATABASE\\`.* TO '$DB_USERNAME'@'127.0.0.1'; FLUSH PRIVILEGES;"
    ok "MariaDB database and user prepared"

    say "3. Preparing J&Z Panel application"
    mkdir -p "$APP_DIR"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    rsync -a --exclude='.git' --exclude='node_modules' --exclude='vendor' "$SCRIPT_DIR/" "$APP_DIR/"
    cd "$APP_DIR"
    [[ -f composer.json && -f package.json ]] || die "The installer must be run from the supplied J&Z Panel source directory."

    cp -n .env.example .env || true
    php -r '$p=".env"; $s=file_get_contents($p); $repls=["APP_NAME"=>"J&Z Panel","APP_ENV"=>"production","APP_DEBUG"=>"false","APP_URL"=>getenv("JZ_DOMAIN") ? "https://".getenv("JZ_DOMAIN") : "http://localhost","DB_HOST"=>getenv("DB_HOST"),"DB_PORT"=>getenv("DB_PORT"),"DB_DATABASE"=>getenv("DB_DATABASE"),"DB_USERNAME"=>getenv("DB_USERNAME"),"DB_PASSWORD"=>getenv("DB_PASSWORD")]; foreach($repls as $k=>$v){$v=(string)$v; $s=preg_replace("/^".preg_quote($k,"/")."=.*/m", $k."=".str_replace("\\n","",$v), $s, 1, $n); if(!$n) $s.="\\n$k=$v";} file_put_contents($p,$s);' \
        APP_URL="${DOMAIN:+https://$DOMAIN}" DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_DATABASE="$DB_DATABASE" DB_USERNAME="$DB_USERNAME" DB_PASSWORD="$DB_PASSWORD"
    # APP_URL is corrected explicitly for HTTP/no-domain deployments.
    if [[ -n "$DOMAIN" ]]; then sed -i "s#^APP_URL=.*#APP_URL=https://${DOMAIN}#" .env; else sed -i "s#^APP_URL=.*#APP_URL=http://localhost#" .env; fi
    sed -i 's#^APP_NAME=.*#APP_NAME="J\&Z Panel"#' .env
    sed -i 's#^APP_DEBUG=.*#APP_DEBUG=false#' .env
    sed -i "s#^DB_HOST=.*#DB_HOST=${DB_HOST}#; s#^DB_PORT=.*#DB_PORT=${DB_PORT}#; s#^DB_DATABASE=.*#DB_DATABASE=${DB_DATABASE}#; s#^DB_USERNAME=.*#DB_USERNAME=${DB_USERNAME}#; s#^DB_PASSWORD=.*#DB_PASSWORD=${DB_PASSWORD}#" .env

    php artisan key:generate --force
    composer install --no-dev --optimize-autoloader --no-interaction
    yarn install --frozen-lockfile
    yarn run build:production
    php artisan migrate --seed --force
    php artisan storage:link || true
    php artisan optimize:clear
    php artisan optimize

    say "4. Setting secure permissions"
    chown -R www-data:www-data "$APP_DIR"
    find "$APP_DIR" -type d -exec chmod 755 {} +
    chmod -R ug+rwx "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
    ok "Application permissions configured"

    say "5. Configuring queue worker and scheduler"
    cat > /etc/systemd/system/jz-panel-worker.service <<SERVICE
[Unit]
Description=J&Z Panel Queue Worker
After=network.target redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
RestartSec=5
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/php $APP_DIR/artisan queue:work --sleep=3 --tries=3 --timeout=90

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
Restart=always
RestartSec=5
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/php $APP_DIR/artisan schedule:work

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable --now jz-panel-worker jz-panel-scheduler
    ok "Queue worker and scheduler enabled"

    say "6. Installing J&Z management CLI"
    cat > /usr/local/bin/jz-panel <<'CLI'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="__JZ_APP_DIR__"
case "${1:-status}" in
  status) systemctl --no-pager --full status jz-panel-worker jz-panel-scheduler nginx apache2 2>/dev/null || true ;;
  health) cd "$APP_DIR"; php artisan p:info ;;
  update) cd "$APP_DIR"; composer install --no-dev --optimize-autoloader --no-interaction; yarn install --frozen-lockfile; yarn run build:production; php artisan migrate --force; php artisan optimize:clear; php artisan optimize; systemctl restart jz-panel-worker jz-panel-scheduler; echo "J&Z Panel update completed." ;;
  backup) cd "$APP_DIR"; tar --exclude=storage/logs --exclude=node_modules --exclude=vendor -czf "/root/jz-panel-backup-$(date +%Y%m%d-%H%M%S).tar.gz" .env storage 2>/dev/null || tar -czf "/root/jz-panel-backup-$(date +%Y%m%d-%H%M%S).tar.gz" .env; echo "Configuration backup created under /root." ;;
  repair) cd "$APP_DIR"; php artisan optimize:clear; php artisan storage:link || true; chown -R www-data:www-data storage bootstrap/cache; chmod -R ug+rwx storage bootstrap/cache; systemctl restart jz-panel-worker jz-panel-scheduler; echo "Repair completed." ;;
  logs) journalctl -u jz-panel-worker -u jz-panel-scheduler -n 200 --no-pager ;;
  *) echo "Usage: jz-panel {status|health|update|backup|repair|logs}"; exit 2 ;;
esac
CLI
    sed -i "s#__JZ_APP_DIR__#${APP_DIR}#" /usr/local/bin/jz-panel
    chmod 755 /usr/local/bin/jz-panel
    ok "jz-panel CLI installed"

    say "6. Configuring web server"
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
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    location ~ /\.(?!well-known).* { deny all; }
}
NGINX
        ln -sfn /etc/nginx/sites-available/jz-panel.conf /etc/nginx/sites-enabled/jz-panel.conf
        rm -f /etc/nginx/sites-enabled/default
        nginx -t
        systemctl enable --now nginx
    else
        apt-get install -y apache2 libapache2-mod-php8.3
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
        apachectl configtest
        systemctl enable --now apache2
    fi
    ok "$WEB_SERVER configured"

    if [[ "$SSL_MODE" == letsencrypt ]]; then
        [[ -n "$DOMAIN" ]] || die "Let's Encrypt requires --domain."
        apt-get install -y certbot
        if [[ "$WEB_SERVER" == nginx ]]; then apt-get install -y python3-certbot-nginx; certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect; else apt-get install -y python3-certbot-apache; certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect; fi
    elif [[ "$SSL_MODE" == existing ]]; then
        warn "Existing certificate mode selected. Install your certificate/key and update the generated web-server vhost before enabling HTTPS."
    fi

    if [[ -n "$ADMIN_EMAIL" && -n "$ADMIN_PASSWORD" ]]; then
        php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first="$ADMIN_FIRST_NAME" --name-last="$ADMIN_LAST_NAME" --password="$ADMIN_PASSWORD" --admin || warn "Admin creation command was not available or failed; create the administrator using the project's supported CLI flow."
    else
        warn "Admin credentials were not supplied. Create the first administrator using the application's supported CLI command after installation."
    fi

    ok "J&Z Panel installation complete"
    printf '\n%b\n' "${GREEN}${BOLD}J&Z Panel:${NC} ${DOMAIN:+https://$DOMAIN}${DOMAIN:-http://localhost}"
fi

if $INSTALL_WINGS; then
    say "7. Installing Wings"
    apt-get install -y docker.io curl ca-certificates
    systemctl enable --now docker
    mkdir -p "$WINGS_DIR"
    case "$ARCH" in amd64) WINGS_ARCH=amd64 ;; arm64) WINGS_ARCH=arm64 ;; esac
    curl -fL "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}" -o /usr/local/bin/wings
    chmod 755 /usr/local/bin/wings
    cat > /etc/systemd/system/wings.service <<SERVICE
[Unit]
Description=J&Z Wings Service
After=docker.service
Requires=docker.service

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
    if [[ -f "$WINGS_DIR/config.yml" ]]; then
        systemctl enable --now wings
        ok "Wings installed and existing configuration detected; service started"
    else
        systemctl enable wings
        warn "Wings binary/service installed, but $WINGS_DIR/config.yml is missing. Create the node in J&Z Panel and place its generated configuration there before starting Wings."
    fi
fi

say "Final health check"
if $INSTALL_PANEL; then
    php -v | head -1 || true
    systemctl is-active --quiet jz-panel-worker && ok "Queue worker active" || warn "Queue worker is not active"
    systemctl is-active --quiet jz-panel-scheduler && ok "Scheduler active" || warn "Scheduler is not active"
    if [[ "$WEB_SERVER" == nginx ]]; then systemctl is-active --quiet nginx && ok "Nginx active" || warn "Nginx is not active"; else systemctl is-active --quiet apache2 && ok "Apache active" || warn "Apache is not active"; fi
fi
if $INSTALL_WINGS; then /usr/local/bin/wings --version || true; fi

printf '\n%b\n' "${GREEN}${BOLD}Installation finished.${NC}"
printf '%b\n' "${YELLOW}Review ${LOG_FILE} if you need the complete installer log.${NC}"
