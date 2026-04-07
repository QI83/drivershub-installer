#!/bin/bash

################################################################################
# Script de Instalação Automatizada do Drivers Hub
# Versão: 1.3.0
# Data: Abril 2026
#
# Este script automatiza a instalação completa do Drivers Hub Backend
# incluindo configuração de banco de dados, Redis, e serviços.
#
# Cenários suportados:
#   1. VPS/Cloud + Domínio próprio + Let's Encrypt (SSL automático)
#   2. VPS/Cloud + DuckDNS (domínio gratuito) + Let's Encrypt (SSL automático)
#   3. Servidor local + Cloudflare Tunnel (HTTPS via Cloudflare, sem IP fixo)
#
# Multi-VTC: cada VTC recebe seu próprio diretório, banco e serviço.
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

# ── Variáveis globais ─────────────────────────────────────────────────────────
INSTALL_BASE="/opt/drivershub"
INSTALL_DIR=""       # Definido após VTC_ABBR ser conhecido: $INSTALL_BASE/$VTC_ABBR/HubBackend
STATE_FILE=""        # Definido após VTC_ABBR ser conhecido: $INSTALL_BASE/.installer_state_$VTC_ABBR
INSTALL_MODE="fresh" # fresh | repair

DEPLOY_SCENARIO=1    # 1=VPS+domínio, 2=VPS+DuckDNS, 3=local+CloudflareTunnel
DUCKDNS_TOKEN=""
DUCKDNS_SUBDOMAIN=""
CF_TUNNEL_TOKEN=""

DB_PASSWORD=""
VTC_NAME=""
VTC_ABBR=""
DOMAIN=""
PORT="7777"
DISCORD_CLIENT_ID=""
DISCORD_CLIENT_SECRET=""
DISCORD_BOT_TOKEN=""
DISCORD_GUILD_ID=""
STEAM_API_KEY=""
INSTALL_NGINX="n"
INSTALL_SSL="n"

TOTAL_STEPS=12

################################################################################
# Funções Auxiliares
################################################################################

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          INSTALADOR AUTOMÁTICO - DRIVERS HUB                  ║"
    echo "║              Euro Truck Simulator 2 / ATS                     ║"
    echo "║                                                               ║"
    echo "║ Versão: 1.3.0                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[PASSO $1/${TOTAL_STEPS}]${NC} ${GREEN}$2${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

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
        print_error "Este script NÃO deve ser executado como root!"
        print_info "Execute como usuário normal. O script pedirá sudo quando necessário."
        exit 1
    fi
}

################################################################################
# Passo 1 — Requisitos do sistema (hardware + software)
################################################################################

check_requirements() {
    print_step 1 "Verificando requisitos do sistema"

    # Sistema operacional
    if ! command -v apt &>/dev/null; then
        print_error "Este script requer Ubuntu/Debian (sistema com apt)"
        exit 1
    fi
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        print_info "Sistema detectado: $PRETTY_NAME"
    fi

    # Instalar curl se necessário
    if ! command -v curl &>/dev/null; then
        print_info "Instalando curl..."
        sudo apt-get install -y curl -qq
    fi

    # ── Recursos de hardware ─────────────────────────────────────────────────
    local warn=0

    # RAM
    local total_ram
    total_ram=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
    if [[ "$total_ram" -ge 1500 ]]; then
        print_success "RAM: ${total_ram}MB (mínimo: 1500MB)"
    elif [[ "$total_ram" -ge 900 ]]; then
        print_warning "RAM: ${total_ram}MB — abaixo do recomendado (1500MB). O serviço pode ser mais lento."
        warn=$((warn + 1))
    else
        print_error "RAM insuficiente: ${total_ram}MB (mínimo recomendado: 1500MB)"
        if ! confirm "Continuar mesmo assim?" "n"; then
            exit 1
        fi
    fi

    # Disco livre
    local free_disk
    free_disk=$(df -m "${INSTALL_BASE}" 2>/dev/null | awk 'NR==2{print $4}' \
                || df -m / | awk 'NR==2{print $4}')
    if [[ "${free_disk:-0}" -ge 5000 ]]; then
        print_success "Disco: ${free_disk}MB livres (mínimo: 5000MB)"
    elif [[ "${free_disk:-0}" -ge 2000 ]]; then
        print_warning "Disco: ${free_disk}MB livres — pouco espaço (recomendado: 5000MB+)"
        warn=$((warn + 1))
    else
        print_error "Espaço insuficiente: ${free_disk:-?}MB livres (mínimo: 2000MB)"
        if ! confirm "Continuar mesmo assim?" "n"; then
            exit 1
        fi
    fi

    # Acesso à internet
    if curl -s --head https://github.com --max-time 8 &>/dev/null; then
        print_success "Acesso à internet: OK"
    else
        print_warning "Acesso à internet: não confirmado. Verifique a conectividade."
        warn=$((warn + 1))
    fi

    # Portas 80 e 443
    if ss -lnt 2>/dev/null | grep -qE ':80\s|:80$'; then
        print_warning "Porta 80 já está em uso por outro processo!"
        warn=$((warn + 1))
    else
        print_success "Porta 80: disponível"
    fi
    if ss -lnt 2>/dev/null | grep -qE ':443\s|:443$'; then
        print_warning "Porta 443 já está em uso por outro processo!"
        warn=$((warn + 1))
    else
        print_success "Porta 443: disponível"
    fi

    if [[ $warn -gt 0 ]]; then
        print_warning "$warn aviso(s) de recursos. A instalação continuará — verifique os avisos acima."
    else
        print_success "Todos os requisitos verificados com sucesso"
    fi
}

################################################################################
# Passo 2 — Escolha do cenário de implantação
################################################################################

choose_deployment_scenario() {
    print_step 2 "Escolhendo cenário de implantação"

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  CENÁRIO 1 — VPS/Cloud + Domínio Próprio + SSL               ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ✅ Servidor VPS (DigitalOcean, Vultr, Contabo, AWS…)         ║${NC}"
    echo -e "${CYAN}║  ✅ Domínio já registrado (ex: minha-vtc.com.br)              ║${NC}"
    echo -e "${CYAN}║  ✅ SSL/HTTPS automático via Let's Encrypt                    ║${NC}"
    echo -e "${CYAN}║  💡 Ideal para produção com domínio personalizado             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  CENÁRIO 2 — VPS/Cloud + DuckDNS (domínio gratuito) + SSL    ║${NC}"
    echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║  ✅ Servidor VPS mas SEM domínio registrado                  ║${NC}"
    echo -e "${MAGENTA}║  ✅ Subdomínio GRATUITO via duckdns.org (ex: minha-vtc.duckdns.org) ║${NC}"
    echo -e "${MAGENTA}║  ✅ SSL/HTTPS automático via Let's Encrypt                   ║${NC}"
    echo -e "${MAGENTA}║  ✅ Atualização automática de IP (sem IP fixo obrigatório)   ║${NC}"
    echo -e "${MAGENTA}║  💡 Ideal para começar sem custo com domínio                ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  CENÁRIO 3 — Servidor Local + Cloudflare Tunnel               ║${NC}"
    echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  ✅ Computador/servidor local (casa, escritório)              ║${NC}"
    echo -e "${YELLOW}║  ✅ Sem IP fixo? Sem problema!                               ║${NC}"
    echo -e "${YELLOW}║  ✅ HTTPS automático via Cloudflare Tunnel (gratuito)         ║${NC}"
    echo -e "${YELLOW}║  ✅ Sem necessidade de abrir portas no roteador               ║${NC}"
    echo -e "${YELLOW}║  💡 Ideal para uso pessoal ou máquina local                  ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local choice
    while true; do
        read -r -p "$(echo -e "${CYAN}Escolha o cenário [1/2/3]: ${NC}")" choice
        case "$choice" in
            1)
                DEPLOY_SCENARIO=1
                print_success "Cenário 1: VPS + Domínio Próprio + Let's Encrypt"
                INSTALL_NGINX="y"
                INSTALL_SSL="y"
                break
                ;;
            2)
                DEPLOY_SCENARIO=2
                print_success "Cenário 2: VPS + DuckDNS + Let's Encrypt"
                INSTALL_NGINX="y"
                INSTALL_SSL="y"
                break
                ;;
            3)
                DEPLOY_SCENARIO=3
                print_success "Cenário 3: Servidor Local + Cloudflare Tunnel"
                INSTALL_NGINX="y"
                INSTALL_SSL="n"  # SSL é terminado pelo Cloudflare
                break
                ;;
            *)
                print_error "Opção inválida. Digite 1, 2 ou 3."
                ;;
        esac
    done
}

