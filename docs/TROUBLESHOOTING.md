# 🔧 Solução Rápida de Problemas — Drivers Hub

## ⚡ Diagnóstico Rápido

Antes de buscar o problema específico, rode o verificador:

```bash
bash scripts/verificar-instalacao.sh
```

Se preferir coletar tudo de uma vez para pedir ajuda:

```bash
cat << 'EOF' > ~/diagnostico.txt
=== SISTEMA ===
$(uname -a)
$(lsb_release -a 2>/dev/null || cat /etc/os-release)

=== SERVICOS ===
$(sudo systemctl status drivershub-[SIGLA] --no-pager 2>&1)
$(sudo systemctl status mysql --no-pager 2>&1)
$(sudo systemctl status redis-server --no-pager 2>&1)
$(sudo systemctl status nginx --no-pager 2>&1)

=== LOGS (últimas 50 linhas) ===
$(sudo journalctl -u drivershub-[SIGLA] -n 50 --no-pager 2>&1)

=== REDE ===
$(ss -tuln | grep -E '7777|80|443' 2>&1)

=== CONFIG (primeiras 20 linhas) ===
$(python3 -m json.tool /opt/drivershub/HubBackend/config.json 2>/dev/null | head -20)
EOF
cat ~/diagnostico.txt
```

---

## 🔴 Serviço não inicia

```bash
# Ver o erro específico
sudo journalctl -u drivershub-[SIGLA] -n 30 --no-pager
```

**Causa: Porta já em uso**
```bash
sudo lsof -i :7777         # Verificar quem usa a porta
sudo kill -9 [PID]         # Encerrar o processo (se necessário)
# Ou mudar a porta no config.json e reiniciar
```

**Causa: Erro no config.json**
```bash
python3 -m json.tool /opt/drivershub/HubBackend/config.json
# Se der erro de sintaxe, restaure um backup:
ls /opt/drivershub/backups/config_*.json
cp /opt/drivershub/backups/config_YYYYMMDD_HHMMSS.json \
   /opt/drivershub/HubBackend/config.json
sudo systemctl restart drivershub-[SIGLA]
```

**Causa: MySQL ou Redis não rodando**
```bash
sudo systemctl start mysql        && sudo systemctl enable mysql
sudo systemctl start redis-server && sudo systemctl enable redis-server
sudo systemctl restart drivershub-[SIGLA]
```

**Causa: Dependências Python corrompidas**
```bash
# Use o modo reparo — não perde dados
bash scripts/install-drivershub.sh
# → Selecione: 1) Reparar instalação
```

---

## 🔴 Erro: "Can't connect to MySQL"

```bash
# 1. Verificar se MySQL está rodando
sudo systemctl status mysql

# 2. Testar conexão manualmente
mysql -u [SIGLA]_user -p [SIGLA]_db

# 3. Se falhar, recriar usuário e permissões
sudo mysql << EOF
DROP USER IF EXISTS '[SIGLA]_user'@'localhost';
CREATE USER '[SIGLA]_user'@'localhost' IDENTIFIED BY 'SUA_SENHA';
GRANT ALL PRIVILEGES ON [SIGLA]_db.* TO '[SIGLA]_user'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Credenciais Discord inválidas

O instalador valida as credenciais antes de instalar. Se a validação falhou:

**Bot Token inválido**
```
1. Acesse https://discord.com/developers/applications
2. Selecione sua aplicação → Bot
3. Clique em "Reset Token" e copie o novo token
4. Rode: bash scripts/install-drivershub.sh → opção 1 (Reparar)
   Ou edite: nano /opt/drivershub/HubBackend/config.json
   Campo: "discord_bot_token"
```

**Client ID ou Client Secret inválido**
```
1. No portal: OAuth2 → General
2. Copie o Client ID
3. Clique em "Reset Secret" para gerar um novo secret
4. Edite: nano /opt/drivershub/HubBackend/config.json
   Campos: "discord_client_id" e "discord_client_secret"
