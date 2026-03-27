#!/bin/bash

################################################################################
# Script de Atualização do Drivers Hub
# Versão: 1.0.0
# Data: Março 2026
#
# Atualiza Backend e Frontend para a versão mais recente sem perder dados.
# PRÉ-REQUISITO: install-drivershub.sh e install-frontend.sh já executados.
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
FRONTEND_DIR="/opt/drivershub/HubFrontend"
FRONTEND_WEBROOT="/var/www/drivershub-frontend"
LOG_FILE="/opt/drivershub/update.log"

# ── Variáveis do state ────────────────────────────────────────────────────────
BACKEND_VTC_ABBR=""
BACKEND_INSTALL_DIR=""
UPDATE_BACKEND="y"
UPDATE_FRONTEND="y"

################################################################################
# Funções auxiliares
################################################################################

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          ATUALIZADOR - DRIVERS HUB                           ║"
    echo "║              Euro Truck Simulator 2 / ATS                    ║"
    echo "║                                                               ║"
    echo "║ Versão: 1.0.0                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step()    { echo -e "\n${BLUE}[PASSO $1/$2]${NC} ${GREEN}$3${NC}"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }
log()           { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

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
# Passo 0 — Verificações e seleção do que atualizar
################################################################################

check_state() {
    print_step 1 5 "Verificando instalação existente"

    if [[ ! -f "$STATE_FILE" ]]; then
        print_error "Arquivo de estado não encontrado: $STATE_FILE"
        print_info "Execute primeiro: bash scripts/install-drivershub.sh"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$STATE_FILE"

    print_success "Instalação encontrada"
    echo ""
    echo -e "  VTC:          ${GREEN}${BACKEND_VTC_NAME} (${BACKEND_VTC_ABBR})${NC}"
    echo -e "  Backend:      ${GREEN}${BACKEND_INSTALL_DIR}${NC}"
    echo -e "  Instalado em: ${GREEN}${BACKEND_INSTALLED_AT}${NC}"
    echo ""

    # Verificar o que existe para atualizar
    if [[ ! -d "${BACKEND_INSTALL_DIR}" ]]; then
        print_warning "Diretório do backend não encontrado. Pulando atualização do backend."
        UPDATE_BACKEND="n"
    fi

    if [[ ! -d "${FRONTEND_DIR}/.git" ]]; then
        print_warning "Frontend não instalado. Pulando atualização do frontend."
        UPDATE_FRONTEND="n"
    fi

    if [[ "$UPDATE_BACKEND" == "n" && "$UPDATE_FRONTEND" == "n" ]]; then
        print_error "Nenhum componente encontrado para atualizar."
        exit 1
    fi

    echo -e "${MAGENTA}📦 O QUE DESEJA ATUALIZAR?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$UPDATE_BACKEND" == "y" ]]; then
        if ! confirm "Atualizar Backend (HubBackend)?" "y"; then
            UPDATE_BACKEND="n"
        fi
    fi

    if [[ "$UPDATE_FRONTEND" == "y" ]]; then
        if ! confirm "Atualizar Frontend (HubFrontend)?" "y"; then
            UPDATE_FRONTEND="n"
        fi
    fi

    if [[ "$UPDATE_BACKEND" == "n" && "$UPDATE_FRONTEND" == "n" ]]; then
        print_warning "Nada selecionado para atualizar. Saindo."
        exit 0
    fi

    print_success "Seleção confirmada"
}

################################################################################
# Passo 1 — Backup do config.json antes de atualizar
################################################################################

