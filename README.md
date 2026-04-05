# 🚚 Drivers Hub — Instalador Automático

[![Versão](https://img.shields.io/badge/versão-1.3.0-blue.svg)](https://github.com/QI83/drivershub-installer/releases)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-lightgrey.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen.svg)](https://www.shellcheck.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> **Instalação automatizada completa do Drivers Hub — Backend + Frontend — para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.**

[🚀 Início Rápido](#-início-rápido) • [🌐 Cenários](#-cenários-de-implantação) • [✨ O Que Instala](#-o-que-instala) • [🛠️ Scripts](#️-scripts-disponíveis) • [📖 Documentação](#-documentação) • [🆘 Suporte](#-suporte)

---

## 📸 Preview

```
╔═══════════════════════════════════════════════════════════════╗
║          INSTALADOR AUTOMÁTICO - DRIVERS HUB                  ║
║              Euro Truck Simulator 2 / ATS                     ║
║ Versão: 1.3.0                                                 ║
╚═══════════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════╗
║  CENÁRIO 1 — VPS/Cloud + Domínio Próprio + SSL               ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ Servidor VPS (DigitalOcean, Vultr, Contabo, AWS…)         ║
║  ✅ Domínio já registrado (ex: minha-vtc.com.br)              ║
║  ✅ SSL/HTTPS automático via Let's Encrypt                    ║
╚═══════════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════╗
║  CENÁRIO 2 — VPS/Cloud + DuckDNS (domínio gratuito) + SSL    ║
╚═══════════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════╗
║  CENÁRIO 3 — Servidor Local + Cloudflare Tunnel               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 🌐 Cenários de Implantação

O instalador oferece **3 cenários 100% gratuitos e automatizados**. Escolha o que melhor se encaixa na sua situação:

| # | Cenário | Para quem é? | SSL |
|---|---------|-------------|-----|
| **1** | **VPS + Domínio próprio** | Tem servidor VPS e domínio registrado | Let's Encrypt automático |
| **2** | **VPS + DuckDNS** | Tem VPS mas sem domínio — cria grátis em duckdns.org | Let's Encrypt automático |
| **3** | **Local + Cloudflare Tunnel** | Computador em casa, sem IP fixo, sem abrir portas | Cloudflare (automático) |

> 💡 O **Cenário 3** substitui completamente a antiga opção "localhost" — resolve o problema de SSL exigido pelo Discord OAuth.

---

## ✨ O Que Instala

### 🔧 Etapa 1 — Backend (`install-drivershub.sh`)

| Componente | Descrição |
|---|---|
| **Python 3 + venv** | Ambiente virtual isolado com todas as dependências |
| **MySQL Server** | Banco de dados com usuário e schema por VTC |
| **Redis** | Cache e gerenciamento de sessões |
| **HubBackend** | Clone em `/opt/drivershub/{sigla}/HubBackend` por VTC |
| **config.json** | Arquivo de configuração personalizado completo |
| **Systemd Service** | Serviço `drivershub-{sigla}` com restart automático |
| **Nginx** | Proxy reverso com roteamento separado API / frontend |
| **SSL/HTTPS** | Let's Encrypt via Certbot (Cenários 1 e 2) |
| **DuckDNS** | Subdomínio gratuito com atualização de IP automática (Cenário 2) |
| **Cloudflare Tunnel** | Exposição HTTPS via `cloudflared` (Cenário 3) |
| **Firewall (ufw)** | Regras para portas 80, 443 e API configuradas automaticamente |
| **Backup automático** | Cron diário às 3h — retenção de 7 dias |

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
| RAM | 1.5 GB (verificado automaticamente) |
| Disco | 5 GB livres (verificado automaticamente) |
| Acesso | Usuário normal com `sudo` — **NÃO root!** |

> O instalador verifica RAM, disco, acesso à internet e disponibilidade das portas 80/443 **antes de instalar**.

Antes de começar, tenha em mãos:
- 🎮 **Discord**: Client ID, Client Secret, Bot Token, Server ID → [discord.com/developers/applications](https://discord.com/developers/applications)
- 🎮 **Steam API Key** → [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)
- 📋 **Dados da VTC**: nome, sigla (ex: `cdmp`)
- 🌐 **Cenário 2**: conta no [duckdns.org](https://www.duckdns.org) com subdomínio criado
- ☁️ **Cenário 3**: conta no [Cloudflare](https://one.dash.cloudflare.com) com tunnel criado

### Instalação passo a passo

```bash
# 1. Clonar o projeto
git clone https://github.com/QI83/drivershub-installer.git
cd drivershub-installer

# 2. Instalar o Backend (Python, MySQL, Redis, serviço, firewall, backup)
bash scripts/install-drivershub.sh

# 3. Instalar o Frontend (Node.js, build React, Nginx)
bash scripts/install-frontend.sh

# 4. Verificar se tudo está funcionando
bash scripts/verificar-instalacao.sh
```

> ⏱️ Tempo total estimado: **15–30 minutos**

---

## 🛠️ Scripts Disponíveis

| Script | Finalidade |
|---|---|
| `install-drivershub.sh` | **Instalar** o Backend (detecta VTCs existentes, multi-VTC) |
| `install-frontend.sh` | **Instalar** o Frontend |
| `reconfigure-drivershub.sh` | **Reconfigurar** domínio, credenciais, porta, SSL ou Tunnel |
| `update-drivershub.sh` | **Atualizar** Backend e/ou Frontend |
| `backup-drivershub.sh` | **Backup** manual/automático do banco de dados |
| `health-check.sh` | **Monitorar** serviços com notificação Discord |
| `verificar-instalacao.sh` | **Verificar** todos os componentes da instalação |
| `uninstall-drivershub.sh` | **Desinstalar** completamente |

### Reconfigurar após a instalação

Para alterar domínio, credenciais Discord/Steam, porta, SSL ou Cloudflare Tunnel **sem reinstalar**:

```bash
bash scripts/reconfigure-drivershub.sh
```

O script detecta VTCs instaladas automaticamente e exibe um menu com 7 opções. Após cada alteração atualiza o `config.json`, o Nginx, o `api_host` no banco e reinicia o serviço.

> 📖 Veja o **[Guia completo do reconfigure](docs/GUIA_RECONFIGURE.md)** para exemplos de cada opção.

### Backup do banco de dados

```bash
# Menu interativo (criar backup, listar, restaurar, configurar cron)
bash scripts/backup-drivershub.sh

# Backup automático já configurado pelo instalador:
# /opt/drivershub/backup-{sigla}.sh → cron diário às 3h
# Backups em: /opt/drivershub/backups/{sigla}/
```

### Health Check com notificação Discord

Monitoramento automático que verifica 5 componentes (serviço, porta, HTTP, MySQL, Redis) e envia alertas via Discord webhook quando algo para ou se recupera.

```bash
# Configurar webhook e frequência de monitoramento
bash scripts/health-check.sh

# Verificação manual imediata
bash scripts/health-check.sh --run {sigla}
```

> 📖 Veja o **[Guia completo do health-check](docs/GUIA_HEALTH_CHECK.md)** para detalhes de configuração, notificações e multi-VTC.

### Atualizar

```bash
bash scripts/update-drivershub.sh
```

### Desinstalar

```bash
bash scripts/uninstall-drivershub.sh
```

### Modo reparo

```bash
bash scripts/install-drivershub.sh
# → Selecione: r) Reparar instalação
```

---

## 📖 Documentação

| Documento | Descrição |
|---|---|
| 📖 [GUIA_INSTALACAO.md](docs/GUIA_INSTALACAO.md) | Guia completo de instalação com os 3 cenários |
| 🔁 [GUIA_RECONFIGURE.md](docs/GUIA_RECONFIGURE.md) | Como reconfigurar domínio, credenciais, SSL e Tunnel |
| 🏥 [GUIA_HEALTH_CHECK.md](docs/GUIA_HEALTH_CHECK.md) | Monitoramento automático com notificações Discord |
| 🔧 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Soluções rápidas para os problemas mais comuns |
| 📋 [README.txt](README.txt) | Referência rápida em texto puro |
| 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) | Como contribuir com o projeto |

---

## 🔧 Pós-Instalação

### 1. Discord Redirect URI

No [Discord Developer Portal](https://discord.com/developers/applications) → **OAuth2 → Redirects**, adicione **exatamente**:

```
https://seudominio.com/auth/discord/callback
```

> ⚠️ O frontend usa `https://` fixo e o path `/auth/discord/callback` — **sem o prefixo da VTC e sem `/api/`**. Registrar a URL errada resulta em "redirect_uri inválido".

### 2. Convidar o Bot

**OAuth2 → URL Generator** → escopos `bot` + `applications.commands` → permissão `Administrator`

### 3. Acessar

| Cenário | URL |
|---|---|
| Cenário 1 ou 2 (SSL) | `https://seudominio.com/` |
| Cenário 3 (Cloudflare Tunnel) | `https://seu-hostname.cloudflare.com/` |

---

## 📋 Comandos Úteis

```bash
# Serviço — substitua [SIGLA] pela sua abreviação (ex: cdmp)
sudo systemctl status  drivershub-[SIGLA]
sudo journalctl -u     drivershub-[SIGLA] -f
sudo systemctl restart drivershub-[SIGLA]

# Reconfigurar
bash scripts/reconfigure-drivershub.sh

# Backup imediato
bash /opt/drivershub/backup-[SIGLA].sh

# Ver backups
ls -lh /opt/drivershub/backups/[SIGLA]/

# Verificar instalação completa
bash scripts/verificar-instalacao.sh
```

---

## 🏗️ Arquitetura

### Cenários 1 e 2 (VPS)

```
          Internet
              │
        [Nginx :80/443]
         /           \
location /         location /[sigla]/
    │                      │
┌───┴──────────────┐  ┌────┴───────────────┐
│ Frontend (React) │  │  Backend (FastAPI)  │
│ /var/www/dh-fe/  │  │  localhost:{porta}  │
└──────────────────┘  └──────────┬──────────┘
                                 │
                      ┌──────────┴──────────┐
                      │                     │
                   [MySQL]              [Redis]
              /opt/drivershub/        sessões
              {sigla}/HubBackend/
```

### Cenário 3 (Local + Cloudflare Tunnel)

```
  Internet → [Cloudflare Edge] → [cloudflared] → [Nginx :80] → Backend/Frontend
  (HTTPS automático)             (daemon local)   (sem SSL local)
```

### Multi-VTC no mesmo servidor

```
/opt/drivershub/
├── vtc1/HubBackend/       ← VTC 1 isolada
├── vtc2/HubBackend/       ← VTC 2 isolada
├── .installer_state_vtc1  ← estado da VTC 1
├── .installer_state_vtc2  ← estado da VTC 2
├── backups/vtc1/          ← backups da VTC 1
├── backups/vtc2/          ← backups da VTC 2
└── backup-vtc1.sh         ← script de backup VTC 1
```

---

## 📝 Changelog

### [1.3.0] — Abril 2026

- ✨ **3 cenários de implantação** com menu visual explicativo
- ✨ **DuckDNS** (Cenário 2): subdomínio gratuito com atualização automática de IP a cada 5 min
- ✨ **Cloudflare Tunnel** (Cenário 3): substitui a opção localhost — resolve SSL exigido pelo Discord
- ✨ **Multi-VTC**: cada VTC usa `/opt/drivershub/{sigla}/HubBackend` e state file separado
- ✨ **`reconfigure-drivershub.sh`**: alterar domínio, credenciais, porta, SSL ou Tunnel após instalação
- ✨ **`backup-drivershub.sh`**: backup/restauração interativo com cron configurável
- ✨ **`health-check.sh`**: monitoramento com reinício automático e notificação via Discord webhook
- ✨ **`verificar-instalacao.sh` v2.0**: 10 seções, auto-detecta VTCs, verifica api_host, DuckDNS, Cloudflare Tunnel
- ✨ **Firewall automático**: ufw configurado para portas 80, 443 e API durante a instalação
- ✨ **Verificação de recursos**: RAM, disco, internet e portas 80/443 antes de instalar
- 🐛 **Discord Client ID/Secret**: troca endpoint `@me` pelo `oauth2/token` — corrige falsos negativos
- 🐛 **api_host**: patch client-config.py agora aplica `https://` para Cenários 2 e 3 também

### [1.2.1] — Março 2026
- 🐛 `confirm()` sem `-r` causava interpretação de backslash em senhas
- 🐛 Parsing frágil do config.json com grep/cut substituído por `python3 -c json.load`
- 🐛 systemd no WSL: PATH insuficiente causava `grep: not found` no ExecStartPre
- 🐛 Discord OAuth: URL de callback exibida incorretamente nas instruções finais

### [1.2.0] — Março 2026
- ✨ `update-drivershub.sh` com backup automático antes de pull
- ✨ `uninstall-drivershub.sh` com confirmação por etapa
- ✨ Detecção de instalação existente com modo reparo/reinstalar

### [1.1.0] — Março 2026
- ✨ `install-frontend.sh` — instalador completo do HubFrontend
- ✨ State file para comunicação entre scripts
- 🔄 MariaDB substituído por MySQL

### [1.0.0] — Fevereiro 2026
- ✨ Script inicial de instalação automatizada do Backend

---

## 🔒 Segurança

- **Firewall**: configurado automaticamente pelo instalador (HTTP, HTTPS, porta da API)
- **SSL**: automático via Let's Encrypt (Cenários 1 e 2) ou Cloudflare (Cenário 3)
- **Backups**: cron diário configurado automaticamente — backups em `/opt/drivershub/backups/`
- **config.json**: permissões `600` (somente o dono lê)
- Vulnerabilidades: **não abra issue pública** — envie para **kiq.reis09@gmail.com**

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
