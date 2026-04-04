#!/bin/bash

################################################################################
# Script de Instalação Automatizada do Drivers Hub
# Versão: 1.2.1
# Data: Março 2026
#
# Este script automatiza a instalação completa do Drivers Hub Backend
# incluindo configuração de banco de dados, Redis, e serviços.
# Suporta instalação limpa, reparo de instalação existente e reconfiguração.
################################################################################

set -e          # Sair em caso de erro em qualquer comando
set -o pipefail # Propagar erros em pipelines (ex: cmd | grep)

# Cores para interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

# Variáveis globais
INSTALL_DIR="/opt/drivershub/HubBackend"
STATE_FILE="/opt/drivershub/.installer_state"
INSTALL_MODE="fresh"   # fresh | repair | reconfigure
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
    echo "║ Versão: 1.2.1                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[PASSO $1/$2]${NC} ${GREEN}$3${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERRO: $1${NC}"
}

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
# Detecção de Instalação Existente — Melhoria 3
################################################################################

detect_existing_installation() {
    # Nada encontrado → instalação limpa normal
    if [[ ! -f "$STATE_FILE" ]] && [[ ! -d "$INSTALL_DIR" ]]; then
        INSTALL_MODE="fresh"
        return
    fi

    clear
    print_header

    echo -e "${YELLOW}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       ⚠️  INSTALAÇÃO EXISTENTE DETECTADA!                    ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Mostrar o que foi encontrado
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_FILE"
        echo -e "  VTC:          ${CYAN}${BACKEND_VTC_NAME} (${BACKEND_VTC_ABBR})${NC}"
        echo -e "  Backend:      ${CYAN}${BACKEND_INSTALL_DIR}${NC}"
        echo -e "  Domínio:      ${CYAN}${BACKEND_DOMAIN}${NC}"
        echo -e "  Instalado em: ${CYAN}${BACKEND_INSTALLED_AT}${NC}"

        # Verificar se o serviço está rodando
        local svc="drivershub-${BACKEND_VTC_ABBR}"
        if sudo systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            echo -e "  Serviço:      ${GREEN}✅ Rodando${NC}"
        else
            echo -e "  Serviço:      ${RED}❌ Parado${NC}"
        fi
    else
        echo -e "  Diretório encontrado: ${CYAN}${INSTALL_DIR}${NC}"
        echo -e "  (state file ausente — instalação incompleta)"
    fi

    echo ""
    echo -e "${MAGENTA}O que deseja fazer?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Reparar instalação   — corrige dependências, serviço e config"
    echo "     sem apagar seus dados ou o config.json existente"
    echo ""
    echo "  2) Nova instalação      — APAGA tudo e instala do zero"
    echo "     (use quando quiser mudar VTC, domínio ou senha)"
    echo ""
    echo "  3) Cancelar"
    echo ""

    local choice
    read -r -p "$(echo -e "${CYAN}Escolha [1/2/3]: ${NC}")" choice

    case "$choice" in
        1)
            INSTALL_MODE="repair"
            print_info "Modo: Reparo — dados e config.json preservados."

            # Carregar variáveis do state para reutilizar na instalação
            if [[ -f "$STATE_FILE" ]]; then
                VTC_NAME="$BACKEND_VTC_NAME"
                VTC_ABBR="$BACKEND_VTC_ABBR"
                DOMAIN="$BACKEND_DOMAIN"
                PORT="$BACKEND_PORT"
                INSTALL_NGINX="$BACKEND_INSTALL_NGINX"
                INSTALL_SSL="$BACKEND_INSTALL_SSL"

                # Carregar credenciais do config.json existente
                if [[ -f "${BACKEND_INSTALL_DIR}/config.json" ]]; then
                    DB_PASSWORD=$(python3 -c "
import json, sys
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('db_password',''))
except: print('')
" 2>/dev/null || echo "")
                    DISCORD_CLIENT_ID=$(python3 -c "
import json
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('discord_client_id',''))
except: print('')
" 2>/dev/null || echo "")
                    DISCORD_CLIENT_SECRET=$(python3 -c "
import json
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('discord_client_secret',''))
except: print('')
" 2>/dev/null || echo "")
                    DISCORD_BOT_TOKEN=$(python3 -c "
import json
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('discord_bot_token',''))
except: print('')
" 2>/dev/null || echo "")
                    DISCORD_GUILD_ID=$(python3 -c "
import json
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('discord_guild_id',''))
except: print('')
" 2>/dev/null || echo "")
                    STEAM_API_KEY=$(python3 -c "
import json
try:
    d = json.load(open('${BACKEND_INSTALL_DIR}/config.json'))
    print(d.get('steam_api_key',''))
except: print('')
" 2>/dev/null || echo "")
                fi
            fi
            ;;
        2)
            INSTALL_MODE="fresh"
            print_warning "Modo: Nova instalação — dados existentes serão sobrescritos."
            if ! confirm "Tem certeza? O config.json atual será substituído" "n"; then
                print_warning "Cancelado."
                exit 0
            fi
            ;;
        3|"")
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
# Validação de Credenciais Discord e Steam — Melhoria 4
################################################################################