backup_config() {
    print_step 2 5 "Fazendo backup das configurações"

    local backup_dir="/opt/drivershub/backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    sudo mkdir -p "$backup_dir"
    sudo chown "$USER":"$USER" "$backup_dir"

    if [[ "$UPDATE_BACKEND" == "y" && -f "${BACKEND_INSTALL_DIR}/config.json" ]]; then
        cp "${BACKEND_INSTALL_DIR}/config.json" "${backup_dir}/config_${timestamp}.json"
        print_success "config.json → ${backup_dir}/config_${timestamp}.json"
        log "Backup config.json: ${backup_dir}/config_${timestamp}.json"
    fi

    if [[ "$UPDATE_FRONTEND" == "y" && -f "${FRONTEND_DIR}/.env.production" ]]; then
        cp "${FRONTEND_DIR}/.env.production" "${backup_dir}/env_production_${timestamp}"
        print_success ".env.production → ${backup_dir}/env_production_${timestamp}"
        log "Backup .env.production: ${backup_dir}/env_production_${timestamp}"
    fi

    # Listar backups anteriores e manter apenas os 10 mais recentes
    local backup_count
    backup_count=$(find "$backup_dir" -name "config_*.json" | wc -l)
    if [[ "$backup_count" -gt 10 ]]; then
        find "$backup_dir" -name "config_*.json" | sort | head -n -10 | xargs rm -f
        print_info "Backups antigos removidos (mantendo últimos 10)"
    fi

    print_success "Backup concluído em $backup_dir"
}

################################################################################
# Passo 2 — Atualizar Backend
################################################################################

update_backend() {
    if [[ "$UPDATE_BACKEND" != "y" ]]; then
        return
    fi

    print_step 3 5 "Atualizando Backend (HubBackend)"

    local service_name="drivershub-${BACKEND_VTC_ABBR}"
    local config_backup=""

    # Guardar config.json em memória para restaurar depois do git pull
    if [[ -f "${BACKEND_INSTALL_DIR}/config.json" ]]; then
        config_backup=$(cat "${BACKEND_INSTALL_DIR}/config.json")
    fi

    # Parar serviço
    print_info "Parando serviço ${service_name}..."
    sudo systemctl stop "${service_name}.service" 2>/dev/null || true

    # git pull
    print_info "Baixando atualizações do HubBackend..."
    cd "${BACKEND_INSTALL_DIR}"

    local before_commit after_commit
    before_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "desconhecido")
    git fetch origin 2>&1 | tail -3
    git pull --ff-only origin main 2>&1 | tail -5 || git pull --ff-only origin master 2>&1 | tail -5
    after_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "desconhecido")

    if [[ "$before_commit" == "$after_commit" ]]; then
        print_info "Backend já estava na versão mais recente ($before_commit)"
    else
        print_success "Backend atualizado: $before_commit → $after_commit"
        log "Backend atualizado: $before_commit → $after_commit"
    fi

    # Restaurar config.json (git pull pode sobrescrever se existir no repo)
    if [[ -n "$config_backup" ]]; then
        echo "$config_backup" > "${BACKEND_INSTALL_DIR}/config.json"
        chmod 600 "${BACKEND_INSTALL_DIR}/config.json"
        print_success "config.json restaurado"
    fi

    # Reaplicar patch do DATA DIRECTORY se necessário
    if [[ ! -f "${BACKEND_INSTALL_DIR}/src/db.py.backup" ]]; then
        print_info "Reaplicando correção DATA DIRECTORY..."
        cp "${BACKEND_INSTALL_DIR}/src/db.py" "${BACKEND_INSTALL_DIR}/src/db.py.backup"
        sed -i "s/ DATA DIRECTORY = '{app.config.db_data_directory}'//g" \
            "${BACKEND_INSTALL_DIR}/src/db.py"
    fi

    # Atualizar dependências Python
    print_info "Atualizando dependências Python..."
    # shellcheck source=/dev/null
    source "${BACKEND_INSTALL_DIR}/venv/bin/activate"
    pip install --upgrade pip -q
    pip install -r "${BACKEND_INSTALL_DIR}/requirements.txt" -q
    pip install cryptography -q  # garante compatibilidade com MySQL 8+
    deactivate

    # Reiniciar serviço
    print_info "Reiniciando serviço ${service_name}..."
    sudo systemctl start "${service_name}.service"
    sleep 3

    if sudo systemctl is-active --quiet "${service_name}.service"; then
        print_success "Backend reiniciado com sucesso"
        log "Backend reiniciado após atualização"
    else
        print_error "Falha ao reiniciar o backend. Verificando logs..."
        sudo journalctl -u "${service_name}.service" -n 20 --no-pager
        print_warning "O config.json foi preservado. Verifique os logs acima."
        exit 1
    fi
}

