#!/bin/bash

################################################################################
# Script de Verificação Pós-Instalação - Drivers Hub
# Execute após instalar para verificar se tudo está funcionando
################################################################################

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

print_header() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║         VERIFICAÇÃO PÓS-INSTALAÇÃO - DRIVERS HUB              ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

check_item() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Verificando $test_name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_warning() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Verificando $test_name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  AVISO${NC}"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

# Pedir sigla da VTC
echo -e "${CYAN}Digite a abreviação/sigla da sua VTC (ex: cdmp):${NC}"
read -r -p "> " VTC_ABBR

if [ -z "$VTC_ABBR" ]; then
    echo -e "${RED}Sigla não pode ser vazia!${NC}"
    exit 1
fi

print_header

echo -e "${BLUE}[1/8] Sistema Operacional${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_item "Sistema Ubuntu/Debian" "command -v apt"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "Sistema: ${GREEN}$PRETTY_NAME${NC}"
fi
echo ""

echo -e "${BLUE}[2/8] Dependências do Sistema${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_item "Python 3" "python3 --version"
check_item "Pip" "pip3 --version"
check_item "Git" "git --version"
echo ""

echo -e "${BLUE}[3/8] Banco de Dados${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_item "MySQL instalado" "command -v mysql"
check_item "MySQL rodando" "systemctl is-active mysql"

if systemctl is-active mysql &>/dev/null; then
    DB_PASS=$(python3 -c "import json; d=json.load(open('/opt/drivershub/HubBackend/config.json')); print(d.get('db_password',''))" 2>/dev/null || echo "")
    if mysql -u "${VTC_ABBR}_user" -p"${DB_PASS}" -e "USE ${VTC_ABBR}_db;" 2>/dev/null; then
        echo -e "Banco de dados: ${GREEN}✅ Acessível${NC}"
    else
        echo -e "Banco de dados: ${RED}❌ Erro de acesso${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

echo -e "${BLUE}[4/8] Redis${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_item "Redis instalado" "command -v redis-cli"
check_item "Redis rodando" "systemctl is-active redis-server"

if systemctl is-active redis-server &>/dev/null; then
    if redis-cli ping | grep -q PONG; then
        echo -e "Redis: ${GREEN}✅ Respondendo${NC}"
    else
        echo -e "Redis: ${RED}❌ Não responde${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

echo -e "${BLUE}[5/8] Instalação do Drivers Hub${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_item "Diretório do projeto" "[ -d /opt/drivershub/HubBackend ]"
check_item "Ambiente virtual Python" "[ -d /opt/drivershub/HubBackend/venv ]"
check_item "Arquivo config.json" "[ -f /opt/drivershub/HubBackend/config.json ]"

if [ -f /opt/drivershub/HubBackend/config.json ]; then
    if python3 -m json.tool /opt/drivershub/HubBackend/config.json >/dev/null 2>&1; then
        echo -e "config.json: ${GREEN}✅ Válido${NC}"
    else
        echo -e "config.json: ${RED}❌ JSON inválido${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

echo -e "${BLUE}[6/8] Serviço Systemd${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SERVICE_NAME="drivershub-${VTC_ABBR}.service"
check_item "Serviço existe" "systemctl list-unit-files | grep -q $SERVICE_NAME"
check_item "Serviço habilitado" "systemctl is-enabled $SERVICE_NAME"
check_item "Serviço rodando" "systemctl is-active $SERVICE_NAME"

if systemctl is-active $SERVICE_NAME &>/dev/null; then
    echo -e "Status: ${GREEN}✅ Ativo${NC}"
else
    echo -e "Status: ${RED}❌ Inativo${NC}"
    echo -e "${YELLOW}Últimas linhas do log:${NC}"
    sudo journalctl -u $SERVICE_NAME -n 5 --no-pager
fi
echo ""

echo -e "${BLUE}[7/8] Conectividade de Rede${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Ler porta do config
if [ -f /opt/drivershub/HubBackend/config.json ]; then
    PORT=$(python3 -c "import json; d=json.load(open('/opt/drivershub/HubBackend/config.json')); print(d.get('server_port', 7777))" 2>/dev/null || echo "7777")
    echo "Porta configurada: $PORT"
    
    if check_item "Porta $PORT escutando" "ss -tuln | grep -q :$PORT"; then
        if curl -s http://localhost:$PORT/$VTC_ABBR >/dev/null 2>&1; then
            echo -e "Aplicação: ${GREEN}✅ Respondendo${NC}"
        else
            echo -e "Aplicação: ${YELLOW}⚠️  Porta aberta mas não responde${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
fi
echo ""

echo -e "${BLUE}[8/8] Configurações Opcionais${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_warning "Nginx instalado" "command -v nginx"
if command -v nginx &>/dev/null; then
    check_warning "Nginx rodando" "systemctl is-active nginx"
fi

if command -v certbot &>/dev/null; then
    echo -e "Certbot (SSL): ${GREEN}✅ Instalado${NC}"
else
    echo -e "Certbot (SSL): ${YELLOW}⚠️  Não instalado${NC}"
fi
echo ""

# Resumo final
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    RESUMO DA VERIFICAÇÃO${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ TUDO OK! Nenhum erro ou aviso encontrado.${NC}"
    echo -e "\n${CYAN}Sua instalação está perfeita!${NC}"
    echo -e "\nAcesse: ${BLUE}http://localhost:$PORT/$VTC_ABBR${NC}\n"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS aviso(s) encontrado(s), mas nada crítico.${NC}"
    echo -e "\n${CYAN}Sua instalação está funcional!${NC}"
    echo -e "\nAcesse: ${BLUE}http://localhost:$PORT/$VTC_ABBR${NC}\n"
else
    echo -e "${RED}❌ $ERRORS erro(s) encontrado(s)!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS aviso(s) encontrado(s).${NC}"
    fi
    echo -e "\n${YELLOW}Ações recomendadas:${NC}"
    echo "1. Verifique os logs: sudo journalctl -u $SERVICE_NAME -n 50"
    echo "2. Verifique o config: nano /opt/drivershub/HubBackend/config.json"
    echo "3. Consulte o guia: GUIA_INSTALACAO.md"
    echo ""
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

exit $ERRORS
