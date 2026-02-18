# 🚚 Drivers Hub - Instalador Automático

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> **Instalador automatizado completo do Drivers Hub Backend para transportadoras virtuais de Euro Truck Simulator 2 e American Truck Simulator.**

[🚀 Instalação Rápida](#-instala%C3%A7%C3%A3o-r%C3%A1pida) • [📖 Documentação](#-documenta%C3%A7%C3%A3o
) • [🆘 Suporte](#-suporte) • [🤝 Contribuir](#-contribuindo)

---

## 📸 Screenshots

```
╔═══════════════════════════════════════════════════════════════╗
║          INSTALADOR AUTOMÁTICO - DRIVERS HUB                  ║
╚═══════════════════════════════════════════════════════════════╝

[PASSO 3/10] ✅ Instalando dependências do sistema
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  Instalando Python e ferramentas de desenvolvimento...
✅ Dependências do sistema instaladas
```

---

## ✨ Características

- 🎯 **Instalação Zero-Config** - Responda algumas perguntas e pronto!
- 🔧 **Totalmente Automatizado** - Instala tudo: Python, MariaDB, Redis, Nginx
- 🎨 **Interface Amigável** - Cores, emojis e feedback visual
- ✅ **Validação Robusta** - Verifica cada passo antes de continuar
- 🔒 **Seguro** - Senhas confirmadas, validação de inputs
- 📊 **Script de Verificação** - Testa se tudo está funcionando
- 📚 **Documentação Completa** - Guias detalhados inclusos
- 🐛 **Troubleshooting** - Soluções para problemas comuns

---

## 🚀 Instalação Rápida

### Pré-requisitos

- **Sistema**: Ubuntu 20.04+ ou Debian 11+
- **Hardware**: 2 CPU cores, 2GB RAM, 10GB disco
- **Acesso**: Usuário normal com sudo (NÃO root!)
- **Internet**: Conexão estável

### Informações Necessárias

Antes de começar, tenha em mãos:

- 🎮 **Discord**: Client ID, Client Secret, Bot Token, Server ID
- 🎮 **Steam**: API Key
- 📋 **VTC**: Nome, abreviação, domínio (opcional)

### Instalação

```bash
# 1. Baixar o instalador
wget https://raw.githubusercontent.com/KIQ09/drivershub-installer/main/scripts/install-drivershub.sh

# 2. Dar permissão de execução
chmod +x install-drivershub.sh

# 3. Executar
./install-drivershub.sh
```

⏱️ **Tempo de instalação**: 5-15 minutos

---

## 📖 Documentação

### 📚 Guias Disponíveis

| Guia | Descrição | Link |
|------|-----------|------|
| 🚀 **Início Rápido** | Comece aqui! | [README.txt](README.txt) |
| 📖 **Guia Completo** | Documentação detalhada | [GUIA_INSTALACAO.md](docs/GUIA_INSTALACAO.md) |
| 🔧 **Troubleshooting** | Solução de problemas | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

### 🛠️ Scripts Inclusos

| Script | Descrição |
|--------|-----------|
| `install-drivershub.sh` | Instalador principal automatizado |
| `verificar-instalacao.sh` | Verifica se tudo está funcionando |

---

## 🎯 O Que o Script Faz

### Instalação Automática de:

- ✅ Python 3 e ferramentas de desenvolvimento
- ✅ MariaDB com banco de dados configurado
- ✅ Redis para cache
- ✅ Drivers Hub Backend (clone do repositório oficial)
- ✅ Ambiente virtual Python com dependências
- ✅ Arquivo `config.json` personalizado
- ✅ Correções necessárias no código
- ✅ Serviço systemd para inicialização automática
- ✅ Nginx como proxy reverso (opcional)
- ✅ SSL/HTTPS com Let's Encrypt (opcional)

### Configuração Automática de:

- 🔐 Usuário e banco de dados MariaDB
- 🔑 Integração Discord e Steam
- 🌐 Domínio e portas
- 📝 Arquivo de configuração completo
- 🔄 Serviço de inicialização automática

---

## 📋 Uso

### Comandos Principais

```bash
# Ver status do serviço
sudo systemctl status drivershub-[SIGLA]

# Ver logs em tempo real
sudo journalctl -u drivershub-[SIGLA] -f

# Reiniciar serviço
sudo systemctl restart drivershub-[SIGLA]

# Verificar instalação
./verificar-instalacao.sh
```

### Acesso

Após instalação, acesse:

- **Sem domínio**: `http://localhost:7777/[sigla]`
- **Com domínio**: `http://seudominio.com`
- **Com SSL**: `https://seudominio.com`

---

## 🔧 Configuração Pós-Instalação

### 1. Discord Redirect URI

Configure no [Discord Developer Portal](https://discord.com/developers/applications):

```
http://localhost:7777/[SIGLA]/api/auth/discord/callback
```

Ou use seu domínio:

```
https://seudominio.com/[SIGLA]/api/auth/discord/callback
```

### 2. Convidar Bot Discord

1. OAuth2 > URL Generator
2. Selecione: `bot` + `applications.commands`
3. Permissões: Administrator
4. Copie a URL e abra no navegador
5. Selecione seu servidor

---

## 🆘 Suporte

### Documentação Oficial do Drivers Hub

- 📖 **Wiki**: https://wiki.charlws.com/books/chub
- 💬 **Discord**: https://discord.gg/wNTaaBZ5qd
- 🌐 **Site**: https://drivershub.charlws.com

### Problemas Comuns

Consulte o [Guia de Troubleshooting](docs/TROUBLESHOOTING.md) para soluções de problemas comuns:

- ❌ Serviço não inicia
- ❌ Erro de conexão com banco de dados
- ❌ Discord login não funciona
- ❌ Página não carrega
- E muito mais...

### Reportar Bugs

Encontrou um bug? [Abra uma issue](../../issues/new)!

---

## 🤝 Contribuindo

Contribuições são bem-vindas! 

### Como Contribuir

1. Fork este repositório
2. Crie uma branch: `git checkout -b minha-feature`
3. Commit suas mudanças: `git commit -m 'Adiciona nova feature'`
4. Push para a branch: `git push origin minha-feature`
5. Abra um Pull Request

### Diretrizes

- Mantenha o código limpo e comentado
- Teste suas mudanças
- Atualize a documentação se necessário
- Siga o estilo de código existente

---

## 📝 Changelog

### [1.0.0] - 2026-02-17

#### Adicionado
- ✨ Script de instalação automatizado
- 📖 Documentação completa
- 🔧 Script de verificação
- 🐛 Guia de troubleshooting
- 🎨 Interface colorida e interativa

---

## 🔒 Segurança

### Boas Práticas

- 🔐 Use senhas fortes
- 🔒 Configure firewall
- 🌐 Use SSL em produção
- 💾 Faça backups regulares
- 📊 Monitore logs

### Reportar Vulnerabilidades

Encontrou uma vulnerabilidade de segurança? **NÃO abra uma issue pública.**

Envie um email para: [kiq.reis09@gmail.com]

---

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

### Drivers Hub Backend

O [Drivers Hub Backend](https://github.com/CharlesWithC/HubBackend) é copyright © 2022-2026 CharlesWithC, licenciado sob AGPL-3.0.

---

## 👥 Autores

- **Caique Reis** - *Criador do instalador automatizado* - [@KIQ09](https://github.com/KIQ09)

### Agradecimentos

- [CharlesWithC](https://github.com/CharlesWithC) - Criador do Drivers Hub
- Comunidade ETS2/ATS
- Todos os contribuidores

---

## 🌟 Star History

Se este projeto te ajudou, considere dar uma ⭐!

[![Star History](https://api.star-history.com/svg?repos=KIQ09/drivershub-installer&type=Date)](https://star-history.com/#KIQ09/drivershub-installer&Date)

---

## 📊 Estatísticas

![GitHub repo size](https://img.shields.io/github/repo-size/KIQ09/drivershub-installer)
![GitHub issues](https://img.shields.io/github/issues/KIQ09/drivershub-installer)
![GitHub pull requests](https://img.shields.io/github/issues-pr/KIQ09/drivershub-installer)
![GitHub last commit](https://img.shields.io/github/last-commit/KIQ09/drivershub-installer)

---

<div align="center">

**Feito com ❤️ para a comunidade de transportadoras virtuais ETS2/ATS**

[⬆ Voltar ao topo](#-drivers-hub---instalador-automático)

</div>
