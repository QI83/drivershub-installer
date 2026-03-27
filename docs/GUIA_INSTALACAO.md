# 🚚 Guia de Instalação Automatizada - Drivers Hub

## 📋 Índice

- [Sobre](##🎯Sobre)
- [Requisitos](##💻Requisitos)
- [Download](#download)
- [Preparação](#preparação)
- [Execução](#execução)
- [Após a Instalação](#após-a-instalação)
- [Solução de Problemas](#solução-de-problemas)
- [Comandos Úteis](#comandos-úteis)

---

## 🎯 Sobre

Este script automatiza completamente a instalação do **Drivers Hub Backend** para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.

### ✨ O que o script faz automaticamente:

✅ Instala todas as dependências necessárias (Python, MySQL, Redis)  
✅ Clona e configura o repositório do Drivers Hub  
✅ Cria e configura o banco de dados  
✅ Gera o arquivo `config.json` personalizado  
✅ Aplica correções necessárias no código  
✅ Configura serviço systemd para inicialização automática  
✅ Instala e configura Nginx (opcional)  
✅ Configura SSL/HTTPS com Let's Encrypt (opcional)  

---

## 💻 Requisitos

### Sistema Operacional
- **Ubuntu 20.04 ou superior** (recomendado)
- **Debian 11 ou superior**
- Outras distribuições baseadas em Debian/Ubuntu podem funcionar

### Hardware Mínimo
- **CPU**: 2 cores
- **RAM**: 2 GB
- **Disco**: 10 GB livres
- **Rede**: Conexão com internet

### Acesso
- ⚠️ **NÃO execute como root!** Use um usuário normal com sudo
- Acesso SSH (se for servidor remoto)

### Informações Necessárias

Antes de executar o script, tenha em mãos:

#### 🎮 Discord Developer Portal
1. Acesse: https://discord.com/developers/applications
2. Crie uma nova aplicação
3. Anote:
   - **Client ID**
   - **Client Secret** (em OAuth2)
   - **Bot Token** (crie um bot em "Bot")
   - **Server/Guild ID** do seu servidor Discord

#### 🎮 Steam API
1. Acesse: https://steamcommunity.com/dev/apikey
2. Registre seu domínio (ou use `localhost` para testes)
3. Anote a **API Key**

#### 📋 Informações da VTC
- Nome completo da transportadora
- Abreviação (sigla, ex: "cdmp")
- Domínio (se tiver, ou deixe vazio para localhost)
- Senha para o banco de dados

---

## 📥 Download

### Opção 1: Download direto

```bash
# Baixar o script
wget https://raw.githubusercontent.com/SEU_REPO/install-drivershub.sh

# Dar permissão de execução
chmod +x install-drivershub.sh
```

### Opção 2: Clone manual

```bash
# Criar diretório
mkdir -p ~/drivershub-installer
cd ~/drivershub-installer

# Copiar o script para este diretório
# (cole o conteúdo do arquivo install-drivershub.sh)
nano install-drivershub.sh

# Dar permissão de execução
chmod +x install-drivershub.sh
```

---

## 🔧 Preparação

### 1. Atualizar o Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Verificar Usuário

⚠️ **Importante**: Certifique-se de estar usando um usuário **normal** (não root):

```bash
# Verificar usuário atual
whoami

# Se estiver como root, crie um usuário:
# adduser seuusuario
# usermod -aG sudo seuusuario
# su - seuusuario
```

### 3. Preparar Informações

Organize as informações necessárias em um arquivo de texto:

```bash
nano ~/info-instalacao.txt
```

Cole e preencha:

```
NOME DA VTC: 
ABREVIAÇÃO: 
DOMÍNIO (ou localhost): 
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

## 🚀 Execução

### Passo 1: Executar o Script

```bash
./install-drivershub.sh
```

### Passo 2: Seguir as Instruções

O script irá guiá-lo através de várias etapas:

#### 📋 Etapa 1: Informações da VTC
```
Nome completo da VTC: CDMP Express
Abreviação da VTC (ex: cdmp): cdmp
Domínio (deixe vazio para localhost): [Enter para localhost]
Porta do servidor [7777]: [Enter para usar 7777]
```

#### 🔐 Etapa 2: Banco de Dados
```
Senha para o banco de dados MySQL: ********
Confirme a senha: ********
```

💡 **Dica**: Use uma senha forte! O script validará se as senhas coincidem.

#### 🎮 Etapa 3: Discord & Steam
```
Discord Client ID: 1467955638989623468
Discord Client Secret: FnhXn1dZxDEi1YvkVBq954kVpan454Et
Discord Bot Token: MTQ2Nzk1NTYzODk4OTYyMzQ2OA.G1EIDK...
Discord Server (Guild) ID: 1465781784728830192
Steam API Key: DE8C49E18E84FF620514813E035F4BC5
```

💡 **Dica**: Copie e cole diretamente do Discord/Steam Developer Portal.

#### ⚙️ Etapa 4: Configurações Opcionais
```
Deseja instalar e configurar Nginx como proxy reverso? [s/N]: s
Deseja configurar SSL/HTTPS com Let's Encrypt? [s/N]: s
```

- **Nginx**: Recomendado se você tem um domínio
- **SSL**: Necessário para HTTPS (só funciona com domínio real)

#### 📊 Etapa 5: Confirmação

O script mostrará um resumo. Revise tudo e confirme:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VTC: CDMP Express (cdmp)
Domínio: localhost:7777
Porta: 7777
Banco de dados: MySQL (senha configurada)
Discord: 14679556...
Steam: DE8C49E1...
Nginx: y
SSL: n
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Confirma as informações acima e deseja continuar? [s/N]: s
```

### Passo 3: Aguardar

O script executará automaticamente:

```
[PASSO 3/10] ✅ Instalando dependências do sistema
[PASSO 4/10] ✅ Instalando e configurando MySQL
[PASSO 5/10] ✅ Instalando e configurando Redis
[PASSO 6/10] ✅ Clonando repositório do Drivers Hub
[PASSO 7/10] ✅ Configurando ambiente Python
[PASSO 8/10] ✅ Aplicando correção no código
[PASSO 9/10] ✅ Criando arquivo de configuração
[PASSO 10/10] ✅ Configurando serviço systemd
```

⏱️ **Tempo estimado**: 5-15 minutos (dependendo da conexão e hardware)

---

## ✅ Após a Instalação

### 1. Verificar Status

```bash
sudo systemctl status drivershub-cdmp
```

Deve mostrar: `Active: active (running)`

### 2. Configurar Discord Redirect URI

1. Acesse: https://discord.com/developers/applications
2. Selecione sua aplicação
3. Vá em **OAuth2 > Redirects**
4. Adicione a URL:
   - Sem domínio: `http://localhost:7777/cdmp/api/auth/discord/callback`
   - Com domínio: `http://seudominio.com/cdmp/api/auth/discord/callback`
   - Com SSL: `https://seudominio.com/cdmp/api/auth/discord/callback`
5. Salve as alterações

### 3. Convidar o Bot Discord

1. No Discord Developer Portal, vá em **OAuth2 > URL Generator**
2. Selecione os scopes:
   - ✅ `bot`
   - ✅ `applications.commands`
3. Selecione as permissões:
   - ✅ Administrator (recomendado)
4. Copie a URL gerada e abra no navegador
5. Selecione seu servidor e confirme

### 4. Acessar a Interface Web

Abra seu navegador e acesse:

- **Sem domínio**: `http://localhost:7777/cdmp`
- **Com domínio**: `http://seudominio.com`
- **Com SSL**: `https://seudominio.com`

### 5. Fazer Primeiro Login

1. Clique em **"Login com Discord"**
2. Autorize a aplicação
3. Você será redirecionado de volta ao Drivers Hub
4. Configure seu perfil e cargos no painel administrativo

---

## 🔧 Configurações Adicionais

### Configurar Webhooks do Discord

Para receber notificações de entregas, candidaturas, etc:

1. No seu servidor Discord, vá em um canal
2. Configurações do Canal > Integrações > Webhooks
3. Criar Webhook
4. Copie a URL do webhook
5. Edite o arquivo de configuração:

```bash
nano /opt/drivershub/HubBackend/config.json
```

Encontre e edite:

```json
"hook_delivery_log": {
    "channel_id": "ID_DO_CANAL",
    "webhook_url": "URL_DO_WEBHOOK_AQUI"
}
```

6. Reinicie o serviço:

```bash
sudo systemctl restart drivershub-cdmp
```

### Configurar IDs dos Cargos Discord

Para sincronizar cargos entre Discord e Drivers Hub:

1. No Discord, ative o Modo Desenvolvedor:
   - Configurações > Avançado > Modo Desenvolvedor
2. Clique com botão direito em um cargo > Copiar ID
3. Edite o config.json:

```json
"roles": [
    {
        "roleid": 1,
        "name": "Diretor",
        "discordrole": "ID_DO_CARGO_AQUI",
        "permissions": ["admin"]
    }
]
```

---

## 🆘 Solução de Problemas

### Serviço não inicia

```bash
# Ver logs completos
sudo journalctl -u drivershub-cdmp -n 100

# Ver status detalhado
sudo systemctl status drivershub-cdmp -l
```

**Causas comuns:**
- ❌ Porta já em uso
- ❌ Erro no config.json
- ❌ MySQL/Redis não rodando

**Solução:**
```bash
# Verificar portas
sudo lsof -i :7777

# Verificar MySQL
sudo systemctl status mysql

# Verificar Redis
sudo systemctl status redis-server

# Validar config.json
cd /opt/drivershub/HubBackend
python3 -m json.tool config.json
```

### Erro de conexão com banco de dados

```bash
# Testar conexão manualmente
mysql -u cdmp_user -p cdmp_db

# Verificar usuário e banco
sudo mysql -e "SHOW DATABASES;"
sudo mysql -e "SELECT User, Host FROM mysql.user;"
```

**Recriar banco e usuário:**
```bash
sudo mysql << EOF
DROP DATABASE IF EXISTS cdmp_db;
DROP USER IF EXISTS 'cdmp_user'@'localhost';
CREATE DATABASE cdmp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'cdmp_user'@'localhost' IDENTIFIED BY 'sua_senha';
GRANT ALL PRIVILEGES ON cdmp_db.* TO 'cdmp_user'@'localhost';
FLUSH PRIVILEGES;
EOF
```

### Discord login não funciona

1. **Verificar Redirect URI** no Discord Developer Portal
2. **Verificar domínio** no config.json
3. **Verificar bot** está no servidor
4. **Ver logs**:
```bash
sudo journalctl -u drivershub-cdmp -f
```

### Página não carrega

```bash
# Verificar se serviço está rodando
sudo systemctl status drivershub-cdmp

# Verificar logs do Nginx (se instalado)
sudo tail -f /var/log/nginx/error.log

# Testar porta diretamente
curl http://localhost:7777/cdmp
```

### Erro "Permission Denied"

```bash
# Corrigir permissões
sudo chown -R $USER:$USER /opt/drivershub

# Recriar ambiente virtual se necessário
cd /opt/drivershub/HubBackend
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## 📝 Comandos Úteis

### Gerenciamento do Serviço

```bash
# Ver status
sudo systemctl status drivershub-cdmp

# Iniciar
sudo systemctl start drivershub-cdmp

# Parar
sudo systemctl stop drivershub-cdmp

# Reiniciar
sudo systemctl restart drivershub-cdmp

# Recarregar configuração (após editar config.json)
sudo systemctl restart drivershub-cdmp

# Desabilitar inicialização automática
sudo systemctl disable drivershub-cdmp

# Habilitar inicialização automática
sudo systemctl enable drivershub-cdmp
```

### Logs

```bash
# Ver logs em tempo real
sudo journalctl -u drivershub-cdmp -f

# Ver últimas 100 linhas
sudo journalctl -u drivershub-cdmp -n 100

# Ver logs desde hoje
sudo journalctl -u drivershub-cdmp --since today

# Buscar erro específico
sudo journalctl -u drivershub-cdmp | grep ERROR
```

### Banco de Dados

```bash
# Acessar banco
mysql -u cdmp_user -p cdmp_db

# Backup do banco
mysqldump -u cdmp_user -p cdmp_db > backup_$(date +%Y%m%d).sql

# Restaurar backup
mysql -u cdmp_user -p cdmp_db < backup_20260217.sql

# Ver tabelas
mysql -u cdmp_user -p cdmp_db -e "SHOW TABLES;"

# Ver estatísticas
mysql -u cdmp_user -p cdmp_db -e "SELECT COUNT(*) FROM user;"
```

### Atualização

```bash
# Parar serviço
sudo systemctl stop drivershub-cdmp

# Atualizar código
cd /opt/drivershub/HubBackend
git pull

# Atualizar dependências
source venv/bin/activate
pip install -r requirements.txt --upgrade

# Reiniciar
sudo systemctl start drivershub-cdmp
```

### Nginx (se instalado)

```bash
# Ver status
sudo systemctl status nginx

# Testar configuração
sudo nginx -t

# Recarregar configuração
sudo systemctl reload nginx

# Ver logs de erro
sudo tail -f /var/log/nginx/error.log

# Ver logs de acesso
sudo tail -f /var/log/nginx/access.log
```

---

## 🔒 Segurança

### Firewall (Recomendado)

```bash
# Instalar UFW
sudo apt install -y ufw

# Permitir SSH (IMPORTANTE!)
sudo ufw allow 22/tcp

# Permitir HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Ou permitir apenas a porta do app (sem Nginx)
sudo ufw allow 7777/tcp

# Ativar firewall
sudo ufw enable

# Ver status
sudo ufw status
```

### Backups Automáticos

Criar script de backup:

```bash
nano ~/backup-drivershub.sh
```

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/$USER/backups"

mkdir -p $BACKUP_DIR

# Backup banco de dados
mysqldump -u cdmp_user -p'SENHA_AQUI' cdmp_db > $BACKUP_DIR/db_$DATE.sql

# Backup config
cp /opt/drivershub/HubBackend/config.json $BACKUP_DIR/config_$DATE.json

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.json" -mtime +7 -delete

echo "Backup concluído: $DATE"
```

```bash
chmod +x ~/backup-drivershub.sh

# Adicionar ao cron (backup diário às 3h)
crontab -e
```

Adicione:
```
0 3 * * * /home/seuusuario/backup-drivershub.sh
```

---

## 📚 Recursos Adicionais

### Documentação Oficial
- **Wiki**: https://wiki.charlws.com/books/chub
- **API Docs**: http://localhost:7777/cdmp/docs (após instalação)

### Comunidade
- **Discord Oficial**: https://discord.gg/wNTaaBZ5qd
- **Site**: https://drivershub.charlws.com

### Plugins e Extensões
- **TruckSim Tracker**: Para rastreamento automático de entregas
- **Plugins Adicionais**: Verifique a documentação oficial

---

## 🎯 Checklist Pós-Instalação

Use esta checklist para garantir que tudo está configurado:

- [ ] ✅ Serviço rodando (`systemctl status drivershub-cdmp`)
- [ ] ✅ Página web acessível
- [ ] ✅ Redirect URI configurado no Discord
- [ ] ✅ Bot Discord convidado e online
- [ ] ✅ Login com Discord funcionando
- [ ] ✅ Perfil de administrador configurado
- [ ] ✅ Cargos Discord sincronizados
- [ ] ✅ Webhooks configurados (opcional)
- [ ] ✅ Firewall configurado (recomendado)
- [ ] ✅ Backup automático configurado (recomendado)
- [ ] ✅ SSL/HTTPS funcionando (se aplicável)

---

## 💡 Dicas e Boas Práticas

### Performance
- Use SSD se possível
- Para muitos usuários (100+), considere aumentar RAM
- Configure cache no Redis se necessário

### Manutenção
- Faça backups regulares do banco de dados
- Monitore logs regularmente
- Mantenha o sistema atualizado
- Documente alterações de configuração

### Segurança
- Use senhas fortes
- Mantenha as chaves secretas seguras
- Configure firewall
- Use SSL em produção
- Monitore tentativas de acesso suspeitas

---

## 📞 Suporte

Se você encontrar problemas não listados aqui:

1. **Verifique os logs**: `sudo journalctl -u drivershub-cdmp -n 100`
2. **Consulte a Wiki**: https://wiki.charlws.com/books/chub
3. **Discord da Comunidade**: https://discord.gg/wNTaaBZ5qd
4. **GitHub Issues**: Reporte bugs no repositório oficial

---

## 📄 Licença

Este guia e script são fornecidos "como estão", sem garantias.

O **Drivers Hub** é copyright © 2022-2026 CharlesWithC, licenciado sob AGPL-3.0.

---

**Criado com ❤️ para a comunidade de transportadoras virtuais de ETS2/ATS**

🚚 Boa sorte com sua VTC! 🚛
