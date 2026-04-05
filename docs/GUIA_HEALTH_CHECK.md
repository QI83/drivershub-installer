# 🏥 Guia do `health-check.sh`

## O que é

O `health-check.sh` monitora os serviços do Drivers Hub e envia **notificações automáticas via Discord webhook** quando algo para de funcionar ou se recupera. Pode ser executado em modo interativo (configuração) ou em modo automático via cron.

---

## O que é monitorado

A cada verificação, o script testa **5 componentes**:

| Componente | O que verifica |
|---|---|
| **Serviço systemd** | `drivershub-{sigla}` está ativo? |
| **Porta do backend** | A porta configurada está escutando? |
| **Resposta HTTP** | O backend responde em `http://localhost:{porta}/{sigla}`? |
| **MySQL** | Serviço `mysql` ou `mysqld` está ativo? |
| **Redis** | `redis-cli ping` responde `PONG`? |

Se qualquer um desses falhar, uma notificação é enviada ao Discord e o script tenta **reiniciar o serviço** automaticamente.

---

## Como funciona

```
Cron (a cada 5min)
      │
      ▼
health-check.sh --run [SIGLA]
      │
      ├── check_service() ──► todos OK?
      │         │
      │         ├── SIM: salva estado "ok"
      │         │         └── era "down"? → envia notificação de RECUPERAÇÃO ✅
      │         │
      │         └── NÃO: salva estado "down"
      │                   ├── era "ok"? → envia notificação de PROBLEMA 🚨
      │                   └── tenta reiniciar o serviço automaticamente
      │
      └── registra em /opt/drivershub/health-check.log
```

> **Importante:** a notificação de problema é enviada apenas **na primeira detecção** — se o serviço continua down nas verificações seguintes, não envia spam. A notificação de recuperação é enviada quando o serviço volta.

---

## Notificações Discord

### Alerta de problema (🚨)

```
🚨 DriversHub OFFLINE — CDMP EXPRESS (cdmp)

Servidor: `minha-vtc.com.br`

Problemas detectados:
  Serviço systemd drivershub-cdmp.service está INATIVO
  Porta 7777 não está escutando

Verifique com: sudo journalctl -u drivershub-cdmp -n 30
```

### Notificação de recuperação (✅)

```
✅ DriversHub RECUPERADO — CDMP EXPRESS (cdmp)

Servidor: `minha-vtc.com.br`

O serviço voltou a funcionar normalmente.
```

---

## Configuração inicial

```bash
bash scripts/health-check.sh
```

### Menu interativo

```
╔═══════════════════════════════════════════════════════════════╗
║  VTC: CDMP EXPRESS (cdmp) — minha-vtc.com.br                 ║
║  Webhook: não configurado                                     ║
╚═══════════════════════════════════════════════════════════════╝

O que deseja fazer?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Configurar webhook e frequência de verificação
  2) Verificar serviços agora
  3) Ver log de health checks
  4) Sair
```

### Passo a passo da configuração

**1. Criar o webhook no Discord:**
1. Acesse seu servidor Discord
2. Clique em **Editar Canal** no canal onde quer receber alertas
3. Vá em **Integrações → Webhooks → Novo Webhook**
4. Dê um nome (ex: "DriversHub Monitor")
5. Clique em **Copiar URL do Webhook**

**2. Configurar no script:**
```bash
bash scripts/health-check.sh
# → 1) Configurar webhook e frequência de verificação
# → Cole a URL do webhook
# → Escolha a frequência:
#     1) A cada 5 minutos (recomendado)
#     2) A cada 10 minutos
#     3) A cada 1 minuto (gera muito log)
#     4) Desativar
```

Após configurar, uma mensagem de teste é enviada ao Discord automaticamente para confirmar que o webhook está funcionando.

---

## Frequências disponíveis

| Opção | Intervalo | Cron gerado | Ideal para |
|---|---|---|---|
| 1 | 5 minutos | `*/5 * * * *` | Produção (recomendado) |
| 2 | 10 minutos | `*/10 * * * *` | Servidores com recursos limitados |
| 3 | 1 minuto | `* * * * *` | Debug temporário |
| 4 | Desativado | — | Remover monitoramento |