################################################################################
# Detecção de instalação existente — multi-VTC
################################################################################

detect_existing_installation() {
    # Procurar state files existentes (formato novo _ABBR e formato legado)
    local -a found_states=()

    if [[ -d "$INSTALL_BASE" ]]; then
        while IFS= read -r -d '' sf; do
            found_states+=("$sf")
        done < <(find "$INSTALL_BASE" -maxdepth 1 -name '.installer_state*' -print0 2>/dev/null)
    fi

    # Nada encontrado → fresh install
    if [[ ${#found_states[@]} -eq 0 ]] && [[ ! -d "${INSTALL_BASE}/HubBackend" ]]; then
        INSTALL_MODE="fresh"
        return
    fi

    clear
    print_header

    echo -e "${YELLOW}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       ⚠️  INSTALAÇÃO(ÕES) EXISTENTE(S) DETECTADA(S)!         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Mostrar VTCs instaladas
    local idx=0
    local -a vtc_states=()
    for sf in "${found_states[@]}"; do
        (
            # shellcheck source=/dev/null
            source "$sf" 2>/dev/null
            echo "${BACKEND_VTC_NAME:-?} (${BACKEND_VTC_ABBR:-?}) — ${BACKEND_DOMAIN:-?} — instalado em ${BACKEND_INSTALLED_AT:-?}"
        ) 2>/dev/null && vtc_states+=("$sf")
        idx=$((idx + 1))
    done

    # Mostrar lista numerada
    echo -e "${MAGENTA}VTCs instaladas neste servidor:${NC}"
    idx=1
    for sf in "${found_states[@]}"; do
        local abbr_label
        abbr_label=$(basename "$sf" | sed 's/.installer_state_\?//')
        abbr_label=${abbr_label:-legado}
        echo "  $idx) $sf  [$abbr_label]"
        idx=$((idx + 1))
    done
    echo ""
    echo -e "${MAGENTA}O que deseja fazer?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  r) Reparar instalação existente — corrige dependências e serviço"
    echo "     sem apagar dados ou o config.json existente"
    echo ""
    echo "  n) Nova instalação — instala uma nova VTC neste servidor"
    echo ""
    echo "  q) Cancelar"
    echo ""

    local choice
    read -r -p "$(echo -e "${CYAN}Escolha [r/n/q]: ${NC}")" choice

    case "$choice" in
        r|R)
            INSTALL_MODE="repair"
            print_info "Modo: Reparo — dados e config.json preservados."

            # Se há apenas um state file, usar ele automaticamente
            local repair_state=""
            if [[ ${#found_states[@]} -eq 1 ]]; then
                repair_state="${found_states[0]}"
            else
                # Perguntar qual VTC reparar
                echo ""
                read -r -p "$(echo -e "${CYAN}Número da VTC a reparar: ${NC}")" repair_idx
                if [[ "$repair_idx" =~ ^[0-9]+$ ]] && \
                   [[ "$repair_idx" -ge 1 ]] && \
                   [[ "$repair_idx" -le "${#found_states[@]}" ]]; then
                    repair_state="${found_states[$((repair_idx - 1))]}"
                else
                    print_error "Índice inválido."
                    exit 1
                fi
            fi

            if [[ -f "$repair_state" ]]; then
                # shellcheck source=/dev/null
                source "$repair_state"
                VTC_NAME="$BACKEND_VTC_NAME"
                VTC_ABBR="$BACKEND_VTC_ABBR"
                DOMAIN="$BACKEND_DOMAIN"
                PORT="${BACKEND_PORT:-7777}"
                INSTALL_NGINX="${BACKEND_INSTALL_NGINX:-n}"
                INSTALL_SSL="${BACKEND_INSTALL_SSL:-n}"
                DEPLOY_SCENARIO="${BACKEND_DEPLOY_SCENARIO:-1}"

                # Definir caminhos
                INSTALL_DIR="${INSTALL_BASE}/${VTC_ABBR}/HubBackend"
                # Compatibilidade com instalações antigas (diretório legado)
                if [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]]; then
                    INSTALL_DIR="${INSTALL_BASE}/HubBackend"
                fi
                STATE_FILE="$repair_state"

                # Carregar credenciais do config.json existente
                local cfg="${INSTALL_DIR}/config.json"
                if [[ -f "$cfg" ]]; then
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
                fi
            fi
            ;;
        n|N)
            INSTALL_MODE="fresh"
            print_info "Modo: Nova instalação — será instalada uma nova VTC."
            ;;
        q|Q|"")
            print_warning "Instalação cancelada."
            exit 0
            ;;
        *)
            print_error "Opção inválida."
            exit 1
            ;;
    esac
}

################################################################################
# Passo 3 — Coleta de informações
################################################################################

collect_info() {
    # Modo reparo: dados já carregados — apenas confirmar
    if [[ "$INSTALL_MODE" == "repair" ]]; then
        print_step 3 "Confirmando configurações existentes (modo reparo)"
        echo ""
        echo -e "  VTC:        ${CYAN}${VTC_NAME} (${VTC_ABBR})${NC}"
        echo -e "  Domínio:    ${CYAN}${DOMAIN}${NC}"
        echo -e "  Porta:      ${CYAN}${PORT}${NC}"
        echo -e "  Discord:    ${CYAN}${DISCORD_CLIENT_ID:0:8}...${NC}"
        echo -e "  Steam:      ${CYAN}${STEAM_API_KEY:0:8}...${NC}"
        echo -e "  Nginx:      ${CYAN}${INSTALL_NGINX}${NC}"
        echo -e "  SSL:        ${CYAN}${INSTALL_SSL}${NC}"
        echo ""
        print_success "Configurações carregadas da instalação anterior"
        return
    fi

    print_step 3 "Coletando informações da instalação"

    echo -e "\n${MAGENTA}📋 INFORMAÇÕES DA SUA VTC${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    while [[ -z "$VTC_NAME" ]]; do
        read -r -p "$(echo -e "${CYAN}Nome completo da VTC: ${NC}")" VTC_NAME
    done

    while [[ -z "$VTC_ABBR" ]]; do
        read -r -p "$(echo -e "${CYAN}Abreviação da VTC (ex: cdmp): ${NC}")" VTC_ABBR
        VTC_ABBR=$(echo "$VTC_ABBR" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    done

    # Definir caminhos agora que VTC_ABBR é conhecido
    INSTALL_DIR="${INSTALL_BASE}/${VTC_ABBR}/HubBackend"
    STATE_FILE="${INSTALL_BASE}/.installer_state_${VTC_ABBR}"

    # Verificar colisão de abreviação com VTC já instalada
    if [[ -d "$INSTALL_DIR" ]] || [[ -f "$STATE_FILE" ]]; then
        print_warning "Já existe uma instalação para '${VTC_ABBR}' em ${INSTALL_DIR}!"
        if ! confirm "Deseja sobrescrever a instalação existente de '${VTC_ABBR}'?" "n"; then
            print_warning "Instalação cancelada. Use a opção 'Reparar' para atualizar."
            exit 0
        fi
    fi

    # Domínio — varia por cenário
    echo ""
    case "$DEPLOY_SCENARIO" in
        1)
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║  Cenário 1: informe seu domínio já registrado                ║${NC}"
            echo -e "${CYAN}║  Ex: hub.minha-vtc.com.br  ou  minha-vtc.com.br              ║${NC}"
            echo -e "${CYAN}║  ⚠️  Certifique-se de que o DNS já aponta para este servidor  ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            while [[ -z "$DOMAIN" ]]; do
                read -r -p "$(echo -e "${CYAN}Domínio: ${NC}")" DOMAIN
                DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/$||' | tr -d ' ')
            done
            ;;
        2)
            echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${MAGENTA}║  Cenário 2: DuckDNS — será configurado no próximo passo      ║${NC}"
            echo -e "${MAGENTA}║  Tenha em mãos: subdomínio e token do duckdns.org            ║${NC}"
            echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            print_info "O domínio será preenchido automaticamente após configurar o DuckDNS."
            # DOMAIN será preenchido em setup_duckdns()
            DOMAIN="placeholder-duckdns"
            ;;
        3)
            echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║  Cenário 3: Cloudflare Tunnel — informe o domínio que        ║${NC}"
            echo -e "${YELLOW}║  você configurará no painel Cloudflare.                      ║${NC}"
            echo -e "${YELLOW}║  Ex: hub.minha-vtc.com.br  (domínio gerenciado no Cloudflare)║${NC}"
            echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            while [[ -z "$DOMAIN" ]]; do
                read -r -p "$(echo -e "${CYAN}Domínio Cloudflare (ex: hub.minhaVTC.com.br): ${NC}")" DOMAIN
                DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/$||' | tr -d ' ')
            done
            ;;
    esac

    # Porta
    read -r -p "$(echo -e "${CYAN}Porta do servidor [7777]: ${NC}")" input_port
    PORT=${input_port:-7777}

    echo -e "\n${MAGENTA}🔐 CREDENCIAIS DO BANCO DE DADOS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    while [[ -z "$DB_PASSWORD" ]]; do
        read -r -sp "$(echo -e "${CYAN}Senha para o banco de dados MySQL: ${NC}")" DB_PASSWORD
        echo
        local DB_PASSWORD_CONFIRM
        read -r -sp "$(echo -e "${CYAN}Confirme a senha: ${NC}")" DB_PASSWORD_CONFIRM
        echo
        if [[ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]]; then
            print_error "As senhas não coincidem!"
            DB_PASSWORD=""
        fi
    done

    echo -e "\n${MAGENTA}🎮 INTEGRAÇÃO DISCORD & STEAM${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Discord: https://discord.com/developers/applications"
    print_info "Steam:   https://steamcommunity.com/dev/apikey"
    echo ""

    read -r -p "$(echo -e "${CYAN}Discord Client ID: ${NC}")"     DISCORD_CLIENT_ID
    read -r -p "$(echo -e "${CYAN}Discord Client Secret: ${NC}")" DISCORD_CLIENT_SECRET
    read -r -p "$(echo -e "${CYAN}Discord Bot Token: ${NC}")"     DISCORD_BOT_TOKEN
    read -r -p "$(echo -e "${CYAN}Discord Server (Guild) ID: ${NC}")" DISCORD_GUILD_ID
    read -r -p "$(echo -e "${CYAN}Steam API Key: ${NC}")"         STEAM_API_KEY

    # Resumo
    echo -e "\n${GREEN}📊 RESUMO DA INSTALAÇÃO${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC:             $VTC_NAME ($VTC_ABBR)"
    echo "Cenário:         $DEPLOY_SCENARIO"
    if [[ "$DEPLOY_SCENARIO" -ne 2 ]]; then
        echo "Domínio:         $DOMAIN"
    else
        echo "Domínio:         (será definido via DuckDNS)"
    fi
    echo "Porta:           $PORT"
    echo "Diretório:       $INSTALL_DIR"
    echo "Discord:         ${DISCORD_CLIENT_ID:0:8}..."
    echo "Steam:           ${STEAM_API_KEY:0:8}..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! confirm "Confirma as informações acima e deseja continuar?"; then
        print_warning "Instalação cancelada pelo usuário"
        exit 0
    fi

    print_success "Informações coletadas"
}

