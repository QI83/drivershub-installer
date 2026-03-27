#!/bin/bash

################################################################################
# Script de Instalação do Frontend - Drivers Hub
# Versão: 1.0.0
# Data: Março 2026
#
# Instala e configura o HubFrontend (React + Vite) como build estático
# servido pelo Nginx já instalado pelo install-drivershub.sh.
#
# PRÉ-REQUISITO: install-drivershub.sh deve ter sido executado antes.
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

# ── Caminhos ──────────────────────────────────────────────────────────────────
STATE_FILE="/opt/drivershub/.installer_state"
FRONTEND_REPO="https://github.com/CharlesWithC/HubFrontend.git"
FRONTEND_DIR="/opt/drivershub/HubFrontend"
FRONTEND_WEBROOT="/var/www/drivershub-frontend"
NODE_MIN_VERSION=20

# ── Variáveis (serão preenchidas pelo state ou pelo usuário) ──────────────────
BACKEND_DOMAIN=""
BACKEND_VTC_ABBR=""
BACKEND_PORT=""
BACKEND_PROTOCOL=""
BACKEND_INSTALL_NGINX=""
BACKEND_NGINX_CONF=""
VITE_CONFIG_URL=""

################################################################################
# Funções auxiliares
################################################################################

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       INSTALADOR DO FRONTEND - DRIVERS HUB                   ║"
    echo "║           Euro Truck Simulator 2 / ATS                       ║"
    echo "║                                                               ║"
    echo "║ Versão: 1.0.0                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[PASSO $1/$2]${NC} ${GREEN}$3${NC}"
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

################################################################################
# Passo 0 — Verificações iniciais
################################################################################

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Este script NÃO deve ser executado como root!"
        print_info "Execute como usuário normal. O script pedirá sudo quando necessário."
        exit 1
    fi
}

check_backend_state() {
    print_step 1 6 "Verificando pré-requisitos"

    if [[ ! -f "$STATE_FILE" ]]; then
        print_error "Arquivo de estado não encontrado: $STATE_FILE"
        print_info "Execute primeiro: bash scripts/install-drivershub.sh"
        exit 1
    fi

    # Carregar variáveis salvas pelo backend
    # shellcheck source=/dev/null
    source "$STATE_FILE"

    print_success "Estado do backend carregado"
    print_info "VTC: $BACKEND_VTC_NAME ($BACKEND_VTC_ABBR)"
    print_info "Domínio: $BACKEND_DOMAIN"
    print_info "Porta: $BACKEND_PORT"
    print_info "Nginx: $BACKEND_INSTALL_NGINX"
    print_info "SSL: $BACKEND_INSTALL_SSL"

    if [[ "$BACKEND_INSTALL_NGINX" != "y" ]]; then
        print_warning "O Nginx não foi instalado pelo backend."
        print_warning "O frontend precisa do Nginx para servir os arquivos estáticos."
        if ! confirm "Deseja instalar o Nginx agora?"; then
            print_error "Instalação cancelada. Instale o Nginx e execute novamente."
            exit 1
        fi
        print_info "Instalando Nginx..."
        sudo apt-get install -y nginx -qq
        sudo systemctl enable nginx
        sudo systemctl start nginx
        BACKEND_INSTALL_NGINX="y"
        print_success "Nginx instalado"
    fi

    print_success "Pré-requisitos verificados"
}

################################################################################
# Passo 1 — Node.js
################################################################################

