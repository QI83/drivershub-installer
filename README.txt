╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       INSTALADOR AUTOMÁTICO - DRIVERS HUB                     ║
║         Euro Truck Simulator 2 / American Truck Simulator     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

🚀 INÍCIO RÁPIDO — INSTALAÇÃO COMPLETA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  PASSO 1 — Clonar o projeto
  ─────────────────────────────────────────────────
  git clone https://github.com/QI83/drivershub-installer.git
  cd drivershub-installer

  PASSO 2 — Backend (API, banco de dados, serviços)
  ─────────────────────────────────────────────────
  bash scripts/install-drivershub.sh

  PASSO 3 — Frontend (interface web React)
  ─────────────────────────────────────────────────
  bash scripts/install-frontend.sh

  PASSO 4 — Verificar
  ─────────────────────────────────────────────────
  bash scripts/verificar-instalacao.sh


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
   - Abreviação (sigla, ex: cdmp)
   - Domínio (ex: hub.minhaVTC.com)


💻 REQUISITOS DO SISTEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sistema: Ubuntu 20.04+ ou Debian 11+
CPU: 2 cores
RAM: 2 GB
Disco: 10 GB livres
Acesso: Usuário normal com sudo (NÃO root!)


🛠️  SCRIPTS DISPONÍVEIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install-drivershub.sh    Instala o Backend (detecta instalação existente)
install-frontend.sh      Instala o Frontend React
update-drivershub.sh     Atualiza Backend e/ou Frontend
uninstall-drivershub.sh  Remove o Drivers Hub completamente
verificar-instalacao.sh  Verifica se tudo está funcionando


✨ O QUE OS SCRIPTS FAZEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install-drivershub.sh (Backend):
  ✅ Detecta instalação existente — repara ou reinstala do zero
  ✅ Valida credenciais Discord e Steam antes de instalar
  ✅ Instala Python 3, MySQL, Redis
  ✅ Clona e configura o HubBackend
  ✅ Gera config.json personalizado
  ✅ Configura serviço systemd com restart automático
  ✅ Instala e configura Nginx (opcional)
  ✅ Configura SSL com Let's Encrypt (opcional)
  ✅ Salva estado em /opt/drivershub/.installer_state

install-frontend.sh (Frontend):
  ✅ Verifica e instala Node.js 20+ se necessário
  ✅ Clona o HubFrontend e gera .env.production automático
  ✅ Build de produção (npm run build)
  ✅ Deploy em /var/www/drivershub-frontend/
  ✅ Configura roteamento SPA no Nginx (try_files)
  ✅ Verificação final automática

update-drivershub.sh:
  ✅ Backup automático antes de qualquer alteração
  ✅ git pull em Backend e/ou Frontend
  ✅ Restaura config.json e .env.production após pull
  ✅ Reinstala dependências Python e npm
  ✅ Reinicia serviços automaticamente

uninstall-drivershub.sh:
  ✅ Remove serviço systemd
  ✅ Remove configuração do Nginx
  ✅ Remove banco de dados (confirmação extra obrigatória)
  ✅ Remove arquivos do projeto
  ✅ Cada etapa tem confirmação individual


🔧 COMANDOS ÚTEIS APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backend:
  sudo systemctl status drivershub-[SIGLA]
  sudo journalctl -u drivershub-[SIGLA] -f
  sudo systemctl restart drivershub-[SIGLA]
  nano /opt/drivershub/HubBackend/config.json

Frontend (atualizar manualmente):
  cd /opt/drivershub/HubFrontend
  git pull && npm ci && npm run build
  sudo rsync -a --delete build/ /var/www/drivershub-frontend/
  sudo systemctl reload nginx

Ou simplesmente:
  bash scripts/update-drivershub.sh


⚠️  IMPORTANTE APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Configure o Redirect URI no Discord Developer Portal:
   https://[SEU_DOMINIO]/[SIGLA]/api/auth/discord/callback

2. Convide o bot Discord:
   OAuth2 > URL Generator > scopes: bot + applications.commands
   Permissões: Administrator

3. Acesse: https://[SEU_DOMINIO]/

4. Faça login com Discord e configure sua VTC


📚 DOCUMENTAÇÃO COMPLETA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Leia: docs/GUIA_INSTALACAO.md
      docs/TROUBLESHOOTING.md

Wiki oficial: https://wiki.charlws.com/books/chub


🆘 SUPORTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Wiki:    https://wiki.charlws.com/books/chub
Discord: https://discord.gg/wNTaaBZ5qd
Site:    https://drivershub.charlws.com


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Versão: 1.2.0 | Criado para a comunidade ETS2/ATS 🚚
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
