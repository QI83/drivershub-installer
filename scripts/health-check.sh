#!/bin/bash

################################################################################
# Script de Health Check - Drivers Hub
# Versão: 1.0.0
# Data: Abril 2026
#
# Monitora os serviços do Drivers Hub e envia notificação via Discord webhook
# quando um serviço cai ou volta a funcionar.
#
# Uso:
#   bash scripts/health-check.sh              → menu interativo (configuração)
#   bash scripts/health-check.sh --run        → executar verificação (cron)
#   bash scripts/health-check.sh --run ABBR   → verificar VTC específica
#
# Configure o cron via menu ou manualmente:
#   */5 * * * * /opt/drivershub/health-check.sh --run ABBR
################################################################################

set -o pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

INSTALL_BASE="/opt/drivershub"
RUN_MODE=false
RUN_ABBR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)
            RUN_MODE=true
            RUN_ABBR="${2:-}"
            shift 2
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
    echo "║          HEALTH CHECK - DRIVERS HUB                          ║"
    echo "║              Euro Truck Simulator 2 / ATS                    ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ ERRO: $1${NC}"; }

################################################################################
# Carregamento de configuração da VTC
################################################################################

load_vtc() {
    local abbr="$1"
    local sf="${INSTALL_BASE}/.installer_state_${abbr}"
    [[ ! -f "$sf" ]] && sf="${INSTALL_BASE}/.installer_state"
    [[ ! -f "$sf" ]] && return 1

    # shellcheck source=/dev/null
    source "$sf"
    VTC_ABBR="${BACKEND_VTC_ABBR:-$abbr}"
    VTC_NAME="${BACKEND_VTC_NAME:-DriversHub}"
    DOMAIN="${BACKEND_DOMAIN:-localhost}"
    PORT="${BACKEND_PORT:-7777}"
    INSTALL_DIR="${BACKEND_INSTALL_DIR:-${INSTALL_BASE}/${VTC_ABBR}/HubBackend}"
    [[ ! -d "$INSTALL_DIR" ]] && [[ -d "${INSTALL_BASE}/HubBackend" ]] && \
        INSTALL_DIR="${INSTALL_BASE}/HubBackend"

    # Arquivo de configuração do health check para esta VTC
    HC_CONFIG="${INSTALL_BASE}/.healthcheck_${VTC_ABBR}"
    HC_STATE="${INSTALL_BASE}/.healthcheck_state_${VTC_ABBR}"

    # Carregar webhook e configurações
    DISCORD_WEBHOOK=""
    NOTIFY_DOWN=true
    NOTIFY_RECOVERY=true
    if [[ -f "$HC_CONFIG" ]]; then
        # shellcheck source=/dev/null
        source "$HC_CONFIG"
    fi

    return 0
}

################################################################################
# Verificação de serviço
################################################################################

check_service() {
    local service="drivershub-${VTC_ABBR}.service"
    local port="$PORT"
    local issues=()
    local ok=true

    # 1. Serviço systemd ativo?
    if ! sudo systemctl is-active --quiet "$service" 2>/dev/null; then
        issues+=("Serviço systemd ${service} está INATIVO")
        ok=false
    fi

    # 2. Porta respondendo?
    if ! ss -lnt 2>/dev/null | grep -q ":${port}"; then
        issues+=("Porta ${port} não está escutando")
        ok=false
    fi

    # 3. Endpoint HTTP respondendo?
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${port}/${VTC_ABBR}" \
        --max-time 8 2>/dev/null || echo "000")
    if [[ "$http_code" == "000" ]]; then
        issues+=("Backend não responde ao HTTP (timeout)")
        ok=false
    fi

    # 4. MySQL rodando?
    if ! sudo systemctl is-active --quiet mysql 2>/dev/null && \
       ! sudo systemctl is-active --quiet mysqld 2>/dev/null; then
        issues+=("Serviço MySQL está INATIVO")
        ok=false
    fi

    # 5. Redis rodando?
    if ! redis-cli ping 2>/dev/null | grep -q PONG; then
        issues+=("Redis não responde (redis-cli ping falhou)")
        ok=false
    fi

    if $ok; then
        echo "OK"
    else
        printf '%s\n' "${issues[@]}"
    fi
}

################################################################################
# Envio de notificação Discord
################################################################################

