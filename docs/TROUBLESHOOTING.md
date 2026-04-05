# 🔧 Solução Rápida de Problemas — Drivers Hub

## ⚡ Diagnóstico Rápido

Antes de buscar o problema específico, rode o verificador — ele detecta VTCs automaticamente e exibe um relatório completo:

```bash
bash scripts/verificar-instalacao.sh
```

Para coletar tudo de uma vez e pedir ajuda, substitua `[SIGLA]` pela sua sigla (ex: `cdmp`):

```bash
(
echo "=== SISTEMA ===" && uname -a && lsb_release -a 2>/dev/null
echo "=== SERVICOS ===" && sudo systemctl status drivershub-[SIGLA] --no-pager 2>&1
echo "=== MYSQL ===" && sudo systemctl status mysql --no-pager 2>&1
echo "=== REDIS ===" && sudo systemctl status redis-server --no-pager 2>&1
echo "=== NGINX ===" && sudo systemctl status nginx --no-pager 2>&1
echo "=== LOGS (50 linhas) ===" && sudo journalctl -u drivershub-[SIGLA] -n 50 --no-pager 2>&1
echo "=== REDE ===" && ss -tuln | grep -E '7777|80|443' 2>&1
echo "=== CONFIG ===" && python3 -m json.tool /opt/drivershub/[SIGLA]/HubBackend/config.json 2>/dev/null | head -25
) > ~/diagnostico.txt && cat ~/diagnostico.txt
```

---

## 🔴 Serviço não inicia

```bash
# Ver o erro específico
sudo journalctl -u drivershub-[SIGLA] -n 30 --no-pager
```

**Causa: Porta já em uso**
```bash
sudo ss -lntp | grep 7777   # Verificar quem usa a porta
# Mude a porta no config.json e use o reconfigure:
bash scripts/reconfigure-drivershub.sh  # → opção 4
```

**Causa: Erro no config.json**
```bash
python3 -m json.tool /opt/drivershub/[SIGLA]/HubBackend/config.json
# Se der erro de sintaxe, restaure um backup:
ls /opt/drivershub/backups/[SIGLA]/
bash scripts/backup-drivershub.sh  # → opção 3 (restaurar)
```

**Causa: MySQL ou Redis não rodando**
```bash
sudo systemctl start mysql        && sudo systemctl enable mysql
sudo systemctl start redis-server && sudo systemctl enable redis-server
sudo systemctl restart drivershub-[SIGLA]
```

**Causa: PATH insuficiente no serviço (comum no WSL)**
```bash
sudo systemctl cat drivershub-[SIGLA] | grep PATH
# Deve conter :/usr/bin:/bin  — se não, use o modo reparo:
bash scripts/install-drivershub.sh
# → r) Reparar instalação
```

**Causa: Dependências Python corrompidas**
```bash
bash scripts/install-drivershub.sh
# → r) Reparar instalação
```

---

## 🔴 Erro: "Table 'X_db.settings' doesn't exist"

Ocorre porque o `db.py` contém cláusulas `DATA DIRECTORY` que o MySQL rejeita.

**Passo 1 — Verificar se o patch foi aplicado**
```bash
grep -c "DATA DIRECTORY = '" /opt/drivershub/[SIGLA]/HubBackend/src/db.py
# Se retornar > 0: patch NÃO aplicado → execute o Fix abaixo
```

**Passo 2 — Aplicar o patch**
```bash
python3 - << 'PYEOF'
fname = '/opt/drivershub/[SIGLA]/HubBackend/src/db.py'
with open(fname, 'r') as f:
    content = f.read()
patched = content.replace(" DATA DIRECTORY = '{config.db_data_directory}'", "")
patched = patched.replace(" DATA DIRECTORY = '{app.config.db_data_directory}'", "")
with open(fname, 'w') as f:
    f.write(patched)
print(f"Restantes: {patched.count('DATA DIRECTORY')}")
PYEOF
```

**Passo 3 — Criar tabelas manualmente**
```bash
cd /opt/drivershub/[SIGLA]/HubBackend/src
source ../venv/bin/activate
python3 - << 'PYEOF'
import json, sys
sys.path.insert(0, '.')
import db

cfg = json.load(open('../config.json'))

class Cfg:
    def __init__(self, c):
        self.db_host           = c.get('db_host', 'localhost')
        self.db_port           = int(c.get('db_port', 3306))
        self.db_user           = c.get('db_user', '')
        self.db_password       = c.get('db_password', '')
        self.db_name           = c.get('db_name', '')
        self.db_data_directory = ''
        self.db_pool_size      = int(c.get('db_pool_size', 10))

try:
    db.init(Cfg(cfg), '2.11.1')
    print('TABELAS CRIADAS COM SUCESSO')
except Exception as e:
    print(f'ERRO: {e}')
PYEOF
deactivate
```