################################################################################
# Passo 4 — DuckDNS (somente Cenário 2)
################################################################################

setup_duckdns() {
    if [[ "$DEPLOY_SCENARIO" -ne 2 ]]; then
        return
    fi

    print_step 4 "Configurando DuckDNS (domínio gratuito)"

    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  CONFIGURAÇÃO DO DUCKDNS${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "1. Acesse https://www.duckdns.org e faça login (GitHub/Google)"
    print_info "2. Crie um subdomínio desejado (ex: minha-vtc)"
    print_info "3. Copie o Token da sua conta"
    echo ""

    while [[ -z "$DUCKDNS_SUBDOMAIN" ]]; do
        read -r -p "$(echo -e "${CYAN}Subdomínio DuckDNS (sem .duckdns.org): ${NC}")" DUCKDNS_SUBDOMAIN
        DUCKDNS_SUBDOMAIN=$(echo "$DUCKDNS_SUBDOMAIN" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    done

    while [[ -z "$DUCKDNS_TOKEN" ]]; do
        read -r -p "$(echo -e "${CYAN}Token DuckDNS: ${NC}")" DUCKDNS_TOKEN
    done

    DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    print_info "Domínio configurado: ${DOMAIN}"

    # Atualizar IP agora
    print_info "Atualizando IP público no DuckDNS..."
    local duck_result
    duck_result=$(curl -s \
        "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" \
        --max-time 10 2>/dev/null || echo "KO")

    if [[ "$duck_result" == "OK" ]]; then
        print_success "IP atualizado no DuckDNS com sucesso!"
    else
        print_warning "Resposta do DuckDNS: '${duck_result}'. Verifique manualmente em duckdns.org"
    fi

    # Script de atualização automática
    local duck_script="${INSTALL_BASE}/duckdns-update.sh"
    sudo tee "$duck_script" > /dev/null << DUCKEOF
#!/bin/bash
# Atualização automática de IP para DuckDNS — gerado pelo instalador DriversHub
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" \
     >> /var/log/duckdns.log 2>&1
DUCKEOF
    sudo chmod +x "$duck_script"

    # Cron a cada 5 minutos
    ( sudo crontab -l 2>/dev/null | grep -v duckdns-update; \
      echo "*/5 * * * * ${duck_script}" ) | sudo crontab -

    print_success "DuckDNS configurado! IP atualizado automaticamente a cada 5 minutos."
    print_info "Log de atualizações: /var/log/duckdns.log"
}

################################################################################
# Passo 5 — Validação de credenciais Discord e Steam
################################################################################

validate_credentials() {
    print_step 5 "Validando credenciais Discord e Steam"

    local errors=0

    # ── Discord Bot Token ──────────────────────────────────────────────────────
    print_info "Validando Discord Bot Token..."
    local bot_response bot_code bot_body
    bot_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        "https://discord.com/api/v10/users/@me" \
        --max-time 10 2>/dev/null) || true

    bot_code=$(echo "$bot_response" | tail -1)
    bot_body=$(echo "$bot_response" | head -n -1)

    if [[ "$bot_code" == "200" ]]; then
        local bot_username
        bot_username=$(echo "$bot_body" | python3 -c \
            "import json,sys; d=json.load(sys.stdin); print(d.get('username','?'))" \
            2>/dev/null || echo "?")
        print_success "Discord Bot Token válido — Bot: ${bot_username}"
    elif [[ "$bot_code" == "401" ]]; then
        print_error "Discord Bot Token INVÁLIDO! Verifique o token no Discord Developer Portal."
        errors=$((errors + 1))
    else
        print_warning "Não foi possível validar o Bot Token (HTTP ${bot_code:-timeout}). Continuando."
    fi

    # ── Discord Client ID + Secret ─────────────────────────────────────────────
    # Abordagem primária: endpoint OAuth2 token com client_credentials grant
    # Mais confiável do que oauth2/applications/@me com Basic Auth
    print_info "Validando Discord Client ID e Secret..."
    local token_response token_code token_body
    token_response=$(curl -s -w "\n%{http_code}" \
        -X POST "https://discord.com/api/v10/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --user "${DISCORD_CLIENT_ID}:${DISCORD_CLIENT_SECRET}" \
        -d "grant_type=client_credentials&scope=identify" \
        --max-time 15 2>/dev/null) || true

    token_code=$(echo "$token_response" | tail -1)
    token_body=$(echo "$token_response" | head -n -1)

    if [[ "$token_code" == "200" ]]; then
        print_success "Discord Client ID/Secret válidos — OAuth2 confirmado"
    elif [[ "$token_code" == "401" ]]; then
        print_error "Discord Client ID ou Client Secret INVÁLIDO!"
        errors=$((errors + 1))
    else
        # Fallback: tentar oauth2/applications/@me
        local fb_response fb_code
        fb_response=$(curl -s -w "\n%{http_code}" \
            -u "${DISCORD_CLIENT_ID}:${DISCORD_CLIENT_SECRET}" \
            "https://discord.com/api/v10/oauth2/applications/@me" \
            --max-time 10 2>/dev/null) || true
        fb_code=$(echo "$fb_response" | tail -1)

        if [[ "$fb_code" == "200" ]]; then
            print_success "Discord Client ID/Secret válidos"
        elif [[ "$fb_code" == "401" ]]; then
            print_error "Discord Client ID ou Client Secret INVÁLIDO!"
            errors=$((errors + 1))
        else
            print_warning "Não foi possível validar Client ID/Secret (HTTP ${fb_code:-timeout}). Continuando."
        fi
    fi

    # ── Steam API Key ──────────────────────────────────────────────────────────
    print_info "Validando Steam API Key..."
    local steam_response steam_code steam_body
    steam_response=$(curl -s -w "\n%{http_code}" \
        "https://api.steampowered.com/ISteamWebAPIUtil/GetSupportedAPIList/v1/?key=${STEAM_API_KEY}" \
        --max-time 10 2>/dev/null) || true

    steam_code=$(echo "$steam_response" | tail -1)
    steam_body=$(echo "$steam_response" | head -n -1)

    if [[ "$steam_code" == "200" ]] && echo "$steam_body" | grep -q "apilist"; then
        print_success "Steam API Key válida"
    elif echo "$steam_body" | grep -qi "forbidden\|unauthorized\|invalid"; then
        print_error "Steam API Key INVÁLIDA! Obtenha uma em: https://steamcommunity.com/dev/apikey"
        errors=$((errors + 1))
    else
        print_warning "Não foi possível validar Steam API Key (HTTP ${steam_code:-timeout}). Continuando."
    fi

    echo ""

    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_error "$errors credencial(is) inválida(s) detectada(s)!"
        echo ""
        echo "  Corrigir agora evita problemas no login Discord e nas integrações."
        echo ""
        if confirm "Deseja corrigir as credenciais antes de continuar?" "y"; then
            if [[ "$bot_code" == "401" || "$token_code" == "401" ]]; then
                echo -e "\n${MAGENTA}🔐 Corrija suas credenciais Discord${NC}"
                echo "  Portal: https://discord.com/developers/applications"
                read -r -p "$(echo -e "${CYAN}Discord Client ID: ${NC}")"     DISCORD_CLIENT_ID
                read -r -p "$(echo -e "${CYAN}Discord Client Secret: ${NC}")" DISCORD_CLIENT_SECRET
                read -r -p "$(echo -e "${CYAN}Discord Bot Token: ${NC}")"     DISCORD_BOT_TOKEN
            fi
            if echo "$steam_body" | grep -qi "forbidden\|unauthorized\|invalid"; then
                echo -e "\n${MAGENTA}🔐 Corrija sua Steam API Key${NC}"
                read -r -p "$(echo -e "${CYAN}Steam API Key: ${NC}")" STEAM_API_KEY
            fi
            print_info "Revalidando credenciais corrigidas..."
            validate_credentials
        else
            print_warning "Prosseguindo com credenciais possivelmente inválidas. O login Discord pode não funcionar."
        fi
    else
        print_success "Todas as credenciais validadas com sucesso!"
    fi
}

################################################################################
# Passo 6 — Instalação de dependências do sistema
################################################################################

install_system_dependencies() {
    print_step 6 "Instalando dependências do sistema"

    print_info "Atualizando lista de pacotes..."
    sudo apt update -qq

    print_info "Instalando Python e ferramentas de desenvolvimento..."
    sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential \
                        libssl-dev libffi-dev git curl wget -qq

    print_success "Dependências do sistema instaladas"
}

################################################################################
# Passo 7 — MySQL
################################################################################

install_mysql() {
    print_step 7 "Instalando e configurando MySQL"

    if ! command -v mysql &>/dev/null; then
        print_info "Instalando MySQL Server..."

        if dpkg -l 2>/dev/null | grep -q mariadb-server; then
            print_warning "MariaDB detectado. Removendo para evitar conflito com MySQL..."
            sudo systemctl stop mariadb 2>/dev/null || true
            sudo apt-get remove -y --purge mariadb-server mariadb-client mariadb-common -qq
            sudo apt-get autoremove -y -qq
        fi

        sudo apt-get install -y mysql-server mysql-client -qq
        sudo systemctl start mysql
        sudo systemctl enable mysql
        print_success "MySQL instalado"
    else
        local db_version
        db_version=$(mysql --version 2>/dev/null || echo "")
        if echo "$db_version" | grep -qi 'mariadb'; then
            print_warning "Detectado MariaDB no lugar de MySQL. Substituindo..."
            sudo systemctl stop mariadb 2>/dev/null || true
            sudo apt-get remove -y --purge mariadb-server mariadb-client mariadb-common -qq
            sudo apt-get autoremove -y -qq
            sudo apt-get install -y mysql-server mysql-client -qq
            sudo systemctl start mysql
            sudo systemctl enable mysql
            print_success "MySQL instalado em substituição ao MariaDB"
        else
            print_info "MySQL já instalado: $db_version"
        fi
    fi

    print_info "Criando banco de dados e usuário para ${VTC_ABBR}..."

    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${VTC_ABBR}_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    sudo mysql -e "DROP USER IF EXISTS '${VTC_ABBR}_user'@'localhost';" 2>/dev/null || true

    if ! sudo mysql -e "CREATE USER '${VTC_ABBR}_user'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';" 2>/dev/null; then
        print_warning "mysql_native_password indisponível (MySQL 8.4+). Usando autenticação padrão..."
        sudo mysql -e "CREATE USER '${VTC_ABBR}_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" 2>/dev/null || true
    fi

    sudo mysql -e "GRANT ALL PRIVILEGES ON ${VTC_ABBR}_db.* TO '${VTC_ABBR}_user'@'localhost';" 2>/dev/null || true
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

    print_info "Configurando timeouts do MySQL..."
    local mysql_conf="/etc/mysql/mysql.conf.d/drivershub.cnf"
    sudo tee "$mysql_conf" > /dev/null << 'MYSQLEOF'
# Configuração gerada pelo instalador do Drivers Hub
[mysqld]
wait_timeout            = 43200
interactive_timeout     = 43200
connect_timeout         = 10
max_allowed_packet      = 64M
MYSQLEOF

    sudo systemctl restart mysql
    print_success "MySQL configurado com timeouts otimizados"

    if sudo mysql -e "USE ${VTC_ABBR}_db;" 2>/dev/null; then
        print_success "Banco de dados MySQL configurado"
    else
        print_error "Falha ao configurar banco de dados MySQL"
        exit 1
    fi
}

################################################################################
# Passo 8 — Redis
################################################################################

install_redis() {
    print_step 8 "Instalando e configurando Redis"

    if ! command -v redis-cli &>/dev/null; then
        print_info "Instalando Redis..."
        sudo apt install -y redis-server -qq
        sudo systemctl start redis-server
        sudo systemctl enable redis-server
        print_success "Redis instalado"
    else
        print_info "Redis já está instalado"
    fi

    if redis-cli ping | grep -q PONG; then
        print_success "Redis funcionando corretamente"
    else
        print_error "Falha ao conectar com Redis"
        exit 1
    fi
}

################################################################################
# Passo 9 — Clone e configuração do projeto
################################################################################

clone_repository() {
    print_step 9 "Clonando repositório do Drivers Hub"

    # Diretório por VTC para suporte multi-VTC
    local vtc_base="${INSTALL_BASE}/${VTC_ABBR}"
    sudo mkdir -p "$vtc_base"
    sudo chown "$USER":"$USER" "$vtc_base"

    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Diretório já existe. Atualizando..."
        cd "$INSTALL_DIR"
        git pull || true
    else
        print_info "Clonando repositório..."
        cd "$vtc_base"
        git clone https://github.com/CharlesWithC/HubBackend.git
    fi

    print_success "Repositório clonado/atualizado"
}

setup_python_env() {
    cd "$INSTALL_DIR"

    if [[ ! -d "venv" ]]; then
        print_info "Criando ambiente virtual Python..."
        python3 -m venv venv < /dev/null
    fi

    print_info "Ativando ambiente virtual..."
    # shellcheck source=/dev/null
    source venv/bin/activate

    print_info "Atualizando pip..."
    pip install --upgrade pip -q < /dev/null

    print_info "Instalando dependências Python (pode levar alguns minutos)..."
    grep -v '# dev' requirements.txt > /tmp/requirements_prod.txt
    pip install -r /tmp/requirements_prod.txt < /dev/null
    rm -f /tmp/requirements_prod.txt

    print_info "Instalando pacote cryptography (compatibilidade MySQL 8+)..."
    pip install cryptography -q < /dev/null

    deactivate || true
    print_success "Ambiente Python configurado"
}

fix_database_code() {
    cd "$INSTALL_DIR/src"

    if grep -q "DATA DIRECTORY = '" db.py; then
        print_info "Criando backup do db.py original..."
        cp db.py db.py.backup

        print_info "Removendo cláusulas DATA DIRECTORY..."
        python3 - << 'PYEOF'
fname = 'db.py'
with open(fname, 'r') as f:
    content = f.read()
patched = content.replace(" DATA DIRECTORY = '{config.db_data_directory}'", "")
patched = patched.replace(" DATA DIRECTORY = '{app.config.db_data_directory}'", "")
remaining = patched.count("DATA DIRECTORY = '")
with open(fname, 'w') as f:
    f.write(patched)
print(f"Patch aplicado. Ocorrências restantes: {remaining}")
if remaining > 0:
    raise SystemExit(f"ERRO: {remaining} ocorrências de DATA DIRECTORY restantes")
PYEOF
        print_success "Correção DATA DIRECTORY aplicada"
    else
        print_info "Correção DATA DIRECTORY já está aplicada"
    fi
}

fix_client_config_plugin() {
    local plugin_file="$INSTALL_DIR/src/external_plugins/client-config.py"

    if [[ ! -f "$plugin_file" ]]; then
        print_warning "Plugin client-config.py não encontrado — pulando patch."
        return
    fi

    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && protocol="https"  # Cloudflare sempre HTTPS

    if grep -qF "\"${protocol}://\" + config[\"domain\"]" "$plugin_file"; then
        print_info "Patch client-config.py já está correto (${protocol}://)"
        return
    fi

    [[ ! -f "${plugin_file}.bak" ]] && cp "$plugin_file" "${plugin_file}.bak"
    cp "${plugin_file}.bak" "$plugin_file"

    python3 - "$plugin_file" "$protocol" << 'PYEOF'
import sys
fname, protocol = sys.argv[1], sys.argv[2]
with open(fname, 'r') as f:
    content = f.read()
old = '"api_host": config["domain"]'
new = f'"api_host": "{protocol}://" + config["domain"]'
if old not in content:
    print(f"AVISO: padrão não encontrado em {fname} — sem alteração.")
    sys.exit(0)
patched = content.replace(old, new)
with open(fname, 'w') as f:
    f.write(patched)
print(f"Patch aplicado: api_host incluirá {protocol}://")
PYEOF

    if grep -qF "\"${protocol}://\" + config[\"domain\"]" "$plugin_file"; then
        print_success "Patch client-config.py aplicado: api_host incluirá ${protocol}://"
    else
        print_warning "Patch client-config.py não foi aplicado — edite manualmente:"
        print_warning "  Arquivo: $plugin_file"
    fi
}

################################################################################
# Passo 10 — Arquivo de configuração + tabelas
################################################################################

create_config_file() {
    print_step 10 "Criando arquivo de configuração"

    cd "$INSTALL_DIR"

    if [[ "$INSTALL_MODE" == "repair" ]] && [[ -f "config.json" ]]; then
        print_info "Modo reparo — config.json existente preservado."
        print_success "Arquivo config.json mantido"
        return
    fi

    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

    local proto="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto="https"

    cat > config.json << EOF
{
    "abbr": "$VTC_ABBR",
    "name": "$VTC_NAME",
    "language": "pt",
    "distance_unit": "metric",
    "privacy": false,
    "security_level": 1,
    "hex_color": "FFFFFF",
    "logo_url": "${proto}://$DOMAIN/images/logo.png",
    "banner_background_url": "",
    "banner_background_opacity": 0.15,
    "banner_info_first_row": "rank",
    "openapi": true,
    "frontend_urls": {
        "member": "${proto}://$DOMAIN/$VTC_ABBR/member/{userid}",
        "delivery": "${proto}://$DOMAIN/$VTC_ABBR/delivery/{logid}",
        "email_confirm": "${proto}://$DOMAIN/$VTC_ABBR/auth/email?secret={secret}"
    },
    "domain": "$DOMAIN",
    "prefix": "/$VTC_ABBR",
    "server_host": "0.0.0.0",
    "server_port": $PORT,
    "server_workers": 1,
    "whitelist_ips": [],
    "webhook_error": "",
    "database": "mysql",
    "db_host": "localhost",
    "db_port": 3306,
    "db_user": "${VTC_ABBR}_user",
    "db_password": "$DB_PASSWORD",
    "db_name": "${VTC_ABBR}_db",
    "db_data_directory": "",
    "db_pool_size": 5,
    "db_error_keywords": ["lost connection", "deadlock", "readexactly", "timeout", "[aiosql]", "server has gone away"],
    "captcha": {
        "provider": "hcaptcha",
        "secret": ""
    },
    "redis_host": "127.0.0.1",
    "redis_port": 6379,
    "redis_db": 0,
    "redis_password": null,
    "plugins": ["announcements", "applications", "banner", "challenges", "divisions", "downloads", "events", "polls", "route"],
    "external_plugins": ["client-config"],
    "sync_discord_email": true,
    "must_join_guild": true,
    "use_server_nickname": true,
    "allow_custom_profile": true,
    "use_custom_activity": false,
    "avatar_domain_whitelist": ["charlws.com", "cdn.discordapp.com", "steamstatic.com"],
    "required_connections": ["discord", "steam"],
    "register_methods": ["discord", "steam"],
    "trackers": [],
    "delivery_rules": {
        "max_speed": 180,
        "max_profit": 1000000,
        "max_xp": 100000,
        "max_warp": 1,
        "required_realistic_settings": [],
        "action": "block"
    },
    "hook_delivery_log": { "channel_id": "", "webhook_url": "" },
    "hook_audit_log":    { "channel_id": "", "webhook_url": "" },
    "hook_event_log":    { "channel_id": "", "webhook_url": "" },
    "delivery_webhook_image_urls": [
        "https://c.tenor.com/fjTTED8MZxIAAAAC/truck.gif",
        "https://c.tenor.com/QhMgCV8uMvIAAAAC/airtime-weeee.gif",
        "https://c.tenor.com/VYt4iLQJWhcAAAAd/kid-spin.gif"
    ],
    "discord_guild_id": "$DISCORD_GUILD_ID",
    "discord_client_id": "$DISCORD_CLIENT_ID",
    "discord_client_secret": "$DISCORD_CLIENT_SECRET",
    "discord_bot_token": "$DISCORD_BOT_TOKEN",
    "steam_api_key": "$STEAM_API_KEY",
    "discord_guild_message_replace_rules": {},
    "smtp_host": "",
    "smtp_port": "",
    "smtp_email": "",
    "smtp_password": "",
    "secret_key": "$SECRET_KEY",
    "invite_only": false,
    "allow_resign_all_drivers": false,
    "allow_signup_without_invitation": true,
    "invitation_bonus_points": 0,
    "enable_auto_dismissal": false,
    "auto_dismissal_period": 180,
    "auto_dismissal_delivery_count": 1,
    "reward_point": {
        "base": 100,
        "per_km": 4,
        "per_kg": 0.005,
        "per_delivery": 0,
        "per_damage": -100,
        "complete_bonus": 0,
        "auto_bonus_rules": [],
        "daily_bonus_points": 0,
        "daily_bonus_reset_time": "00:00",
        "bonus_points_expire_after_seconds": 0,
        "bonus_points_expire_on_first_delivery": false
    },
    "roles": [
        {"roleid": 1, "name": "Diretor",   "discordrole": "", "permissions": ["admin"]},
        {"roleid": 2, "name": "Gerente",   "discordrole": "", "permissions": ["admin"]},
        {"roleid": 3, "name": "Motorista", "discordrole": "", "permissions": ["driver"]}
    ],
    "ranks": [
        {"rankid": 1, "name": "Iniciante",        "threshold": 0},
        {"rankid": 2, "name": "Motorista Jr.",     "threshold": 1000},
        {"rankid": 3, "name": "Motorista",         "threshold": 5000},
        {"rankid": 4, "name": "Motorista Sênior",  "threshold": 15000},
        {"rankid": 5, "name": "Veterano",          "threshold": 30000},
        {"rankid": 6, "name": "Elite",             "threshold": 50000}
    ],
    "application_questions": [
        "Qual é o seu nome?",
        "Por que deseja entrar na $VTC_NAME?",
        "Quantas horas você tem de jogo no ETS2/ATS?",
        "Você já participou de outras VTCs?"
    ],
    "application_info": "Bem-vindo à $VTC_NAME! Preencha o formulário abaixo para se candidatar."
}
EOF

    chmod 600 config.json
    print_success "Arquivo config.json criado"
}

create_database_tables() {
    print_info "Criando tabelas do banco via db.init()..."

    cd "$INSTALL_DIR/src"
    # shellcheck source=/dev/null
    source "$INSTALL_DIR/venv/bin/activate"

    python3 - "$INSTALL_DIR/config.json" << 'PYEOF'
import sys, json
sys.path.insert(0, '.')
try:
    import db, inspect
    cfg = json.load(open(sys.argv[1]))

    class Cfg:
        def __init__(self, c):
            self.db_host           = c.get('db_host', 'localhost')
            self.db_port           = int(c.get('db_port', 3306))
            self.db_user           = c.get('db_user', '')
            self.db_password       = c.get('db_password', '')
            self.db_name           = c.get('db_name', '')
            self.db_data_directory = ''
            self.db_pool_size      = int(c.get('db_pool_size', 10))

    config_obj = Cfg(cfg)
    sig    = inspect.signature(db.init)
    params = list(sig.parameters.keys())

    if len(params) >= 2:
        db.init(config_obj, '2.11.1')
    else:
        class App:
            def __init__(self, c): self.config = c
        db.init(App(config_obj))

    print('OK: tabelas criadas/verificadas com sucesso')
except Exception as e:
    import traceback
    print(f'ERRO: {e}')
    traceback.print_exc()
    sys.exit(1)
PYEOF

    local db_exit=$?
    deactivate || true

    if [[ $db_exit -eq 0 ]]; then
        local table_count
        table_count=$(sudo mysql -N -s -e \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${VTC_ABBR}_db';" \
            2>/dev/null | tr -d '[:space:]' || echo "0")
        print_success "Banco inicializado — ${table_count} tabelas"
    else
        print_error "Falha ao criar tabelas. Verifique MySQL e credenciais."
        exit 1
    fi
}

################################################################################
# Passo 11 — Serviço systemd
################################################################################

create_systemd_service() {
    print_step 11 "Configurando serviço systemd"

    sudo tee "/etc/systemd/system/drivershub-${VTC_ABBR}.service" > /dev/null << EOF
[Unit]
Description=$VTC_NAME - Drivers Hub Backend
After=network.target mysql.service redis.service
Wants=mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/src
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStartPre=/bin/sh -c 'i=0; while [ \$i -lt 15 ]; do ss -lnt 2>/dev/null | grep -q ":3306" && exit 0; sleep 2; i=\$((i+1)); done; exit 0'
ExecStart=$INSTALL_DIR/venv/bin/python3 main.py --config ../config.json
Restart=on-failure
RestartSec=10
TimeoutStartSec=90
StartLimitIntervalSec=120
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "drivershub-${VTC_ABBR}.service"

    if sudo systemctl is-active --quiet "drivershub-${VTC_ABBR}.service" 2>/dev/null; then
        print_info "Parando serviço existente para aplicar atualização..."
        sudo systemctl stop "drivershub-${VTC_ABBR}.service"
        sleep 2
    fi

    print_info "Iniciando serviço..."
    sudo systemctl start "drivershub-${VTC_ABBR}.service" || true

    print_info "Aguardando inicialização (até 40s)..."
    local attempt=0
    while [[ $attempt -lt 20 ]]; do
        sleep 2
        attempt=$((attempt + 1))
        if sudo systemctl is-active --quiet "drivershub-${VTC_ABBR}.service"; then
            print_success "Serviço iniciado com sucesso"
            return
        fi
    done

    print_error "Falha ao iniciar serviço. Verificando logs..."
    sudo journalctl -u "drivershub-${VTC_ABBR}.service" -n 30 --no-pager
    exit 1
}

fix_client_config_api_host() {
    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && protocol="https"
    local correct_api_host="${protocol}://${DOMAIN}"

    print_info "Aguardando plugin client-config criar entrada no banco (até 60s)..."

    local attempt=0 entry_exists=0
    while [[ $attempt -lt 30 ]]; do
        sleep 2
        attempt=$((attempt + 1))
        local count
        count=$(sudo mysql -N -s -e \
            "SELECT COUNT(*) FROM \`${VTC_ABBR}_db\`.settings WHERE skey='client-config/meta';" \
            2>/dev/null | tr -d '[:space:]' || echo "0")
        if [[ "$count" == "1" ]]; then
            entry_exists=1
            break
        fi
        (( attempt % 5 == 0 )) && print_info "Aguardando backend... (${attempt}×2s)"
    done

    if [[ $entry_exists -eq 1 ]]; then
        sudo mysql -e \
            "UPDATE \`${VTC_ABBR}_db\`.settings \
             SET sval = JSON_SET(sval, '\$.api_host', '${correct_api_host}') \
             WHERE skey='client-config/meta';" 2>/dev/null || true
        redis-cli DEL "client-config:meta" >/dev/null 2>&1 || true
        sudo systemctl restart "drivershub-${VTC_ABBR}.service" 2>/dev/null || true
        sleep 3
        print_success "api_host corrigido para: ${correct_api_host}"
    else
        print_warning "Entrada client-config não encontrada após 60s — corrija manualmente:"
        print_warning "  sudo mysql -e \"UPDATE ${VTC_ABBR}_db.settings SET sval = JSON_SET(sval, '\$.api_host', '${correct_api_host}') WHERE skey='client-config/meta';\""
        print_warning "  redis-cli DEL 'client-config:meta'"
        print_warning "  sudo systemctl restart drivershub-${VTC_ABBR}"
    fi
}

configure_nginx() {
    if [[ "$INSTALL_NGINX" != "y" ]]; then
        return
    fi

    print_info "Instalando Nginx..."
    sudo apt install -y nginx -qq
    sudo rm -f /etc/nginx/sites-enabled/default

    local NGINX_CONF_NAME="drivershub-${VTC_ABBR}"

    sudo tee "/etc/nginx/sites-available/${NGINX_CONF_NAME}" > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # ── API do backend ────────────────────────────────────────────────────────
    location /$VTC_ABBR/ {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ── Frontend (React SPA) ──────────────────────────────────────────────────
    # FRONTEND_PLACEHOLDER
    location / {
        return 503 "Frontend ainda nao instalado. Execute: bash scripts/install-frontend.sh";
        add_header Content-Type text/plain;
    }
}
EOF

    sudo ln -sf "/etc/nginx/sites-available/${NGINX_CONF_NAME}" \
                "/etc/nginx/sites-enabled/${NGINX_CONF_NAME}"

    if sudo nginx -t; then
        sudo systemctl restart nginx
        print_success "Nginx configurado"
    else
        print_error "Erro na configuração do Nginx"
        exit 1
    fi
}

configure_ssl() {
    if [[ "$INSTALL_SSL" != "y" ]]; then
        return
    fi

    print_info "Instalando Certbot..."
    sudo apt install -y certbot python3-certbot-nginx -qq

    print_warning "Certifique-se de que '$DOMAIN' aponta para este servidor!"

    if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
            --register-unsafely-without-email; then
        print_success "SSL configurado com sucesso"
    else
        print_warning "Falha ao configurar SSL automaticamente. Configure manualmente:"
        print_warning "  sudo certbot --nginx -d $DOMAIN"
    fi
}

################################################################################
# Passo 12 — Cloudflare Tunnel (Cenário 3)
################################################################################

setup_cloudflare_tunnel() {
    if [[ "$DEPLOY_SCENARIO" -ne 3 ]]; then
        return
    fi

    print_step 12 "Configurando Cloudflare Tunnel"

    echo ""
    print_info "O Cloudflare Tunnel expõe sua aplicação local com HTTPS seguro."
    print_info "Sem necessidade de IP fixo ou abertura de portas no roteador!"
    echo ""

    # Instalar cloudflared
    if ! command -v cloudflared &>/dev/null; then
        print_info "Instalando cloudflared..."
        local arch
        arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
        local cf_url=""
        case "$arch" in
            amd64|x86_64)
                cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
                ;;
            arm64|aarch64)
                cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
                ;;
            *)
                print_error "Arquitetura não suportada para cloudflared: $arch"
                return 1
                ;;
        esac

        curl -L --output /tmp/cloudflared.deb "$cf_url" --max-time 120 2>/dev/null
        sudo dpkg -i /tmp/cloudflared.deb 2>/dev/null || true
        rm -f /tmp/cloudflared.deb
    fi

    if ! command -v cloudflared &>/dev/null; then
        print_error "Falha ao instalar cloudflared. Instale manualmente:"
        print_error "  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/"
        return 1
    fi
    print_success "cloudflared instalado: $(cloudflared version 2>/dev/null | head -1)"

    echo ""
    echo -e "${CYAN}Para conectar ao seu domínio Cloudflare:${NC}"
    echo "  1. Acesse: https://one.dash.cloudflare.com"
    echo "  2. Vá em: Networks → Tunnels → Create a tunnel"
    echo "  3. Escolha 'Cloudflared' como connector"
    echo "  4. Copie o token gerado"
    echo "  5. Em 'Public Hostname', configure:"
    echo "     Hostname: ${DOMAIN}"
    echo "     Service:  http://localhost:${PORT}"
    echo ""

    if [[ -n "$CF_TUNNEL_TOKEN" ]]; then
        # Token já fornecido (modo não-interativo ou re-entrada)
        :
    else
        read -r -p "$(echo -e "${CYAN}Cole o Tunnel Token (Enter para pular): ${NC}")" CF_TUNNEL_TOKEN
    fi

    if [[ -z "$CF_TUNNEL_TOKEN" ]]; then
        print_warning "Token não fornecido. Configure o tunnel manualmente com:"
        print_warning "  sudo cloudflared service install <TOKEN>"
        return
    fi

    sudo cloudflared service install "$CF_TUNNEL_TOKEN" 2>/dev/null || true
    sudo systemctl enable cloudflared 2>/dev/null || true
    sudo systemctl start cloudflared 2>/dev/null || true

    if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
        print_success "Cloudflare Tunnel iniciado com sucesso!"
    else
        print_warning "Tunnel não pôde ser iniciado agora."
        print_info "  sudo systemctl start cloudflared"
        print_info "  sudo journalctl -u cloudflared -f"
    fi
}