install_node() {
    print_step 2 6 "Verificando / instalando Node.js"

    local installed_version=""

    if command -v node &>/dev/null; then
        installed_version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [[ "$installed_version" -ge "$NODE_MIN_VERSION" ]]; then
            print_success "Node.js $(node --version) já instalado e compatível"
            return
        else
            print_warning "Node.js $(node --version) instalado, mas precisa de v${NODE_MIN_VERSION}+. Atualizando..."
        fi
    else
        print_info "Node.js não encontrado. Instalando v${NODE_MIN_VERSION}..."
    fi

    # Instalar via NodeSource (método oficial para Ubuntu/Debian)
    print_info "Adicionando repositório NodeSource (Node ${NODE_MIN_VERSION}.x)..."
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MIN_VERSION}.x" | sudo -E bash - 2>&1 | grep -E "^(##|error)" || true
    sudo apt-get install -y nodejs -qq

    # Verificar instalação
    local new_version
    new_version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ "$new_version" -ge "$NODE_MIN_VERSION" ]]; then
        print_success "Node.js $(node --version) instalado com sucesso"
    else
        print_error "Falha ao instalar Node.js v${NODE_MIN_VERSION}+"
        exit 1
    fi
}

################################################################################
# Passo 2 — Configuração (.env e VITE_CONFIG_URL)
################################################################################

configure_frontend() {
    print_step 3 6 "Configurando variáveis do frontend"

    local base_url="${BACKEND_PROTOCOL}://${BACKEND_DOMAIN}"

    echo -e "\n${MAGENTA}🌐 URL DE CONEXÃO COM O BACKEND${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "O frontend precisa saber onde está o endpoint de configuração do backend."
    print_info "Detectado automaticamente:"

    if [[ "$BACKEND_INSTALL_NGINX" == "y" ]]; then
        # Com Nginx: o prefix do backend está em /<abbr>/
        VITE_CONFIG_URL="${base_url}/${BACKEND_VTC_ABBR}/client/config/global"
    else
        # Sem Nginx: acesso direto pela porta
        VITE_CONFIG_URL="${BACKEND_PROTOCOL}://${BACKEND_DOMAIN}:${BACKEND_PORT}/${BACKEND_VTC_ABBR}/client/config/global"
    fi

    echo ""
    echo -e "  ${GREEN}VITE_CONFIG_URL=${VITE_CONFIG_URL}${NC}"
    echo ""

    if ! confirm "Confirmar esta URL? (responda não para digitar manualmente)" "y"; then
        read -r -p "$(echo -e "${CYAN}Digite a VITE_CONFIG_URL completa: ${NC}")" VITE_CONFIG_URL
        # Sanitizar
        VITE_CONFIG_URL=$(echo "$VITE_CONFIG_URL" | tr -d ' ')
    fi

    print_success "URL configurada: $VITE_CONFIG_URL"
}

################################################################################
# Passo 3 — Clone e build
################################################################################

clone_and_build() {
    print_step 4 6 "Clonando repositório e fazendo build"

    # Garantir que /opt/drivershub existe e pertence ao usuário
    sudo mkdir -p /opt/drivershub
    sudo chown "$USER":"$USER" /opt/drivershub

    # Clone ou atualização
    if [[ -d "$FRONTEND_DIR/.git" ]]; then
        print_info "Repositório já existe. Atualizando..."
        cd "$FRONTEND_DIR"
        git pull --ff-only
    else
        print_info "Clonando HubFrontend..."
        git clone "$FRONTEND_REPO" "$FRONTEND_DIR"
        cd "$FRONTEND_DIR"
    fi

    # Gerar .env.production com a URL do backend
    print_info "Gerando .env.production..."
    cat > .env.production << EOF
# Gerado automaticamente por install-frontend.sh
VITE_USE_MULTIHUB=false
VITE_MULTIHUB_DISCOVERY=
VITE_CONFIG_URL=${VITE_CONFIG_URL}
EOF
    print_info "Conteúdo do .env.production:"
    cat .env.production
    echo ""

    # Instalar dependências
    print_info "Instalando dependências npm (pode demorar alguns minutos)..."
    npm ci --prefer-offline 2>&1 | tail -5 || npm ci 2>&1 | tail -5

    # Build de produção
    print_info "Compilando o frontend (npm run build)..."
    npm run build

    # Verificar se o build gerou arquivos
    if [[ ! -d "$FRONTEND_DIR/build" ]] || [[ -z "$(ls -A "$FRONTEND_DIR/build" 2>/dev/null)" ]]; then
        print_error "O build não gerou a pasta 'build/' ou ela está vazia."
        print_error "Verifique os logs acima e tente novamente."
        exit 1
    fi

    print_success "Build concluído — $(find "$FRONTEND_DIR/build" -type f | wc -l) arquivos gerados"
}

