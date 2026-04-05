#!/bin/bash

################################################################################
# Script de Reconfiguração Pós-Instalação - Drivers Hub
# Versão: 1.0.0
# Data: Abril 2026
#
# Permite alterar configurações após a instalação:
#   - Domínio / protocolo
#   - Credenciais Discord e Steam
#   - Porta do backend
#   - Troca de cenário (ex: DuckDNS → domínio próprio)
#   - Reconfiguração do Nginx / SSL
#   - Reconfiguração do Cloudflare Tunnel
################################################################################

set -e
set -o pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_BASE="/opt/drivershub"

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       RECONFIGURAÇÃO PÓS-INSTALAÇÃO - DRIVERS HUB            ║"
    echo "║              Euro Truck Simulator 2 / ATS                     ║"
    echo "║                                                               ║"
    echo "║ Versão: 1.0.0                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }

confirm() {
    local prompt="$1" default="${2:-n}" response
    if [[ "$default" == "y" ]]; then
        read -r -p "$(echo -e "${YELLOW}${prompt} [S/n]: ${NC}")" response
        response=${response:-y}
    else
        read -r -p "$(echo -e "${YELLOW}${prompt} [s/N]: ${NC}")" response
        response=${response:-n}
    fi
    [[ "$response" =~ ^[SsYy]$ ]]
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Não execute como root. O script pedirá sudo quando necessário."
        exit 1
    fi
}

################################################################################
# Seleção de VTC
################################################################################