################################################################################
# Firewall (ufw) — executado antes do Cloudflare Tunnel
################################################################################

configure_firewall() {
    print_info "Configurando firewall (ufw)..."

    if ! command -v ufw &>/dev/null; then
        sudo apt-get install -y ufw -qq
    fi

    local ufw_status
    ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "")

    # Garantir SSH liberado antes de ativar
    if ! echo "$ufw_status" | grep -qi "active"; then
        sudo ufw allow ssh 2>/dev/null || sudo ufw allow 22/tcp 2>/dev/null || true
    fi

    sudo ufw allow 80/tcp  comment "HTTP - DriversHub"  2>/dev/null || true
    sudo ufw allow 443/tcp comment "HTTPS - DriversHub" 2>/dev/null || true
    sudo ufw allow "${PORT}/tcp" comment "API DriversHub-${VTC_ABBR}" 2>/dev/null || true

    if ! echo "$ufw_status" | grep -qi "active"; then
        print_info "Ativando firewall..."
        echo "y" | sudo ufw enable 2>/dev/null || true
    fi

    sudo ufw reload 2>/dev/null || true
    print_success "Firewall configurado (HTTP, HTTPS, porta ${PORT}, SSH)"
}

################################################################################
# Backup automático (item 6)
################################################################################

setup_backup_cron() {
    print_info "Configurando backup automático do banco de dados..."

    # Garantir que o diretório base pertence ao usuário atual antes de escrever
    sudo mkdir -p "${INSTALL_BASE}"
    sudo chown "$USER":"$USER" "${INSTALL_BASE}"

    local backup_dir="${INSTALL_BASE}/backups/${VTC_ABBR}"
    local backup_script="${INSTALL_BASE}/backup-${VTC_ABBR}.sh"

    sudo mkdir -p "$backup_dir"
    sudo chown "$USER":"$USER" "$backup_dir"

    cat > "$backup_script" << BACKUPEOF
#!/bin/bash
# Backup automático — ${VTC_NAME} (${VTC_ABBR})
# Gerado por install-drivershub.sh

BACKUP_DIR="${backup_dir}"
DB_NAME="${VTC_ABBR}_db"
DB_USER="${VTC_ABBR}_user"
KEEP_DAYS=7
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/\${DB_NAME}_\${TIMESTAMP}.sql.gz"

# Criar backup comprimido
mysqldump -u "\${DB_USER}" -p"${DB_PASSWORD}" "\${DB_NAME}" 2>/dev/null | gzip > "\${BACKUP_FILE}"

if [[ \$? -eq 0 ]]; then
    echo "\$(date): Backup criado: \${BACKUP_FILE}" >> "\${BACKUP_DIR}/backup.log"
else
    echo "\$(date): ERRO ao criar backup" >> "\${BACKUP_DIR}/backup.log"
fi

# Remover backups mais antigos que KEEP_DAYS dias
find "\${BACKUP_DIR}" -name "*.sql.gz" -mtime +\${KEEP_DAYS} -delete 2>/dev/null || true
BACKUPEOF

    chmod +x "$backup_script"

    # Cron: backup diário às 3h da manhã
    ( crontab -l 2>/dev/null | grep -v "backup-${VTC_ABBR}"; \
      echo "0 3 * * * ${backup_script}" ) | crontab -

    print_success "Backup automático configurado — diário às 3h em ${backup_dir}/"
    print_info "Para executar manualmente: bash ${backup_script}"
}

