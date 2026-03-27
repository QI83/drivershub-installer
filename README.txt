╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       INSTALADOR AUTOMÁTICO - DRIVERS HUB                     ║
║         Euro Truck Simulator 2 / American Truck Simulator     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

🚀 INÍCIO RÁPIDO — INSTALAÇÃO COMPLETA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A instalação é feita em duas etapas:

  PASSO 1 — Backend (API, banco de dados, serviços)
  ─────────────────────────────────────────────────
  git clone https://github.com/QI83/drivershub-installer.git
  cd drivershub-installer
  bash scripts/install-drivershub.sh

  PASSO 2 — Frontend (interface web React)
  ─────────────────────────────────────────────────
  bash scripts/install-frontend.sh

  Siga as instruções na tela de cada script.


📋 ANTES DE COMEÇAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tenha em mãos:

✅ Discord Developer Portal (https://discord.com/developers/applications)
   - Client ID
   - Client Secret
   - Bot Token
   - Server ID

✅ Steam API Key (https://steamcommunity.com/dev/apikey)

✅ Informações da sua VTC
   - Nome completo
   - Abreviação (sigla)
   - Domínio (ex: hub.minhaVTC.com)


💻 REQUISITOS DO SISTEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sistema: Ubuntu 20.04+ ou Debian 11+
CPU: 2 cores
RAM: 2 GB
Disco: 10 GB livres
Acesso: Usuário normal com sudo (NÃO root!)


✨ O QUE OS SCRIPTS FAZEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install-drivershub.sh (Backend):
  ✅ Instala Python, MySQL, Redis
  ✅ Clona e configura o HubBackend
  ✅ Cria banco de dados automaticamente
  ✅ Gera config.json personalizado
  ✅ Configura serviço systemd
  ✅ Instala e configura Nginx (opcional)
  ✅ Configura SSL com Let's Encrypt (opcional)
  ✅ Salva estado para o instalador do frontend

install-frontend.sh (Frontend):
  ✅ Verifica e instala Node.js 20+
  ✅ Clona o HubFrontend
  ✅ Gera .env.production com URL do backend
  ✅ Compila o build de produção (npm run build)
  ✅ Faz deploy dos arquivos estáticos no Nginx
  ✅ Configura roteamento SPA (React Router)
  ✅ Verifica a instalação automaticamente


🔧 COMANDOS ÚTEIS APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backend:
  sudo systemctl status drivershub-[SIGLA]
  sudo journalctl -u drivershub-[SIGLA] -f
  sudo systemctl restart drivershub-[SIGLA]
  nano /opt/drivershub/HubBackend/config.json

Frontend (atualizar):
  cd /opt/drivershub/HubFrontend
  git pull && npm ci && npm run build
  sudo rsync -a --delete build/ /var/www/drivershub-frontend/
  sudo systemctl reload nginx

Verificar instalação:
  bash scripts/verificar-instalacao.sh


⚠️  IMPORTANTE APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Configure o Redirect URI no Discord Developer Portal:
   https://[SEU_DOMINIO]/[SIGLA]/api/auth/discord/callback

2. Convide o bot Discord para seu servidor

3. Acesse: https://[SEU_DOMINIO]/

4. Faça login com Discord e configure sua VTC


📚 DOCUMENTAÇÃO COMPLETA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Leia: docs/GUIA_INSTALACAO.md
      docs/TROUBLESHOOTING.md

Wiki oficial: https://wiki.charlws.com/books/chub


🆘 SUPORTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Wiki: https://wiki.charlws.com/books/chub
Discord: https://discord.gg/wNTaaBZ5qd
Site: https://drivershub.charlws.com


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Versão: 1.1.0 | Criado para a comunidade ETS2/ATS 🚚
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