select_vtc() {
    # Procurar state files
    local -a states=()
    while IFS= read -r -d '' sf; do
        states+=("$sf")
    done < <(find "${INSTALL_BASE}" -maxdepth 1 -name '.installer_state*' -print0 2>/dev/null)

    if [[ ${#states[@]} -eq 0 ]]; then
        print_error "Nenhuma instalação encontrada em ${INSTALL_BASE}."
        print_info "Execute primeiro: bash scripts/install-drivershub.sh"
        exit 1
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
        read -r -p "$(echo -e "${CYAN}Escolha a VTC [1-${#states[@]}]: ${NC}")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && \
           [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#states[@]}" ]]; then
            STATE_FILE="${states[$((choice - 1))]}"
        else
            print_error "Opção inválida."
            exit 1
        fi
    fi

    # Carregar estado
    # shellcheck source=/dev/null
    source "$STATE_FILE"

    VTC_NAME="$BACKEND_VTC_NAME"
    VTC_ABBR="$BACKEND_VTC_ABBR"
    DOMAIN="$BACKEND_DOMAIN"
    PORT="${BACKEND_PORT:-7777}"
    INSTALL_NGINX="${BACKEND_INSTALL_NGINX:-n}"
    INSTALL_SSL="${BACKEND_INSTALL_SSL:-n}"
    DEPLOY_SCENARIO="${BACKEND_DEPLOY_SCENARIO:-1}"
    INSTALL_DIR="${BACKEND_INSTALL_DIR:-${INSTALL_BASE}/${VTC_ABBR}/HubBackend}"

    # Compatibilidade com diretório legado
    if [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]]; then
        INSTALL_DIR="${INSTALL_BASE}/HubBackend"
    fi

    print_success "VTC selecionada: ${VTC_NAME} (${VTC_ABBR})"
}

################################################################################
# Carregar credenciais atuais do config.json
################################################################################

load_current_credentials() {
    local cfg="${INSTALL_DIR}/config.json"
    if [[ ! -f "$cfg" ]]; then
        print_warning "config.json não encontrado em ${INSTALL_DIR}"
        return
    fi

    DB_PASSWORD=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('db_password',''))
except: print('')
" 2>/dev/null || echo "")

    DISCORD_CLIENT_ID=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('discord_client_id',''))
except: print('')
" 2>/dev/null || echo "")

    DISCORD_CLIENT_SECRET=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('discord_client_secret',''))
except: print('')
" 2>/dev/null || echo "")

    DISCORD_BOT_TOKEN=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('discord_bot_token',''))
except: print('')
" 2>/dev/null || echo "")

    DISCORD_GUILD_ID=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('discord_guild_id',''))
except: print('')
" 2>/dev/null || echo "")

    STEAM_API_KEY=$(python3 -c "
import json
try:
    d = json.load(open('${cfg}'))
    print(d.get('steam_api_key',''))
except: print('')
" 2>/dev/null || echo "")
}

################################################################################
# Opções de reconfiguração
################################################################################

reconfig_domain() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  ALTERAR DOMÍNIO${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Domínio atual: ${CYAN}${DOMAIN}${NC}"
    echo ""
    read -r -p "$(echo -e "${CYAN}Novo domínio (Enter para manter): ${NC}")" new_domain
    new_domain=$(echo "$new_domain" | sed 's|https\?://||' | sed 's|/$||' | tr -d ' ')

    if [[ -z "$new_domain" ]]; then
        print_info "Domínio mantido: ${DOMAIN}"
        return
    fi

    DOMAIN="$new_domain"
    print_success "Domínio alterado para: ${DOMAIN}"

    # Perguntar sobre SSL
    if confirm "Deseja configurar/reconfigurar SSL para '${DOMAIN}'?" "y"; then
        INSTALL_SSL="y"
        apply_ssl
    fi

    apply_nginx_and_config
}

reconfig_discord() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  ALTERAR CREDENCIAIS DISCORD${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Discord Developer Portal: ${CYAN}https://discord.com/developers/applications${NC}"
    echo ""
    echo -e "  Client ID atual:     ${CYAN}${DISCORD_CLIENT_ID:0:8}...${NC}"
    echo -e "  Client Secret atual: ${CYAN}${DISCORD_CLIENT_SECRET:0:4}...${NC}"
    echo -e "  Bot Token atual:     ${CYAN}${DISCORD_BOT_TOKEN:0:8}...${NC}"
    echo -e "  Guild ID atual:      ${CYAN}${DISCORD_GUILD_ID}${NC}"
    echo ""

    local new_id new_secret new_token new_guild
    read -r -p "$(echo -e "${CYAN}Novo Discord Client ID (Enter para manter): ${NC}")"     new_id
    read -r -p "$(echo -e "${CYAN}Novo Discord Client Secret (Enter para manter): ${NC}")" new_secret
    read -r -p "$(echo -e "${CYAN}Novo Discord Bot Token (Enter para manter): ${NC}")"     new_token
    read -r -p "$(echo -e "${CYAN}Novo Discord Guild ID (Enter para manter): ${NC}")"      new_guild

    [[ -n "$new_id" ]]     && DISCORD_CLIENT_ID="$new_id"
    [[ -n "$new_secret" ]] && DISCORD_CLIENT_SECRET="$new_secret"
    [[ -n "$new_token" ]]  && DISCORD_BOT_TOKEN="$new_token"
    [[ -n "$new_guild" ]]  && DISCORD_GUILD_ID="$new_guild"

    update_config_json
    restart_service
    print_success "Credenciais Discord atualizadas no config.json"

    local callback_url="https://${DOMAIN}/auth/discord/callback"
    echo ""
    print_info "Lembre-se de atualizar o Redirect URI no Discord Developer Portal:"
    echo -e "  ${GREEN}${callback_url}${NC}"
}

reconfig_steam() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  ALTERAR STEAM API KEY${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Portal Steam: ${CYAN}https://steamcommunity.com/dev/apikey${NC}"
    echo -e "  Steam API Key atual: ${CYAN}${STEAM_API_KEY:0:8}...${NC}"
    echo ""

    local new_key
    read -r -p "$(echo -e "${CYAN}Nova Steam API Key (Enter para manter): ${NC}")" new_key
    if [[ -n "$new_key" ]]; then
        STEAM_API_KEY="$new_key"
        update_config_json
        restart_service
        print_success "Steam API Key atualizada"
    else
        print_info "Steam API Key mantida"
    fi
}

reconfig_port() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  ALTERAR PORTA DO BACKEND${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Porta atual: ${CYAN}${PORT}${NC}"
    echo ""

    local new_port
    read -r -p "$(echo -e "${CYAN}Nova porta (Enter para manter): ${NC}")" new_port
    if [[ -n "$new_port" ]] && [[ "$new_port" =~ ^[0-9]+$ ]]; then
        PORT="$new_port"
        update_config_json
        apply_nginx_and_config
        restart_service
        print_success "Porta alterada para: ${PORT}"
    else
        print_info "Porta mantida: ${PORT}"
    fi
}

reconfig_ssl() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  CONFIGURAR / RENOVAR SSL${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Domínio: ${CYAN}${DOMAIN}${NC}"
    echo -e "  SSL atual: ${CYAN}${INSTALL_SSL}${NC}"
    echo ""
    print_warning "Certifique-se de que '${DOMAIN}' aponta para este servidor!"
    echo ""

    if confirm "Configurar/renovar SSL via Let's Encrypt para '${DOMAIN}'?" "y"; then
        INSTALL_SSL="y"
        apply_ssl
    fi
}

reconfig_cloudflare_tunnel() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  RECONFIGURAR CLOUDFLARE TUNNEL${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! command -v cloudflared &>/dev/null; then
        print_error "cloudflared não está instalado."
        print_info "Execute o instalador com Cenário 3 para instalar."
        return
    fi

    echo -e "  Painel Cloudflare: ${CYAN}https://one.dash.cloudflare.com${NC}"
    echo ""
    print_info "Acesse Networks → Tunnels → selecione ou crie seu tunnel → copie o token"
    echo ""

    local new_token
    read -r -p "$(echo -e "${CYAN}Novo Tunnel Token: ${NC}")" new_token

    if [[ -z "$new_token" ]]; then
        print_info "Operação cancelada."
        return
    fi

    # Remover serviço antigo e instalar novo
    sudo cloudflared service uninstall 2>/dev/null || true
    sudo cloudflared service install "$new_token"
    sudo systemctl enable cloudflared 2>/dev/null || true
    sudo systemctl restart cloudflared 2>/dev/null || true

    sleep 3
    if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
        print_success "Cloudflare Tunnel reconfigurado e ativo!"
    else
        print_warning "Tunnel instalado mas não pôde iniciar. Verifique:"
        print_warning "  sudo journalctl -u cloudflared -n 20"
    fi
}

################################################################################
# Helpers de aplicação
################################################################################

update_config_json() {
    local cfg="${INSTALL_DIR}/config.json"
    if [[ ! -f "$cfg" ]]; then
        print_error "config.json não encontrado: ${cfg}"
        return 1
    fi

    local proto="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto="https"

    python3 - "$cfg" "$DOMAIN" "$PORT" \
        "$DISCORD_CLIENT_ID" "$DISCORD_CLIENT_SECRET" \
        "$DISCORD_BOT_TOKEN" "$DISCORD_GUILD_ID" \
        "$STEAM_API_KEY" "$proto" << 'PYEOF'
import sys, json

cfg_path, domain, port, cli_id, cli_sec, bot_tok, guild_id, steam_key, proto = sys.argv[1:]

with open(cfg_path, 'r') as f:
    d = json.load(f)

d['domain']                  = domain
d['server_port']             = int(port)
d['discord_client_id']       = cli_id
d['discord_client_secret']   = cli_sec
d['discord_bot_token']       = bot_tok
d['discord_guild_id']        = guild_id
d['steam_api_key']           = steam_key
d['logo_url']                = f"{proto}://{domain}/images/logo.png"

# Atualizar frontend_urls com protocolo e domínio novos
abbr = d.get('abbr', '')
d['frontend_urls'] = {
    "member":        f"{proto}://{domain}/{abbr}/member/{{userid}}",
    "delivery":      f"{proto}://{domain}/{abbr}/delivery/{{logid}}",
    "email_confirm": f"{proto}://{domain}/{abbr}/auth/email?secret={{secret}}"
}

with open(cfg_path, 'w') as f:
    json.dump(d, f, indent=4, ensure_ascii=False)

print(f"config.json atualizado: domain={domain}, port={port}, proto={proto}")
PYEOF

    chmod 600 "$cfg"
    print_success "config.json atualizado"

    # Atualizar api_host no banco e limpar cache Redis
    local correct_api_host
    local proto_local="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto_local="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto_local="https"
    correct_api_host="${proto_local}://${DOMAIN}"

    sudo mysql -e \
        "UPDATE \`${VTC_ABBR}_db\`.settings \
         SET sval = JSON_SET(sval, '\$.api_host', '${correct_api_host}') \
         WHERE skey='client-config/meta';" 2>/dev/null || true
    redis-cli DEL "client-config:meta" >/dev/null 2>&1 || true
    print_info "api_host no banco atualizado para: ${correct_api_host}"
}

apply_nginx_and_config() {
    if [[ "$INSTALL_NGINX" != "y" ]]; then
        return
    fi

    local NGINX_CONF="/etc/nginx/sites-available/drivershub-${VTC_ABBR}"
    if [[ ! -f "$NGINX_CONF" ]]; then
        print_warning "Config Nginx não encontrada: ${NGINX_CONF}. Pulando atualização Nginx."
        return
    fi

    # Atualizar server_name e proxy_pass
    sudo sed -i "s|server_name .*;|server_name ${DOMAIN};|" "$NGINX_CONF"
    sudo sed -i "s|proxy_pass http://localhost:[0-9]*;|proxy_pass http://localhost:${PORT};|" "$NGINX_CONF"

    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        print_success "Nginx reconfigurado para ${DOMAIN}:${PORT}"
    else
        print_error "Erro na configuração Nginx — reverta manualmente"
    fi
}

apply_ssl() {
    if ! command -v certbot &>/dev/null; then
        print_info "Instalando Certbot..."
        sudo apt-get install -y certbot python3-certbot-nginx -qq
    fi

    print_warning "Certifique-se de que '${DOMAIN}' aponta para este servidor antes de prosseguir!"

    if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
            --register-unsafely-without-email; then
        INSTALL_SSL="y"
        print_success "SSL/HTTPS configurado para ${DOMAIN}"
    else
        print_warning "Falha no Certbot. Configure manualmente:"
        print_warning "  sudo certbot --nginx -d ${DOMAIN}"
    fi
}

restart_service() {
    print_info "Reiniciando serviço..."
    sudo systemctl restart "drivershub-${VTC_ABBR}.service" 2>/dev/null || true
    sleep 2
    if sudo systemctl is-active --quiet "drivershub-${VTC_ABBR}.service"; then
        print_success "Serviço reiniciado com sucesso"
    else
        print_warning "Serviço não está ativo. Verifique:"
        print_warning "  sudo journalctl -u drivershub-${VTC_ABBR} -n 20"
    fi
}

save_state() {
    local proto="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto="https"

    cat > "$STATE_FILE" << EOF
# Gerado por reconfigure-drivershub.sh — não edite manualmente
BACKEND_VTC_NAME="$VTC_NAME"
BACKEND_VTC_ABBR="$VTC_ABBR"
BACKEND_DOMAIN="$DOMAIN"
BACKEND_PORT="$PORT"
BACKEND_PROTOCOL="$proto"
BACKEND_INSTALL_NGINX="$INSTALL_NGINX"
BACKEND_INSTALL_SSL="$INSTALL_SSL"
BACKEND_NGINX_CONF="drivershub-${VTC_ABBR}"
BACKEND_INSTALL_DIR="$INSTALL_DIR"
BACKEND_DEPLOY_SCENARIO="$DEPLOY_SCENARIO"
BACKEND_INSTALLED_AT="${BACKEND_INSTALLED_AT:-}"
BACKEND_RECONFIGURED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BACKEND_INSTALLER_VERSION="${BACKEND_INSTALLER_VERSION:-1.3.0}"
EOF
    chmod 600 "$STATE_FILE"
    print_success "Estado salvo em $STATE_FILE"
}

################################################################################
# Menu principal
################################################################################

main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  VTC: ${VTC_NAME} (${VTC_ABBR})${NC}"
        echo -e "${CYAN}║  Domínio: ${DOMAIN}  |  Porta: ${PORT}  |  SSL: ${INSTALL_SSL}${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${MAGENTA}O que deseja reconfigurar?${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  1) Domínio                   — alterar domínio/URL do servidor"
        echo "  2) Credenciais Discord        — Client ID, Secret, Bot Token, Guild ID"
        echo "  3) Steam API Key              — chave de integração Steam"
        echo "  4) Porta do backend           — porta em que o backend escuta"
        echo "  5) SSL / HTTPS                — configurar ou renovar certificado"
        echo "  6) Cloudflare Tunnel          — reconfigurar token do tunnel"
        echo "  7) Validar credenciais agora  — testar Discord e Steam"
        echo "  8) Sair"
        echo ""
        local choice
        read -r -p "$(echo -e "${CYAN}Escolha [1-8]: ${NC}")" choice

        case "$choice" in
            1) reconfig_domain;             save_state ;;
            2) load_current_credentials
               reconfig_discord;            save_state ;;
            3) load_current_credentials
               reconfig_steam;              save_state ;;
            4) load_current_credentials
               reconfig_port;              save_state ;;
            5) reconfig_ssl;               save_state ;;
            6) reconfig_cloudflare_tunnel  ;;
            7) load_current_credentials
               validate_credentials_quick  ;;
            8|q|Q) print_info "Saindo."; exit 0 ;;
            *) print_error "Opção inválida." ;;
        esac
    done
}