################################################################################
# Passo 4 — Deploy no Nginx
################################################################################

deploy_nginx() {
    print_step 5 6 "Fazendo deploy no Nginx"

    # Criar e popular webroot
    print_info "Copiando arquivos para $FRONTEND_WEBROOT..."
    sudo mkdir -p "$FRONTEND_WEBROOT"
    sudo rsync -a --delete "$FRONTEND_DIR/build/" "$FRONTEND_WEBROOT/"
    sudo chown -R www-data:www-data "$FRONTEND_WEBROOT"
    print_success "$(find "$FRONTEND_WEBROOT" -type f | wc -l) arquivos implantados em $FRONTEND_WEBROOT"

    local nginx_conf_path="/etc/nginx/sites-available/${BACKEND_NGINX_CONF}"

    if [[ -f "$nginx_conf_path" ]]; then
        # O backend já criou o arquivo — substituímos o bloco placeholder
        print_info "Atualizando configuração Nginx existente: ${BACKEND_NGINX_CONF}"

        # Substituir o bloco location / placeholder pelo bloco real do SPA
        sudo python3 - "$nginx_conf_path" "$FRONTEND_WEBROOT" << 'PYEOF'
import sys, re

conf_path = sys.argv[1]
webroot   = sys.argv[2]

with open(conf_path, 'r') as f:
    content = f.read()

# Bloco SPA que substituirá o placeholder
spa_block = f"""    # ── Frontend (React SPA) ──────────────────────────────────────────────────
    root {webroot};
    index index.html;

    location / {{
        try_files $uri $uri/ /index.html;
    }}

    # Cache agressivo para assets com hash no nome
    location ~* \\.(?:js|css|woff2?|ttf|eot|svg|png|jpg|ico|webp)$ {{
        expires 1y;
        add_header Cache-Control "public, immutable";
    }}"""

# Substituir o bloco location / de placeholder (inclui linha do comentário FRONTEND_PLACEHOLDER)
pattern = r'    # Placeholder:.*?# FRONTEND_PLACEHOLDER\n    location / \{[^}]+\}'
replacement = spa_block

new_content, n = re.subn(pattern, spa_block, content, flags=re.DOTALL)

if n == 0:
    # Fallback: substituir qualquer location / existente
    pattern2 = r'    location / \{[^}]+\}'
    new_content, n2 = re.subn(pattern2, spa_block, content, flags=re.DOTALL)
    if n2 == 0:
        print("WARN: não encontrei o bloco location / para substituir. Adicionando ao final do server block.")
        new_content = content.rstrip().rstrip('}') + '\n\n' + spa_block + '\n}\n'

with open(conf_path, 'w') as f:
    f.write(new_content)

print("OK")
PYEOF

    else
        # Nginx não foi instalado pelo backend — criar config do zero
        print_info "Criando configuração Nginx dedicada para o frontend..."

        BACKEND_NGINX_CONF="drivershub-${BACKEND_VTC_ABBR}"
        nginx_conf_path="/etc/nginx/sites-available/${BACKEND_NGINX_CONF}"

        local api_block=""
        if [[ -n "$BACKEND_PORT" ]]; then
            api_block="
    # ── API do backend ────────────────────────────────────────────────────────
    location /${BACKEND_VTC_ABBR}/ {
        proxy_pass http://localhost:${BACKEND_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }"
        fi

        sudo tee "$nginx_conf_path" > /dev/null << EOF
server {
    listen 80;
    server_name ${BACKEND_DOMAIN};
    ${api_block}

    # ── Frontend (React SPA) ──────────────────────────────────────────────────
    root ${FRONTEND_WEBROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \\.(?:js|css|woff2?|ttf|eot|svg|png|jpg|ico|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
        sudo ln -sf "$nginx_conf_path" "/etc/nginx/sites-enabled/${BACKEND_NGINX_CONF}"
    fi

    # Remover default se ainda existir
    sudo rm -f /etc/nginx/sites-enabled/default

    # Testar e recarregar
    print_info "Testando configuração do Nginx..."
    if sudo nginx -t; then
        sudo systemctl reload nginx
        print_success "Nginx recarregado com sucesso"
    else
        print_error "Erro na configuração do Nginx. Verifique:"
        print_error "  sudo nginx -t"
        exit 1
    fi
}

################################################################################
# Passo 5 — Verificação final
################################################################################

verify_installation() {
    print_step 6 6 "Verificando instalação"

    local errors=0

    # Verificar arquivos no webroot
    echo -n "Arquivos em $FRONTEND_WEBROOT... "
    if [[ -f "$FRONTEND_WEBROOT/index.html" ]]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ index.html não encontrado${NC}"
        errors=$((errors + 1))
    fi

    # Verificar Nginx rodando
    echo -n "Nginx ativo... "
    if sudo systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ Nginx não está rodando${NC}"
        errors=$((errors + 1))
    fi

    # Verificar resposta HTTP
    echo -n "Resposta HTTP (localhost)... "
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost/ 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ 200 OK${NC}"
    elif [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
        echo -e "${YELLOW}⚠️  ${http_code} (redirecionamento — esperado se SSL ativo)${NC}"
    else
        echo -e "${YELLOW}⚠️  Código HTTP: ${http_code} (pode ser normal se o domínio não apontar para localhost)${NC}"
    fi

    if [[ $errors -gt 0 ]]; then
        print_error "$errors erro(s) encontrado(s) na verificação."
        exit 1
    fi

    print_success "Verificação concluída sem erros"
}

################################################################################
# Tela final
################################################################################

print_final_info() {
    clear
    print_header

    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     ✅ FRONTEND INSTALADO COM SUCESSO! ✅                     ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local base_url="${BACKEND_PROTOCOL}://${BACKEND_DOMAIN}"

    echo -e "\n${CYAN}🌐 ACESSO${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  Frontend:  ${GREEN}${base_url}/${NC}"
    echo -e "  Backend:   ${GREEN}${base_url}/${BACKEND_VTC_ABBR}/${NC}"
    echo ""
    echo "  Webroot:   $FRONTEND_WEBROOT"
    echo "  Fonte:     $FRONTEND_DIR"
    echo "  Config:    $VITE_CONFIG_URL"

    echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Status Nginx:   sudo systemctl status nginx"
    echo "Logs Nginx:     sudo tail -f /var/log/nginx/error.log"
    echo "Atualizar FE:   cd $FRONTEND_DIR && git pull && npm ci && npm run build"
    echo "                sudo rsync -a --delete build/ $FRONTEND_WEBROOT/"
    echo "                sudo systemctl reload nginx"

    echo -e "\n${CYAN}⚠️  PRÓXIMOS PASSOS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Verifique se o domínio '$BACKEND_DOMAIN' aponta para este servidor"
    echo ""
    echo "2. Confirme o Redirect URI no Discord Developer Portal:"
    echo "   ${base_url}/${BACKEND_VTC_ABBR}/api/auth/discord/callback"
    echo ""
    echo "3. Acesse ${base_url}/ e faça login com Discord"
    echo ""
    if [[ "$BACKEND_INSTALL_SSL" != "y" ]]; then
        echo "4. Para habilitar HTTPS execute:"
        echo "   sudo certbot --nginx -d $BACKEND_DOMAIN"
        echo ""
    fi

    echo -e "${GREEN}🎉 Sistema completo! Backend + Frontend operacionais. 🚚${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    print_header

    check_root
    check_backend_state
    install_node
    configure_frontend
    clone_and_build
    deploy_nginx
    verify_installation
    print_final_info
}

main "$@"