################################################################################
# Salvar estado da instalação
################################################################################

save_installer_state() {
    print_info "Salvando estado da instalação..."

    sudo mkdir -p "${INSTALL_BASE}"
    sudo chown "$USER":"$USER" "${INSTALL_BASE}"

    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && protocol="https"

    cat > "$STATE_FILE" << EOF
# Gerado automaticamente por install-drivershub.sh v1.3.0 — não edite manualmente
BACKEND_VTC_NAME="$VTC_NAME"
BACKEND_VTC_ABBR="$VTC_ABBR"
BACKEND_DOMAIN="$DOMAIN"
BACKEND_PORT="$PORT"
BACKEND_PROTOCOL="$protocol"
BACKEND_INSTALL_NGINX="$INSTALL_NGINX"
BACKEND_INSTALL_SSL="$INSTALL_SSL"
BACKEND_NGINX_CONF="drivershub-${VTC_ABBR}"
BACKEND_INSTALL_DIR="$INSTALL_DIR"
BACKEND_DEPLOY_SCENARIO="$DEPLOY_SCENARIO"
BACKEND_DUCKDNS_SUBDOMAIN="$DUCKDNS_SUBDOMAIN"
BACKEND_INSTALLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BACKEND_INSTALLER_VERSION="1.3.0"
EOF

    chmod 600 "$STATE_FILE"
    print_success "Estado salvo em $STATE_FILE"
}

