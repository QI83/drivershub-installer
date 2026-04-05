# 🔧 Guia do `reconfigure-drivershub.sh`

## O que é

O `reconfigure-drivershub.sh` permite alterar qualquer configuração do Drivers Hub **após a instalação**, sem precisar reinstalar do zero. Ele atualiza o `config.json`, o Nginx, o banco de dados e o state file de forma consistente e segura.

---

## Quando usar

| Situação | Opção no menu |
|---|---|
| Mudou o domínio (ex: obteve um domínio próprio) | 1 — Domínio |
| Bot Discord com token inválido / expirado | 2 — Credenciais Discord |
| Criou uma nova aplicação Discord | 2 — Credenciais Discord |
| Steam API Key expirou ou foi revogada | 3 — Steam API Key |
| Porta 7777 em conflito com outro serviço | 4 — Porta do backend |
| Quer ativar HTTPS em domínio já configurado | 5 — SSL / HTTPS |
| Renovar certificado SSL manualmente | 5 — SSL / HTTPS |
| Token do Cloudflare Tunnel expirou ou mudou | 6 — Cloudflare Tunnel |
| Quer testar se Discord e Steam estão funcionando | 7 — Validar credenciais |

---

## Como executar

```bash
bash scripts/reconfigure-drivershub.sh
```

> ⚠️ **Não execute como root.** O script pedirá `sudo` quando necessário.

Se houver múltiplas VTCs instaladas, o script exibirá um menu para escolher qual configurar:

```
Instalações encontradas:
  1) CDMP EXPRESS (cdmp) — minha-vtc.com.br
  2) Outra VTC (vtc2)    — vtc2.com.br

Escolha a VTC [1-2]:
```

---

## Menu de opções

```
╔═══════════════════════════════════════════════════════════════╗
║  VTC: CDMP EXPRESS (cdmp)                                     ║
║  Domínio: minha-vtc.com.br  |  Porta: 7777  |  SSL: y        ║
╚═══════════════════════════════════════════════════════════════╝

O que deseja reconfigurar?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1) Domínio                   — alterar domínio/URL do servidor
  2) Credenciais Discord        — Client ID, Secret, Bot Token, Guild ID
  3) Steam API Key              — chave de integração Steam
  4) Porta do backend           — porta em que o backend escuta
  5) SSL / HTTPS                — configurar ou renovar certificado
  6) Cloudflare Tunnel          — reconfigurar token do tunnel
  7) Validar credenciais agora  — testar Discord e Steam
  8) Sair
```

---

## O que cada opção faz

### Opção 1 — Domínio

Altera o domínio e atualiza automaticamente:

- Campo `domain` e `frontend_urls` no `config.json`
- `server_name` na configuração do Nginx
- `api_host` na tabela `settings` do banco de dados
- Cache Redis limpo para refletir a mudança imediatamente
- Oferece configurar SSL (Let's Encrypt) para o novo domínio

### Opção 2 — Credenciais Discord

Atualiza uma ou mais credenciais. Pressione Enter para manter o valor atual de cada campo:

| Campo | Onde obter |
|---|---|
| Client ID | [discord.com/developers](https://discord.com/developers/applications) → sua app |
| Client Secret | OAuth2 → General → Reset Secret |
| Bot Token | Bot → Reset Token |
| Guild ID | Discord → botão direito no servidor → Copiar ID |

> Após salvar, o script exibe o **Redirect URI** correto — adicione-o em **OAuth2 → Redirects** no portal.

### Opção 3 — Steam API Key

Atualiza a chave Steam. Obtenha uma nova em [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey).

### Opção 4 — Porta do backend

Altera a porta TCP do backend (padrão: `7777`). Atualiza `server_port` no `config.json` e `proxy_pass` no Nginx.

> Verifique se a nova porta está livre: `sudo ss -lntp | grep NOVA_PORTA`

### Opção 5 — SSL / HTTPS

Configura ou renova o certificado via **Let's Encrypt** (Certbot). Requer que o domínio já aponte para o IP do servidor. Não se aplica ao Cenário 3 (Cloudflare gerencia SSL automaticamente).

### Opção 6 — Cloudflare Tunnel

Reinstala o `cloudflared` com um novo token. Use quando o token expirou ou você criou um novo tunnel.

**Como obter o token:**
1. [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → **Networks → Tunnels**
2. Selecione seu tunnel → **Configure** → copie o token

### Opção 7 — Validar credenciais

Testa as credenciais atuais **sem alterar nada**:

- Discord Bot Token via `GET /users/@me`
- Discord Client ID + Secret via `POST /oauth2/token`
- Steam API Key via `GetSupportedAPIList`

---

## O que é preservado em todas as operações

- Banco de dados e dados dos usuários
- Senha do banco de dados (`db_password`)
- `secret_key` (chave de sessão)
- Configurações de cargos, ranks, plugins e webhooks

---

## Fluxo automático após cada alteração

Para todas as opções (exceto Validar), o script executa automaticamente:

1. Atualiza `config.json` com permissões `600`
2. Atualiza configuração do Nginx (se aplicável)
3. Atualiza `api_host` no banco de dados
4. Limpa cache Redis (`client-config:meta`)
5. Reinicia o serviço `drivershub-{sigla}`
6. Salva o novo estado em `/opt/drivershub/.installer_state_{sigla}`

---

## Exemplos de uso

### Migrar de localhost para domínio com SSL

```bash
bash scripts/reconfigure-drivershub.sh
# → 1) Domínio → Digite: minha-vtc.com.br
# → Deseja configurar SSL? [S/n]: s
```

Depois adicione no Discord Developer Portal (OAuth2 → Redirects):
```
https://minha-vtc.com.br/auth/discord/callback
```

### Renovar token do bot Discord

```bash
bash scripts/reconfigure-drivershub.sh
# → 2) Credenciais Discord
# → Bot Token: [cole o novo token]
# → Demais campos: [Enter para manter]
```

### Verificar se as credenciais estão válidas

```bash
bash scripts/reconfigure-drivershub.sh
# → 7) Validar credenciais agora
```

### Mudar a porta do backend

```bash
bash scripts/reconfigure-drivershub.sh
# → 4) Porta do backend → Nova porta: 7778
```

---

## Solução de problemas

**"Nenhuma instalação encontrada"**
```bash
ls /opt/drivershub/.installer_state*
# Se não existir: bash scripts/install-drivershub.sh
```

**Nginx retorna erro após alterar domínio**
```bash
sudo nginx -t
sudo journalctl -u nginx -n 20
```

**Serviço não reinicia após reconfiguração**
```bash
sudo journalctl -u drivershub-[SIGLA] -n 30 --no-pager
```

**Certificado SSL falha**
```bash
# Verificar se o domínio aponta para este servidor
dig minha-vtc.com.br +short
# Deve retornar o IP do servidor
```