validate_credentials_quick() {
    echo ""
    print_info "Validando Discord Bot Token..."
    local bot_response bot_code
    bot_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        "https://discord.com/api/v10/users/@me" \
        --max-time 10 2>/dev/null) || true
    bot_code=$(echo "$bot_response" | tail -1)

    if [[ "$bot_code" == "200" ]]; then
        local bot_user
        bot_user=$(echo "$bot_response" | head -n -1 | python3 -c \
            "import json,sys; d=json.load(sys.stdin); print(d.get('username','?'))" 2>/dev/null || echo "?")
        print_success "Bot Token válido — Bot: ${bot_user}"
    elif [[ "$bot_code" == "401" ]]; then
        print_error "Bot Token INVÁLIDO!"
    else
        print_warning "Não foi possível validar Bot Token (HTTP ${bot_code:-timeout})"
    fi

    print_info "Validando Discord Client ID e Secret..."
    local token_response token_code
    token_response=$(curl -s -w "\n%{http_code}" \
        -X POST "https://discord.com/api/v10/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --user "${DISCORD_CLIENT_ID}:${DISCORD_CLIENT_SECRET}" \
        -d "grant_type=client_credentials&scope=identify" \
        --max-time 15 2>/dev/null) || true
    token_code=$(echo "$token_response" | tail -1)

    if [[ "$token_code" == "200" ]]; then
        print_success "Client ID/Secret válidos — OAuth2 confirmado"
    elif [[ "$token_code" == "401" ]]; then
        print_error "Client ID ou Client Secret INVÁLIDO!"
    else
        print_warning "Não foi possível validar Client ID/Secret (HTTP ${token_code:-timeout})"
    fi

    print_info "Validando Steam API Key..."
    local steam_response steam_code
    steam_response=$(curl -s -w "\n%{http_code}" \
        "https://api.steampowered.com/ISteamWebAPIUtil/GetSupportedAPIList/v1/?key=${STEAM_API_KEY}" \
        --max-time 10 2>/dev/null) || true
    steam_code=$(echo "$steam_response" | tail -1)

    if [[ "$steam_code" == "200" ]] && echo "$steam_response" | grep -q "apilist"; then
        print_success "Steam API Key válida"
    elif echo "$steam_response" | grep -qi "forbidden\|unauthorized\|invalid"; then
        print_error "Steam API Key INVÁLIDA!"
    else
        print_warning "Não foi possível validar Steam API Key (HTTP ${steam_code:-timeout})"
    fi
}

################################################################################
# Main
################################################################################

print_header
check_root
select_vtc
load_current_credentials
main_menu
