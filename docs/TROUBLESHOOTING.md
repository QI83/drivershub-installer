# 🔧 Solução Rápida de Problemas - Drivers Hub

## ⚡ Problemas Comuns e Soluções Rápidas

### 🔴 Serviço não inicia

```bash
# Ver erro específico
sudo journalctl -u drivershub-[SIGLA] -n 20 --no-pager

# Causas comuns:
```

**1. Porta já em uso**
```bash
# Verificar quem está usando a porta
sudo lsof -i :7777

# Matar processo (se necessário)
sudo kill -9 [PID]

# Ou mudar a porta no config.json
nano /opt/drivershub/HubBackend/config.json
# Alterar: "server_port": 7777 para outra porta
```

**2. Erro no config.json**
```bash
# Validar JSON
python3 -m json.tool /opt/drivershub/HubBackend/config.json

# Se der erro, corrija o JSON ou use backup:
cp /opt/drivershub/HubBackend/old.config_sample.json /opt/drivershub/HubBackend/config.json
# E reconfigure
```

**3. MySQL/Redis não rodando**
```bash
# Iniciar MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Iniciar Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

---

### 🔴 Erro: "Can't connect to MySQL"

```bash
# Verificar se MySQL está rodando
sudo systemctl status mysql

# Se não estiver, iniciar
sudo systemctl start mysql

# Verificar usuário e senha
mysql -u [SIGLA]_user -p [SIGLA]_db
# Digite a senha configurada

# Se falhar, recriar usuário:
sudo mysql << EOF
DROP USER IF EXISTS '[SIGLA]_user'@'localhost';
CREATE USER '[SIGLA]_user'@'localhost' IDENTIFIED BY 'SUA_SENHA';
GRANT ALL PRIVILEGES ON [SIGLA]_db.* TO '[SIGLA]_user'@'localhost';
FLUSH PRIVILEGES;
EOF
```

---

### 🔴 Erro: "Connection refused" (Redis)

```bash
# Verificar Redis
sudo systemctl status redis-server

# Se não estiver rodando
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Testar conexão
redis-cli ping
# Deve responder: PONG

# Se não responder, reinstalar:
sudo apt install --reinstall redis-server
```

---

### 🔴 Discord login não funciona

**Passo 1: Verificar Redirect URI**
```
1. Acesse: https://discord.com/developers/applications
2. Selecione sua aplicação
3. Vá em OAuth2 > Redirects
4. Adicione exatamente como está no seu servidor:
   - Local: http://localhost:7777/[SIGLA]/api/auth/discord/callback
   - Domínio: http://seudominio.com/[SIGLA]/api/auth/discord/callback
   - SSL: https://seudominio.com/[SIGLA]/api/auth/discord/callback
```

**Passo 2: Verificar config.json**
```bash
# Verificar configurações Discord
grep -A 5 "discord_" /opt/drivershub/HubBackend/config.json

# Verificar domínio
grep "domain" /opt/drivershub/HubBackend/config.json
```

**Passo 3: Verificar bot no servidor**
```
1. Bot deve estar online no seu servidor Discord
2. Bot precisa de permissões de administrador
3. Verificar Guild ID está correto
```

**Passo 4: Ver logs**
```bash
sudo journalctl -u drivershub-[SIGLA] -f
# Tente fazer login novamente e observe os erros
```

---

### 🔴 Página não carrega / 502 Bad Gateway

**Se usando Nginx:**
```bash
# Verificar se aplicação está rodando
sudo systemctl status drivershub-[SIGLA]

# Verificar Nginx
sudo systemctl status nginx

# Ver logs do Nginx
sudo tail -30 /var/log/nginx/error.log

# Testar configuração
sudo nginx -t

# Recarregar
sudo systemctl reload nginx
```

**Se sem Nginx:**
```bash
# Verificar se porta está aberta
sudo ss -tuln | grep 7777

# Testar diretamente
curl http://localhost:7777/[SIGLA]

# Se falhar, ver logs do serviço
sudo journalctl -u drivershub-[SIGLA] -n 50
```

---

### 🔴 Erro: "Permission Denied"

```bash
# Corrigir proprietário
sudo chown -R $USER:$USER /opt/drivershub

# Corrigir permissões
chmod 755 /opt/drivershub/HubBackend
chmod 600 /opt/drivershub/HubBackend/config.json

# Corrigir permissões do venv
cd /opt/drivershub/HubBackend
chmod -R 755 venv/
```

---

### 🔴 Erro após atualização (git pull)

```bash
cd /opt/drivershub/HubBackend

# Descartar alterações locais
git reset --hard
git clean -fd

# Atualizar
git pull

# Reinstalar dependências
source venv/bin/activate
pip install -r requirements.txt --upgrade

# Replicar correção do DATA DIRECTORY
cd src
sed -i "s/ DATA DIRECTORY = '{app.config.db_data_directory}'//g" db.py

# Reiniciar
sudo systemctl restart drivershub-[SIGLA]
```

---

### 🔴 Erro: "Module not found"

```bash
cd /opt/drivershub/HubBackend

# Recriar ambiente virtual
rm -rf venv
python3 -m venv venv
source venv/bin/activate

# Reinstalar tudo
pip install --upgrade pip
pip install -r requirements.txt