validate_credentials() {
    print_step 2 10 "Validando credenciais Discord e Steam"

    local errors=0

    # ── Discord Bot Token ──────────────────────────────────────────────────────
    print_info "Validando Discord Bot Token..."
    local discord_response http_code
    discord_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        "https://discord.com/api/v10/users/@me" \
        --max-time 10 2>/dev/null) || true

    http_code=$(echo "$discord_response" | tail -1)
    local discord_body
    discord_body=$(echo "$discord_response" | head -n -1)

    if [[ "$http_code" == "200" ]]; then
        local bot_username
        bot_username=$(echo "$discord_body" | python3 -c \
            "import json,sys; d=json.load(sys.stdin); print(d.get('username','?'))" \
            2>/dev/null || echo "?")
        print_success "Discord Bot Token válido — Bot: ${bot_username}"
    elif [[ "$http_code" == "401" ]]; then
        print_error "Discord Bot Token INVÁLIDO! Verifique o token no Discord Developer Portal."
        errors=$((errors + 1))
    else
        print_warning "Não foi possível validar o Bot Token (HTTP ${http_code:-timeout}). Continuando mesmo assim."
    fi

    # ── Discord Client ID + Secret ─────────────────────────────────────────────
    print_info "Validando Discord Client ID e Secret..."
    local client_response client_code
    client_response=$(curl -s -w "\n%{http_code}" \
        -u "${DISCORD_CLIENT_ID}:${DISCORD_CLIENT_SECRET}" \
        "https://discord.com/api/v10/oauth2/applications/@me" \
        --max-time 10 2>/dev/null) || true

    client_code=$(echo "$client_response" | tail -1)
    local client_body
    client_body=$(echo "$client_response" | head -n -1)

    if [[ "$client_code" == "200" ]]; then
        local app_name
        app_name=$(echo "$client_body" | python3 -c \
            "import json,sys; d=json.load(sys.stdin); print(d.get('name','?'))" \
            2>/dev/null || echo "?")
        print_success "Discord Client ID/Secret válidos — App: ${app_name}"
    elif [[ "$client_code" == "401" ]]; then
        print_error "Discord Client ID ou Client Secret INVÁLIDO!"
        errors=$((errors + 1))
    else
        print_warning "Não foi possível validar Client ID/Secret (HTTP ${client_code:-timeout}). Continuando mesmo assim."
    fi

    # ── Steam API Key ──────────────────────────────────────────────────────────
    print_info "Validando Steam API Key..."
    local steam_response steam_code
    steam_response=$(curl -s -w "\n%{http_code}" \
        "https://api.steampowered.com/ISteamWebAPIUtil/GetSupportedAPIList/v1/?key=${STEAM_API_KEY}" \
        --max-time 10 2>/dev/null) || true

    steam_code=$(echo "$steam_response" | tail -1)
    local steam_body
    steam_body=$(echo "$steam_response" | head -n -1)

    if [[ "$steam_code" == "200" ]] && echo "$steam_body" | grep -q "apilist"; then
        print_success "Steam API Key válida"
    elif echo "$steam_body" | grep -qi "forbidden\|unauthorized\|invalid"; then
        print_error "Steam API Key INVÁLIDA! Obtenha uma em: https://steamcommunity.com/dev/apikey"
        errors=$((errors + 1))
    else
        print_warning "Não foi possível validar Steam API Key (HTTP ${steam_code:-timeout}). Continuando mesmo assim."
    fi

    echo ""

    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_error "$errors credencial(is) inválida(s) detectada(s)!"
        echo ""
        echo "  Corrigir agora evita problemas no login Discord e nas integrações."
        echo ""
        if confirm "Deseja corrigir as credenciais antes de continuar?" "y"; then
            # Recoletar apenas os campos com erro
            if [[ "$http_code" == "401" || "$client_code" == "401" ]]; then
                echo -e "\n${MAGENTA}🔐 Corrija suas credenciais Discord${NC}"
                echo "  Portal: https://discord.com/developers/applications"
                read -r -p "$(echo -e "${CYAN}Discord Client ID: ${NC}")"     DISCORD_CLIENT_ID
                read -r -p "$(echo -e "${CYAN}Discord Client Secret: ${NC}")" DISCORD_CLIENT_SECRET
                read -r -p "$(echo -e "${CYAN}Discord Bot Token: ${NC}")"     DISCORD_BOT_TOKEN
            fi
            if echo "$steam_body" | grep -qi "forbidden\|unauthorized\|invalid"; then
                echo -e "\n${MAGENTA}🔐 Corrija sua Steam API Key${NC}"
                echo "  Portal: https://steamcommunity.com/dev/apikey"
                read -r -p "$(echo -e "${CYAN}Steam API Key: ${NC}")" STEAM_API_KEY
            fi
            # Revalidar com as novas credenciais
            print_info "Revalidando credenciais corrigidas..."
            validate_credentials
        else
            print_warning "Prosseguindo com credenciais inválidas. O login Discord pode não funcionar."
        fi
    else
        print_success "Todas as credenciais validadas com sucesso!"
    fi
}

check_requirements() {
    print_step 1 10 "Verificando requisitos do sistema"

    # Verificar se é Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        print_error "Este script requer Ubuntu/Debian (sistema com apt)"
        exit 1
    fi

    # Verificar versão do Ubuntu
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_info "Sistema detectado: $PRETTY_NAME"
    fi

    # Em modo reparo, verificar curl (necessário para validação de credenciais)
    if ! command -v curl &>/dev/null; then
        print_info "Instalando curl..."
        sudo apt-get install -y curl -qq
    fi

    print_success "Requisitos do sistema verificados"
}

