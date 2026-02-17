╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       INSTALADOR AUTOMÁTICO - DRIVERS HUB                     ║
║         Euro Truck Simulator 2 / American Truck Simulator     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

🚀 INÍCIO RÁPIDO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Baixe o script:
   wget https://github.com/KIQ09/drivershub-installer/blob/main/scripts/install-drivershub.sh
   chmod +x install-drivershub.sh

2. Execute:
   ./install-drivershub.sh

3. Siga as instruções na tela


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
   - Domínio (opcional)


💻 REQUISITOS DO SISTEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sistema: Ubuntu 20.04+ ou Debian 11+
CPU: 2 cores
RAM: 2 GB
Disco: 10 GB livres
Acesso: Usuário normal com sudo (NÃO root!)


✨ O QUE O SCRIPT FAZ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Instala todas as dependências (Python, MariaDB, Redis)
✅ Clona e configura o Drivers Hub
✅ Cria banco de dados automaticamente
✅ Gera config.json personalizado
✅ Configura serviço systemd
✅ Instala Nginx (opcional)
✅ Configura SSL (opcional)


🔧 COMANDOS ÚTEIS APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ver status:
  sudo systemctl status drivershub-[SIGLA]

Ver logs:
  sudo journalctl -u drivershub-[SIGLA] -f

Reiniciar:
  sudo systemctl restart drivershub-[SIGLA]

Editar config:
  nano /opt/drivershub/HubBackend/config.json


⚠️  IMPORTANTE APÓS INSTALAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Configure o Redirect URI no Discord Developer Portal:
   http://localhost:7777/[SIGLA]/api/auth/discord/callback
   (ou use seu domínio)

2. Convide o bot Discord para seu servidor

3. Acesse: http://localhost:7777/[SIGLA]

4. Faça login com Discord e configure sua VTC


📚 DOCUMENTAÇÃO COMPLETA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Leia: GUIA_INSTALACAO.md

Contém:
- Preparação detalhada
- Solução de problemas
- Comandos úteis
- Configurações avançadas
- Segurança e backups


🆘 SUPORTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Wiki: https://wiki.charlws.com/books/chub
Discord: https://discord.gg/wNTaaBZ5qd
Site: https://drivershub.charlws.com


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Versão: 1.0.0 | Criado para a comunidade ETS2/ATS 🚚
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