---

## Modos de execução

### Modo interativo (configuração)

```bash
bash scripts/health-check.sh
```

Abre o menu para configurar webhook, frequência e verificações manuais.

### Modo cron (verificação automática)

```bash
# Verificar todas as VTCs detectadas automaticamente
bash scripts/health-check.sh --run

# Verificar uma VTC específica
bash scripts/health-check.sh --run cdmp
```

Este modo é usado pelo cron e não exibe interface. Registra resultado em `/opt/drivershub/health-check.log`.

### Verificação manual imediata

```bash
bash scripts/health-check.sh
# → 2) Verificar serviços agora
```

Ou diretamente:
```bash
bash scripts/health-check.sh --run cdmp
```

---

## Arquivos gerados

| Arquivo | Conteúdo |
|---|---|
| `/opt/drivershub/.healthcheck_{sigla}` | Configuração: webhook URL, notificações ativadas |
| `/opt/drivershub/.healthcheck_state_{sigla}` | Estado atual: `ok` ou `down` |
| `/opt/drivershub/health-check.log` | Log de todas as verificações |

### Exemplo do log

```
Thu Apr 03 03:00:01 UTC 2026: OK cdmp todos os serviços funcionando
Thu Apr 03 03:05:01 UTC 2026: OK cdmp todos os serviços funcionando
Thu Apr 03 03:10:01 UTC 2026: DOWN cdmp: Serviço systemd drivershub-cdmp.service está INATIVO
Thu Apr 03 03:10:02 UTC 2026: RESTART tentando reiniciar drivershub-cdmp.service
Thu Apr 03 03:15:01 UTC 2026: RECOVERY cdmp voltou a funcionar
Thu Apr 03 03:15:01 UTC 2026: OK cdmp todos os serviços funcionando
```

### Ver log

```bash
# Via menu
bash scripts/health-check.sh
# → 3) Ver log de health checks

# Ou diretamente
tail -50 /opt/drivershub/health-check.log

# Filtrar apenas problemas
grep -E 'DOWN|RESTART|RECOVERY' /opt/drivershub/health-check.log
```

---

## Gerenciar o cron manualmente

```bash
# Ver o cron configurado
crontab -l | grep health-check

# Resultado esperado:
# */5 * * * * /caminho/health-check.sh --run cdmp >> /opt/drivershub/health-check.log 2>&1

# Remover o monitoramento manualmente
crontab -l | grep -v "health-check.*cdmp" | crontab -

# Reconfigurar frequência
bash scripts/health-check.sh
# → 1) Configurar webhook e frequência
```

---

## Multi-VTC

Em servidores com múltiplas VTCs, cada uma tem seu próprio monitoramento independente:

```bash
# Configurar para a segunda VTC
bash scripts/health-check.sh
# → Selecione vtc2
# → 1) Configurar webhook e frequência

# Verificar VTC específica
bash scripts/health-check.sh --run vtc2
```

Cada VTC terá sua própria entrada no cron e seus próprios arquivos de estado e configuração.

---

## Solução de problemas

**Webhook não envia mensagens**
```bash
# Testar o webhook manualmente
curl -X POST "URL_DO_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d '{"content": "Teste manual"}'
# Deve retornar HTTP 204
```

**Cron não está executando**
```bash
# Verificar se o cron está ativo
sudo systemctl status cron

# Ver log do cron
grep CRON /var/log/syslog | tail -20
```

**Notificações repetidas (spam)**
```bash
# Verificar o arquivo de estado
cat /opt/drivershub/.healthcheck_state_cdmp
# Se contiver "down" mas o serviço está ok, resetar:
echo "ok" > /opt/drivershub/.healthcheck_state_cdmp
```

**Serviço reinicia mas volta a cair**
```bash
# Ver logs detalhados do backend
sudo journalctl -u drivershub-[SIGLA] -n 50 --no-pager
# Consulte o TROUBLESHOOTING.md para o erro específico
```