################################################################################
# Passo 3 — Atualizar Frontend
################################################################################

update_frontend() {
    if [[ "$UPDATE_FRONTEND" != "y" ]]; then
        return
    fi

    print_step 4 5 "Atualizando Frontend (HubFrontend)"

    # Guardar .env.production para restaurar depois
    local env_backup=""
    if [[ -f "${FRONTEND_DIR}/.env.production" ]]; then
        env_backup=$(cat "${FRONTEND_DIR}/.env.production")
    fi

    # git pull
    print_info "Baixando atualizações do HubFrontend..."
    cd "${FRONTEND_DIR}"

    local before_commit after_commit
    before_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "desconhecido")
    git fetch origin 2>&1 | tail -3
    git pull --ff-only origin main 2>&1 | tail -5 || git pull --ff-only origin master 2>&1 | tail -5
    after_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "desconhecido")

    if [[ "$before_commit" == "$after_commit" ]]; then
        print_info "Frontend já estava na versão mais recente ($before_commit)"
        if ! confirm "Deseja forçar o rebuild mesmo assim?" "n"; then
            print_info "Rebuild ignorado."
            return
        fi
    else
        print_success "Frontend atualizado: $before_commit → $after_commit"
        log "Frontend atualizado: $before_commit → $after_commit"
    fi

    # Restaurar .env.production
    if [[ -n "$env_backup" ]]; then
        echo "$env_backup" > "${FRONTEND_DIR}/.env.production"
        print_success ".env.production restaurado"
    fi

    # Atualizar dependências e rebuild
    print_info "Atualizando dependências npm..."
    npm ci --prefer-offline 2>&1 | tail -3 || npm ci 2>&1 | tail -3

    print_info "Compilando novo build de produção..."
    npm run build

    # Verificar se o build gerou arquivos
    if [[ ! -f "${FRONTEND_DIR}/build/index.html" ]]; then
        print_error "Build falhou — index.html não encontrado em ${FRONTEND_DIR}/build/"
        exit 1
    fi

    # Deploy
    print_info "Implantando arquivos em ${FRONTEND_WEBROOT}..."
    sudo mkdir -p "$FRONTEND_WEBROOT"
    sudo rsync -a --delete "${FRONTEND_DIR}/build/" "${FRONTEND_WEBROOT}/"
    sudo chown -R www-data:www-data "${FRONTEND_WEBROOT}"
    print_success "$(find "$FRONTEND_WEBROOT" -type f | wc -l) arquivos implantados"

    # Reload Nginx
    if sudo systemctl is-active --quiet nginx; then
        print_info "Recarregando Nginx..."
        sudo systemctl reload nginx
        print_success "Nginx recarregado"
        log "Frontend atualizado e Nginx recarregado"
    fi
}

################################################################################
# Passo 4 — Resumo
################################################################################

print_final_info() {
    print_step 5 5 "Atualização concluída"

    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          ✅ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO! ✅             ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local base_url="${BACKEND_PROTOCOL}://${BACKEND_DOMAIN}"

    echo -e "\n${CYAN}🌐 ACESSO${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$UPDATE_FRONTEND" == "y" ]]; then
        echo -e "  Frontend:  ${GREEN}${base_url}/${NC}"
    fi
    echo -e "  Backend:   ${GREEN}${base_url}/${BACKEND_VTC_ABBR}/${NC}"

    echo -e "\n${CYAN}📋 LOG${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Histórico completo: $LOG_FILE"
    echo -e "\n${GREEN}🎉 Sistema atualizado! 🚚${NC}\n"
}

################################################################################
# Main
################################################################################

main() {
    print_header
    check_root

    # Inicializar log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo chown "$USER":"$USER" "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log "=== Início da atualização ==="

    check_state
    backup_config
    update_backend
    update_frontend
    print_final_info

    log "=== Atualização concluída ==="
}

main "$@"
