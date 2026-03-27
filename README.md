# 🚚 Drivers Hub — Instalador Automático

[![Versão](https://img.shields.io/badge/versão-1.1.0-blue.svg)](https://github.com/QI83/drivershub-installer/releases)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-lightgrey.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen.svg)](https://www.shellcheck.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> **Instalação automatizada completa do Drivers Hub — Backend + Frontend — para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.**

[🚀 Início Rápido](#-início-rápido) • [✨ O Que Instala](#-o-que-instala) • [📖 Documentação](#-documentação) • [🔧 Pós-Instalação](#-pós-instalação) • [🆘 Suporte](#-suporte)

---

## 📸 Preview

```
╔═══════════════════════════════════════════════════════════════╗
║          INSTALADOR AUTOMÁTICO - DRIVERS HUB                  ║
║              Euro Truck Simulator 2 / ATS                     ║
║ Versão: 1.1.0                                                 ║
╚═══════════════════════════════════════════════════════════════╝

[PASSO 4/10] Instalando e configurando MySQL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  Instalando MySQL Server...
ℹ️  Iniciando serviço MySQL...
✅ MySQL instalado
ℹ️  Criando banco de dados e usuário...
✅ Banco de dados MySQL configurado

[PASSO 10/10] Configurando serviço systemd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Serviço iniciado com sucesso
✅ Estado salvo em /opt/drivershub/.installer_state
```

---

## ✨ O Que Instala

A instalação é feita em **duas etapas independentes**:

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
| **Cache de assets** | Headers de cache de 1 ano para JS/CSS/imagens |

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
| Internet | Conexão estável |

### Informações necessárias antes de começar

- 🎮 **Discord Developer Portal** → [discord.com/developers/applications](https://discord.com/developers/applications)
  - Client ID, Client Secret, Bot Token, Server (Guild) ID
- 🎮 **Steam API Key** → [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)
- 📋 **Dados da VTC** → Nome completo, sigla (ex: `cdmp`), domínio

---

### Instalação

#### Passo 1 — Baixar o projeto

```bash
git clone https://github.com/QI83/drivershub-installer.git
cd drivershub-installer
```

#### Passo 2 — Instalar o Backend

```bash
bash scripts/install-drivershub.sh
```

> ⏱️ Tempo estimado: **5–15 minutos**
>
> O script irá instalar Python, MySQL, Redis, clonar o HubBackend, gerar o `config.json` e configurar o serviço systemd.
> Ao final, salva um arquivo de estado em `/opt/drivershub/.installer_state` usado pelo instalador do frontend.

#### Passo 3 — Instalar o Frontend

```bash
bash scripts/install-frontend.sh
```

> ⏱️ Tempo estimado: **3–10 minutos** (depende da velocidade do npm install)
>
> O script lê automaticamente as configurações salvas pelo backend, instala Node.js se necessário, faz o build do HubFrontend e configura o Nginx para servir a interface.

#### Passo 4 — Verificar

```bash
bash scripts/verificar-instalacao.sh
```

---

## 📖 Documentação

| Documento | Descrição |
|---|---|
| 📖 [GUIA_INSTALACAO.md](docs/GUIA_INSTALACAO.md) | Guia detalhado passo a passo |
| 🔧 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Soluções para os problemas mais comuns |
| 📋 [README.txt](README.txt) | Referência rápida em texto puro |
| 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) | Como contribuir com o projeto |

### Scripts disponíveis

| Script | Descrição |
|---|---|
| `scripts/install-drivershub.sh` | Instalador do Backend — Python, MySQL, Redis, Nginx |
| `scripts/install-frontend.sh` | Instalador do Frontend — Node.js, React build, deploy |
| `scripts/verificar-instalacao.sh` | Verificação pós-instalação de todos os componentes |

---

## 🔧 Pós-Instalação

### 1. Configurar o Discord Redirect URI

No [Discord Developer Portal](https://discord.com/developers/applications), em **OAuth2 → Redirects**, adicione:

```
https://seudominio.com/[SIGLA]/api/auth/discord/callback
```

> Substitua `seudominio.com` pelo seu domínio e `[SIGLA]` pela abreviação da VTC.

### 2. Convidar o Bot Discord

1. No portal, acesse **OAuth2 → URL Generator**
2. Escopos: `bot` + `applications.commands`
3. Permissões Bot: `Administrator`
4. Copie a URL gerada, abra no navegador e selecione seu servidor

### 3. Acessar o sistema

| Situação | URL |
|---|---|
| Com domínio + SSL | `https://seudominio.com/` |
| Com domínio, sem SSL | `http://seudominio.com/` |
| Sem Nginx (apenas backend) | `http://localhost:7777/[sigla]` |

---

## 📋 Comandos Úteis

### Backend

```bash
# Status do serviço
sudo systemctl status drivershub-[SIGLA]

# Logs em tempo real
sudo journalctl -u drivershub-[SIGLA] -f

# Reiniciar / parar / iniciar
sudo systemctl restart drivershub-[SIGLA]
sudo systemctl stop    drivershub-[SIGLA]
sudo systemctl start   drivershub-[SIGLA]

# Editar configuração
nano /opt/drivershub/HubBackend/config.json
sudo systemctl restart drivershub-[SIGLA]
```

### Frontend

```bash
# Atualizar para a versão mais recente
cd /opt/drivershub/HubFrontend
git pull
npm ci
npm run build
sudo rsync -a --delete build/ /var/www/drivershub-frontend/
sudo systemctl reload nginx

# Logs do Nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Banco de Dados (MySQL)

```bash
# Acessar o banco
mysql -u [SIGLA]_user -p [SIGLA]_db

# Backup
mysqldump -u [SIGLA]_user -p [SIGLA]_db > backup_$(date +%Y%m%d).sql

# Restaurar
mysql -u [SIGLA]_user -p [SIGLA]_db < backup_YYYYMMDD.sql
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
                         [MySQL]               [Redis]
                    banco de dados           cache / sessão
```

---

## 📝 Changelog

### [1.1.0] — Março 2026

#### ✨ Adicionado
- `install-frontend.sh` — instalador completo do HubFrontend (Node.js, build, Nginx SPA)
- `save_installer_state()` — persiste configurações do backend em `/opt/drivershub/.installer_state`
- Nginx com roteamento separado: `/[sigla]/` para API, `/` para frontend
- Detecção e remoção automática de MariaDB conflitante ao instalar MySQL
- Verificação do banco de dados após criação
- `-r` em todos os `read` e aspas nos argumentos de cor

#### 🐛 Corrigido
- **Bug crítico**: `set -o pipefail` + `grep -v "already"` causava abort silencioso do script em 5 lugares
- **Bug crítico**: `{domain}` literal gerado no `config.json` em vez do domínio real
- Domínio sanitizado: remove `https://`, barras e espaços digitados pelo usuário
- Variável `CONFIG_FILE` declarada mas nunca usada removida
- Indentação mista (tabs/espaços) corrigida
- Dependência do systemd corrigida: `mariadb.service` → `mysql.service`
- Certbot: aspas adicionadas em `-d "$DOMAIN"`, erro não mais fatal
- `verificar-instalacao.sh`: bug SC2046 corrigido (aspas no `-p"${DB_PASS}"`)

#### 🔄 Alterado
- **MariaDB substituído por MySQL** em todos os scripts e documentação
- Nginx: bloco `location /` separado do proxy do backend

---

### [1.0.1] — Fevereiro 2026

#### 🐛 Corrigido
- Ajustes menores na interface

---

### [1.0.0] — Fevereiro 2026

#### ✨ Adicionado
- Script de instalação automatizado do Backend
- Documentação completa
- Script de verificação pós-instalação
- Guia de troubleshooting
- Interface colorida e interativa

---

## 🔒 Segurança

### Boas Práticas

- 🔐 Use senhas fortes para o banco de dados
- 🔒 Configure firewall (`ufw allow 80,443/tcp`)
- 🌐 Use sempre SSL em produção
- 💾 Configure backups automáticos do banco
- 📊 Monitore os logs regularmente

### Reportar Vulnerabilidades

Encontrou uma vulnerabilidade? **Não abra uma issue pública.**
Envie um e-mail para: **kiq.reis09@gmail.com**

---

## 🆘 Suporte

### Documentação Oficial do Drivers Hub

- 📖 **Wiki**: https://wiki.charlws.com/books/chub
- 💬 **Discord**: https://discord.gg/wNTaaBZ5qd
- 🌐 **Site**: https://drivershub.charlws.com

### Problemas Comuns

Consulte o [Guia de Troubleshooting](docs/TROUBLESHOOTING.md):

- ❌ Serviço não inicia
- ❌ Erro de conexão com MySQL
- ❌ Login Discord não funciona
- ❌ Frontend não carrega / página em branco
- ❌ Nginx retorna 503

### Reportar Bugs

Encontrou um bug? [Abra uma issue](https://github.com/QI83/drivershub-installer/issues/new) com o máximo de detalhes possível.

---

## 🤝 Contribuindo

Contribuições são bem-vindas!

1. Fork este repositório
2. Crie uma branch: `git checkout -b minha-feature`
3. Commit suas mudanças: `git commit -m 'feat: descrição da mudança'`
4. Push: `git push origin minha-feature`
5. Abra um Pull Request

Consulte o [CONTRIBUTING.md](CONTRIBUTING.md) para as diretrizes completas.

---

## 📊 Estatísticas

![GitHub repo size](https://img.shields.io/github/repo-size/QI83/drivershub-installer)
![GitHub issues](https://img.shields.io/github/issues/QI83/drivershub-installer)
![GitHub pull requests](https://img.shields.io/github/issues-pr/QI83/drivershub-installer)
![GitHub last commit](https://img.shields.io/github/last-commit/QI83/drivershub-installer)

---

## 👥 Autores

- **ScriptKID** — *Criador do instalador automatizado* — [@QI83](https://github.com/QI83)

### Agradecimentos

- [CharlesWithC](https://github.com/CharlesWithC) — Criador do Drivers Hub
- Comunidade ETS2/ATS
- Todos os contribuidores

---

## 📄 Licença

Este projeto está licenciado sob a Licença MIT — veja [LICENSE](LICENSE) para detalhes.

O [HubBackend](https://github.com/CharlesWithC/HubBackend) e o [HubFrontend](https://github.com/CharlesWithC/HubFrontend) são copyright © 2022–2026 CharlesWithC, licenciados sob AGPL-3.0.

---

<div align="center">

**Feito com ❤️ para a comunidade de transportadoras virtuais ETS2/ATS**

[⬆ Voltar ao topo](#-drivers-hub--instalador-automático)

⭐ Se este projeto te ajudou, considere dar uma estrela!

</div>