################################################################################
# Coleta de Informações
################################################################################

collect_info() {
    # Modo reparo: dados já foram carregados do state/config — apenas confirmar
    if [[ "$INSTALL_MODE" == "repair" ]]; then
        print_step 2 10 "Confirmando configurações existentes (modo reparo)"
        echo ""
        echo -e "  VTC:       ${CYAN}${VTC_NAME} (${VTC_ABBR})${NC}"
        echo -e "  Domínio:   ${CYAN}${DOMAIN}${NC}"
        echo -e "  Porta:     ${CYAN}${PORT}${NC}"
        echo -e "  Discord:   ${CYAN}${DISCORD_CLIENT_ID:0:8}...${NC}"
        echo -e "  Steam:     ${CYAN}${STEAM_API_KEY:0:8}...${NC}"
        echo -e "  Nginx:     ${CYAN}${INSTALL_NGINX}${NC}"
        echo ""
        print_success "Configurações carregadas da instalação anterior"
        return
    fi

    print_step 2 10 "Coletando informações da instalação"

    echo -e "\n${MAGENTA}📋 INFORMAÇÕES DA SUA VTC${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Nome da VTC
    while [[ -z "$VTC_NAME" ]]; do
        read -r -p "$(echo -e "${CYAN}Nome completo da VTC: ${NC}")" VTC_NAME
    done

    # Abreviação
    while [[ -z "$VTC_ABBR" ]]; do
        read -r -p "$(echo -e "${CYAN}Abreviação da VTC (ex: cdmp): ${NC}")" VTC_ABBR
        VTC_ABBR=$(echo "$VTC_ABBR" | tr '[:upper:]' '[:lower:]')
    done

    # Domínio
    read -r -p "$(echo -e "${CYAN}Domínio (deixe vazio para localhost): ${NC}")" DOMAIN
    # Remover protocolo e barras que o usuário possa ter digitado
    DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/$||' | tr -d ' ')
    DOMAIN=${DOMAIN:-localhost}

    # Porta
    read -r -p "$(echo -e "${CYAN}Porta do servidor [7777]: ${NC}")" input_port
    PORT=${input_port:-7777}

    echo -e "\n${MAGENTA}🔐 CREDENCIAIS DO BANCO DE DADOS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Senha do banco
    while [[ -z "$DB_PASSWORD" ]]; do
        read -r -sp "$(echo -e "${CYAN}Senha para o banco de dados MySQL: ${NC}")" DB_PASSWORD
        echo
        read -r -sp "$(echo -e "${CYAN}Confirme a senha: ${NC}")" DB_PASSWORD_CONFIRM
        echo

        if [[ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]]; then
            print_error "As senhas não coincidem!"
            DB_PASSWORD=""
        fi
    done

    echo -e "\n${MAGENTA}🎮 INTEGRAÇÃO DISCORD & STEAM${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Obtenha estas informações em:"
    print_info "Discord: https://discord.com/developers/applications"
    print_info "Steam: https://steamcommunity.com/dev/apikey"
    echo

    read -r -p "$(echo -e "${CYAN}Discord Client ID: ${NC}")"     DISCORD_CLIENT_ID
    read -r -p "$(echo -e "${CYAN}Discord Client Secret: ${NC}")" DISCORD_CLIENT_SECRET
    read -r -p "$(echo -e "${CYAN}Discord Bot Token: ${NC}")"     DISCORD_BOT_TOKEN
    read -r -p "$(echo -e "${CYAN}Discord Server (Guild) ID: ${NC}")" DISCORD_GUILD_ID
    read -r -p "$(echo -e "${CYAN}Steam API Key: ${NC}")"         STEAM_API_KEY

    echo -e "\n${MAGENTA}⚙️  CONFIGURAÇÕES OPCIONAIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Perguntar sobre Frontend ANTES do Nginx para contextualizar
    echo -e "${CYAN}ℹ️  O Drivers Hub possui uma interface web (Frontend React).${NC}"
    echo "   Para usá-la, o Nginx é obrigatório."
    echo ""
    if confirm "Deseja instalar o Frontend (interface web) após o backend?" "y"; then
        print_info "Frontend selecionado — Nginx será configurado automaticamente."
        INSTALL_NGINX="y"
        echo ""
        if [[ "$DOMAIN" != "localhost"* ]]; then
            if confirm "Deseja configurar SSL/HTTPS com Let's Encrypt?"; then
                INSTALL_SSL="y"
            fi
        fi
    else
        print_info "Frontend não selecionado — acesso apenas via API na porta $PORT."
        echo ""
        if confirm "Deseja instalar o Nginx como proxy reverso para a API?"; then
            INSTALL_NGINX="y"
            if [[ "$DOMAIN" != "localhost"* ]]; then
                if confirm "Deseja configurar SSL/HTTPS com Let's Encrypt?"; then
                    INSTALL_SSL="y"
                fi
            fi
        fi
    fi

    # Resumo
    echo -e "\n${GREEN}📊 RESUMO DA INSTALAÇÃO${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC:             $VTC_NAME ($VTC_ABBR)"
    echo "Domínio:         $DOMAIN"
    echo "Porta:           $PORT"
    echo "Banco de dados:  MySQL (senha configurada)"
    echo "Discord:         ${DISCORD_CLIENT_ID:0:8}..."
    echo "Steam:           ${STEAM_API_KEY:0:8}..."
    echo "Nginx:           $INSTALL_NGINX"
    echo "SSL:             $INSTALL_SSL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! confirm "Confirma as informações acima e deseja continuar?"; then
        print_warning "Instalação cancelada pelo usuário"
        exit 0
    fi

    print_success "Informações coletadas"
}