**Passo 4 — Confirmar e reiniciar**
```bash
sudo mysql -e "SHOW TABLES FROM [SIGLA]_db;" | wc -l  # ~43 tabelas esperadas
sudo systemctl restart drivershub-[SIGLA]
sleep 10
sudo journalctl -u drivershub-[SIGLA] -n 10 --no-pager
# Deve mostrar: Application startup complete.
```

---

## 🔴 Erro: "Can't connect to MySQL"

```bash
# 1. Verificar se MySQL está rodando
sudo systemctl status mysql

# 2. Testar conexão manualmente
mysql -u [SIGLA]_user -p [SIGLA]_db

# 3. Recriar usuário e permissões
sudo mysql << EOF
DROP USER IF EXISTS '[SIGLA]_user'@'localhost';
CREATE USER '[SIGLA]_user'@'localhost' IDENTIFIED BY 'SUA_SENHA';
GRANT ALL PRIVILEGES ON [SIGLA]_db.* TO '[SIGLA]_user'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Tela: "O DriversHub está enfrentando uma inoperância temporária"

Esta tela aparece quando o Frontend carrega mas não consegue buscar a configuração no backend.

**Verificar se client-config está ativado:**
```bash
grep 'external_plugins' /opt/drivershub/[SIGLA]/HubBackend/config.json
```
Deve mostrar: `"external_plugins": ["client-config"]`

Se estiver vazio (`[]`):
```bash
# Use reconfigure para corrigir e reiniciar
bash scripts/reconfigure-drivershub.sh
# Ou edite manualmente:
nano /opt/drivershub/[SIGLA]/HubBackend/config.json
sudo systemctl restart drivershub-[SIGLA]
```

**Verificar api_host no banco:**
```bash
sudo mysql -N -s -e "SELECT JSON_UNQUOTE(JSON_EXTRACT(sval,'\$.api_host')) FROM \`[SIGLA]_db\`.settings WHERE skey='client-config/meta';"
```
Deve retornar algo como `https://seudominio.com`. Se estiver sem protocolo (`http://` ou `https://`):
```bash
sudo mysql -e "UPDATE \`[SIGLA]_db\`.settings SET sval=JSON_SET(sval,'\$.api_host','https://seudominio.com') WHERE skey='client-config/meta';"
redis-cli DEL "client-config:meta"
sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Discord login não funciona / "redirect_uri inválido"

**Esta é a causa mais comum**: URL de callback registrada incorretamente no Discord.

**URL correta do callback:**
```
https://seudominio.com/auth/discord/callback
```

> ⚠️ O frontend usa `https://` fixo e `/auth/discord/callback` — **SEM o prefixo da VTC** (`/cdmp/`), **SEM `/api/`**. Qualquer variação resulta em "redirect_uri inválido".

**Passo 1 — Verificar Redirect URI no portal**
```
1. https://discord.com/developers/applications → sua app → OAuth2 → Redirects
2. A URI deve ser EXATAMENTE como acima (sem barra no final, com https://)
```

**Passo 2 — Verificar se o domínio está correto no config.json**
```bash
python3 -c "
import json
d = json.load(open('/opt/drivershub/[SIGLA]/HubBackend/config.json'))
print('domain:', d['domain'])
print('discord_client_id:', d['discord_client_id'][:8], '...')
"
```

**Passo 3 — Verificar bot no servidor**
```
- O bot deve estar online no seu servidor Discord
- Deve ter permissão Administrator
- discord_guild_id deve corresponder ao ID do servidor correto
```

**Passo 4 — Ver logs em tempo real**
```bash
sudo journalctl -u drivershub-[SIGLA] -f
# Tente login e observe os erros
```

---

## 🔴 Credenciais Discord mostram erro mesmo sendo válidas

O instalador v1.3.0 corrigiu este problema usando o endpoint `oauth2/token` em vez de `@me`. Se você ainda vê falsos negativos:

