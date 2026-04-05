#!/bin/bash

################################################################################
# Script de Verificação Pós-Instalação - Drivers Hub
# Versão: 2.0.0
# Data: Abril 2026
#
# Verifica todos os componentes da instalação:
#   sistema, dependências, MySQL, Redis, backend, systemd,
#   Nginx, SSL, Cloudflare Tunnel, DuckDNS, rede, api_host no banco
################################################################################

set -o pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

INSTALL_BASE="/opt/drivershub"
ERRORS=0
WARNINGS=0
VTC_ABBR=""
STATE_FILE=""
INSTALL_DIR=""
PORT="7777"
DOMAIN=""
DEPLOY_SCENARIO=1

################################################################################
# Helpers
################################################################################

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     VERIFICAÇÃO PÓS-INSTALAÇÃO - DRIVERS HUB v2.0            ║"
    echo "║              Euro Truck Simulator 2 / ATS                    ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

ok()   { echo -e "${GREEN}✅ OK${NC}"; }
fail() { echo -e "${RED}❌ FALHOU${NC}"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}⚠️  AVISO${NC}"; WARNINGS=$((WARNINGS + 1)); }
skip() { echo -e "${CYAN}⏭  PULADO${NC}"; }

check() {
    local label="$1"; shift
    echo -n "  ${label}... "
    if "$@" &>/dev/null 2>&1; then ok; return 0; else fail; return 1; fi
}

check_warn() {
    local label="$1"; shift
    echo -n "  ${label}... "
    if "$@" &>/dev/null 2>&1; then ok; return 0; else warn; return 1; fi
}