send_discord_notification() {
    local status="$1"   # "down" ou "recovery"
    local details="$2"  # texto com os problemas
    local webhook="$DISCORD_WEBHOOK"

    if [[ -z "$webhook" ]]; then
        return
    fi

    local color title description
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ "$status" == "down" ]]; then
        color=15158332  # vermelho
        title="🚨 DriversHub OFFLINE — ${VTC_NAME} (${VTC_ABBR})"
        description="**Servidor:** \`${DOMAIN}\`\n\n**Problemas detectados:**\n\`\`\`\n${details}\n\`\`\`\n\n_Verifique com:_ \`sudo journalctl -u drivershub-${VTC_ABBR} -n 30\`"
    else
        color=3066993   # verde
        title="✅ DriversHub RECUPERADO — ${VTC_NAME} (${VTC_ABBR})"
        description="**Servidor:** \`${DOMAIN}\`\n\nO serviço voltou a funcionar normalmente."
    fi

    local payload
    payload=$(python3 -c "
import json
payload = {
    'embeds': [{
        'title':       '${title}',
        'description': '${description}',
        'color':       ${color},
        'footer':      {'text': 'DriversHub Health Check'},
        'timestamp':   '${timestamp}'
    }]
}
print(json.dumps(payload))
" 2>/dev/null)

    if [[ -n "$payload" ]]; then
        curl -s -X POST "$webhook" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 10 &>/dev/null || true
    fi
}

################################################################################
# Ciclo de verificação (modo cron)
################################################################################

run_health_check() {
    local abbr="$1"
    if ! load_vtc "$abbr"; then
        echo "$(date): ERRO: VTC '$abbr' não encontrada" >&2
        exit 1
    fi

    # Estado anterior: "ok" ou "down"
    local prev_state="ok"
    [[ -f "$HC_STATE" ]] && prev_state=$(cat "$HC_STATE")

    local result
    result=$(check_service)

    if [[ "$result" == "OK" ]]; then
        # Serviço está OK
        if [[ "$prev_state" == "down" ]] && [[ "$NOTIFY_RECOVERY" == "true" ]]; then
            # Recuperou — notificar
            echo "$(date): RECOVERY ${VTC_ABBR} voltou a funcionar" >> "${INSTALL_BASE}/health-check.log"
            send_discord_notification "recovery" ""
        fi
        echo "ok" > "$HC_STATE"
        echo "$(date): OK ${VTC_ABBR} todos os serviços funcionando" >> "${INSTALL_BASE}/health-check.log"
    else
        # Serviço com problema
        echo "$(date): DOWN ${VTC_ABBR}: ${result//$'\n'/ | }" >> "${INSTALL_BASE}/health-check.log"

        if [[ "$prev_state" != "down" ]] && [[ "$NOTIFY_DOWN" == "true" ]]; then
            # Primeira detecção — notificar
            send_discord_notification "down" "$result"
        fi
        echo "down" > "$HC_STATE"
    fi

    # Tentar reiniciar automaticamente se estiver down
    if [[ "$result" != "OK" ]]; then
        local service="drivershub-${VTC_ABBR}.service"
        if ! sudo systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "$(date): RESTART tentando reiniciar ${service}" >> "${INSTALL_BASE}/health-check.log"
            sudo systemctl restart "$service" 2>/dev/null || true
        fi
    fi
}

################################################################################
# Configuração interativa
################################################################################

