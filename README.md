# 🚚 Drivers Hub — Instalador Automático

[![Versão](https://img.shields.io/badge/versão-1.2.1-blue.svg)](https://github.com/QI83/drivershub-installer/releases)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-lightgrey.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen.svg)](https://www.shellcheck.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> **Instalação automatizada completa do Drivers Hub — Backend + Frontend — para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.**

[🚀 Início Rápido](#-início-rápido) • [✨ O Que Instala](#-o-que-instala) • [🛠️ Scripts](#️-scripts-disponíveis) • [📖 Documentação](#-documentação) • [🆘 Suporte](#-suporte)

---

## 📸 Preview

```
╔═══════════════════════════════════════════════════════════════╗
║          INSTALADOR AUTOMÁTICO - DRIVERS HUB                  ║
║              Euro Truck Simulator 2 / ATS                     ║
║ Versão: 1.2.0                                                 ║
╚═══════════════════════════════════════════════════════════════╝

⚠️  INSTALAÇÃO EXISTENTE DETECTADA!

  VTC:          CDMP Express (cdmp)
  Backend:      /opt/drivershub/HubBackend
  Instalado em: 2026-03-15T14:32:00Z
  Serviço:      ✅ Rodando

O que deseja fazer?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Reparar instalação   — corrige dependências sem apagar dados
  2) Nova instalação      — APAGA tudo e instala do zero
  3) Cancelar
```

---

## ✨ O Que Instala

### 🔧 Etapa 1 — Backend (`install-drivershub.sh`)

| Componente | Descrição |
|---|---|
| **Python 3 + venv** | Ambiente virtual isolado com todas as dependências |
| **MySQL Server** | Banco de dados com usuário e schema configurados |
| **Redis** | Cache e gerenciamento de sessões |
| **HubBackend** | Clone e configuração do repositório oficial |
| **config.json** | Arquivo de configuração personalizado completo |
| **Systemd Service** | Serviço com restart automático em caso de falha |
| **Nginx** | Proxy reverso com roteamento separado API / frontend *(opcional)* |
| **SSL/HTTPS** | Certificado Let's Encrypt via Certbot *(opcional)* |

### 🎨 Etapa 2 — Frontend (`install-frontend.sh`)

| Componente | Descrição |
|---|---|
| **Node.js 20+** | Instalado automaticamente via NodeSource se necessário |
| **HubFrontend** | Clone e build de produção do repositório oficial |
| **.env.production** | Configuração com `VITE_CONFIG_URL` gerada automaticamente |
| **Build estático** | Compilação React + Vite otimizada para produção |
| **Deploy Nginx** | Arquivos servidos em `/var/www/drivershub-frontend/` |
| **Roteamento SPA** | `try_files` configurado para suporte ao React Router |

---

## 🚀 Início Rápido

### Pré-requisitos

| Requisito | Mínimo |
|---|---|
| Sistema | Ubuntu 20.04+ ou Debian 11+ |
| CPU | 2 cores |
| RAM | 2 GB |
| Disco | 10 GB livres |
| Acesso | Usuário normal com `sudo` — **NÃO root!** |

Antes de começar, tenha em mãos:
- 🎮 **Discord**: Client ID, Client Secret, Bot Token, Server ID → [discord.com/developers/applications](https://discord.com/developers/applications)
- 🎮 **Steam API Key** → [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)
- 📋 **Dados da VTC**: nome, sigla (ex: `cdmp`), domínio

### Instalação passo a passo

```bash
# 1. Clonar o projeto
git clone https://github.com/QI83/drivershub-installer.git
cd drivershub-installer

# 2. Instalar o Backend (Python, MySQL, Redis, serviço)
bash scripts/install-drivershub.sh

# 3. Instalar o Frontend (Node.js, build React, Nginx)
bash scripts/install-frontend.sh

# 4. Verificar se tudo está funcionando
bash scripts/verificar-instalacao.sh
```

> ⏱️ Tempo total estimado: **10–25 minutos**

---

## 🛠️ Scripts Disponíveis

| Script | Finalidade |
|---|---|
| `install-drivershub.sh` | **Instalar** o Backend |
| `install-frontend.sh` | **Instalar** o Frontend |
| `update-drivershub.sh` | **Atualizar** Backend e/ou Frontend |
| `uninstall-drivershub.sh` | **Desinstalar** completamente |
| `verificar-instalacao.sh` | **Verificar** todos os componentes |

### Atualizar

```bash
bash scripts/update-drivershub.sh
```

Faz backup automático do `config.json` antes de qualquer alteração, executa `git pull` nos repositórios e reinstala dependências. Você escolhe o que atualizar.

### Desinstalar

```bash
bash scripts/uninstall-drivershub.sh
```

Remove cada componente (serviço, Nginx, banco, arquivos) com confirmação individual. O banco de dados exige confirmação extra por ser irreversível.

### Modo reparo

Se algo quebrar, rode novamente o instalador do backend:

```bash
bash scripts/install-drivershub.sh
# → Selecione: 1) Reparar instalação
```

O modo reparo corrige dependências, reinicia serviços e reaplicar patches sem tocar no `config.json` nem nos dados.

---

## 📖 Documentação

| Documento | Descrição |
|---|---|
| 📖 [GUIA_INSTALACAO.md](docs/GUIA_INSTALACAO.md) | Guia detalhado passo a passo com exemplos |
| 🔧 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Soluções rápidas para os problemas mais comuns |
| 📋 [README.txt](README.txt) | Referência rápida em texto puro |
| 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) | Como contribuir com o projeto |

---

## 🔧 Pós-Instalação

### 1. Discord Redirect URI

No [Discord Developer Portal](https://discord.com/developers/applications) → **OAuth2 → Redirects**:

```
https://seudominio.com/[SIGLA]/api/auth/discord/callback
```

### 2. Convidar o Bot

**OAuth2 → URL Generator** → escopos `bot` + `applications.commands` → permissão `Administrator`

### 3. Acessar

| Configuração | URL |
|---|---|
| Com domínio + SSL | `https://seudominio.com/` |
| Com domínio sem SSL | `http://seudominio.com/` |
| Sem Nginx | `http://localhost:7777/[sigla]` |

---

## 📋 Comandos Úteis

```bash
# Backend — gerenciamento do serviço
sudo systemctl status  drivershub-[SIGLA]
sudo journalctl -u     drivershub-[SIGLA] -f
sudo systemctl restart drivershub-[SIGLA]

# Banco de dados
mysql -u [SIGLA]_user -p [SIGLA]_db
mysqldump -u [SIGLA]_user -p [SIGLA]_db > backup_$(date +%Y%m%d).sql

# Nginx
sudo nginx -t && sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 🏗️ Arquitetura

```
                     Internet
                         │
                    [Nginx :80/443]
                    /             \
           location /          location /[sigla]/
                │                      │
   ┌────────────┴───────────┐  ┌───────┴────────────┐
   │  Frontend (estático)   │  │  Backend (FastAPI)  │
   │  /var/www/dh-frontend  │  │  localhost:7777     │
   │  React SPA + Vite      │  │  Python + venv      │
   └────────────────────────┘  └─────────┬───────────┘
                                         │
                              ┌──────────┴──────────┐
                              │                     │
                           [MySQL]              [Redis]
                       banco de dados         cache / sessão
```

---

## 📝 Changelog

### [1.2.1] — Março 2026
- 🐛 **Bug crítico**: `"external_plugins": []` no `config.json` gerado causava tela "inoperância temporária" — corrigido para `["client-config"]`
- 🐛 **Bug crítico**: `python3 -m venv` travava aguardando input no Passo 7 — corrigido com `< /dev/null`
- 🐛 MySQL 8+: `default_authentication_plugin` definido globalmente para cobrir conexões diretas via `pymysql`
- ✨ Validação de credenciais agora **revalida** após o usuário corrigir token ou API Key
- ✨ Pergunta sobre Frontend adicionada ao fluxo do instalador — Nginx é configurado automaticamente se frontend for selecionado
- ✨ `"db_port": 3306` adicionado ao `config.json` (campo exigido na versão atual do HubBackend)

### [1.2.0] — Março 2026
- ✨ `update-drivershub.sh` — atualiza Backend e/ou Frontend com backup automático
- ✨ `uninstall-drivershub.sh` — desinstalação completa com confirmação por etapa
- ✨ Detecção de instalação existente com menu de reparo / reinstalar / cancelar
- ✨ Modo reparo preserva `config.json` e recarrega dados automaticamente
- ✨ Validação de credenciais Discord e Steam antes de instalar

### [1.1.0] — Março 2026
- ✨ `install-frontend.sh` — instalador completo do HubFrontend
- ✨ State file `/opt/drivershub/.installer_state` para comunicação entre scripts
- ✨ Nginx separado: `/[sigla]/` → API, `/` → frontend
- 🐛 Bug crítico: `set -o pipefail` + `grep -v` causava abort silencioso
- 🐛 Bug crítico: `{domain}` literal no `config.json`
- 🔄 MariaDB substituído por MySQL

### [1.0.0] — Fevereiro 2026
- ✨ Script de instalação automatizado do Backend
- ✨ Documentação completa e script de verificação

---

## 🔒 Segurança

Use senhas fortes, configure firewall (`ufw allow 80,443/tcp`), SSL em produção e backups regulares.
Vulnerabilidades: **não abra issue pública** — envie e-mail para **kiq.reis09@gmail.com**

---

## 🆘 Suporte

- 📖 **Wiki**: https://wiki.charlws.com/books/chub
- 💬 **Discord**: https://discord.gg/wNTaaBZ5qd
- 🌐 **Site**: https://drivershub.charlws.com
- 🐛 **Bugs**: [Abra uma issue](https://github.com/QI83/drivershub-installer/issues/new)

---

## 📊 Estatísticas

![GitHub repo size](https://img.shields.io/github/repo-size/QI83/drivershub-installer)
![GitHub issues](https://img.shields.io/github/issues/QI83/drivershub-installer)
![GitHub last commit](https://img.shields.io/github/last-commit/QI83/drivershub-installer)

---

## 👥 Autores

**Caique Reis** — [@QI83](https://github.com/QI83) · Agradecimentos: [CharlesWithC](https://github.com/CharlesWithC) e à comunidade ETS2/ATS.

## 📄 Licença

MIT — veja [LICENSE](LICENSE). HubBackend e HubFrontend: AGPL-3.0 © 2022–2026 CharlesWithC.

---

<div align="center">

**Feito com ❤️ para a comunidade de transportadoras virtuais ETS2/ATS**

[⬆ Voltar ao topo](#-drivers-hub--instalador-automático) · ⭐ Deixe uma estrela se ajudou!

</div>