```bash
# Testar manualmente com o novo método:
curl -s -w "\n%{http_code}" \
    -X POST "https://discord.com/api/v10/oauth2/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "SEU_CLIENT_ID:SEU_CLIENT_SECRET" \
    -d "grant_type=client_credentials&scope=identify" \
    --max-time 15
# HTTP 200 = válidas | HTTP 401 = inválidas
```

Se retornar 200 mas o instalador mostra erro, use o menu de reconfiguração:
```bash
bash scripts/reconfigure-drivershub.sh  # → opção 7 (Validar credenciais)
```

---

## 🔴 Frontend não carrega / página em branco

**Verificar se o build existe:**
```bash
ls -la /var/www/drivershub-frontend/
# Deve ter index.html e a pasta assets/
```

**Verificar Nginx:**
```bash
sudo nginx -t                         # Testar configuração
sudo systemctl reload nginx           # Recarregar
sudo tail -30 /var/log/nginx/error.log
```

**Página em branco (SPA sem try_files):**
```bash
grep try_files /etc/nginx/sites-available/drivershub-[SIGLA]
# Se não aparecer, reinstale o frontend:
bash scripts/install-frontend.sh
```

---

## 🔴 Nginx retorna 503 / "Frontend ainda não instalado"

```bash
bash scripts/install-frontend.sh
```

---

## 🔴 502 Bad Gateway

```bash
sudo systemctl status drivershub-[SIGLA]   # Backend ativo?
sudo ss -lntp | grep 7777                  # Porta respondendo?
curl http://localhost:7777/[SIGLA]         # Responde diretamente?
sudo tail -30 /var/log/nginx/error.log     # Erros Nginx?
```

---

## 🔴 Cloudflare Tunnel não conecta (Cenário 3)

```bash
# Verificar status
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -n 30 --no-pager

# Reiniciar tunnel
sudo systemctl restart cloudflared

# Reconfigurar com novo token
bash scripts/reconfigure-drivershub.sh  # → opção 6
```

**Verificar no painel Cloudflare:**
1. https://one.dash.cloudflare.com → Networks → Tunnels
2. O tunnel deve estar com status "Healthy"
3. O hostname configurado deve apontar para `http://localhost:{porta}`

---

## 🔴 DuckDNS não atualiza IP (Cenário 2)

```bash
# Verificar última atualização
cat /var/log/duckdns.log

# Testar manualmente
bash /opt/drivershub/duckdns-update.sh

# Verificar cron
sudo crontab -l | grep duckdns

# Testar URL de atualização diretamente
curl "https://www.duckdns.org/update?domains=SEU_SUBDOMINIO&token=SEU_TOKEN&ip="
# Deve retornar "OK"
```

---

## 🔴 Notificação Discord do health check não chega

```bash
# Verificar configuração
cat /opt/drivershub/.healthcheck_[SIGLA]

# Testar webhook manualmente
curl -X POST "URL_DO_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d '{"content":"Teste manual"}'

# Reconfigurar
bash scripts/health-check.sh  # → opção 1
```

---

## 🔴 Backup automático não está funcionando

```bash
# Verificar cron
crontab -l | grep backup

# Verificar log
cat /opt/drivershub/backups/[SIGLA]/backup.log

# Testar manualmente
bash /opt/drivershub/backup-[SIGLA].sh

# Reconfigurar
bash scripts/backup-drivershub.sh  # → opção 4
```

---

## 🔴 "Permission Denied"

```bash
# Corrigir proprietário
sudo chown -R "$USER":"$USER" /opt/drivershub

# Corrigir permissões do config
chmod 600 /opt/drivershub/[SIGLA]/HubBackend/config.json

# Corrigir permissões do venv
chmod -R 755 /opt/drivershub/[SIGLA]/HubBackend/venv/
```

---

## 🔴 "Module not found" (Python)

```bash
cd /opt/drivershub/[SIGLA]/HubBackend
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
grep -v '# dev' requirements.txt > /tmp/req.txt
pip install -r /tmp/req.txt -q
pip install cryptography -q
deactivate
sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Banco de dados corrompido

```bash
# 1. Backup de emergência
mysqldump -u [SIGLA]_user -p [SIGLA]_db > ~/backup_emergency.sql

# 2. Tentar reparar
mysql -u [SIGLA]_user -p [SIGLA]_db -e "
REPAIR TABLE user;
REPAIR TABLE dlog;
REPAIR TABLE session;"