################################################################################
# Instalação de Dependências
################################################################################

install_system_dependencies() {
    print_step 3 10 "Instalando dependências do sistema"
    
    print_info "Atualizando lista de pacotes..."
    sudo apt update -qq
    
    print_info "Instalando Python e ferramentas de desenvolvimento..."
    sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential \
                        libssl-dev libffi-dev git curl wget -qq
    
    print_success "Dependências do sistema instaladas"
}

install_mysql() {
    print_step 4 10 "Instalando e configurando MySQL"

    if ! command -v mysql &> /dev/null; then
        print_info "Instalando MySQL Server..."

        # Garantir que não há conflito com MariaDB pré-instalado
        if dpkg -l | grep -q mariadb-server 2>/dev/null; then
            print_warning "MariaDB detectado. Removendo para evitar conflito com MySQL..."
            sudo systemctl stop mariadb 2>/dev/null || true
            sudo apt-get remove -y --purge mariadb-server mariadb-client mariadb-common -qq
            sudo apt-get autoremove -y -qq
        fi

        sudo apt-get install -y mysql-server mysql-client -qq

        print_info "Iniciando serviço MySQL..."
        sudo systemctl start mysql
        sudo systemctl enable mysql

        print_success "MySQL instalado"
    else
        # Checar se o mysql instalado é MySQL (não MariaDB disfarçado)
        local db_version
        db_version=$(mysql --version 2>/dev/null || echo "")
        if echo "$db_version" | grep -qi 'mariadb'; then
            print_warning "mysql apontando para MariaDB detectado. Reinstalando como MySQL..."
            sudo systemctl stop mariadb 2>/dev/null || true
            sudo apt-get remove -y --purge mariadb-server mariadb-client mariadb-common -qq
            sudo apt-get autoremove -y -qq
            sudo apt-get install -y mysql-server mysql-client -qq
            sudo systemctl start mysql
            sudo systemctl enable mysql
            print_success "MySQL instalado em substituição ao MariaDB"
        else
            print_info "MySQL já está instalado: $db_version"
        fi
    fi

    print_info "Criando banco de dados e usuário..."

    # Criar banco de dados
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${VTC_ABBR}_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true

    # Remover usuário anterior (se existir) para garantir criação limpa
    sudo mysql -e "DROP USER IF EXISTS '${VTC_ABBR}_user'@'localhost';" 2>/dev/null || true

    # Tentar criar com mysql_native_password (MySQL 8.0.x)
    # Se falhar (MySQL 8.4+ removeu o plugin), usar autenticação padrão com cryptography
    if ! sudo mysql -e "CREATE USER '${VTC_ABBR}_user'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';" 2>/dev/null; then
        print_warning "mysql_native_password indisponível (MySQL 8.4+). Usando autenticação padrão..."
        sudo mysql -e "CREATE USER '${VTC_ABBR}_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" 2>/dev/null || true
    fi

    sudo mysql -e "GRANT ALL PRIVILEGES ON ${VTC_ABBR}_db.* TO '${VTC_ABBR}_user'@'localhost';" 2>/dev/null || true
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

    # Configurar timeouts do MySQL para evitar "Lost connection" e "Timeout" no pool
    # O backend mantém conexões abertas — sem isso elas expiram em 8h (padrão)
    # e o próximo acesso falha com OperationalError
    print_info "Configurando timeouts do MySQL..."
    local mysql_conf="/etc/mysql/mysql.conf.d/drivershub.cnf"
    sudo tee "$mysql_conf" > /dev/null << 'MYSQLEOF'
# Configuração gerada pelo instalador do Drivers Hub
[mysqld]
# Manter conexões abertas por até 12h (43200s) — evita "Lost connection" no pool
wait_timeout            = 43200
interactive_timeout     = 43200
# Permitir reconexão automática do pool
connect_timeout         = 10
# Tamanho máximo de pacote (para dados de entrega grandes)
max_allowed_packet      = 64M
MYSQLEOF

    sudo systemctl restart mysql
    print_success "MySQL configurado com timeouts otimizados"

    # Verificar se o banco foi criado com sucesso
    if sudo mysql -e "USE ${VTC_ABBR}_db;" 2>/dev/null; then
        print_success "Banco de dados MySQL configurado"
    else
        print_error "Falha ao configurar banco de dados MySQL"
        exit 1
    fi
}

install_redis() {
    print_step 5 10 "Instalando e configurando Redis"
    
    if ! command -v redis-cli &> /dev/null; then
        print_info "Instalando Redis..."
        sudo apt install -y redis-server -qq
        
        print_info "Iniciando serviço Redis..."
        sudo systemctl start redis-server
        sudo systemctl enable redis-server
        
        print_success "Redis instalado"
    else
        print_info "Redis já está instalado"
    fi
    
    # Testar conexão
    if redis-cli ping | grep -q PONG; then
        print_success "Redis funcionando corretamente"
    else
        print_error "Falha ao conectar com Redis"
        exit 1
    fi
}

