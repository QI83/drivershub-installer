#!/bin/bash

################################################################################
# Script de Desinstalação do Drivers Hub
# Versão: 1.0.0
# Data: Março 2026
#
# Remove completamente o Drivers Hub do servidor.
# Cada etapa é confirmada individualmente para evitar remoções acidentais.
################################################################################

set -e
set -o pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Caminhos ──────────────────────────────────────────────────────────────────
STATE_FILE="/opt/drivershub/.installer_state"
FRONTEND_WEBROOT="/var/www/drivershub-frontend"

# ── Variáveis do state ────────────────────────────────────────────────────────
BACKEND_VTC_NAME=""
BACKEND_VTC_ABBR=""
BACKEND_INSTALL_DIR=""
BACKEND_NGINX_CONF=""
BACKEND_INSTALL_NGINX=""

################################################################################
# Funções auxiliares
################################################################################

print_header() {
    clear
    echo -e "${RED}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          DESINSTALADOR - DRIVERS HUB                         ║"
    echo "║              Euro Truck Simulator 2 / ATS                    ║"
    echo "║                                                               ║"
    echo "║  ⚠️  ATENÇÃO: Esta operação remove dados permanentemente!  ⚠️  ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step()    { echo -e "\n${BLUE}[PASSO $1/$2]${NC} ${RED}$3${NC}"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }
print_removed() { echo -e "${RED}🗑️  Removido: $1${NC}"; }

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
        print_error "Este script NÃO deve ser executado como root!"
        exit 1
    fi
}

################################################################################
# Passo 0 — Confirmação e carregamento do state
################################################################################

load_and_confirm() {
    print_step 1 6 "Identificando instalação"

    # Tentar carregar state file
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_FILE"
        echo ""
        echo -e "  Instalação encontrada:"
        echo -e "  VTC:       ${YELLOW}${BACKEND_VTC_NAME} (${BACKEND_VTC_ABBR})${NC}"
        echo -e "  Backend:   ${YELLOW}${BACKEND_INSTALL_DIR}${NC}"
        echo -e "  Nginx:     ${YELLOW}${BACKEND_INSTALL_NGINX}${NC}"
        echo ""
    else
        print_warning "Arquivo de estado não encontrado ($STATE_FILE)."
        print_info "Tentando detectar instalação manualmente..."
        echo ""

        # Pedir sigla manualmente
        read -r -p "$(echo -e "${CYAN}Qual é a sigla/abreviação da VTC instalada? ${NC}")" BACKEND_VTC_ABBR
        if [[ -z "$BACKEND_VTC_ABBR" ]]; then
            print_error "Sigla não informada. Abortando."
            exit 1
        fi

        BACKEND_INSTALL_DIR="/opt/drivershub/HubBackend"
        BACKEND_NGINX_CONF="drivershub-${BACKEND_VTC_ABBR}"
        BACKEND_INSTALL_NGINX="y"
    fi

    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  Isto irá remover PERMANENTEMENTE o Drivers Hub do servidor.  ║${NC}"
    echo -e "${RED}║  Backups do banco de dados NÃO serão criados automaticamente. ║${NC}"
    echo -e "${RED}║  Certifique-se de ter feito backup antes de continuar.        ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! confirm "Tem CERTEZA que deseja desinstalar o Drivers Hub?" "n"; then
        print_warning "Desinstalação cancelada pelo usuário."
        exit 0
    fi

    print_success "Confirmação recebida. Iniciando desinstalação..."
}

################################################################################
# Passo 1 — Parar e remover serviço systemd
################################################################################

remove_service() {
    print_step 2 6 "Removendo serviço systemd"

    local service_name="drivershub-${BACKEND_VTC_ABBR}"
    local service_file="/etc/systemd/system/${service_name}.service"

    if systemctl list-unit-files | grep -q "${service_name}"; then
        print_info "Parando ${service_name}..."
        sudo systemctl stop "${service_name}.service" 2>/dev/null || true

        print_info "Desabilitando ${service_name}..."
        sudo systemctl disable "${service_name}.service" 2>/dev/null || true

        if [[ -f "$service_file" ]]; then
            sudo rm -f "$service_file"
            print_removed "$service_file"
        fi

        sudo systemctl daemon-reload
        print_success "Serviço removido"
    else
        print_info "Serviço ${service_name} não encontrado (já removido ou nunca criado)"
    fi
}

################################################################################
# Passo 2 — Remover configuração do Nginx
################################################################################

