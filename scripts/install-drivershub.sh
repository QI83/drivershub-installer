#!/bin/bash

################################################################################
# Script de Instalação Automatizada do Drivers Hub
# Versão: 1.0.0
# Data: Fevereiro 2026
# 
# Este script automatiza a instalação completa do Drivers Hub Backend
# incluindo configuração de banco de dados, Redis, e serviços.
################################################################################

set -e  # Sair em caso de erro

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
CONFIG_FILE=""
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
        read -p "$(echo -e ${YELLOW}$prompt [S/n]: ${NC})" response
        response=${response:-y}
    else
        read -p "$(echo -e ${YELLOW}$prompt [s/N]: ${NC})" response
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
    
    print_success "Requisitos do sistema verificados"
}

################################################################################
# Coleta de Informações
################################################################################

collect_info() {
    print_step 2 10 "Coletando informações da instalação"
    
    echo -e "\n${MAGENTA}📋 INFORMAÇÕES DA SUA VTC${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Nome da VTC
    while [[ -z "$VTC_NAME" ]]; do
        read -p "$(echo -e ${CYAN}Nome completo da VTC: ${NC})" VTC_NAME
    done
    
    # Abreviação
    while [[ -z "$VTC_ABBR" ]]; do
        read -p "$(echo -e ${CYAN}Abreviação da VTC \(ex: cdmp\): ${NC})" VTC_ABBR
        VTC_ABBR=$(echo "$VTC_ABBR" | tr '[:upper:]' '[:lower:]')
    done
    
    # Domínio
    read -p "$(echo -e ${CYAN}Domínio \(deixe vazio para localhost\): ${NC})" DOMAIN
    DOMAIN=${DOMAIN:-localhost:$PORT}
    
    # Porta
    read -p "$(echo -e ${CYAN}Porta do servidor [7777]: ${NC})" input_port
    PORT=${input_port:-7777}
    
    echo -e "\n${MAGENTA}🔐 CREDENCIAIS DO BANCO DE DADOS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Senha do banco
    while [[ -z "$DB_PASSWORD" ]]; do
        read -sp "$(echo -e ${CYAN}Senha para o banco de dados MariaDB: ${NC})" DB_PASSWORD
        echo
        read -sp "$(echo -e ${CYAN}Confirme a senha: ${NC})" DB_PASSWORD_CONFIRM
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
    
    read -p "$(echo -e ${CYAN}Discord Client ID: ${NC})" DISCORD_CLIENT_ID
    read -p "$(echo -e ${CYAN}Discord Client Secret: ${NC})" DISCORD_CLIENT_SECRET
    read -p "$(echo -e ${CYAN}Discord Bot Token: ${NC})" DISCORD_BOT_TOKEN
    read -p "$(echo -e ${CYAN}Discord Server \(Guild\) ID: ${NC})" DISCORD_GUILD_ID
    read -p "$(echo -e ${CYAN}Steam API Key: ${NC})" STEAM_API_KEY
    
    echo -e "\n${MAGENTA}⚙️  CONFIGURAÇÕES OPCIONAIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if confirm "Deseja instalar e configurar Nginx como proxy reverso?"; then
        INSTALL_NGINX="y"
    fi
    
    if [[ "$INSTALL_NGINX" == "y" ]] && [[ "$DOMAIN" != "localhost"* ]]; then
        if confirm "Deseja configurar SSL/HTTPS com Let's Encrypt?"; then
            INSTALL_SSL="y"
        fi
    fi
    
    # Resumo
    echo -e "\n${GREEN}📊 RESUMO DA INSTALAÇÃO${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC: $VTC_NAME ($VTC_ABBR)"
    echo "Domínio: $DOMAIN"
    echo "Porta: $PORT"
    echo "Banco de dados: MariaDB (senha configurada)"
    echo "Discord: ${DISCORD_CLIENT_ID:0:8}..."
    echo "Steam: ${STEAM_API_KEY:0:8}..."
    echo "Nginx: $INSTALL_NGINX"
    echo "SSL: $INSTALL_SSL"
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
                        libssl-dev libffi-dev git curl wget 2>&1 | grep -v "already"
    
    print_success "Dependências do sistema instaladas"
}