################################################################################
# Clone e Configuração do Projeto
################################################################################

clone_repository() {
    print_step 6 10 "Clonando repositório do Drivers Hub"

    # Criar diretório
    sudo mkdir -p /opt/drivershub
    sudo chown "$USER":"$USER" /opt/drivershub

    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Diretório já existe. Atualizando..."
        cd "$INSTALL_DIR"
        git pull
    else
        print_info "Clonando repositório..."
        cd /opt/drivershub
        git clone https://github.com/CharlesWithC/HubBackend.git
    fi

    print_success "Repositório clonado/atualizado"
}

setup_python_env() {
    print_step 7 10 "Configurando ambiente Python"

    cd "$INSTALL_DIR"

    if [ ! -d "venv" ]; then
        print_info "Criando ambiente virtual..."
        # Redirecionar stdin para evitar travamento em alguns ambientes
        python3 -m venv venv < /dev/null
    fi

    print_info "Ativando ambiente virtual..."
    # shellcheck source=/dev/null
    source venv/bin/activate

    print_info "Atualizando pip..."
    pip install --upgrade pip -q < /dev/null

    # Gerar requirements sem os pacotes de dev (nuitka, ruff) que são pesados
    # e não são necessários para execução — apenas para desenvolvimento
    print_info "Instalando dependências Python (pode levar alguns minutos)..."
    grep -v '# dev' requirements.txt > /tmp/requirements_prod.txt
    pip install -r /tmp/requirements_prod.txt < /dev/null
    rm -f /tmp/requirements_prod.txt

    # Garantir cryptography para autenticação MySQL 8+
    print_info "Instalando pacote cryptography (compatibilidade MySQL 8+)..."
    pip install cryptography -q < /dev/null

    deactivate || true
    print_success "Ambiente Python configurado"
}

fix_database_code() {
    print_step 8 10 "Aplicando correção no código (DATA DIRECTORY)"

    cd "$INSTALL_DIR/src"

    # Verificar se o patch precisa ser aplicado
    # IMPORTANTE: usar Python em vez de sed — o padrão exato das aspas no arquivo
    # pode variar entre versões e sed falha silenciosamente com variações de escape.
    # O arquivo usa: DATA DIRECTORY = '{config.db_data_directory}'  (sem app.)
    if grep -q "DATA DIRECTORY = '" db.py; then
        print_info "Criando backup do db.py original..."
        cp db.py db.py.backup

        print_info "Removendo cláusulas DATA DIRECTORY via Python..."
        python3 - << 'PYEOF'
fname = 'db.py'
with open(fname, 'r') as f:
    content = f.read()
# Cobrir ambas as variações encontradas no código fonte:
# versão antiga: DATA DIRECTORY = '{app.config.db_data_directory}'
# versão atual:  DATA DIRECTORY = '{config.db_data_directory}'
patched = content.replace(" DATA DIRECTORY = '{config.db_data_directory}'", "")
patched = patched.replace(" DATA DIRECTORY = '{app.config.db_data_directory}'", "")
remaining = patched.count("DATA DIRECTORY = '")
with open(fname, 'w') as f:
    f.write(patched)
print(f"Patch aplicado. Ocorrências SQL restantes: {remaining}")
if remaining > 0:
    raise SystemExit(f"ERRO: ainda há {remaining} ocorrências de DATA DIRECTORY")
PYEOF
        print_success "Correção DATA DIRECTORY aplicada"
    else
        print_info "Correção DATA DIRECTORY já está aplicada no db.py"
    fi
}

fix_client_config_plugin() {
    # CORREÇÃO DEFINITIVA para "inoperância temporária":
    # O plugin client-config.py salva api_host como config["domain"] = "localhost"
    # sem protocolo. O frontend monta apiPath = "localhost/cdmp" que o browser
    # interpreta como URL relativa → todas as chamadas de API vão para o caminho errado.
    # Este patch altera o fonte para incluir o protocolo: "http://localhost".

    local plugin_file="$INSTALL_DIR/src/external_plugins/client-config.py"

    if [[ ! -f "$plugin_file" ]]; then
        print_warning "Plugin client-config.py não encontrado — pulando patch."
        return
    fi

    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"

    # Verificar se o patch correto já está aplicado
    if grep -qF "\"${protocol}://\" + config[\"domain\"]" "$plugin_file"; then
        print_info "Patch client-config.py já está correto (${protocol}://)"
        return
    fi

    # Backup na primeira vez
    [[ ! -f "${plugin_file}.bak" ]] && cp "$plugin_file" "${plugin_file}.bak"

    # Restaurar do backup antes de aplicar (protocolo pode ter mudado de http para https)
    cp "${plugin_file}.bak" "$plugin_file"

    # Aplicar via Python — mais confiável que sed com strings complexas
    python3 - "$plugin_file" "$protocol" << 'PYEOF'
import sys
fname, protocol = sys.argv[1], sys.argv[2]
with open(fname, 'r') as f:
    content = f.read()
# Padrão atual no código fonte do CharlesWithC:
old = '"api_host": config["domain"]'
new = f'"api_host": "{protocol}://" + config["domain"]'
if old not in content:
    print(f"AVISO: padrão não encontrado em {fname} — nenhuma alteração feita.")
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
        print_warning "  Linha:   \"api_host\": config[\"domain\"]"
        print_warning "  Para:    \"api_host\": \"${protocol}://\" + config[\"domain\"]"
    fi
}

