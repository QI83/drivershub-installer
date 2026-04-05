#!/bin/bash

################################################################################
# Script de Backup do Banco de Dados - Drivers Hub
# Versão: 1.0.0
# Data: Abril 2026
#
# Uso:
#   bash scripts/backup-drivershub.sh              → menu interativo
#   bash scripts/backup-drivershub.sh --auto ABBR  → modo automático (cron)
#   bash scripts/backup-drivershub.sh --restore    → restaurar um backup
#
# O cron é configurado automaticamente pelo install-drivershub.sh.
# Backups ficam em: /opt/drivershub/backups/<abbr>/
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
KEEP_DAYS=7
AUTO_MODE=false
RESTORE_MODE=false
AUTO_ABBR=""

# ── Argumentos ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            AUTO_ABBR="${2:-}"
            shift 2
            ;;
        --restore)
            RESTORE_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          BACKUP DO BANCO DE DADOS - DRIVERS HUB               ║"
    echo "║              Euro Truck Simulator 2 / ATS                     ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }

################################################################################
# Seleção de VTC
################################################################################

select_vtc() {
    local -a states=()
    while IFS= read -r -d '' sf; do
        states+=("$sf")
    done < <(find "${INSTALL_BASE}" -maxdepth 1 -name '.installer_state*' -print0 2>/dev/null)

    if [[ ${#states[@]} -eq 0 ]]; then
        print_error "Nenhuma instalação encontrada em ${INSTALL_BASE}."
        exit 1
    fi

    if [[ ${#states[@]} -eq 1 ]]; then
        STATE_FILE="${states[0]}"
    else
        echo -e "${MAGENTA}Instalações disponíveis para backup:${NC}"
        local i=1
        for sf in "${states[@]}"; do
            (
                # shellcheck source=/dev/null
                source "$sf" 2>/dev/null
                echo "  $i) ${BACKEND_VTC_NAME:-?} (${BACKEND_VTC_ABBR:-?})"
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

    # shellcheck source=/dev/null
    source "$STATE_FILE"
    VTC_NAME="$BACKEND_VTC_NAME"
    VTC_ABBR="$BACKEND_VTC_ABBR"
    INSTALL_DIR="${BACKEND_INSTALL_DIR:-${INSTALL_BASE}/${VTC_ABBR}/HubBackend}"
    if [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]]; then
        INSTALL_DIR="${INSTALL_BASE}/HubBackend"
    fi

    DB_NAME="${VTC_ABBR}_db"
    DB_USER="${VTC_ABBR}_user"
    DB_PASSWORD=$(python3 -c "
import json
try:
    d = json.load(open('${INSTALL_DIR}/config.json'))
    print(d.get('db_password',''))
except: print('')
" 2>/dev/null || echo "")

    BACKUP_DIR="${INSTALL_BASE}/backups/${VTC_ABBR}"
    mkdir -p "$BACKUP_DIR"
}

load_vtc_auto() {
    # Modo automático — recebe o abbr diretamente
    local abbr="$1"
    STATE_FILE="${INSTALL_BASE}/.installer_state_${abbr}"
    if [[ ! -f "$STATE_FILE" ]]; then
        # Tentar state legado
        STATE_FILE="${INSTALL_BASE}/.installer_state"
    fi
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "$(date): ERRO: state file não encontrado para abbr=${abbr}" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$STATE_FILE"
    VTC_ABBR="${BACKEND_VTC_ABBR:-$abbr}"
    INSTALL_DIR="${BACKEND_INSTALL_DIR:-${INSTALL_BASE}/${VTC_ABBR}/HubBackend}"
    if [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]]; then
        INSTALL_DIR="${INSTALL_BASE}/HubBackend"
    fi

    DB_NAME="${VTC_ABBR}_db"
    DB_USER="${VTC_ABBR}_user"
    DB_PASSWORD=$(python3 -c "
import json
try:
    d = json.load(open('${INSTALL_DIR}/config.json'))
    print(d.get('db_password',''))
except: print('')
" 2>/dev/null || echo "")

    BACKUP_DIR="${INSTALL_BASE}/backups/${VTC_ABBR}"
    mkdir -p "$BACKUP_DIR"
}

################################################################################
# Funções de backup
################################################################################

do_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${DB_NAME}_${timestamp}.sql.gz"
    local log_file="${BACKUP_DIR}/backup.log"

    if [[ -z "$DB_PASSWORD" ]]; then
        echo "$(date): ERRO: senha do banco não encontrada" >> "$log_file"
        print_error "Senha do banco não encontrada. Verifique o config.json."
        return 1
    fi

    print_info "Iniciando backup de '${DB_NAME}' → ${backup_file}..."

    if mysqldump -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" 2>/dev/null \
            | gzip > "$backup_file"; then
        local size
        size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        echo "$(date): OK backup=${backup_file} size=${size}" >> "$log_file"
        print_success "Backup criado: ${backup_file} (${size})"
    else
        echo "$(date): ERRO ao criar backup de ${DB_NAME}" >> "$log_file"
        rm -f "$backup_file"
        print_error "Falha ao criar backup!"
        return 1
    fi

    # Limpar backups antigos
    local removed
    removed=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"${KEEP_DAYS}" -print 2>/dev/null | wc -l)
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true
    if [[ "$removed" -gt 0 ]]; then
        echo "$(date): Removidos ${removed} backup(s) com mais de ${KEEP_DAYS} dias" >> "$log_file"
        print_info "Removidos ${removed} backup(s) antigo(s) (>${KEEP_DAYS} dias)"
    fi

    return 0
}

list_backups() {
    echo ""
    echo -e "${CYAN}Backups disponíveis em ${BACKUP_DIR}:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local -a backups=()
    while IFS= read -r -d '' f; do
        backups+=("$f")
    done < <(find "$BACKUP_DIR" -name "*.sql.gz" -print0 2>/dev/null | sort -z)

    if [[ ${#backups[@]} -eq 0 ]]; then
        print_warning "Nenhum backup encontrado."
        return 1
    fi

    local i=1
    for f in "${backups[@]}"; do
        local size date_str
        size=$(du -sh "$f" 2>/dev/null | cut -f1)
        date_str=$(basename "$f" | grep -oP '\d{8}_\d{6}' | \
                   sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        echo "  $i) ${date_str} — $(basename "$f") (${size})"
        i=$((i + 1))
    done

    echo ""
    return 0
}

do_restore() {
    if ! list_backups; then
        return
    fi

    local -a backups=()
    while IFS= read -r -d '' f; do
        backups+=("$f")
    done < <(find "$BACKUP_DIR" -name "*.sql.gz" -print0 2>/dev/null | sort -z)

    local choice
    read -r -p "$(echo -e "${CYAN}Escolha o backup para restaurar [número]: ${NC}")" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
       [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#backups[@]}" ]]; then
        print_error "Opção inválida."
        return
    fi

    local selected="${backups[$((choice - 1))]}"

    echo ""
    print_warning "ATENÇÃO: isso irá SUBSTITUIR todos os dados atuais de '${DB_NAME}'!"
    print_warning "Arquivo: $(basename "$selected")"
    echo ""

    if ! [[ "${RESTORE_MODE}" == "true" ]]; then
        read -r -p "$(echo -e "${YELLOW}Confirma a restauração? [sim/N]: ${NC}")" confirm_restore
        if [[ "$confirm_restore" != "sim" ]]; then
            print_info "Restauração cancelada."
            return
        fi
    fi

    print_info "Criando backup de segurança antes de restaurar..."
    do_backup

    print_info "Restaurando '${DB_NAME}' a partir de $(basename "$selected")..."
    if zcat "$selected" | mysql -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" 2>/dev/null; then
        redis-cli FLUSHDB >/dev/null 2>&1 || true
        sudo systemctl restart "drivershub-${VTC_ABBR}.service" 2>/dev/null || true
        echo "$(date): OK restaurado=${selected}" >> "${BACKUP_DIR}/backup.log"
        print_success "Banco de dados restaurado com sucesso!"
        print_info "Cache Redis limpo. Serviço reiniciado."
    else
        print_error "Falha ao restaurar o banco. Verifique as credenciais e o arquivo."
    fi
}

configure_cron() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  CONFIGURAR CRON DE BACKUP AUTOMÁTICO${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local this_script
    this_script="$(realpath "$0" 2>/dev/null || echo "$0")"

    echo "  Opções de frequência:"
    echo "  1) Diário às 3h (recomendado)"
    echo "  2) A cada 6 horas"
    echo "  3) A cada hora"
    echo "  4) Personalizado (expressão cron)"
    echo ""
    local choice
    read -r -p "$(echo -e "${CYAN}Escolha [1-4]: ${NC}")" choice

    local cron_expr=""
    case "$choice" in
        1) cron_expr="0 3 * * *" ;;
        2) cron_expr="0 */6 * * *" ;;
        3) cron_expr="0 * * * *" ;;
        4)
            read -r -p "$(echo -e "${CYAN}Expressão cron (ex: 0 3 * * *): ${NC}")" cron_expr
            ;;
        *)
            print_error "Opção inválida."
            return
            ;;
    esac

    read -r -p "$(echo -e "${CYAN}Manter backups por quantos dias? [${KEEP_DAYS}]: ${NC}")" new_days
    KEEP_DAYS="${new_days:-$KEEP_DAYS}"

    local cron_line="${cron_expr} ${this_script} --auto ${VTC_ABBR}"
    ( crontab -l 2>/dev/null | grep -v "backup.*${VTC_ABBR}"; \
      echo "$cron_line" ) | crontab -

    print_success "Cron configurado: ${cron_expr}"
    print_info "Comando: ${cron_line}"
    print_info "Retenção: ${KEEP_DAYS} dias"
}

show_log() {
    local log_file="${BACKUP_DIR}/backup.log"
    if [[ -f "$log_file" ]]; then
        echo ""
        echo -e "${CYAN}Últimas 20 entradas do log de backup:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        tail -20 "$log_file"
    else
        print_warning "Nenhum log de backup encontrado."
    fi
}

################################################################################
# Main
################################################################################

# Modo automático (chamado pelo cron)
if [[ "$AUTO_MODE" == "true" ]]; then
    load_vtc_auto "${AUTO_ABBR:-}"
    do_backup
    exit $?
fi

print_header

select_vtc

echo ""
echo -e "${CYAN}VTC: ${VTC_NAME} (${VTC_ABBR})${NC}"
echo -e "${CYAN}Banco: ${DB_NAME}${NC}"
echo -e "${CYAN}Destino: ${BACKUP_DIR}${NC}"
echo ""

# Modo restauração direto
if [[ "$RESTORE_MODE" == "true" ]]; then
    do_restore
    exit 0
fi

# Menu interativo
while true; do
    echo ""
    echo -e "${MAGENTA}O que deseja fazer?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Criar backup agora"
    echo "  2) Listar backups disponíveis"
    echo "  3) Restaurar backup"
    echo "  4) Configurar cron de backup automático"
    echo "  5) Ver log de backups"
    echo "  6) Sair"
    echo ""
    local choice
    read -r -p "$(echo -e "${CYAN}Escolha [1-6]: ${NC}")" choice

    case "$choice" in
        1) do_backup ;;
        2) list_backups ;;
        3) do_restore ;;
        4) configure_cron ;;
        5) show_log ;;
        6|q|Q) print_info "Saindo."; exit 0 ;;
        *) print_error "Opção inválida." ;;
    esac
done
