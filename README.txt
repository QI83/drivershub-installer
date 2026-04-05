╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       INSTALADOR AUTOMÁTICO - DRIVERS HUB                     ║
║         Euro Truck Simulator 2 / American Truck Simulator     ║
║                          v1.3.0                               ║
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
  (escolha um dos 3 cenários de implantação)

  PASSO 3 — Frontend (interface web React)
  ─────────────────────────────────────────────────
  bash scripts/install-frontend.sh

  PASSO 4 — Verificar
  ─────────────────────────────────────────────────
  bash scripts/verificar-instalacao.sh


🌐 CENÁRIOS DE IMPLANTAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  O instalador pergunta qual cenário você quer usar:

  CENÁRIO 1 — VPS/Cloud + Domínio Próprio + SSL
  ─────────────────────────────────────────────────────────────
  ✅ Você tem um servidor VPS (DigitalOcean, Vultr, Contabo...)
  ✅ Você tem um domínio registrado (ex: minha-vtc.com.br)
  ✅ SSL/HTTPS automático via Let's Encrypt
  💡 Ideal para produção com domínio personalizado

  CENÁRIO 2 — VPS/Cloud + DuckDNS (domínio gratuito) + SSL
  ─────────────────────────────────────────────────────────────
  ✅ Você tem um servidor VPS, mas SEM domínio registrado
  ✅ Cria subdomínio GRÁTIS em duckdns.org (ex: minha-vtc.duckdns.org)
  ✅ SSL/HTTPS automático via Let's Encrypt
  ✅ Atualização automática de IP a cada 5 minutos
  💡 Ideal para começar sem gastar com domínio

  CENÁRIO 3 — Servidor Local + Cloudflare Tunnel
  ─────────────────────────────────────────────────────────────
  ✅ Computador/servidor em casa ou escritório
  ✅ Sem IP fixo? Sem problema!
  ✅ HTTPS automático via Cloudflare Tunnel (gratuito)
  ✅ Não precisa abrir portas no roteador
  💡 Substitui a antiga opção "localhost" — resolve SSL do Discord OAuth


📋 ANTES DE COMEÇAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tenha em mãos:

✅ Discord Developer Portal (https://discord.com/developers/applications)
   - Client ID
   - Client Secret
   - Bot Token
   - Server (Guild) ID

✅ Steam API Key (https://steamcommunity.com/dev/apikey)

✅ Informações da sua VTC
   - Nome completo (ex: CDMP Express)
   - Abreviação (ex: cdmp)

✅ Para Cenário 2 — DuckDNS
   - Conta em duckdns.org com subdomínio criado
   - Token da conta DuckDNS

✅ Para Cenário 3 — Cloudflare Tunnel
   - Conta Cloudflare em one.dash.cloudflare.com
   - Tunnel criado com hostname e token copiado


💻 REQUISITOS DO SISTEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sistema: Ubuntu 20.04+ ou Debian 11+
CPU: 2 cores
RAM: 1.5 GB (verificado automaticamente)
Disco: 5 GB livres (verificado automaticamente)
Rede: Acesso à internet verificado automaticamente
Portas: 80 e 443 verificadas automaticamente
Acesso: Usuário normal com sudo (NÃO root!)


🛠️  SCRIPTS DISPONÍVEIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install-drivershub.sh    Instala o Backend (multi-VTC, 3 cenários)
install-frontend.sh      Instala o Frontend React
reconfigure-drivershub.sh Reconfigurar após instalação (domínio, Discord, porta...)
update-drivershub.sh     Atualiza Backend e/ou Frontend
backup-drivershub.sh     Backup manual/automático do banco de dados
health-check.sh          Monitoramento com notificação Discord webhook
verificar-instalacao.sh  Verifica todos os componentes (v2.0)
uninstall-drivershub.sh  Remove o Drivers Hub completamente


✨ O QUE O INSTALADOR FAZ (install-drivershub.sh)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Verifica recursos: RAM, disco, internet, portas 80/443
  ✅ Exibe menu dos 3 cenários de implantação com explicações
  ✅ Detecta instalações existentes (multi-VTC)
  ✅ Configura DuckDNS automaticamente (Cenário 2)
  ✅ Valida credenciais Discord e Steam com revalidação se necessário
     (usa endpoint oauth2/token — mais confiável)
  ✅ Instala Python 3, MySQL 8, Redis
  ✅ Clona em /opt/drivershub/{sigla}/HubBackend (por VTC)
  ✅ Gera config.json personalizado com protocolos corretos
  ✅ Configura serviço systemd drivershub-{sigla} com restart automático
  ✅ Configura Nginx com roteamento API + frontend
  ✅ Configura SSL com Let's Encrypt (Cenários 1 e 2)
  ✅ Configura Cloudflare Tunnel via cloudflared (Cenário 3)
  ✅ Configura firewall ufw (HTTP, HTTPS, porta da API)
  ✅ Configura backup automático diário às 3h
  ✅ Salva estado em /opt/drivershub/.installer_state_{sigla}


🔧 COMANDOS ÚTEIS APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backend (substitua [SIGLA] pela sigla da sua VTC):
  sudo systemctl status  drivershub-[SIGLA]
  sudo journalctl -u     drivershub-[SIGLA] -f
  sudo systemctl restart drivershub-[SIGLA]
  nano /opt/drivershub/[SIGLA]/HubBackend/config.json

Reconfigurar após instalação:
  bash scripts/reconfigure-drivershub.sh

Backup do banco de dados:
  bash scripts/backup-drivershub.sh           ← menu interativo
  bash /opt/drivershub/backup-[SIGLA].sh      ← backup imediato

Health check manual:
  bash scripts/health-check.sh                ← configurar webhook
  bash scripts/health-check.sh --run [SIGLA]  ← verificar agora

Frontend (atualizar):
  bash scripts/update-drivershub.sh

Verificar tudo:
  bash scripts/verificar-instalacao.sh


⚠️  IMPORTANTE APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Configure o Redirect URI no Discord Developer Portal:
   OAuth2 → Redirects → Adicionar EXATAMENTE:

   https://[SEU_DOMINIO]/auth/discord/callback

   ⚠️  SEM o prefixo da VTC, SEM /api/ — é uma rota do frontend!

2. Convide o bot Discord:
   OAuth2 > URL Generator > scopes: bot + applications.commands
   Permissões: Administrator

3. Acesse:
   Cenários 1 e 2:     https://[SEU_DOMINIO]/
   Cenário 3 (Tunnel): https://[HOSTNAME_CLOUDFLARE]/

4. Faça login com Discord e configure sua VTC


📁 ESTRUTURA DE ARQUIVOS (Multi-VTC)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/opt/drivershub/
├── [sigla1]/HubBackend/         ← Backend da VTC 1
│   ├── config.json              ← Configuração (chmod 600)
│   ├── src/                     ← Código fonte
│   └── venv/                    ← Ambiente Python
├── [sigla2]/HubBackend/         ← Backend da VTC 2 (se houver)
├── .installer_state_[sigla1]    ← Estado da instalação VTC 1
├── .installer_state_[sigla2]    ← Estado da instalação VTC 2
├── backups/[sigla1]/            ← Backups da VTC 1
├── backups/[sigla2]/            ← Backups da VTC 2
├── backup-[sigla1].sh           ← Script de backup VTC 1
├── duckdns-update.sh            ← Atualização DuckDNS (Cenário 2)
└── health-check.log             ← Log do health check


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
Bugs:    https://github.com/QI83/drivershub-installer/issues


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Versão: 1.3.0 | Abril 2026 | Criado para a comunidade ETS2/ATS 🚚
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
