# 🤝 Contribuindo para o Drivers Hub Installer

Obrigado por considerar contribuir! Este projeto é feito por e para a comunidade de transportadoras virtuais de ETS2/ATS, e toda ajuda é bem-vinda.

---

## 📋 Índice

- [Antes de começar](#-antes-de-começar)
- [Como contribuir](#-como-contribuir)
- [Estrutura do projeto](#-estrutura-do-projeto)
- [Padrões de código Bash](#-padrões-de-código-bash)
- [Testando suas mudanças](#-testando-suas-mudanças)
- [Convenção de commits](#-convenção-de-commits)
- [Reportar bugs](#-reportar-bugs)
- [Sugerir melhorias](#-sugerir-melhorias)
- [Áreas que precisam de ajuda](#-áreas-que-precisam-de-ajuda)

---

## 🚀 Antes de começar

- Todo o projeto é escrito em **Bash Shell** — contribuições em outra linguagem só são aceitas se houver motivo técnico que justifique (ex: Python para manipulação de JSON, como já usado no projeto)
- Leia o [README.md](README.md) e o [GUIA_INSTALACAO.md](docs/GUIA_INSTALACAO.md) para entender o que o projeto faz
- Verifique as [Issues abertas](../../issues) para não duplicar trabalho em andamento
- Para mudanças grandes, abra uma Issue primeiro para discutir antes de implementar

---

## 🛠️ Como contribuir

```bash
# 1. Fork o repositório e clone o seu fork
git clone https://github.com/SEU_USUARIO/drivershub-installer.git
cd drivershub-installer

# 2. Crie uma branch descritiva
git checkout -b fix/mysql-timeout-conexao
# ou
git checkout -b feat/suporte-debian-12

# 3. Faça suas alterações e rode o ShellCheck
shellcheck -S warning scripts/*.sh

# 4. Commit seguindo a convenção
git commit -m "fix: corrigir timeout de conexão MySQL após idle"

# 5. Push e abra um Pull Request
git push origin fix/mysql-timeout-conexao
```

---

## 📁 Estrutura do projeto

```
drivershub-installer/
├── scripts/
│   ├── install-drivershub.sh    ← Instalador do backend (principal)
│   ├── install-frontend.sh      ← Instalador do frontend
│   ├── reconfigure-drivershub.sh← Reconfiguração pós-instalação
│   ├── update-drivershub.sh     ← Atualização de backend/frontend
│   ├── backup-drivershub.sh     ← Backup e restauração do banco
│   ├── health-check.sh          ← Monitoramento com webhook Discord
│   ├── verificar-instalacao.sh  ← Verificação pós-instalação
│   └── uninstall-drivershub.sh  ← Desinstalação completa
├── docs/
│   ├── GUIA_INSTALACAO.md       ← Guia completo de instalação
│   ├── GUIA_RECONFIGURE.md      ← Guia do reconfigure
│   ├── GUIA_HEALTH_CHECK.md     ← Guia do health check
│   └── TROUBLESHOOTING.md       ← Solução de problemas
├── README.md
└── CONTRIBUTING.md
```

### Arquivos de estado (gerados em runtime)

```
/opt/drivershub/
├── .installer_state_{sigla}     ← Estado da instalação por VTC
├── .healthcheck_{sigla}         ← Config do health check por VTC
├── .healthcheck_state_{sigla}   ← Estado atual do health check
└── health-check.log             ← Log de monitoramento
```

---

## 📝 Padrões de código Bash

### Obrigatórios

**ShellCheck sem warnings** — todo script deve passar sem avisos:
```bash
shellcheck -S warning scripts/nome-do-script.sh
```

**Cabeçalho padrão** em todo script:
```bash
#!/bin/bash

################################################################################
# Descrição do Script
# Versão: X.Y.Z
# Data: Mês Ano
################################################################################

set -e
set -o pipefail
```

**Variáveis sempre entre aspas:**
```bash
# ✅ Correto
cd "$INSTALL_DIR"
echo "$VTC_NAME"

# ❌ Errado
cd $INSTALL_DIR
echo $VTC_NAME
```

**Funções com nomes descritivos em snake_case:**
```bash
# ✅ Correto
install_mysql() { ... }
fix_database_code() { ... }

# ❌ Evitar
installMySQL() { ... }
fix() { ... }
```

**Manipulação de JSON sempre via Python**, nunca com `grep`/`sed`/`cut`:
```bash
# ✅ Correto
DB_PASS=$(python3 -c "
import json
d = json.load(open('config.json'))
print(d.get('db_password', ''))
" 2>/dev/null || echo "")

# ❌ Frágil e propenso a erros
DB_PASS=$(grep db_password config.json | cut -d'"' -f4)
```

**Patches em arquivos Python via `python3`**, nunca com `sed` para código complexo:
```bash
# ✅ Correto — cobre variações de aspas e espaçamento
python3 - arquivo.py << 'PYEOF'
with open(sys.argv[1]) as f:
    content = f.read()
patched = content.replace('padrão_antigo', 'padrão_novo')
with open(sys.argv[1], 'w') as f:
    f.write(patched)
PYEOF

# ❌ Frágil — quebra com variações mínimas no arquivo
sed -i "s/padrão_antigo/padrão_novo/g" arquivo.py
```

**Verificações de erro explícitas** em operações críticas:
```bash
# ✅ Correto
if ! sudo mysql -e "USE ${VTC_ABBR}_db;" 2>/dev/null; then
    print_error "Falha ao acessar banco de dados"
    exit 1
fi

# ❌ Silencia erros críticos
sudo mysql -e "USE ${VTC_ABBR}_db;" 2>/dev/null || true
```

### Funções de output padronizadas

Use sempre as funções já definidas nos scripts:

```bash
print_info    "mensagem informativa"    # cyan  ℹ️
print_success "operação concluída"      # green ✅
print_warning "atenção: algo a checar"  # yellow ⚠️
print_error   "falha crítica"           # red   ❌
print_step N TOTAL "descrição do passo" # cabeçalho de passo
```

### Compatibilidade

- Testar em **Ubuntu 20.04+** e **Debian 11+**
- Não usar recursos exclusivos do Bash 5.x sem verificar disponibilidade
- Evitar dependências externas não instaladas pelo script (verificar com `command -v`)

---

## 🧪 Testando suas mudanças

### Ambiente de teste recomendado

```bash
# VM ou container Ubuntu 24.04 limpo
# Mínimo: 2GB RAM, 10GB disco

# Testar instalação limpa
bash scripts/install-drivershub.sh

# Testar reinstalação (modo reparo)
bash scripts/install-drivershub.sh
# → Selecione: r) Reparar instalação

# Testar nova instalação sobre existente
bash scripts/install-drivershub.sh
# → Selecione: n) Nova instalação
```

### Checklist antes do Pull Request

```
[ ] shellcheck -S warning scripts/*.sh passa sem erros
[ ] Testado em instalação limpa (Ubuntu 20.04+ ou Debian 11+)
[ ] Testado em reinstalação (modo reparo funciona)
[ ] bash scripts/verificar-instalacao.sh retorna 0 erros
[ ] Documentação atualizada (se necessário)
[ ] Sem credenciais, tokens ou senhas no código
[ ] Sem dados específicos da sua VTC nos exemplos
```

### Testar um script específico

```bash
# Verificar script com ShellCheck
shellcheck -S warning scripts/install-drivershub.sh

# Executar em modo debug para ver cada comando
bash -x scripts/install-drivershub.sh 2>&1 | head -100
```

---

## 📌 Convenção de commits

Use o formato **Conventional Commits**:

```
tipo: descrição curta em minúsculas (máx. 72 chars)
```

| Tipo | Quando usar |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Alteração apenas em documentação |
| `refactor` | Refatoração sem mudança de comportamento |
| `test` | Adição ou correção de testes |
| `chore` | Tarefas de manutenção (atualizar versão, etc.) |

**Exemplos:**
```bash
git commit -m "feat: adicionar suporte ao Debian 12"
git commit -m "fix: corrigir patch DATA DIRECTORY para MySQL 8.4+"
git commit -m "docs: adicionar exemplos de multi-VTC no GUIA_INSTALACAO"
git commit -m "refactor: substituir grep/cut por python3 json.load no reconfigure"
git commit -m "chore: bump versão para 1.3.1"
```

---

## 🐛 Reportar bugs

Abra uma [Issue](../../issues/new) e inclua:

**Informações obrigatórias:**
```bash
# Cole o output deste comando na issue
(
  echo "=== SISTEMA ===" && uname -a && lsb_release -a 2>/dev/null
  echo "=== SERVICOS ===" && sudo systemctl status drivershub-[SIGLA] --no-pager 2>&1
  echo "=== LOGS ===" && sudo journalctl -u drivershub-[SIGLA] -n 50 --no-pager 2>&1
  echo "=== VERIFICACAO ===" && bash scripts/verificar-instalacao.sh 2>&1
) > ~/bug-report.txt && cat ~/bug-report.txt
```

**Template da issue:**
```
**Versão do instalador:** 1.3.0
**Ubuntu/Debian:** Ubuntu 24.04
**MySQL:** 8.0.x / 8.4.x
**Script com problema:** install-drivershub.sh / reconfigure / etc.

**Comportamento esperado:**
O que deveria acontecer.

**Comportamento observado:**
O que aconteceu de fato.

**Passos para reproduzir:**
1. ...
2. ...

**Logs relevantes:**
(cole aqui o output do comando acima)
```

> ⚠️ **Nunca** inclua tokens Discord, Steam API Keys, senhas ou dados de usuários na issue.

---

## 💡 Sugerir melhorias

Abra uma [Issue](../../issues/new) com o label `enhancement` e descreva:

- **O problema que resolve** — por que essa melhoria é útil?
- **Como funcionaria** — comportamento esperado
- **Alternativas consideradas** — outras formas de resolver
- **Impacto em instalações existentes** — quebra compatibilidade?

---

## 🎯 Áreas que precisam de ajuda

Se quiser contribuir mas não sabe por onde começar:

| Área | Dificuldade | Descrição |
|---|---|---|
| **Testes em Debian 11/12** | 🟢 Fácil | Validar e reportar bugs em Debian |
| **Testes com MySQL 8.4+** | 🟢 Fácil | Confirmar compatibilidade |
| **Melhorar mensagens de erro** | 🟢 Fácil | Tornar mensagens mais claras e acionáveis |
| **Tradução da documentação** | 🟡 Médio | EN, ES para alcançar mais VTCs |
| **GitHub Actions / ShellCheck CI** | 🟡 Médio | Automatizar verificação em PRs |
| **Suporte ao Cenário 2 com Namecheap/Cloudflare DNS** | 🟡 Médio | Alternativas ao DuckDNS |
| **Backup para Google Drive / S3** | 🔴 Difícil | Destinos remotos para backup |
| **Interface TUI (whiptail/dialog)** | 🔴 Difícil | Menus mais visuais no terminal |

---

## 📄 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a mesma [Licença MIT](LICENSE) do projeto.

---

**Dúvidas?** Abra uma [Discussion](../../discussions) ou entre no [Discord da comunidade](https://discord.gg/wNTaaBZ5qd). 🚚