# 3. Recriar banco (PERDE DADOS — use backup)
sudo mysql -e "
DROP DATABASE IF EXISTS [SIGLA]_db;
CREATE DATABASE [SIGLA]_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON [SIGLA]_db.* TO '[SIGLA]_user'@'localhost';
FLUSH PRIVILEGES;"
sudo systemctl restart drivershub-[SIGLA]
```

Ou use o script de restauração:
```bash
bash scripts/backup-drivershub.sh  # → opção 3 (restaurar)
```

---

## 🔴 Aplicação lenta

```bash
htop          # CPU e memória
df -h         # Espaço em disco
free -m       # RAM disponível

# Otimizar MySQL
mysql -u [SIGLA]_user -p [SIGLA]_db -e "
OPTIMIZE TABLE user;
OPTIMIZE TABLE dlog;
OPTIMIZE TABLE session;"

# Limpar sessões antigas (30+ dias)
mysql -u [SIGLA]_user -p [SIGLA]_db -e "
DELETE FROM session
WHERE last_used_timestamp < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY));"

# Limpar cache Redis
redis-cli FLUSHDB
sudo systemctl restart drivershub-[SIGLA]
```

---

## 🚨 Procedimentos de Emergência

### Reiniciar tudo

```bash
sudo systemctl restart mysql
sudo systemctl restart redis-server
sudo systemctl restart drivershub-[SIGLA]
sudo systemctl reload nginx
```

### Verificação rápida de todos os serviços

```bash
bash scripts/health-check.sh --run [SIGLA]
```

### Modo debug (ver erros na tela)

```bash
sudo systemctl stop drivershub-[SIGLA]
cd /opt/drivershub/[SIGLA]/HubBackend
source venv/bin/activate
python3 src/main.py --config config.json
# Ctrl+C para parar
```

### Resetar instalação sem perder banco

```bash
# 1. Backup (por via das dúvidas)
bash scripts/backup-drivershub.sh       # → opção 1

# 2. Reinstalar em modo reparo (preserva config.json e banco)
bash scripts/install-drivershub.sh
# → r) Reparar instalação
```

### Trocar domínio sem reinstalar

```bash
bash scripts/reconfigure-drivershub.sh  # → opção 1
```

---

## ✅ Checklist de Debug

```
[ ] MySQL rodando?           sudo systemctl status mysql
[ ] Redis rodando?           sudo systemctl status redis-server
[ ] Nginx rodando?           sudo systemctl status nginx
[ ] Serviço rodando?         sudo systemctl status drivershub-[SIGLA]
[ ] config.json válido?      python3 -m json.tool /opt/drivershub/[SIGLA]/HubBackend/config.json
[ ] Porta aberta?            ss -tuln | grep 7777
[ ] Logs têm erro?           journalctl -u drivershub-[SIGLA] -n 30
[ ] Banco acessível?         mysql -u [SIGLA]_user -p [SIGLA]_db
[ ] Redis responde?          redis-cli ping
[ ] api_host correto?        sudo mysql -N -s -e "SELECT JSON_UNQUOTE(JSON_EXTRACT(sval,'\$.api_host')) FROM \`[SIGLA]_db\`.settings WHERE skey='client-config/meta';"
[ ] Frontend existe?         ls /var/www/drivershub-frontend/index.html
[ ] Nginx config OK?         sudo nginx -t
[ ] Permissões corretas?     ls -la /opt/drivershub/[SIGLA]/HubBackend/config.json
[ ] Discord Redirect URI?    https://seudominio.com/auth/discord/callback (sem prefixo VTC)
[ ] Cloudflare Tunnel?       sudo systemctl status cloudflared  (somente Cenário 3)
[ ] DuckDNS atualizado?      cat /var/log/duckdns.log  (somente Cenário 2)
```

---

## 📞 Quando pedir ajuda

Execute o verificador e compartilhe a saída:

```bash
bash scripts/verificar-instalacao.sh 2>&1 | tee ~/verificacao.txt
cat ~/verificacao.txt
```

Ou colete logs detalhados:

```bash
sudo journalctl -u drivershub-[SIGLA] -n 100 --no-pager > ~/logs_drivershub.txt
cat ~/logs_drivershub.txt
```

**Comunidade**: https://discord.gg/wNTaaBZ5qd
**Wiki**: https://wiki.charlews.com/books/chub

---

**📚 Para o guia completo de instalação, consulte [GUIA_INSTALACAO.md](GUIA_INSTALACAO.md)**
