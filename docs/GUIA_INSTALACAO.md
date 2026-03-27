# 🚚 Guia de Instalação — Drivers Hub

## 📋 Índice

- [Sobre](#-sobre)
- [Requisitos](#-requisitos)
- [Preparação](#-preparação)
- [Passo 1 — Backend](#-passo-1--backend)
- [Passo 2 — Frontend](#-passo-3--frontend)
- [Pós-Instalação](#-pós-instalação)
- [Atualizar](#-atualizando)
- [Desinstalar](#-desinstalando)
- [Modo Reparo](#-modo-reparo)
- [Comandos Úteis](#-comandos-úteis)
- [Segurança](#-segurança)
- [Checklist](#-checklist-pós-instalação)

---

## 🎯 Sobre

Este projeto automatiza completamente a instalação do **Drivers Hub** — Backend e Frontend — para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.

### O que é instalado automaticamente

**Backend:**
- Python 3 com ambiente virtual e dependências
- MySQL com banco de dados e usuário configurados
- Redis para cache e sessões
- HubBackend clonado e configurado
- Serviço systemd com restart automático
- Nginx como proxy reverso *(opcional)*
- SSL/HTTPS com Let's Encrypt *(opcional)*

**Frontend:**
- Node.js 20+ via NodeSource
- HubFrontend clonado e compilado
- Arquivos estáticos em `/var/www/drivershub-frontend/`
- Roteamento SPA configurado no Nginx

---

## 💻 Requisitos

### Sistema Operacional
- **Ubuntu 20.04+** *(recomendado)*
- **Debian 11+**

### Hardware
- **CPU**: 2 cores mínimo
- **RAM**: 2 GB mínimo
- **Disco**: 10 GB livres
- **Rede**: Conexão estável com internet

### Acesso
> ⚠️ **NÃO execute como root!** Use um usuário normal com `sudo`.

```bash
# Verificar seu usuário atual
whoami

# Se estiver como root, crie um usuário:
adduser seuusuario
usermod -aG sudo seuusuario
su - seuusuario
```

### Informações necessárias

**Discord Developer Portal** — [discord.com/developers/applications](https://discord.com/developers/applications)

| Campo | Onde encontrar |
|---|---|
| Client ID | Página principal da aplicação |
| Client Secret | OAuth2 → General |
| Bot Token | Bot → Reset Token |
| Server (Guild) ID | No Discord: clique direito no servidor → Copiar ID |

**Steam** — [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)

| Campo | Onde encontrar |
|---|---|
| API Key | Preencha o domínio e clique em "Register" |

**Dados da VTC**

| Campo | Exemplo |
|---|---|
| Nome completo | CDMP Express |
| Abreviação (sigla) | cdmp |
| Domínio | hub.minhaVTC.com *(deixe vazio para localhost)* |

---

## 🔧 Preparação

### 1. Atualizar o sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Clonar o instalador

```bash
git clone https://github.com/QI83/drivershub-installer.git
cd drivershub-installer
```

### 3. Organizar suas credenciais

Antes de executar o script, anote tudo em um arquivo seguro:

```
NOME DA VTC:
ABREVIAÇÃO:
DOMÍNIO (ou deixe em branco):
PORTA: 7777

=== DISCORD ===
Client ID:
Client Secret:
Bot Token:
Server ID:

=== STEAM ===
API Key:

=== BANCO DE DADOS ===
Senha desejada:
```

---

## 🚀 Passo 1 — Backend

```bash
bash scripts/install-drivershub.sh
```

### Etapas do script

```
[PASSO 1/10] Verificando requisitos do sistema
[PASSO 2/10] Coletando informações da instalação  ← você preenche aqui
[PASSO 2/10] Validando credenciais Discord e Steam ← automático
[PASSO 3/10] Instalando dependências do sistema
[PASSO 4/10] Instalando e configurando MySQL
[PASSO 5/10] Instalando e configurando Redis
[PASSO 6/10] Clonando repositório do Drivers Hub
[PASSO 7/10] Configurando ambiente Python
[PASSO 8/10] Aplicando correção no código
[PASSO 9/10] Criando arquivo de configuração
[PASSO 10/10] Configurando serviço systemd
```

### Validação de credenciais

O script valida automaticamente suas credenciais **antes** de iniciar a instalação:

- ✅ **Discord Bot Token** — testa via `GET /users/@me`
- ✅ **Discord Client ID + Secret** — testa via `GET /oauth2/applications/@me`
- ✅ **Steam API Key** — testa via `GetSupportedAPIList`

Se alguma credencial estiver inválida, o script avisa e oferece a opção de corrigir antes de continuar — evitando instalar tudo e só descobrir o problema no login.

### Exemplo de preenchimento

```
Nome completo da VTC: CDMP Express
Abreviação da VTC (ex: cdmp): cdmp
Domínio (deixe vazio para localhost): hub.minhaVTC.com
Porta do servidor [7777]: [Enter]

Senha para o banco de dados MySQL: ************
Confirme a senha: ************

Discord Client ID: 1467955638989623468
Discord Client Secret: FnhXn1dZxDEi1YvkVBq954kVpan454Et
Discord Bot Token: MTQ2Nzk1NTYzODk4OTYyMzQ2OA.G1EIDK...
Discord Server (Guild) ID: 1465781784728830192
Steam API Key: DE8C49E18E84FF620514813E035F4BC5

Deseja instalar e configurar Nginx? [s/N]: s
Deseja configurar SSL/HTTPS? [s/N]: s
```

### Detecção de instalação existente

Se o script detectar uma instalação anterior, exibirá um menu:

```
⚠️  INSTALAÇÃO EXISTENTE DETECTADA!

  VTC:          CDMP Express (cdmp)
  Serviço:      ✅ Rodando

O que deseja fazer?
  1) Reparar instalação   — corrige dependências sem apagar dados
  2) Nova instalação      — APAGA tudo e instala do zero
  3) Cancelar
```

**Use opção 1 (Reparar)** quando:
- O serviço parou de funcionar
- Dependências Python estão corrompidas
- Você quer reaplicar patches sem perder dados

**Use opção 2 (Nova instalação)** quando:
- Quer mudar o domínio, sigla ou senha
- Quer recomeçar do zero

---

## 🎨 Passo 2 — Frontend

```bash
bash scripts/install-frontend.sh
```

O script lê automaticamente as configurações salvas pelo backend em `/opt/drivershub/.installer_state` — você não precisa digitar o domínio ou sigla novamente.

```
[PASSO 1/6] Verificando pré-requisitos
[PASSO 2/6] Verificando / instalando Node.js
[PASSO 3/6] Configurando variáveis do frontend
[PASSO 4/6] Clonando repositório e fazendo build
[PASSO 5/6] Fazendo deploy no Nginx
[PASSO 6/6] Verificando instalação
```

A `VITE_CONFIG_URL` é calculada automaticamente com base no domínio e sigla configurados no backend. O script mostra a URL gerada e pede confirmação antes de prosseguir.

---

## ✅ Pós-Instalação

### 1. Verificar o status

```bash
bash scripts/verificar-instalacao.sh
```

### 2. Configurar o Discord Redirect URI

No [Discord Developer Portal](https://discord.com/developers/applications):

1. Selecione sua aplicação
2. Vá em **OAuth2 → Redirects**
3. Adicione:

```
https://seudominio.com/[SIGLA]/api/auth/discord/callback
```

### 3. Convidar o bot

1. No portal: **OAuth2 → URL Generator**
2. Escopos: `bot` + `applications.commands`
3. Permissões: `Administrator`
4. Abra a URL gerada no navegador e selecione seu servidor

### 4. Acessar o sistema

| Situação | URL |
|---|---|
| Com domínio + SSL | `https://seudominio.com/` |
| Com domínio sem SSL | `http://seudominio.com/` |
| Sem Nginx | `http://localhost:7777/[sigla]` |

### 5. Primeiro login

1. Clique em **Login com Discord**
2. Autorize a aplicação
3. Configure perfil e cargos no painel administrativo

### 6. Configurar webhooks Discord *(opcional)*

```bash
nano /opt/drivershub/HubBackend/config.json
```

```json
"hook_delivery_log": {
    "channel_id": "ID_DO_CANAL",
    "webhook_url": "https://discord.com/api/webhooks/..."
}
```

```bash
sudo systemctl restart drivershub-[SIGLA]
```

### 7. Configurar IDs dos cargos Discord *(opcional)*

1. Discord → Configurações → Avançado → **Modo Desenvolvedor** (ativar)
2. Clique direito no cargo → **Copiar ID**
3. Edite o `config.json`:

```json
"roles": [
    {"roleid": 1, "name": "Diretor", "discordrole": "ID_DO_CARGO", "permissions": ["admin"]}
]
```

---

## 🔄 Atualizando

```bash
bash scripts/update-drivershub.sh
```

O script pergunta o que atualizar (backend, frontend ou ambos), faz **backup automático** do `config.json` e `.env.production`, executa `git pull`, e restaura as suas configurações após o pull — o `git pull` nunca vai sobrescrever seus dados.

---

## 🗑️ Desinstalando

```bash
bash scripts/uninstall-drivershub.sh
```

Cada etapa tem confirmação individual. O banco de dados exige uma confirmação extra por ser irreversível. MySQL, Redis, Nginx e Node.js são preservados pois podem estar em uso por outros projetos.

---

## 🔨 Modo Reparo

Se a instalação estiver com problema (serviço caindo, dependências corrompidas, Nginx com erro):

```bash
bash scripts/install-drivershub.sh
# → Escolha: 1) Reparar instalação
```

O que o reparo faz:
- Recarrega variáveis do `config.json` existente
- Reinstala dependências Python
- Reaplicar patch do DATA DIRECTORY se necessário
- Reinicia o serviço
- **Não altera o `config.json` nem o banco de dados**

---

## 📝 Comandos Úteis

### Backend

```bash
# Status e logs
sudo systemctl status drivershub-[SIGLA]
sudo journalctl -u drivershub-[SIGLA] -f
sudo journalctl -u drivershub-[SIGLA] -n 100

# Controle do serviço
sudo systemctl start   drivershub-[SIGLA]
sudo systemctl stop    drivershub-[SIGLA]
sudo systemctl restart drivershub-[SIGLA]

# Após editar config.json
sudo systemctl restart drivershub-[SIGLA]

# Modo debug manual
sudo systemctl stop drivershub-[SIGLA]
cd /opt/drivershub/HubBackend
source venv/bin/activate
python3 src/main.py --config config.json
```

### MySQL

```bash
# Acessar banco
mysql -u [SIGLA]_user -p [SIGLA]_db

# Backup
mysqldump -u [SIGLA]_user -p [SIGLA]_db > backup_$(date +%Y%m%d).sql

# Restaurar
mysql -u [SIGLA]_user -p [SIGLA]_db < backup_YYYYMMDD.sql

# Verificar banco
sudo mysql -e "SHOW DATABASES;"
sudo mysql -e "SELECT User, Host FROM mysql.user;"
```

### Nginx

```bash
sudo nginx -t                          # Testar configuração
sudo systemctl reload nginx            # Recarregar
sudo tail -f /var/log/nginx/error.log  # Logs de erro
sudo tail -f /var/log/nginx/access.log # Logs de acesso
```

### Frontend (atualização manual)

```bash
cd /opt/drivershub/HubFrontend
git pull
npm ci
npm run build
sudo rsync -a --delete build/ /var/www/drivershub-frontend/
sudo systemctl reload nginx
```

---

## 🔒 Segurança

### Firewall

```bash
sudo apt install -y ufw

sudo ufw allow 22/tcp    # SSH — obrigatório!
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

sudo ufw enable
sudo ufw status
```

### Backups automáticos

Crie um script de backup e agende via cron:

```bash
nano ~/backup-drivershub.sh
```

```bash
#!/bin/bash
SIGLA="cdmp"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/drivershub/backups"

mkdir -p "$BACKUP_DIR"

# Backup banco
mysqldump -u "${SIGLA}_user" -p'SUA_SENHA' "${SIGLA}_db" \
    > "${BACKUP_DIR}/db_${DATE}.sql"

# Backup config
cp /opt/drivershub/HubBackend/config.json \
   "${BACKUP_DIR}/config_${DATE}.json"

# Manter apenas últimos 7 dias
find "$BACKUP_DIR" -name "*.sql"  -mtime +7 -delete
find "$BACKUP_DIR" -name "*.json" -mtime +7 -delete

echo "Backup concluído: $DATE"
```

```bash
chmod +x ~/backup-drivershub.sh

# Agendar backup diário às 3h
crontab -e
# Adicionar:
# 0 3 * * * /home/seuusuario/backup-drivershub.sh >> /opt/drivershub/backup.log 2>&1
```

---

## ✅ Checklist Pós-Instalação

```
[ ] Backend rodando       sudo systemctl status drivershub-[SIGLA]
[ ] Frontend acessível    curl -s -o /dev/null -w "%{http_code}" http://localhost
[ ] Redirect URI Discord  configurado no Developer Portal
[ ] Bot Discord           convidado e online no servidor
[ ] Login Discord         funcionando no navegador
[ ] Cargos Discord        sincronizados no painel
[ ] Webhooks Discord      configurados (opcional)
[ ] Firewall              ufw status
[ ] Backup automático     crontab -l
[ ] SSL/HTTPS             certbot certificates (se aplicável)
```

---

## 📚 Recursos

- **Wiki oficial**: https://wiki.charlws.com/books/chub
- **API docs**: `https://seudominio.com/[sigla]/docs` *(após instalação)*
- **Discord da comunidade**: https://discord.gg/wNTaaBZ5qd
- **Site**: https://drivershub.charlws.com

---

**Criado com ❤️ para a comunidade de transportadoras virtuais ETS2/ATS 🚚**