```

**Steam API Key inválida**
```
1. Acesse https://steamcommunity.com/dev/apikey
2. Registre um novo domínio e copie a chave
3. Edite: nano /opt/drivershub/HubBackend/config.json
   Campo: "steam_api_key"
```

Após editar o config.json:
```bash
sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Discord login não funciona

**Passo 1 — Verificar Redirect URI**
```
1. https://discord.com/developers/applications → sua app → OAuth2 → Redirects
2. A URI deve ser EXATAMENTE:
   https://seudominio.com/[SIGLA]/api/auth/discord/callback
   (sem barra no final, com o protocolo correto)
```

**Passo 2 — Verificar config.json**
```bash
grep -E '"domain"|"prefix"|"discord_client_id"' \
    /opt/drivershub/HubBackend/config.json
```

**Passo 3 — Verificar bot no servidor**
```
- O bot deve estar online no seu servidor Discord
- Deve ter permissão de Administrator
- O discord_guild_id deve corresponder ao ID do servidor correto
```

**Passo 4 — Ver logs em tempo real**
```bash
sudo journalctl -u drivershub-[SIGLA] -f
# Agora tente fazer login e observe os erros
```

---

## 🔴 Frontend não carrega / página em branco

**Verificar se o build existe**
```bash
ls -la /var/www/drivershub-frontend/
# Deve ter index.html e as pastas assets/
```

**Verificar Nginx**
```bash
sudo nginx -t                         # Testar configuração
sudo systemctl reload nginx           # Recarregar
sudo tail -30 /var/log/nginx/error.log # Ver erros
```

**Página em branco (SPA sem try_files)**
```bash
# Verificar se try_files está na config do Nginx
grep try_files /etc/nginx/sites-available/drivershub-[SIGLA]
# Se não estiver, reinstale o frontend:
bash scripts/install-frontend.sh
```

**Frontend desatualizado após git pull**
```bash
bash scripts/update-drivershub.sh
# → Selecione: Atualizar Frontend
```

---

## 🔴 Nginx retorna 503 / "Frontend ainda não instalado"

O backend foi instalado mas o frontend ainda não. Execute:

```bash
bash scripts/install-frontend.sh
```

---

## 🔴 Página não carrega / 502 Bad Gateway

```bash
# Verificar se a aplicação está rodando
sudo systemctl status drivershub-[SIGLA]

# Verificar se a porta está aberta
sudo ss -tuln | grep 7777

# Testar a aplicação diretamente (sem Nginx)
curl http://localhost:7777/[SIGLA]

# Ver logs do Nginx
sudo tail -30 /var/log/nginx/error.log
```

---

## 🔴 Erro após atualização (git pull manual)

```bash
cd /opt/drivershub/HubBackend

# Restaurar config.json de backup (se foi sobrescrito)
ls /opt/drivershub/backups/
cp /opt/drivershub/backups/config_YYYYMMDD_HHMMSS.json config.json

# Reaplicar patch do DATA DIRECTORY
cd src
grep -q "DATA DIRECTORY" db.py && \
    sed -i "s/ DATA DIRECTORY = '{app.config.db_data_directory}'//g" db.py

# Reinstalar dependências
source ../venv/bin/activate
pip install -r ../requirements.txt -q
deactivate

sudo systemctl restart drivershub-[SIGLA]
```

> 💡 **Dica**: Use `bash scripts/update-drivershub.sh` — ele faz tudo isso automaticamente, inclusive o backup antes do pull.

---

## 🔴 Erro: "Permission Denied"

```bash
# Corrigir proprietário do diretório
sudo chown -R "$USER":"$USER" /opt/drivershub

# Corrigir permissões do config
chmod 600 /opt/drivershub/HubBackend/config.json

# Corrigir permissões do venv
chmod -R 755 /opt/drivershub/HubBackend/venv/
```

---

## 🔴 Erro: "Module not found" (Python)