# Reiniciar
sudo systemctl restart drivershub-[SIGLA]
```

---

### 🔴 Banco de dados corrompido

```bash
# Fazer backup primeiro!
mysqldump -u [SIGLA]_user -p [SIGLA]_db > backup_emergency.sql

# Opção 1: Reparar tabelas
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
REPAIR TABLE user;
REPAIR TABLE dlog;
REPAIR TABLE session;
EOF

# Opção 2: Recriar banco (PERDE DADOS!)
sudo mysql << EOF
DROP DATABASE IF EXISTS [SIGLA]_db;
CREATE DATABASE [SIGLA]_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF

# Reiniciar aplicação (recria tabelas)
sudo systemctl restart drivershub-[SIGLA]
```

---

### 🔴 Aplicação lenta

**1. Verificar uso de recursos**
```bash
# CPU e RAM
htop

# Espaço em disco
df -h

# Ver uso por processo
top -p $(pgrep -f "drivershub")
```

**2. Otimizar banco de dados**
```bash
# Otimizar tabelas
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
OPTIMIZE TABLE user;
OPTIMIZE TABLE dlog;
OPTIMIZE TABLE session;
EOF

# Limpar logs antigos
mysql -u [SIGLA]_user -p [SIGLA]_db << EOF
DELETE FROM session WHERE last_used_timestamp < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY));
EOF
```

**3. Limpar Redis**
```bash
redis-cli FLUSHDB
sudo systemctl restart drivershub-[SIGLA]
```

---

### 🔴 Webhooks Discord não funcionam

**1. Verificar URLs**
```bash
# Ver configuração de webhooks
grep -A 5 "webhook_url" /opt/drivershub/HubBackend/config.json

# Testar webhook manualmente
curl -X POST "URL_DO_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d '{"content": "Teste de webhook"}'
```

**2. Verificar formato**
- URL deve começar com: `https://discord.com/api/webhooks/`
- Channel ID deve ser apenas números
- Sem espaços ou quebras de linha

**3. Recriar webhook**
```
1. No Discord: Canal > Configurações > Integrações > Webhooks
2. Deletar webhook antigo
3. Criar novo
4. Copiar URL completa
5. Colar no config.json
6. Reiniciar serviço
```

---

## 🚨 Comandos de Emergência

### Resetar tudo (mantém banco de dados)

```bash
# Parar serviço
sudo systemctl stop drivershub-[SIGLA]

# Backup do config
cp /opt/drivershub/HubBackend/config.json ~/config.json.backup

# Backup do banco
mysqldump -u [SIGLA]_user -p [SIGLA]_db > ~/banco_backup.sql

# Deletar instalação
sudo rm -rf /opt/drivershub

# Executar instalador novamente
./install-drivershub.sh

# Restaurar banco (se necessário)
mysql -u [SIGLA]_user -p [SIGLA]_db < ~/banco_backup.sql
```

### Logs de debug completos

```bash
# Parar serviço
sudo systemctl stop drivershub-[SIGLA]

# Executar manualmente com debug
cd /opt/drivershub/HubBackend
source venv/bin/activate
python3 src/main.py --config config.json

# Ver todos os erros na tela
# Pressione Ctrl+C para parar
```

### Verificar tudo de uma vez

```bash
# Usar script de verificação
chmod +x verificar-instalacao.sh
./verificar-instalacao.sh
```

---

## 📞 Quando pedir ajuda

Se nada funcionar, colete estas informações antes de pedir ajuda:

```bash
# Informações do sistema
cat << EOF > ~/diagnostico.txt
=== SISTEMA ===
$(uname -a)
$(lsb_release -a)

=== SERVICOS ===
$(systemctl status drivershub-[SIGLA] --no-pager)
$(systemctl status mysql --no-pager)
$(systemctl status redis-server --no-pager)

=== LOGS ===
$(sudo journalctl -u drivershub-[SIGLA] -n 50 --no-pager)

=== REDE ===
$(ss -tuln | grep 7777)
$(curl -I http://localhost:7777/[SIGLA] 2>&1)

=== CONFIG ===
$(python3 -m json.tool /opt/drivershub/HubBackend/config.json | head -30)
EOF

# Ver arquivo criado
cat ~/diagnostico.txt
```

Envie o arquivo `diagnostico.txt` junto com sua dúvida no Discord da comunidade.

---

## ✅ Checklist de Debug

Use esta lista para debug sistemático:

```
[ ] MySQL rodando?           sudo systemctl status mysql
[ ] Redis rodando?             sudo systemctl status redis-server
[ ] Serviço rodando?           sudo systemctl status drivershub-[SIGLA]
[ ] config.json válido?        python3 -m json.tool config.json
[ ] Porta aberta?              ss -tuln | grep 7777
[ ] Logs têm erro?             journalctl -u drivershub-[SIGLA] -n 20
[ ] Banco acessível?           mysql -u [SIGLA]_user -p [SIGLA]_db
[ ] Redis responde?            redis-cli ping
[ ] Permissões corretas?       ls -la /opt/drivershub/HubBackend
[ ] Venv intacto?              ls /opt/drivershub/HubBackend/venv/bin
```

---

**📚 Para mais ajuda, consulte GUIA_INSTALACAO.md**