install_mariadb() {
    print_step 4 10 "Instalando e configurando MariaDB"
    
    if ! command -v mysql &> /dev/null; then
        print_info "Instalando MariaDB..."
        sudo apt install -y mariadb-server mariadb-client 2>&1 | grep -v "already"
        
        print_info "Iniciando serviço MariaDB..."
        sudo systemctl start mariadb
        sudo systemctl enable mariadb
        
        print_success "MariaDB instalado"
    else
        print_info "MariaDB já está instalado"
    fi
    
    print_info "Criando banco de dados e usuário..."
    
    # Criar banco e usuário
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${VTC_ABBR}_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    sudo mysql -e "CREATE USER IF NOT EXISTS '${VTC_ABBR}_user'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" 2>/dev/null || true
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${VTC_ABBR}_db.* TO '${VTC_ABBR}_user'@'localhost';" 2>/dev/null || true
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    print_success "Banco de dados MariaDB configurado"
}

install_redis() {
    print_step 5 10 "Instalando e configurando Redis"
    
    if ! command -v redis-cli &> /dev/null; then
        print_info "Instalando Redis..."
        sudo apt install -y redis-server 2>&1 | grep -v "already"
        
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
    sudo chown $USER:$USER /opt/drivershub
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Diretório já existe. Atualizando..."
        cd $INSTALL_DIR
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
    
    cd $INSTALL_DIR
    
    if [ ! -d "venv" ]; then
        print_info "Criando ambiente virtual..."
        python3 -m venv venv
    fi
    
    print_info "Ativando ambiente virtual..."
    source venv/bin/activate
    
    print_info "Atualizando pip..."
    pip install --upgrade pip -q
    
    print_info "Instalando dependências Python..."
    pip install -r requirements.txt -q
    
    print_success "Ambiente Python configurado"
}

fix_database_code() {
    print_step 8 10 "Aplicando correção no código (DATA DIRECTORY)"
    
    cd $INSTALL_DIR/src
    
    if [ ! -f "db.py.backup" ]; then
        print_info "Criando backup do db.py..."
        cp db.py db.py.backup
        
        print_info "Removendo cláusulas DATA DIRECTORY..."
        sed -i "s/ DATA DIRECTORY = '{app.config.db_data_directory}'//g" db.py
        
        print_success "Correção aplicada"
    else
        print_info "Correção já foi aplicada anteriormente"
    fi
}