################################################################################
# Informações finais
################################################################################

print_final_info() {
    clear
    print_header

    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║        ✅ BACKEND INSTALADO COM SUCESSO! ✅                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local proto="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto="https"
    [[ "$DEPLOY_SCENARIO" -eq 3 ]] && proto="https"

    echo -e "\n${CYAN}📊 INFORMAÇÕES DO SISTEMA${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC:        $VTC_NAME ($VTC_ABBR)"
    echo "Domínio:    $DOMAIN"
    echo "Backend:    ${proto}://$DOMAIN/$VTC_ABBR"
    echo "Serviço:    drivershub-${VTC_ABBR}.service"
    echo "Diretório:  $INSTALL_DIR"
    echo "Config:     $INSTALL_DIR/config.json"
    echo "State:      $STATE_FILE"
    echo "Backup:     ${INSTALL_BASE}/backups/${VTC_ABBR}/ (diário às 3h)"

    echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Status:     sudo systemctl status drivershub-${VTC_ABBR}"
    echo "Logs:       sudo journalctl -u drivershub-${VTC_ABBR} -f"
    echo "Reiniciar:  sudo systemctl restart drivershub-${VTC_ABBR}"
    echo "Verificar:  bash scripts/verificar-instalacao.sh"
    echo "Reconfigurar: bash scripts/reconfigure-drivershub.sh"
    echo "Backup now: bash ${INSTALL_BASE}/backup-${VTC_ABBR}.sh"

    # URL de callback Discord correta
    local callback_url="https://${DOMAIN}/auth/discord/callback"

    echo -e "\n${CYAN}⚠️  PRÓXIMOS PASSOS IMPORTANTES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Configure o Redirect URI no Discord Developer Portal:"
    echo "   Portal: https://discord.com/developers/applications"
    echo "   → OAuth2 → Redirects → Adicionar exatamente:"
    echo -e "   ${GREEN}${callback_url}${NC}"
    echo "   ⚠️  O frontend usa https:// fixo e /auth/discord/callback (sem prefixo da VTC)"
    echo ""
    echo "2. Convide o bot Discord para seu servidor com permissões de admin"
    echo ""
    echo "3. Instale o Frontend:"
    echo -e "   ${GREEN}bash scripts/install-frontend.sh${NC}"
    echo ""

    if [[ "$DEPLOY_SCENARIO" -eq 2 ]]; then
        echo "4. Verifique o DuckDNS:"
        echo "   - Acesse https://www.duckdns.org para confirmar que o IP está correto"
        echo "   - Aguarde até 5 minutos para o DNS propagar"
        echo ""
    fi

    if [[ "$DEPLOY_SCENARIO" -eq 3 ]]; then
        echo "4. Verifique o Cloudflare Tunnel:"
        echo "   sudo systemctl status cloudflared"
        echo "   sudo journalctl -u cloudflared -f"
        echo ""
    fi

    echo -e "\n${CYAN}📚 DOCUMENTAÇÃO E SUPORTE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Wiki:    https://wiki.charlws.com/books/chub"
    echo "Discord: https://discord.gg/wNTaaBZ5qd"

    echo -e "\n${GREEN}🎉 Boa sorte com sua transportadora virtual! 🚚${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    print_header
    check_root

    # Passo 1 — Requisitos do sistema
    check_requirements

    # Detectar instalações existentes (multi-VTC)
    detect_existing_installation

    # Passo 2 — Escolher cenário (somente modo fresh)
    if [[ "$INSTALL_MODE" == "fresh" ]]; then
        choose_deployment_scenario
    fi

    # Passo 3 — Coletar informações
    collect_info

    # Passo 4 — DuckDNS (somente Cenário 2)
    if [[ "$DEPLOY_SCENARIO" -eq 2 ]]; then
        setup_duckdns
    fi

    # Passo 5 — Validar credenciais
    validate_credentials

    # Passos 6–9: dependências, MySQL, Redis, projeto
    install_system_dependencies
    install_mysql
    install_redis
    clone_repository
    setup_python_env
    fix_database_code
    fix_client_config_plugin

    # Passo 10 — Config + Tabelas
    create_config_file
    create_database_tables

    # Passo 11 — Serviço + Nginx + SSL
    create_systemd_service
    configure_nginx
    configure_ssl
    configure_firewall

    # Passo 12 — Cloudflare Tunnel (Cenário 3)
    if [[ "$DEPLOY_SCENARIO" -eq 3 ]]; then
        setup_cloudflare_tunnel
    fi

    # Pós-start: corrigir api_host e configurar backup
    fix_client_config_api_host
    setup_backup_cron
    save_installer_state

    print_final_info
}

main "$@"