```bash
cd /opt/drivershub/HubBackend

# Recriar ambiente virtual
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
deactivate

sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Banco de dados corrompido

```bash
# 1. Fazer backup de emergência (mesmo corrompido)
mysqldump -u [SIGLA]_user -p [SIGLA]_db > ~/backup_emergency.sql

# 2. Tentar reparar as tabelas
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
REPAIR TABLE user;
REPAIR TABLE dlog;
REPAIR TABLE session;
EOF

# 3. Se não funcionar — recriar banco (PERDE TODOS OS DADOS)
sudo mysql << EOF
DROP DATABASE IF EXISTS [SIGLA]_db;
CREATE DATABASE [SIGLA]_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON [SIGLA]_db.* TO '[SIGLA]_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# A aplicação recria as tabelas automaticamente ao iniciar
sudo systemctl restart drivershub-[SIGLA]
```

---

## 🔴 Webhooks Discord não funcionam

```bash
# Testar webhook manualmente
curl -X POST "URL_DO_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d '{"content": "Teste de webhook"}'

# URL deve começar com: https://discord.com/api/webhooks/
# Verificar no config.json
grep -A3 "webhook_url" /opt/drivershub/HubBackend/config.json
```

---

## 🔴 Aplicação lenta

```bash
# Verificar uso de CPU e memória
htop

# Verificar disco
df -h

# Otimizar tabelas MySQL
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
OPTIMIZE TABLE user;
OPTIMIZE TABLE dlog;
OPTIMIZE TABLE session;
EOF

# Limpar sessões antigas (mais de 30 dias)
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
DELETE FROM session
WHERE last_used_timestamp < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY));
EOF

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

### Resetar instalação sem perder banco

```bash
# 1. Backup
mysqldump -u [SIGLA]_user -p [SIGLA]_db > ~/banco_backup.sql
cp /opt/drivershub/HubBackend/config.json ~/config_backup.json

# 2. Reinstalar (opção 2 — nova instalação)
bash scripts/install-drivershub.sh

# 3. Restaurar banco (se necessário)
mysql -u [SIGLA]_user -p [SIGLA]_db < ~/banco_backup.sql
```

### Modo debug (ver erros na tela)

```bash
sudo systemctl stop drivershub-[SIGLA]
cd /opt/drivershub/HubBackend
source venv/bin/activate
python3 src/main.py --config config.json
# Todos os erros aparecem aqui — Ctrl+C para parar
```

---

## ✅ Checklist de Debug

```
[ ] MySQL rodando?           sudo systemctl status mysql
[ ] Redis rodando?           sudo systemctl status redis-server
[ ] Nginx rodando?           sudo systemctl status nginx
[ ] Serviço rodando?         sudo systemctl status drivershub-[SIGLA]
[ ] config.json válido?      python3 -m json.tool /opt/drivershub/HubBackend/config.json
[ ] Porta aberta?            ss -tuln | grep 7777
[ ] Logs têm erro?           journalctl -u drivershub-[SIGLA] -n 30
[ ] Banco acessível?         mysql -u [SIGLA]_user -p [SIGLA]_db
[ ] Redis responde?          redis-cli ping
[ ] Frontend existe?         ls /var/www/drivershub-frontend/index.html
[ ] Nginx config OK?         sudo nginx -t
[ ] Permissões corretas?     ls -la /opt/drivershub/HubBackend
```

---

## 📞 Quando pedir ajuda

Compartilhe no Discord da comunidade o arquivo gerado por:

```bash
bash scripts/verificar-instalacao.sh
```

Ou colete logs manualmente:

```bash
sudo journalctl -u drivershub-[SIGLA] -n 100 --no-pager > ~/logs_drivershub.txt
cat ~/logs_drivershub.txt
```

**Comunidade**: https://discord.gg/wNTaaBZ5qd  
**Wiki**: https://wiki.charlws.com/books/chub

---

**📚 Para o guia completo de instalação, consulte [GUIA_INSTALACAO.md](GUIA_INSTALACAO.md)**