section() {
    echo ""
    echo -e "${BLUE}[$1] $2${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

detail() { echo -e "  ${CYAN}→ $1${NC}"; }
info()   { echo -e "  ${CYAN}ℹ  $1${NC}"; }

################################################################################
# Seleção de VTC
################################################################################

select_vtc() {
    local -a states=()
    while IFS= read -r -d '' sf; do
        states+=("$sf")
    done < <(find "${INSTALL_BASE}" -maxdepth 1 -name '.installer_state*' -print0 2>/dev/null)

    if [[ ${#states[@]} -eq 0 ]]; then
        # Tentar perguntar diretamente
        echo -e "${YELLOW}Nenhum arquivo de estado encontrado em ${INSTALL_BASE}.${NC}"
        read -r -p "$(echo -e "${CYAN}Digite a abreviação da VTC manualmente (ex: cdmp): ${NC}")" VTC_ABBR
        if [[ -z "$VTC_ABBR" ]]; then
            echo -e "${RED}Abreviação não pode ser vazia.${NC}"
            exit 1
        fi
        # Tentar diretório legado
        if [[ -d "${INSTALL_BASE}/HubBackend" ]]; then
            INSTALL_DIR="${INSTALL_BASE}/HubBackend"
        else
            INSTALL_DIR="${INSTALL_BASE}/${VTC_ABBR}/HubBackend"
        fi
        STATE_FILE=""
        return
    fi

    if [[ ${#states[@]} -eq 1 ]]; then
        STATE_FILE="${states[0]}"
    else
        echo -e "${MAGENTA}Instalações encontradas:${NC}"
        local i=1
        for sf in "${states[@]}"; do
            (
                # shellcheck source=/dev/null
                source "$sf" 2>/dev/null
                echo "  $i) ${BACKEND_VTC_NAME:-?} (${BACKEND_VTC_ABBR:-?}) — ${BACKEND_DOMAIN:-?}"
            ) 2>/dev/null
            i=$((i + 1))
        done
        echo ""
        local choice
        read -r -p "$(echo -e "${CYAN}Escolha a VTC para verificar [1-${#states[@]}]: ${NC}")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && \
           [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#states[@]}" ]]; then
            STATE_FILE="${states[$((choice - 1))]}"
        else
            echo -e "${RED}Opção inválida.${NC}"
            exit 1
        fi
    fi

    # Carregar estado
    # shellcheck source=/dev/null
    source "$STATE_FILE"
    VTC_ABBR="$BACKEND_VTC_ABBR"
    DOMAIN="${BACKEND_DOMAIN:-localhost}"
    PORT="${BACKEND_PORT:-7777}"
    DEPLOY_SCENARIO="${BACKEND_DEPLOY_SCENARIO:-1}"
    INSTALL_DIR="${BACKEND_INSTALL_DIR:-${INSTALL_BASE}/${VTC_ABBR}/HubBackend}"
    [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]] && \
        INSTALL_DIR="${INSTALL_BASE}/HubBackend"
}

################################################################################
# Verificações
################################################################################

check_os() {
    section "1/10" "Sistema Operacional"

    check "Ubuntu/Debian detectado" command -v apt
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        detail "Sistema: ${PRETTY_NAME}"
    fi

    local total_ram free_disk
    total_ram=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
    free_disk=$(df -m "${INSTALL_BASE}" 2>/dev/null | awk 'NR==2{print $4}' \
                || df -m / | awk 'NR==2{print $4}' || echo "?")
    detail "RAM total: ${total_ram}MB"
    detail "Disco livre em ${INSTALL_BASE}: ${free_disk}MB"

    if [[ "${total_ram}" != "?" ]] && [[ "${total_ram}" -lt 900 ]]; then
        echo -n "  RAM suficiente (≥900MB)... "
        warn
        info "RAM: ${total_ram}MB — pode causar lentidão"
    else
        echo -n "  RAM suficiente (≥900MB)... "
        ok
    fi
}

check_deps() {
    section "2/10" "Dependências do Sistema"

    check "Python 3"   python3 --version
    check "pip"        pip3 --version
    check "Git"        git --version
    check "curl"       curl --version
    check "redis-cli"  command -v redis-cli
    check "ss (iproute2)" command -v ss
}

check_mysql() {
    section "3/10" "Banco de Dados MySQL"

    check "MySQL instalado"  command -v mysql
    check "MySQL rodando"    sudo systemctl is-active --quiet mysql

    # Carregar senha do config.json
    local db_pass=""
    if [[ -f "${INSTALL_DIR}/config.json" ]]; then
        db_pass=$(python3 -c "
import json
try:
    d = json.load(open('${INSTALL_DIR}/config.json'))
    print(d.get('db_password',''))
except: print('')
" 2>/dev/null || echo "")
    fi

    if sudo systemctl is-active --quiet mysql 2>/dev/null; then
        echo -n "  Banco '${VTC_ABBR}_db' acessível... "
        if mysql -u "${VTC_ABBR}_user" -p"${db_pass}" \
                -e "USE ${VTC_ABBR}_db;" 2>/dev/null; then
            ok
            # Contar tabelas
            local tbl_count
            tbl_count=$(sudo mysql -N -s -e \
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${VTC_ABBR}_db';" \
                2>/dev/null | tr -d '[:space:]' || echo "?")
            detail "Tabelas em ${VTC_ABBR}_db: ${tbl_count}"
        else
            fail
            info "Verifique credenciais em ${INSTALL_DIR}/config.json"
        fi

        # Verificar api_host no banco
        echo -n "  api_host no banco (client-config)... "
        local api_host_db
        api_host_db=$(sudo mysql -N -s -e \
            "SELECT JSON_UNQUOTE(JSON_EXTRACT(sval, '\$.api_host')) \
             FROM \`${VTC_ABBR}_db\`.settings \
             WHERE skey='client-config/meta';" \
            2>/dev/null | tr -d '[:space:]' || echo "")
        if [[ -n "$api_host_db" ]]; then
            ok
            detail "api_host: ${api_host_db}"
            # Verificar se está com protocolo correto
            if [[ "$api_host_db" != http* ]]; then
                echo -n "  api_host inclui protocolo (http/https)... "
                warn
                info "api_host sem protocolo pode causar erro de API no frontend."
                info "Corrija: sudo mysql -e \"UPDATE ${VTC_ABBR}_db.settings SET sval=JSON_SET(sval,'\$.api_host','https://${DOMAIN}') WHERE skey='client-config/meta';\""
            fi
        else
            warn
            info "Entrada client-config/meta não encontrada — frontend pode não mostrar dados corretamente."
        fi
    fi
}

check_redis() {
    section "4/10" "Redis"

    check "Redis instalado"  command -v redis-cli
    check "Redis rodando"    sudo systemctl is-active --quiet redis-server

    echo -n "  Redis respondendo (PING)... "
    if redis-cli ping 2>/dev/null | grep -q PONG; then ok; else fail; fi
}

check_project() {
    section "5/10" "Instalação do Drivers Hub"

    check "Diretório do projeto"     test -d "${INSTALL_DIR}"
    check "Ambiente virtual Python"  test -d "${INSTALL_DIR}/venv"
    check "Arquivo config.json"      test -f "${INSTALL_DIR}/config.json"
    check "Código-fonte (src/)"      test -d "${INSTALL_DIR}/src"
    check "main.py"                  test -f "${INSTALL_DIR}/src/main.py"
    check "db.py"                    test -f "${INSTALL_DIR}/src/db.py"

    if [[ -f "${INSTALL_DIR}/config.json" ]]; then
        echo -n "  config.json é JSON válido... "
        if python3 -m json.tool "${INSTALL_DIR}/config.json" &>/dev/null; then ok; else fail; fi

        # Verificar patch DATA DIRECTORY
        echo -n "  Patch DATA DIRECTORY aplicado... "
        if [[ -f "${INSTALL_DIR}/src/db.py" ]] && \
           ! grep -q "DATA DIRECTORY = '" "${INSTALL_DIR}/src/db.py" 2>/dev/null; then
            ok
        else
            warn
            info "Patch DATA DIRECTORY pode não estar aplicado — tabelas MySQL podem não criar"
        fi

        # Verificar patch client-config.py
        local plugin="${INSTALL_DIR}/src/external_plugins/client-config.py"
        if [[ -f "$plugin" ]]; then
            echo -n "  Patch client-config.py (protocolo api_host)... "
            if grep -qF '://' "$plugin" 2>/dev/null; then ok; else warn; fi
        fi
    fi

    if [[ -n "$STATE_FILE" ]]; then
        check "State file"  test -f "${STATE_FILE}"
        detail "State: ${STATE_FILE}"
        detail "Instalado em: ${BACKEND_INSTALLED_AT:-?}"
        detail "Cenário: ${DEPLOY_SCENARIO}"
    fi
}

check_service() {
    section "6/10" "Serviço Systemd"

    local svc="drivershub-${VTC_ABBR}.service"

    echo -n "  Serviço existe... "
    if sudo systemctl list-unit-files 2>/dev/null | grep -q "$svc"; then ok; else fail; fi

    check "Serviço habilitado (autostart)"  sudo systemctl is-enabled --quiet "$svc"
    check "Serviço ativo (rodando)"         sudo systemctl is-active --quiet "$svc"

    if sudo systemctl is-active --quiet "$svc" 2>/dev/null; then
        local uptime_str
        uptime_str=$(sudo systemctl show "$svc" --property=ActiveEnterTimestamp \
                     2>/dev/null | cut -d= -f2 || echo "?")
        detail "Ativo desde: ${uptime_str}"
    else
        echo ""
        echo -e "  ${YELLOW}Últimas linhas do log:${NC}"
        sudo journalctl -u "$svc" -n 8 --no-pager 2>/dev/null | sed 's/^/    /'
    fi

    # Verificar se PATH no serviço está correto
    echo -n "  PATH do serviço inclui /usr/bin... "
    if sudo systemctl cat "$svc" 2>/dev/null | grep -q "PATH=.*:/usr/bin"; then ok; else warn; fi
}

check_network() {
    section "7/10" "Rede e Conectividade"

    detail "Domínio: ${DOMAIN}"
    detail "Porta backend: ${PORT}"

    echo -n "  Porta ${PORT} escutando... "
    if ss -lnt 2>/dev/null | grep -q ":${PORT}"; then ok; else fail; fi

    echo -n "  Backend responde HTTP... "
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${PORT}/${VTC_ABBR}" --max-time 8 2>/dev/null || echo "000")
    if [[ "$http_code" != "000" ]]; then
        ok
        detail "HTTP status: ${http_code}"
    else
        fail
        info "Backend não respondeu. Verifique: sudo journalctl -u drivershub-${VTC_ABBR} -n 30"
    fi

    # Portas 80/443
    echo -n "  Porta 80 escutando... "
    if ss -lnt 2>/dev/null | grep -qE ':80\s|:80$'; then ok; else warn; fi

    echo -n "  Porta 443 escutando... "
    if ss -lnt 2>/dev/null | grep -qE ':443\s|:443$'; then ok; else warn; fi
}

check_nginx() {
    section "8/10" "Nginx e SSL"

    if [[ "${BACKEND_INSTALL_NGINX:-n}" != "y" ]]; then
        info "Nginx não foi selecionado nesta instalação."
        return
    fi

    check "Nginx instalado"  command -v nginx
    check "Nginx rodando"    sudo systemctl is-active --quiet nginx

    local nginx_conf="/etc/nginx/sites-enabled/drivershub-${VTC_ABBR}"
    check "Config Nginx ativa"  test -f "${nginx_conf}"

    if [[ -f "${nginx_conf}" ]]; then
        echo -n "  Nginx config sintaxe OK... "
        if sudo nginx -t 2>/dev/null; then ok; else fail; fi

        # Verificar server_name
        echo -n "  server_name correto (${DOMAIN})... "
        if grep -q "server_name ${DOMAIN}" "${nginx_conf}" 2>/dev/null; then ok; else warn; fi

        # Verificar FRONTEND_PLACEHOLDER (frontend ainda não instalado)
        if grep -q "FRONTEND_PLACEHOLDER" "${nginx_conf}" 2>/dev/null; then
            echo -n "  Frontend instalado no Nginx... "
            warn
            info "Frontend ainda não instalado. Execute: bash scripts/install-frontend.sh"
        fi
    fi

    if [[ "${BACKEND_INSTALL_SSL:-n}" == "y" ]]; then
        check "Certbot instalado"  command -v certbot
        echo -n "  Certificado SSL válido para ${DOMAIN}... "
        if sudo certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
            ok
            # Verificar validade
            local exp_date
            exp_date=$(sudo certbot certificates 2>/dev/null | grep -A3 "$DOMAIN" | grep "Expiry Date" | awk '{print $3, $4, $5}')
            [[ -n "$exp_date" ]] && detail "Validade: ${exp_date}"
        else
            warn
            info "Certificado não encontrado para '${DOMAIN}'. Configure com: sudo certbot --nginx -d ${DOMAIN}"
        fi
    else
        info "SSL não configurado para este domínio."
    fi
}

check_cloudflare() {
    section "9/10" "Cloudflare Tunnel (Cenário 3)"

    if [[ "$DEPLOY_SCENARIO" -ne 3 ]]; then
        info "Cloudflare Tunnel não é usado neste cenário (${DEPLOY_SCENARIO})."
        return
    fi

    check "cloudflared instalado"  command -v cloudflared
    check "Serviço cloudflared ativo"  sudo systemctl is-active --quiet cloudflared

    if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
        detail "Tunnel ativo"
    else
        echo ""
        info "Para iniciar: sudo systemctl start cloudflared"
        info "Para ver logs: sudo journalctl -u cloudflared -n 20"
    fi
}

check_extras() {
    section "10/10" "Extras (backup, health check, DuckDNS)"

    # Backup
    local backup_dir="${INSTALL_BASE}/backups/${VTC_ABBR}"
    echo -n "  Diretório de backup criado... "
    if [[ -d "$backup_dir" ]]; then ok; else warn; fi

    echo -n "  Cron de backup configurado... "
    if crontab -l 2>/dev/null | grep -q "backup.*${VTC_ABBR}"; then
        ok
        detail "$(crontab -l 2>/dev/null | grep "backup.*${VTC_ABBR}")"
    else
        warn
        info "Configure: bash scripts/backup-drivershub.sh → opção 4"
    fi

    # Health check
    echo -n "  Cron de health check configurado... "
    if crontab -l 2>/dev/null | grep -q "health-check.*${VTC_ABBR}"; then
        ok
        detail "$(crontab -l 2>/dev/null | grep "health-check.*${VTC_ABBR}")"
    else
        warn
        info "Configure: bash scripts/health-check.sh → opção 1"
    fi

    # DuckDNS (somente Cenário 2)
    if [[ "$DEPLOY_SCENARIO" -eq 2 ]]; then
        echo -n "  Cron DuckDNS configurado... "
        if sudo crontab -l 2>/dev/null | grep -q "duckdns"; then ok; else warn; fi
        echo -n "  Script DuckDNS existe... "
        if [[ -f "${INSTALL_BASE}/duckdns-update.sh" ]]; then ok; else warn; fi
    fi
}

################################################################################
# Resumo
################################################################################

print_summary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    RESUMO DA VERIFICAÇÃO${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  VTC:     ${CYAN}${BACKEND_VTC_NAME:-?} (${VTC_ABBR})${NC}"
    echo -e "  Domínio: ${CYAN}${DOMAIN}${NC}"
    echo -e "  Porta:   ${CYAN}${PORT}${NC}"
    echo ""

    if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ TUDO OK! Instalação perfeita — nenhum erro ou aviso.${NC}"
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  ${WARNINGS} aviso(s) — instalação funcional mas com pontos de atenção.${NC}"
    else
        echo -e "${RED}❌ ${ERRORS} erro(s) crítico(s) encontrado(s)!${NC}"
        [[ $WARNINGS -gt 0 ]] && echo -e "${YELLOW}⚠️  ${WARNINGS} aviso(s) adicional(is).${NC}"
    fi

    echo ""
    echo -e "${CYAN}Ações recomendadas:${NC}"
    if [[ $ERRORS -gt 0 ]]; then
        echo "  1. Verifique os logs:  sudo journalctl -u drivershub-${VTC_ABBR} -n 50"
        echo "  2. Verifique config:   ${INSTALL_DIR}/config.json"
        echo "  3. Reexecute:          bash scripts/install-drivershub.sh  (modo reparo)"
    fi

    local proto="http"
    [[ "${BACKEND_INSTALL_SSL:-n}" == "y" ]] && proto="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto="https"

    echo ""
    echo -e "  Backend: ${CYAN}${proto}://${DOMAIN}/${VTC_ABBR}${NC}"
    local callback="${proto}://${DOMAIN}/auth/discord/callback"
    echo -e "  Discord Redirect URI: ${GREEN}${callback}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

################################################################################
# Main
################################################################################

print_header
select_vtc
print_header  # Reexibir após seleção

echo -e "${MAGENTA}Verificando instalação: ${VTC_ABBR} — ${DOMAIN}${NC}"
echo ""

check_os
check_deps
check_mysql
check_redis
check_project
check_service
check_network
check_nginx
check_cloudflare
check_extras
print_summary

exit $ERRORS