create_database_tables() {
    # Cria todas as tabelas do banco via db.init() do próprio HubBackend.
    # Isso é feito ANTES de iniciar o serviço systemd para garantir que
    # as tabelas existam na primeira tentativa de inicialização.
    # Sem isso, o backend falha com "Table 'X_db.settings' doesn't exist"
    # porque o db.init() no startup do app pode falhar silenciosamente.

    print_info "Criando tabelas do banco de dados via db.init()..."

    cd "$INSTALL_DIR/src"

    # shellcheck source=/dev/null
    source "$INSTALL_DIR/venv/bin/activate"

    python3 - "$INSTALL_DIR/config.json" << 'PYEOF'
import sys, json
sys.path.insert(0, '.')

try:
    import db
    import inspect

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

    # Detectar assinatura real do db.init() para compatibilidade com versões futuras
    sig = inspect.signature(db.init)
    params = list(sig.parameters.keys())

    if len(params) >= 2:
        # Versão atual: db.init(config, version)
        db.init(config_obj, '2.11.1')
    else:
        # Versão antiga: db.init(app)
        class App:
            def __init__(self, c): self.config = c
        db.init(App(config_obj))

    print('OK: tabelas criadas/verificadas com sucesso')

except Exception as e:
    print(f'ERRO: {e}')
    import traceback
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
        print_success "Banco de dados inicializado — ${table_count} tabelas"
    else
        print_error "Falha ao criar tabelas. Verifique a conexão com MySQL e as credenciais."
        print_error "Tente manualmente: mysql -u ${VTC_ABBR}_user -p ${VTC_ABBR}_db"
        exit 1
    fi
}

