# 🚚 Guia de Instalação — Drivers Hub

## 📋 Índice

- [Sobre](#-sobre)
- [Requisitos](#-requisitos)
- [Cenários de Implantação](#-cenários-de-implantação)
- [Preparação](#-preparação)
- [Passo 1 — Backend](#-passo-1--backend)
- [Passo 2 — Frontend](#-passo-2--frontend)
- [Pós-Instalação](#-pós-instalação)
- [Reconfigurar após instalação](#-reconfigurar-após-instalação)
- [Multi-VTC no mesmo servidor](#-multi-vtc-no-mesmo-servidor)
- [Backup automático](#-backup-automático)
- [Health Check](#-health-check)
- [Atualizar](#-atualizando)
- [Desinstalar](#-desinstalando)
- [Modo Reparo](#-modo-reparo)
- [Comandos Úteis](#-comandos-úteis)
- [Segurança](#-segurança)
- [Checklist](#-checklist-pós-instalação)

---

## 🎯 Sobre

Este projeto automatiza completamente a instalação do **Drivers Hub** — Backend e Frontend — para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.

O instalador oferece **3 cenários 100% gratuitos**, cuida do domínio, SSL, firewall e backup automaticamente — sem necessidade de configuração manual.

### O que é instalado automaticamente

**Backend:**
- Python 3 com ambiente virtual e dependências
- MySQL com banco de dados e usuário configurados por VTC
- Redis para cache e sessões
- HubBackend clonado em `/opt/drivershub/{sigla}/HubBackend`
- Serviço systemd `drivershub-{sigla}` com restart automático
- Nginx como proxy reverso
- SSL/HTTPS com Let's Encrypt (Cenários 1 e 2)
- DuckDNS com atualização automática de IP (Cenário 2)
- Cloudflare Tunnel via `cloudflared` (Cenário 3)
- Firewall ufw configurado automaticamente
- Backup automático do banco (cron diário às 3h)

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

> O instalador verifica automaticamente os recursos antes de prosseguir.

- **CPU**: 2 cores mínimo
- **RAM**: 1.5 GB mínimo (aviso abaixo de 900 MB)
- **Disco**: 5 GB livres mínimo
- **Rede**: Conexão estável com internet (verificada automaticamente)
- **Portas**: 80 e 443 disponíveis (verificadas automaticamente)

### Acesso
> ⚠️ **NÃO execute como root!** Use um usuário normal com `sudo`.

```bash
whoami          # Deve mostrar um nome, não "root"

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

**Dados da VTC**

| Campo | Exemplo |
|---|---|
| Nome completo | CDMP Express |
| Abreviação (sigla) | cdmp |

---

## 🌐 Cenários de Implantação

O instalador apresenta um menu visual e pede que você escolha **um dos 3 cenários** antes de instalar.

### Cenário 1 — VPS/Cloud + Domínio Próprio + Let's Encrypt

**Para quem tem**: servidor VPS e um domínio registrado (ex: `hub.minhaVTC.com.br`)

O que acontece automaticamente:
- Nginx configurado com `server_name seu.dominio`
- Certbot obtém certificado SSL gratuito via Let's Encrypt
- config.json gerado com `https://`

**Pré-requisito**: o DNS do domínio deve apontar para o IP do servidor antes de iniciar.

```
seudominio.com → A → 1.2.3.4 (IP do servidor)
```

---

### Cenário 2 — VPS/Cloud + DuckDNS + Let's Encrypt

**Para quem tem**: servidor VPS mas **sem domínio registrado**

O que acontece automaticamente:
1. Você informa o subdomínio desejado (ex: `minha-vtc`) e o token DuckDNS
2. O instalador atualiza o IP no DuckDNS imediatamente
3. Cria script de atualização automática a cada 5 minutos via cron
4. Certbot obtém certificado SSL para `minha-vtc.duckdns.org`

**Como criar sua conta DuckDNS:**
1. Acesse https://www.duckdns.org
2. Faça login com Google, GitHub ou Discord
3. Crie um subdomínio (ex: `minha-vtc`)
4. Copie o **token** exibido na página principal

> 💡 DuckDNS é gratuito, sem limite de uso, e funciona mesmo sem IP fixo.

---

### Cenário 3 — Servidor Local + Cloudflare Tunnel

**Para quem tem**: computador ou servidor em casa/escritório, sem IP fixo e sem abrir portas no roteador.

Este cenário **substitui completamente a antiga opção "localhost"** — que era incompatível com o Discord OAuth por exigir HTTPS.

O que acontece automaticamente:
1. Você instala `cloudflared` (feito pelo script)
2. Informa o token do tunnel criado no painel Cloudflare
3. O tunnel expõe sua aplicação local com HTTPS via Cloudflare Edge

**Como criar o tunnel:**
1. Acesse https://one.dash.cloudflare.com
2. Networks → Tunnels → Create a tunnel
3. Escolha **Cloudflared** como connector
4. Copie o token gerado
5. Em "Public Hostname", configure:
   - Hostname: `hub.suavtc.com` (seu domínio gerenciado pelo Cloudflare)
   - Service: `http://localhost:{porta}`

> 💡 SSL é terminado pelo Cloudflare — não é necessário configurar Let's Encrypt localmente.

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

```
NOME DA VTC:
ABREVIAÇÃO (sigla):
CENÁRIO: [ ] 1-VPS+Domínio  [ ] 2-DuckDNS  [ ] 3-CloudflareTunnel
PORTA: 7777

=== CENÁRIO 1 ===
Domínio: hub.minha-vtc.com.br (já apontando para o servidor)

=== CENÁRIO 2 ===
Subdomínio DuckDNS: minha-vtc  →  minha-vtc.duckdns.org
Token DuckDNS:

=== CENÁRIO 3 ===
Hostname no Cloudflare: hub.minha-vtc.com
Tunnel Token:

=== DISCORD ===
Client ID:
Client Secret:
Bot Token:
Server (Guild) ID:

=== STEAM ===
API Key:

=== BANCO DE DADOS ===
Senha desejada (mínimo 8 caracteres):
```

---

## 🚀 Passo 1 — Backend

```bash
bash scripts/install-drivershub.sh
```

### Passos executados

```
[PASSO  1/12] Verificando requisitos do sistema (RAM, disco, internet, portas)
[PASSO  2/12] Escolhendo cenário de implantação
[PASSO  3/12] Coletando informações da instalação
[PASSO  4/12] Configurando DuckDNS  ← somente Cenário 2
[PASSO  5/12] Validando credenciais Discord e Steam
[PASSO  6/12] Instalando dependências do sistema
[PASSO  7/12] Instalando e configurando MySQL
[PASSO  8/12] Instalando e configurando Redis
[PASSO  9/12] Clonando repositório do Drivers Hub
[PASSO 10/12] Criando arquivo de configuração + tabelas
[PASSO 11/12] Configurando serviço systemd + Nginx + SSL + Firewall
[PASSO 12/12] Configurando Cloudflare Tunnel  ← somente Cenário 3
               → fix api_host no banco
               → configurar backup automático
               → salvar estado
```

### Validação de credenciais

O script valida automaticamente **antes** de instalar:

- ✅ **Discord Bot Token** — testa via `GET /users/@me`
- ✅ **Discord Client ID + Secret** — testa via endpoint `oauth2/token` com `client_credentials` grant (mais confiável que `@me`)
- ✅ **Steam API Key** — testa via `GetSupportedAPIList`

Se alguma credencial estiver inválida, o script permite corrigir e **revalida automaticamente** as novas credenciais antes de continuar.

### Detecção de instalação existente (multi-VTC)

Se já houver VTCs instaladas, o script exibe:

```
⚠️  INSTALAÇÃO(ÕES) EXISTENTE(S) DETECTADA(S)!

VTCs instaladas neste servidor:
  1) /opt/drivershub/.installer_state_cdmp  [cdmp]
  2) /opt/drivershub/.installer_state_vtc2  [vtc2]

O que deseja fazer?
  r) Reparar instalação existente
  n) Nova instalação (nova VTC neste servidor)
  q) Cancelar
```

**Use opção `r` (Reparar)** para corrigir uma VTC já instalada sem perder dados.
**Use opção `n`** para adicionar uma nova VTC ao mesmo servidor.

---

## 🎨 Passo 2 — Frontend

```bash
bash scripts/install-frontend.sh
```

O script lê automaticamente as configurações de `/opt/drivershub/.installer_state_{sigla}` — você não precisa repetir domínio, sigla ou protocolo.

```
[PASSO 1/6] Verificando pré-requisitos
[PASSO 2/6] Verificando / instalando Node.js 20+
[PASSO 3/6] Configurando variáveis do frontend
[PASSO 4/6] Clonando repositório e fazendo build
[PASSO 5/6] Deploy no Nginx
[PASSO 6/6] Verificação final
```

A `VITE_CONFIG_URL` é calculada automaticamente com base no domínio e protocolo do backend.

---

## ✅ Pós-Instalação

### 1. Verificar a instalação

```bash
bash scripts/verificar-instalacao.sh
```

O script detecta automaticamente todas as VTCs instaladas e verifica:
- Sistema operacional e recursos
- MySQL, Redis, backend, serviço systemd
- Nginx, SSL, Cloudflare Tunnel, DuckDNS
- api_host no banco, backup e health check configurados

### 2. Configurar o Discord Redirect URI

No [Discord Developer Portal](https://discord.com/developers/applications):

1. Selecione sua aplicação
2. Vá em **OAuth2 → Redirects**
3. Adicione **exatamente** (sem barra no final):

```
https://seudominio.com/auth/discord/callback
```

> ⚠️ **Atenção crítica**: O frontend usa `https://` fixo e o path `/auth/discord/callback` — **sem o prefixo da VTC** e **sem `/api/`**. Registrar a URL errada (ex: com `/cdmp/api/`) resulta em "redirect_uri inválido" ao tentar login.

### 3. Convidar o bot

1. **OAuth2 → URL Generator**
2. Escopos: `bot` + `applications.commands`
3. Permissões: `Administrator`
4. Abra a URL gerada e selecione seu servidor

### 4. Acessar o sistema

| Cenário | URL |
|---|---|
| Cenário 1 — VPS + domínio | `https://seudominio.com/` |
| Cenário 2 — DuckDNS | `https://minha-vtc.duckdns.org/` |
| Cenário 3 — Cloudflare Tunnel | `https://hub.suavtc.com/` |

### 5. Configurar webhooks Discord *(opcional)*

```bash
nano /opt/drivershub/[SIGLA]/HubBackend/config.json
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

### 6. Configurar IDs dos cargos Discord *(opcional)*

1. Discord → Configurações → Avançado → **Modo Desenvolvedor** (ativar)
2. Clique direito no cargo → **Copiar ID**
3. Edite o `config.json`:

```json
"roles": [
    {"roleid": 1, "name": "Diretor", "discordrole": "ID_DO_CARGO", "permissions": ["admin"]}
]
```

---

## 🔁 Reconfigurar após instalação

Para alterar qualquer configuração **sem reinstalar**, use:

```bash
bash scripts/reconfigure-drivershub.sh
```

O script detecta automaticamente as VTCs instaladas. Em servidores com múltiplas VTCs, exibe um menu de seleção.

**O que pode ser reconfigurado:**

| Opção | O que faz | Reinicia serviço? |
|---|---|---|
| **1 — Domínio** | Atualiza `config.json`, Nginx (`server_name`) e `api_host` no banco | ✅ Sim |
| **2 — Credenciais Discord** | Atualiza Client ID, Secret, Bot Token e Guild ID | ✅ Sim |
| **3 — Steam API Key** | Atualiza a chave no `config.json` | ✅ Sim |
| **4 — Porta do backend** | Atualiza `server_port` no `config.json` e `proxy_pass` do Nginx | ✅ Sim |
| **5 — SSL / HTTPS** | Executa Certbot para emitir ou renovar certificado | ✅ Sim |
| **6 — Cloudflare Tunnel** | Reinstala `cloudflared` com novo token | — |
| **7 — Validar credenciais** | Testa Discord e Steam **sem alterar nada** | — |

Após qualquer alteração, o script atualiza o `config.json`, o Nginx, o `api_host` no banco de dados, limpa o cache Redis e reinicia o serviço automaticamente.

> 📖 **Guia completo:** veja [GUIA_RECONFIGURE.md](GUIA_RECONFIGURE.md) para exemplos detalhados de cada opção, o que é preservado e solução de problemas.

---

## 🖥️ Multi-VTC no mesmo servidor

O instalador suporta múltiplas VTCs no mesmo servidor. Cada VTC tem:

- Diretório isolado: `/opt/drivershub/{sigla}/HubBackend/`
- Banco de dados próprio: `{sigla}_db`
- Serviço systemd próprio: `drivershub-{sigla}`
- State file próprio: `/opt/drivershub/.installer_state_{sigla}`
- Porta própria (configure uma porta diferente para cada VTC)
- Script de backup próprio: `/opt/drivershub/backup-{sigla}.sh`

**Para instalar uma segunda VTC:**

```bash
bash scripts/install-drivershub.sh
# → Selecione: n) Nova instalação
# → Informe a sigla e porta diferente (ex: vtc2, porta 7778)
```

O Nginx será atualizado automaticamente com a nova VTC em `/vtc2/`.

---

## 💾 Backup Automático

O backup automático é configurado durante a instalação (cron diário às 3h). Para gerenciar:

```bash
bash scripts/backup-drivershub.sh
```

**Menu disponível:**

| Opção | Descrição |
|---|---|
| Criar backup agora | Gera dump comprimido do banco |
| Listar backups | Mostra arquivos com data e tamanho |
| Restaurar backup | Restaura com backup de segurança automático antes |
| Configurar cron | Alterar frequência (a cada hora, 6h, diário...) |
| Ver log | Histórico de backups e erros |

**Localização dos backups:**
```
/opt/drivershub/backups/{sigla}/
  {sigla}_db_YYYYMMDD_HHMMSS.sql.gz  ← backups comprimidos
  backup.log                          ← log de operações
```

Retenção padrão: **7 dias** (configurável).

---

## 🏥 Health Check

Monitoramento automático dos serviços com notificação via **Discord webhook** quando algo para ou se recupera.

```bash
bash scripts/health-check.sh
```

**5 componentes monitorados a cada verificação:**

| Componente | Verificação |
|---|---|
| Serviço systemd | `drivershub-{sigla}` está ativo? |
| Porta do backend | A porta configurada está escutando? |
| Resposta HTTP | Backend responde em `http://localhost:{porta}/{sigla}`? |
| MySQL | Serviço MySQL está ativo? |
| Redis | `redis-cli ping` responde `PONG`? |

**Comportamento:**
- 🚨 Notificação enviada na **primeira detecção** de problema (sem spam em falhas repetidas)
- ✅ Notificação de recuperação quando o serviço volta
- 🔄 Tenta reiniciar o `drivershub-{sigla}` automaticamente se estiver inativo

**Configuração inicial:**
1. Crie um webhook: Discord → Editar Canal → Integrações → Webhooks → Novo Webhook
2. Execute o script e informe a URL do webhook
3. Escolha a frequência: 1 min / 5 min (padrão) / 10 min

```bash
# Verificação manual imediata
bash scripts/health-check.sh --run [SIGLA]

# Ver log de health checks
tail -50 /opt/drivershub/health-check.log

# Filtrar apenas eventos de problema e recuperação
grep -E 'DOWN|RESTART|RECOVERY' /opt/drivershub/health-check.log
```

> 📖 **Guia completo:** veja [GUIA_HEALTH_CHECK.md](GUIA_HEALTH_CHECK.md) para detalhes sobre as notificações Discord, gerenciamento do cron, multi-VTC e solução de problemas.

---

## 🔄 Atualizando

```bash
bash scripts/update-drivershub.sh
```

O script pergunta o que atualizar (backend, frontend ou ambos), faz **backup automático** do `config.json` e `.env.production`, executa `git pull`, e restaura suas configurações após o pull.

---

## 🗑️ Desinstalando

```bash
bash scripts/uninstall-drivershub.sh
```

Cada etapa tem confirmação individual. O banco de dados exige confirmação extra por ser irreversível.

---

## 🔨 Modo Reparo

Se a instalação estiver com problema:

```bash
bash scripts/install-drivershub.sh
# → Escolha: r) Reparar instalação
```

**O que o reparo faz:**
- Recarrega variáveis do `config.json` existente
- Reinstala dependências Python (sem filtro de dev)
- Reaplicar patch do DATA DIRECTORY se necessário
- Reinicia o serviço
- **Não altera o `config.json` nem o banco de dados**

---

## 📝 Comandos Úteis

### Backend

```bash
# Status e logs — substitua [SIGLA] pela sua abreviação
sudo systemctl status drivershub-[SIGLA]
sudo journalctl -u drivershub-[SIGLA] -f
sudo journalctl -u drivershub-[SIGLA] -n 100

# Controle
sudo systemctl start   drivershub-[SIGLA]
sudo systemctl stop    drivershub-[SIGLA]
sudo systemctl restart drivershub-[SIGLA]

# Modo debug manual
sudo systemctl stop drivershub-[SIGLA]
cd /opt/drivershub/[SIGLA]/HubBackend
source venv/bin/activate
python3 src/main.py --config config.json
```

### MySQL

```bash
# Acessar banco
mysql -u [SIGLA]_user -p [SIGLA]_db

# Backup manual
mysqldump -u [SIGLA]_user -p [SIGLA]_db > backup_$(date +%Y%m%d).sql

# Restaurar
mysql -u [SIGLA]_user -p [SIGLA]_db < backup_YYYYMMDD.sql

# Verificar tabelas
sudo mysql -e "SHOW TABLES FROM [SIGLA]_db;" | wc -l
```

### Nginx

```bash
sudo nginx -t                          # Testar configuração
sudo systemctl reload nginx            # Recarregar
sudo tail -f /var/log/nginx/error.log  # Logs de erro
cat /etc/nginx/sites-enabled/drivershub-[SIGLA]
```

### Cloudflare Tunnel (Cenário 3)

```bash
sudo systemctl status  cloudflared
sudo systemctl restart cloudflared
sudo journalctl -u cloudflared -f
```

### DuckDNS (Cenário 2)

```bash
# Verificar atualização manual
bash /opt/drivershub/duckdns-update.sh
cat /var/log/duckdns.log

# Ver cron configurado
sudo crontab -l | grep duckdns
```

---

## 🔒 Segurança

### Firewall

O instalador configura o `ufw` automaticamente. Para verificar ou ajustar:

```bash
sudo ufw status numbered    # Ver regras atuais
sudo ufw allow 22/tcp       # SSH — adicionar se necessário
sudo ufw allow 80/tcp       # HTTP
sudo ufw allow 443/tcp      # HTTPS
```

### Backups

O cron de backup é configurado durante a instalação. Para verificar:

```bash
crontab -l | grep backup    # Cron de backup
ls -lh /opt/drivershub/backups/[SIGLA]/  # Arquivos
```

### Certificado SSL

```bash
sudo certbot certificates               # Ver certificados
sudo certbot renew --dry-run            # Testar renovação
# Renovação automática já configurada pelo Certbot
```

### config.json

```bash
ls -la /opt/drivershub/[SIGLA]/HubBackend/config.json
# Deve mostrar: -rw------- (permissão 600)

# Se necessário, corrigir:
chmod 600 /opt/drivershub/[SIGLA]/HubBackend/config.json
```

---

## ✅ Checklist Pós-Instalação

```
[ ] Backend rodando         sudo systemctl status drivershub-[SIGLA]
[ ] Frontend acessível      curl -s -o /dev/null -w "%{http_code}" https://seudominio.com
[ ] Redirect URI Discord    configurado em /auth/discord/callback (SEM prefixo VTC)
[ ] Bot Discord             convidado e online no servidor
[ ] Login Discord           funcionando no navegador
[ ] Cargos Discord          sincronizados no painel admin
[ ] Webhooks Discord        configurados no config.json (opcional)
[ ] Firewall                sudo ufw status
[ ] Backup automático       crontab -l | grep backup
[ ] Health check            crontab -l | grep health-check (opcional)
[ ] SSL/HTTPS               certbot certificates (Cenários 1 e 2)
[ ] Cloudflare Tunnel       sudo systemctl status cloudflared (Cenário 3)
[ ] DuckDNS                 sudo crontab -l | grep duckdns (Cenário 2)
```

---

## 📚 Recursos

- **Wiki oficial**: https://wiki.charlws.com/books/chub
- **API docs**: `https://seudominio.com/[sigla]/docs` *(após instalação)*
- **Discord da comunidade**: https://discord.gg/wNTaaBZ5qd
- **Site**: https://drivershub.charlws.com

---

**Criado com ❤️ para a comunidade de transportadoras virtuais ETS2/ATS 🚚**