create_config_file() {
    print_step 9 10 "Criando arquivo de configuração"
    
    cd $INSTALL_DIR
    
    # Gerar secret key aleatória
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    
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
    "logo_url": "https://{domain}/images/logo.png",
    "banner_background_url": "",
    "banner_background_opacity": 0.15,
    "banner_info_first_row": "rank",
    "openapi": true,
    "frontend_urls": {
        "member": "https://{domain}/member/{userid}",
        "delivery": "https://{domain}/delivery/{logid}",
        "email_confirm": "https://{domain}/auth/email?secret={secret}"
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
    "db_user": "${VTC_ABBR}_user",
    "db_password": "$DB_PASSWORD",
    "db_name": "${VTC_ABBR}_db",
    "db_data_directory": "",
    "db_pool_size": 10,
    "db_error_keywords": ["lost connection", "deadlock", "readexactly", "timeout", "[aiosql]"],
    "captcha": {
        "provider": "hcaptcha",
        "secret": ""
    },
    "redis_host": "127.0.0.1",
    "redis_port": 6379,
    "redis_db": 0,
    "redis_password": null,
    "plugins": ["announcements", "applications", "banner", "challenges", "divisions", "downloads", "events", "polls", "route"],
    "external_plugins": [],
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
    
    sudo tee /etc/systemd/system/drivershub-${VTC_ABBR}.service > /dev/null << EOF
[Unit]
Description=$VTC_NAME - Drivers Hub Backend
After=network.target mariadb.service redis.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python3 src/main.py --config config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    print_info "Recarregando systemd..."
    sudo systemctl daemon-reload
    
    print_info "Habilitando serviço..."
    sudo systemctl enable drivershub-${VTC_ABBR}.service
    
    print_info "Iniciando serviço..."
    sudo systemctl start drivershub-${VTC_ABBR}.service
    
    sleep 3
    
    if sudo systemctl is-active --quiet drivershub-${VTC_ABBR}.service; then
        print_success "Serviço iniciado com sucesso"
    else
        print_error "Falha ao iniciar serviço. Verificando logs..."
        sudo journalctl -u drivershub-${VTC_ABBR}.service -n 20
        exit 1
    fi
}

configure_nginx() {
    if [[ "$INSTALL_NGINX" != "y" ]]; then
        return
    fi
    
    print_info "Instalando Nginx..."
    sudo apt install -y nginx 2>&1 | grep -v "already"
    
    print_info "Criando configuração do Nginx..."
    
    sudo tee /etc/nginx/sites-available/drivershub-${VTC_ABBR} > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/drivershub-${VTC_ABBR} /etc/nginx/sites-enabled/
    
    print_info "Testando configuração do Nginx..."
    if sudo nginx -t; then
        print_info "Reiniciando Nginx..."
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
    sudo apt install -y certbot python3-certbot-nginx 2>&1 | grep -v "already"
    
    print_info "Obtendo certificado SSL..."
    print_warning "Certifique-se de que seu domínio $DOMAIN aponta para este servidor!"
    
    if sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email; then
        print_success "SSL configurado com sucesso"
    else
        print_error "Falha ao configurar SSL. Configure manualmente depois."
    fi
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
    echo "║              ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✅         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "\n${CYAN}📊 INFORMAÇÕES DO SISTEMA${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VTC: $VTC_NAME"
    echo "Abreviação: $VTC_ABBR"
    
    if [[ "$INSTALL_NGINX" == "y" ]]; then
        if [[ "$INSTALL_SSL" == "y" ]]; then
            echo "URL de Acesso: https://$DOMAIN"
        else
            echo "URL de Acesso: http://$DOMAIN"
        fi
    else
        echo "URL de Acesso: http://localhost:$PORT/$VTC_ABBR"
    fi
    
    echo ""
    echo "Serviço: drivershub-${VTC_ABBR}.service"
    echo "Diretório: $INSTALL_DIR"
    echo "Config: $INSTALL_DIR/config.json"
    
    echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ver status:    sudo systemctl status drivershub-${VTC_ABBR}"
    echo "Ver logs:      sudo journalctl -u drivershub-${VTC_ABBR} -f"
    echo "Reiniciar:     sudo systemctl restart drivershub-${VTC_ABBR}"
    echo "Parar:         sudo systemctl stop drivershub-${VTC_ABBR}"
    echo "Iniciar:       sudo systemctl start drivershub-${VTC_ABBR}"
    
    echo -e "\n${CYAN}⚠️  PRÓXIMOS PASSOS IMPORTANTES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Configure o Redirect URI no Discord Developer Portal:"
    if [[ "$INSTALL_SSL" == "y" ]]; then
        echo "   https://$DOMAIN/$VTC_ABBR/api/auth/discord/callback"
    elif [[ "$INSTALL_NGINX" == "y" ]]; then
        echo "   http://$DOMAIN/$VTC_ABBR/api/auth/discord/callback"
    else
        echo "   http://localhost:$PORT/$VTC_ABBR/api/auth/discord/callback"
    fi
    echo ""
    echo "2. Convide o bot Discord para seu servidor com permissões de admin"
    echo ""
    echo "3. Acesse a interface web e faça login com Discord"
    echo ""
    echo "4. Configure os cargos e webhooks do Discord no painel"
    
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
    
    # Coletar informações
    collect_info
    
    # Executar instalação
    install_system_dependencies
    install_mariadb
    install_redis
    clone_repository
    setup_python_env
    fix_database_code
    create_config_file
    create_systemd_service
    
    # Configurações opcionais
    configure_nginx
    configure_ssl
    
    # Finalizar
    print_final_info
}

# Executar script
main "$@"