create_config_file() {
    print_step 9 10 "Criando arquivo de configuração"

    cd "$INSTALL_DIR"

    # Modo reparo: preservar o config.json existente
    if [[ "$INSTALL_MODE" == "repair" ]] && [[ -f "config.json" ]]; then
        print_info "Modo reparo — config.json existente preservado."
        print_success "Arquivo config.json mantido sem alterações"
        return
    fi

    # Gerar secret key aleatória
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

    # Protocolo correto baseado em SSL — evita redirect_uri inválido no Discord OAuth
    local proto="http"
    [[ "$INSTALL_SSL" == "y" ]] && proto="https"

    print_info "Gerando config.json..."

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
    "hook_delivery_log": {
        "channel_id": "",
        "webhook_url": ""
    },
    "hook_audit_log": {
        "channel_id": "",
        "webhook_url": ""
    },
    "hook_event_log": {
        "channel_id": "",
        "webhook_url": ""
    },
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
        {"roleid": 1, "name": "Diretor", "discordrole": "", "permissions": ["admin"]},
        {"roleid": 2, "name": "Gerente", "discordrole": "", "permissions": ["admin"]},
        {"roleid": 3, "name": "Motorista", "discordrole": "", "permissions": ["driver"]}
    ],
    "ranks": [
        {"rankid": 1, "name": "Iniciante", "threshold": 0},
        {"rankid": 2, "name": "Motorista Jr.", "threshold": 1000},
        {"rankid": 3, "name": "Motorista", "threshold": 5000},
        {"rankid": 4, "name": "Motorista Sênior", "threshold": 15000},
        {"rankid": 5, "name": "Veterano", "threshold": 30000},
        {"rankid": 6, "name": "Elite", "threshold": 50000}
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

################################################################################
# Configuração de Serviços
################################################################################

create_systemd_service() {
    print_step 10 10 "Configurando serviço systemd"

    print_info "Criando arquivo de serviço..."

    # WorkingDirectory deve ser $INSTALL_DIR/src para que os.path.exists("external_plugins/...")
    # no app.py resolva corretamente para src/external_plugins/ onde os plugins estão.
    # O config.json fica em $INSTALL_DIR, por isso usamos ../config.json no ExecStart.
    sudo tee /etc/systemd/system/drivershub-${VTC_ABBR}.service > /dev/null << EOF
[Unit]
Description=$VTC_NAME - Drivers Hub Backend
After=network.target mysql.service redis.service
# Wants (suave) em vez de Requires — compatível com WSL onde mysql pode não ser unit systemd
Wants=mysql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/src
# PATH inclui venv (prioridade) + caminhos do sistema — necessário para ExecStartPre
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Aguardar MySQL (porta 3306) estar acessível — sem sudo, compatível com WSL
# Loop limitado a 15 tentativas × 2s = 30s máx; exit 0 para nunca bloquear o start
ExecStartPre=/bin/sh -c 'i=0; while [ \$i -lt 15 ]; do ss -lnt 2>/dev/null | grep -q ":3306" && exit 0; sleep 2; i=\$((i+1)); done; exit 0'
ExecStart=$INSTALL_DIR/venv/bin/python3 main.py --config ../config.json
Restart=on-failure
RestartSec=10
# Tempo máximo para o serviço inicializar (cobre compilação Python inicial)
TimeoutStartSec=90
# Tentar até 5 vezes antes de desistir
StartLimitIntervalSec=120
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

    print_info "Recarregando systemd..."
    sudo systemctl daemon-reload

    print_info "Habilitando serviço..."
    sudo systemctl enable drivershub-${VTC_ABBR}.service

    # Parar o serviço se já estiver rodando (reinstalação)
    # Necessário para que o novo WorkingDirectory e ExecStart entrem em vigor
    if sudo systemctl is-active --quiet drivershub-${VTC_ABBR}.service 2>/dev/null; then
        print_info "Parando serviço existente para aplicar atualização..."
        sudo systemctl stop drivershub-${VTC_ABBR}.service
        sleep 2
    fi

    print_info "Iniciando serviço..."
    # Usar || true: em WSL o systemctl start pode retornar erro de job timeout mesmo
    # quando o serviço sobe com sucesso — verificamos o estado real logo abaixo
    sudo systemctl start drivershub-${VTC_ABBR}.service || true

    # Aguardar o serviço inicializar — loop de até 40s para cobrir compilação Python inicial
    print_info "Aguardando inicialização (pode levar alguns segundos)..."
    local attempt=0
    while [[ $attempt -lt 20 ]]; do
        sleep 2
        attempt=$((attempt + 1))
        if sudo systemctl is-active --quiet drivershub-${VTC_ABBR}.service; then
            print_success "Serviço iniciado com sucesso"
            return
        fi
    done

    print_error "Falha ao iniciar serviço. Verificando logs..."
    sudo journalctl -u drivershub-${VTC_ABBR}.service -n 30 --no-pager
    exit 1
}

fix_client_config_api_host() {
    # O plugin client-config.py salva api_host sem protocolo (ex: "localhost").
    # O frontend monta apiPath = api_host + "/" + abbr — sem protocolo o browser
    # interpreta como URL relativa e resolve para o caminho errado.
    # Este fix aguarda a entrada ser criada e atualiza para o valor correto.

    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"
    local correct_api_host="${protocol}://${DOMAIN}"

    print_info "Aguardando plugin client-config criar entrada no banco (até 60s)..."

    # Aguardar até 60s (30 tentativas × 2s) para a entrada ser criada
    local attempt=0
    local entry_exists=0
    while [[ $attempt -lt 30 ]]; do
        sleep 2
        attempt=$((attempt + 1))
        local count
        # -N: sem cabeçalho, -s: modo silencioso (sem formatação extra)
        # tr -d: remove qualquer whitespace residual do output do mysql
        count=$(sudo mysql -N -s -e \
            "SELECT COUNT(*) FROM \`${VTC_ABBR}_db\`.settings WHERE skey='client-config/meta';" \
            2>/dev/null | tr -d '[:space:]' || echo "0")
        if [[ "$count" == "1" ]]; then
            entry_exists=1
            break
        fi
        # Mostrar progresso a cada 10s
        if (( attempt % 5 == 0 )); then
            print_info "Aguardando inicialização do backend... (${attempt}x2s)"
        fi
    done

    if [[ $entry_exists -eq 1 ]]; then
        print_info "Corrigindo api_host para: ${correct_api_host}..."
        sudo mysql -e \
            "UPDATE \`${VTC_ABBR}_db\`.settings \
             SET sval = JSON_SET(sval, '\$.api_host', '${correct_api_host}') \
             WHERE skey='client-config/meta';" 2>/dev/null || true

        # Limpar cache Redis para o frontend receber o valor corrigido imediatamente
        redis-cli DEL "client-config:meta" >/dev/null 2>&1 || true

        print_success "api_host corrigido para: ${correct_api_host}"

        # Reiniciar o serviço para garantir que o Redis foi limpo e novo cache gerado
        print_info "Reiniciando serviço para aplicar configuração..."
        sudo systemctl restart "drivershub-${VTC_ABBR}.service" 2>/dev/null || true
        sleep 3
    else
        print_warning "Entrada client-config não encontrada no banco após 60s."
        print_warning "Execute manualmente após verificar os logs do serviço:"
        print_warning "  sudo journalctl -u drivershub-${VTC_ABBR} -n 30"
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

    print_info "Removendo configuração default do Nginx..."
    sudo rm -f /etc/nginx/sites-enabled/default

    print_info "Criando configuração do backend (com slot para o frontend)..."

    # Nome do arquivo de configuração salvo também no state para o frontend reutilizar
    NGINX_CONF_NAME="drivershub-${VTC_ABBR}"

    sudo tee /etc/nginx/sites-available/${NGINX_CONF_NAME} > /dev/null << EOF
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
    # Este bloco será substituído pelo install-frontend.sh
    # FRONTEND_PLACEHOLDER
    location / {
        return 503 "Frontend ainda nao instalado. Execute: bash scripts/install-frontend.sh";
        add_header Content-Type text/plain;
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/${NGINX_CONF_NAME} \
                /etc/nginx/sites-enabled/${NGINX_CONF_NAME}

    print_info "Testando configuração do Nginx..."
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

    print_info "Obtendo certificado SSL..."
    print_warning "Certifique-se de que o domínio '$DOMAIN' aponta para este servidor!"

    if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email; then
        print_success "SSL configurado com sucesso"
    else
        print_warning "Falha ao configurar SSL automaticamente. Configure manualmente depois com:"
        print_warning "  sudo certbot --nginx -d $DOMAIN"
    fi
}

################################################################################
# Salvar estado da instalação para uso pelo install-frontend.sh
################################################################################

save_installer_state() {
    print_info "Salvando estado da instalação..."

    # Garantir que o diretório base existe
    sudo mkdir -p /opt/drivershub
    sudo chown "$USER":"$USER" /opt/drivershub

    # Determinar protocolo real já aplicado
    local protocol="http"
    [[ "$INSTALL_SSL" == "y" ]] && protocol="https"

    cat > "$STATE_FILE" << EOF
# Gerado automaticamente por install-drivershub.sh — não edite manualmente
BACKEND_VTC_NAME="$VTC_NAME"
BACKEND_VTC_ABBR="$VTC_ABBR"
BACKEND_DOMAIN="$DOMAIN"
BACKEND_PORT="$PORT"
BACKEND_PROTOCOL="$protocol"
BACKEND_INSTALL_NGINX="$INSTALL_NGINX"
BACKEND_INSTALL_SSL="$INSTALL_SSL"
BACKEND_NGINX_CONF="drivershub-${VTC_ABBR}"
BACKEND_INSTALL_DIR="$INSTALL_DIR"
BACKEND_INSTALLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

    chmod 600 "$STATE_FILE"
    print_success "Estado salvo em $STATE_FILE"
}

################################################################################
# Finalização
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

    echo -e "\n${CYAN}📊 INFORMAÇÕES DO SISTEMA${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC: $VTC_NAME"
    echo "Abreviação: $VTC_ABBR"

    if [[ "$INSTALL_NGINX" == "y" ]]; then
        if [[ "$INSTALL_SSL" == "y" ]]; then
            echo "URL do Backend: https://$DOMAIN/$VTC_ABBR"
        else
            echo "URL do Backend: http://$DOMAIN/$VTC_ABBR"
        fi
    else
        echo "URL do Backend: http://localhost:$PORT/$VTC_ABBR"
    fi

    echo ""
    echo "Serviço: drivershub-${VTC_ABBR}.service"
    echo "Diretório: $INSTALL_DIR"
    echo "Config: $INSTALL_DIR/config.json"
    echo "State: $STATE_FILE"

    echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ver status:    sudo systemctl status drivershub-${VTC_ABBR}"
    echo "Ver logs:      sudo journalctl -u drivershub-${VTC_ABBR} -f"
    echo "Reiniciar:     sudo systemctl restart drivershub-${VTC_ABBR}"
    echo "Parar:         sudo systemctl stop drivershub-${VTC_ABBR}"
    echo "Iniciar:       sudo systemctl start drivershub-${VTC_ABBR}"

    echo -e "\n${CYAN}⚠️  PRÓXIMOS PASSOS IMPORTANTES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Calcular a URL de callback exata
    local callback_url
    if [[ "$INSTALL_SSL" == "y" ]]; then
        callback_url="https://$DOMAIN/$VTC_ABBR/api/auth/discord/callback"
    elif [[ "$INSTALL_NGINX" == "y" ]]; then
        callback_url="http://$DOMAIN/$VTC_ABBR/api/auth/discord/callback"
    else
        callback_url="http://localhost:$PORT/$VTC_ABBR/api/auth/discord/callback"
    fi

    echo "1. Configure o Redirect URI no Discord Developer Portal:"
    echo "   Portal: https://discord.com/developers/applications"
    echo "   → OAuth2 → Redirects → Adicionar exatamente:"
    echo -e "   ${GREEN}${callback_url}${NC}"
    echo "   ⚠️  Sem este passo o login com Discord retorna 'redirect_uri inválido'"
    echo ""
    echo "2. Convide o bot Discord para seu servidor com permissões de admin"
    echo ""
    echo "3. Instale o Frontend executando:"
    echo -e "   ${GREEN}bash scripts/install-frontend.sh${NC}"
    echo ""
    echo "4. Após o frontend, acesse a interface web e faça login com Discord"

    echo -e "\n${CYAN}📚 DOCUMENTAÇÃO E SUPORTE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Wiki: https://wiki.charlws.com/books/chub"
    echo "Discord: https://discord.gg/wNTaaBZ5qd"
    echo "Site: https://drivershub.charlws.com"

    echo -e "\n${GREEN}🎉 Boa sorte com sua transportadora virtual! 🚚${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    print_header

    # Verificações iniciais
    check_root
    check_requirements

    # Detectar instalação existente e definir INSTALL_MODE
    detect_existing_installation

    # Coletar informações (pula em modo reparo, que reutiliza dados existentes)
    collect_info

    # Validar credenciais Discord e Steam antes de instalar
    validate_credentials

    # Executar instalação
    install_system_dependencies
    install_mysql
    install_redis
    clone_repository
    setup_python_env
    fix_database_code
    fix_client_config_plugin
    create_config_file
    create_database_tables
    create_systemd_service

    # Configurações opcionais (Nginx precisa estar pronto antes de corrigir api_host)
    configure_nginx
    configure_ssl

    # Corrigir api_host no banco APÓS nginx estar configurado
    # (dá mais tempo para o backend inicializar e o plugin criar a entrada)
    fix_client_config_api_host

    # Salvar estado para o instalador do frontend
    save_installer_state

    # Finalizar
    print_final_info
}

# Executar script
main "$@"