remove_nginx_config() {
    print_step 3 6 "Removendo configuração do Nginx"

    if [[ -z "$BACKEND_NGINX_CONF" ]]; then
        BACKEND_NGINX_CONF="drivershub-${BACKEND_VTC_ABBR}"
    fi

    local sites_available="/etc/nginx/sites-available/${BACKEND_NGINX_CONF}"
    local sites_enabled="/etc/nginx/sites-enabled/${BACKEND_NGINX_CONF}"
    local removed=0

    if [[ -f "$sites_enabled" ]]; then
        sudo rm -f "$sites_enabled"
        print_removed "$sites_enabled"
        removed=1
    fi

    if [[ -f "$sites_available" ]]; then
        sudo rm -f "$sites_available"
        print_removed "$sites_available"
        removed=1
    fi

    # Remover webroot do frontend
    if [[ -d "$FRONTEND_WEBROOT" ]]; then
        if confirm "Remover webroot do frontend ($FRONTEND_WEBROOT)?" "y"; then
            sudo rm -rf "$FRONTEND_WEBROOT"
            print_removed "$FRONTEND_WEBROOT"
            removed=1
        fi
    fi

    if [[ $removed -eq 1 ]] && sudo systemctl is-active --quiet nginx 2>/dev/null; then
        # Reativar o default do nginx para não deixar o servidor sem resposta
        if [[ -f /etc/nginx/sites-available/default ]]; then
            sudo ln -sf /etc/nginx/sites-available/default \
                        /etc/nginx/sites-enabled/default 2>/dev/null || true
        fi
        sudo nginx -t 2>/dev/null && sudo systemctl reload nginx
        print_success "Nginx recarregado"
    elif [[ $removed -eq 0 ]]; then
        print_info "Nenhuma configuração Nginx encontrada para remover"
    fi
}

################################################################################
# Passo 3 — Remover banco de dados
################################################################################

remove_database() {
    print_step 4 6 "Removendo banco de dados"

    if ! command -v mysql &>/dev/null; then
        print_info "MySQL não encontrado. Pulando."
        return
    fi

    local db_name="${BACKEND_VTC_ABBR}_db"
    local db_user="${BACKEND_VTC_ABBR}_user"

    echo -e "\n${RED}ATENÇÃO: Esta operação apaga todos os dados da VTC irreversivelmente!${NC}"
    echo -e "  Banco:    ${YELLOW}${db_name}${NC}"
    echo -e "  Usuário:  ${YELLOW}${db_user}${NC}"
    echo ""

    if confirm "⚠️  Deseja remover o banco de dados '$db_name' e todos os seus dados?" "n"; then
        print_info "Removendo banco de dados ${db_name}..."
        sudo mysql -e "DROP DATABASE IF EXISTS \`${db_name}\`;" 2>/dev/null || true
        print_removed "Banco: ${db_name}"

        print_info "Removendo usuário ${db_user}..."
        sudo mysql -e "DROP USER IF EXISTS '${db_user}'@'localhost';" 2>/dev/null || true
        sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        print_removed "Usuário MySQL: ${db_user}"

        print_success "Banco de dados removido"
    else
        print_warning "Banco de dados preservado — você pode removê-lo manualmente depois:"
        print_warning "  sudo mysql -e \"DROP DATABASE ${db_name};\""
    fi
}

################################################################################
# Passo 4 — Remover arquivos do projeto
################################################################################

remove_files() {
    print_step 5 6 "Removendo arquivos do projeto"

    local base_dir="/opt/drivershub"

    if [[ -d "$base_dir" ]]; then
        echo -e "\n  Conteúdo de ${YELLOW}${base_dir}${NC}:"
        ls -la "$base_dir" 2>/dev/null | tail -n +2 | awk '{print "    "$0}'
        echo ""

        if confirm "Remover o diretório completo '$base_dir' (código, venv, backups, state)?" "y"; then
            sudo rm -rf "$base_dir"
            print_removed "$base_dir"
            print_success "Arquivos do projeto removidos"
        else
            # Remover apenas o backend mas preservar backups
            if [[ -d "${BACKEND_INSTALL_DIR}" ]]; then
                if confirm "Remover apenas o código do backend (${BACKEND_INSTALL_DIR})?" "y"; then
                    sudo rm -rf "${BACKEND_INSTALL_DIR}"
                    print_removed "${BACKEND_INSTALL_DIR}"
                fi
            fi

            if [[ -d "${base_dir}/HubFrontend" ]]; then
                if confirm "Remover o código do frontend (${base_dir}/HubFrontend)?" "y"; then
                    sudo rm -rf "${base_dir}/HubFrontend"
                    print_removed "${base_dir}/HubFrontend"
                fi
            fi

            print_warning "Diretório base preservado: $base_dir"
        fi
    else
        print_info "Diretório $base_dir não encontrado (já removido)"
    fi
}

################################################################################
# Passo 5 — Resumo final
################################################################################

print_final_info() {
    print_step 6 6 "Desinstalação concluída"

    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          ✅ DESINSTALAÇÃO CONCLUÍDA!                         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "\n${CYAN}📋 O QUE NÃO FOI REMOVIDO AUTOMATICAMENTE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MySQL Server  — ainda instalado no sistema"
    echo "  Redis Server  — ainda instalado no sistema"
    echo "  Nginx         — ainda instalado (pode ter outros sites)"
    echo "  Node.js       — ainda instalado no sistema"
    echo ""
    echo "  Para remover esses pacotes do sistema (se não usar em outro projeto):"
    echo "    sudo apt remove mysql-server redis-server nginx nodejs"
    echo ""
    echo -e "${CYAN}🔄 PARA REINSTALAR${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "    bash scripts/install-drivershub.sh"
    echo "    bash scripts/install-frontend.sh"
    echo ""
    echo -e "${GREEN}🚚 Até a próxima!${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    print_header
    check_root
    load_and_confirm
    remove_service
    remove_nginx_config
    remove_database
    remove_files
    print_final_info
}

main "$@"