select_vtc_interactive() {
    local -a states=()
    while IFS= read -r -d '' sf; do
        states+=("$sf")
    done < <(find "${INSTALL_BASE}" -maxdepth 1 -name '.installer_state*' -print0 2>/dev/null)

    if [[ ${#states[@]} -eq 0 ]]; then
        print_error "Nenhuma instalação encontrada."
        exit 1
    fi

    if [[ ${#states[@]} -eq 1 ]]; then
        # shellcheck source=/dev/null
        source "${states[0]}"
        VTC_ABBR="$BACKEND_VTC_ABBR"
    else
        echo -e "${MAGENTA}Instalações disponíveis:${NC}"
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
            # shellcheck source=/dev/null
            source "${states[$((choice - 1))]}"
            VTC_ABBR="$BACKEND_VTC_ABBR"
        else
            print_error "Opção inválida."
            exit 1
        fi
    fi

    load_vtc "$VTC_ABBR"
}

configure_healthcheck() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  CONFIGURAR HEALTH CHECK — ${VTC_NAME} (${VTC_ABBR})${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}Para notificações Discord, você precisa de um Webhook URL.${NC}"
    echo "  1. Acesse seu servidor Discord"
    echo "  2. Editar Canal → Integrações → Webhooks → Novo Webhook"
    echo "  3. Copie a URL do Webhook"
    echo ""

    local current_webhook="${DISCORD_WEBHOOK:-}"
    if [[ -n "$current_webhook" ]]; then
        echo -e "  Webhook atual: ${CYAN}${current_webhook:0:50}...${NC}"
    fi

    local new_webhook
    read -r -p "$(echo -e "${CYAN}Discord Webhook URL (Enter para manter): ${NC}")" new_webhook
    [[ -n "$new_webhook" ]] && DISCORD_WEBHOOK="$new_webhook"

    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        print_warning "Sem webhook configurado. Notificações desativadas."
    else
        # Testar webhook
        print_info "Testando webhook..."
        local test_payload='{"content":"✅ **DriversHub Health Check** configurado com sucesso para '"${VTC_NAME}"' ('"${VTC_ABBR}"')!"}'
        if curl -s -X POST "$DISCORD_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "$test_payload" \
                --max-time 10 &>/dev/null; then
            print_success "Webhook testado — mensagem enviada ao Discord!"
        else
            print_warning "Não foi possível enviar mensagem de teste. Verifique a URL."
        fi
    fi

    # Configurar frequência do cron
    echo ""
    echo "  Frequência de verificação:"
    echo "  1) A cada 5 minutos (recomendado)"
    echo "  2) A cada 10 minutos"
    echo "  3) A cada 1 minuto (alto volume de logs)"
    echo "  4) Desativar verificação automática"
    echo ""
    local freq_choice
    read -r -p "$(echo -e "${CYAN}Escolha [1-4]: ${NC}")" freq_choice

    local cron_expr=""
    case "$freq_choice" in
        1) cron_expr="*/5 * * * *" ;;
        2) cron_expr="*/10 * * * *" ;;
        3) cron_expr="* * * * *" ;;
        4)
            # Remover cron existente
            ( crontab -l 2>/dev/null | grep -v "health-check.*${VTC_ABBR}" ) | crontab - 2>/dev/null || true
            print_info "Verificação automática desativada."
            ;;
        *)
            print_error "Opção inválida."
            return
            ;;
    esac

    # Salvar configuração
    cat > "$HC_CONFIG" << EOF
# Health Check config — ${VTC_NAME} (${VTC_ABBR})
# Gerado por health-check.sh
DISCORD_WEBHOOK="${DISCORD_WEBHOOK}"
NOTIFY_DOWN=true
NOTIFY_RECOVERY=true
EOF
    chmod 600 "$HC_CONFIG"

    if [[ -n "$cron_expr" ]]; then
        local this_script
        this_script="$(realpath "$0" 2>/dev/null || echo "${INSTALL_BASE}/health-check.sh")"
        local cron_line="${cron_expr} ${this_script} --run ${VTC_ABBR} >> ${INSTALL_BASE}/health-check.log 2>&1"
        ( crontab -l 2>/dev/null | grep -v "health-check.*${VTC_ABBR}"; \
          echo "$cron_line" ) | crontab -
        print_success "Cron configurado: ${cron_expr}"
        print_info "Comando: ${cron_line}"
    fi

    print_success "Health check configurado para ${VTC_NAME}!"
}

run_now() {
    echo ""
    print_info "Executando verificação agora..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local result
    result=$(check_service)

    if [[ "$result" == "OK" ]]; then
        print_success "Todos os serviços estão funcionando normalmente!"
    else
        echo -e "${RED}Problemas detectados:${NC}"
        echo "$result" | while IFS= read -r line; do
            echo -e "  ${RED}• ${line}${NC}"
        done
        echo ""
        print_warning "Para diagnosticar: sudo journalctl -u drivershub-${VTC_ABBR} -n 30"
    fi
}

show_log() {
    local log_file="${INSTALL_BASE}/health-check.log"
    if [[ -f "$log_file" ]]; then
        echo ""
        echo -e "${CYAN}Últimas 30 entradas do log:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        tail -30 "$log_file"
    else
        print_warning "Nenhum log encontrado ainda."
    fi
}

################################################################################
# Main
################################################################################

# Modo cron: executar diretamente
if [[ "$RUN_MODE" == "true" ]]; then
    run_health_check "${RUN_ABBR:-}"
    exit $?
fi

print_header
select_vtc_interactive

while true; do
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  VTC: ${VTC_NAME} (${VTC_ABBR}) — ${DOMAIN}${NC}"
    local wh_status="${DISCORD_WEBHOOK:+configurado}"
    wh_status="${wh_status:-não configurado}"
    echo -e "${CYAN}║  Webhook: ${wh_status}${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}O que deseja fazer?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Configurar webhook e frequência de verificação"
    echo "  2) Verificar serviços agora"
    echo "  3) Ver log de health checks"
    echo "  4) Sair"
    echo ""
    local choice
    read -r -p "$(echo -e "${CYAN}Escolha [1-4]: ${NC}")" choice

    case "$choice" in
        1) configure_healthcheck ;;
        2) run_now ;;
        3) show_log ;;
        4|q|Q) print_info "Saindo."; exit 0 ;;
        *) print_error "Opção inválida." ;;
    esac
done
