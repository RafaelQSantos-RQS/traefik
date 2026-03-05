# Projeto Traefik: Proxy Reverso como Serviço

<p align="center"><img src="https://doc.traefik.io/traefik/assets/images/logo-traefik-proxy-logo.svg" width="auto" height="200px" alt="Traefik Logo"></p>

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/traefik-%232496ed.svg?style=for-the-badge&logo=traefikmesh&logoColor=white)

## 📜 Visão Geral

Este projeto implanta uma instância do **Traefik Proxy** conteinerizada, pronta para operar como o ponto de entrada (edge router) da sua infraestrutura. O foco é ser uma solução robusta, segura e de fácil manutenção para ambientes on-premise.

A complexidade da gestão é abstraída por um `Makefile`, que serve como uma interface de controle padronizada, garantindo que as operações de setup, deploy e manutenção sejam consistentes e previsíveis.

**Versão do Traefik:** v3.6.9

---

## 📑 Índice Rápido

### 🚀 Começar Agora
- [⚡ Guia Rápido de Deployment](#-guia-rápido-de-deployment) - Setup em 5 minutos
- [✅ Pré-requisitos](#-pré-requisitos) - O que você precisa

### 🏗️ Entender a Arquitetura
- [🏗️ Arquitetura](#-arquitetura) - Como funciona
- [🔑 Secrets vs Configs](#-secrets-vs-configs-entendendo-a-diferença) - Diferenças importantes
- [⚙️ Docker Configs para Arquivo de Configuração](#️-docker-configs-para-arquivo-de-configuração) - Como usar configs

### 🔧 Modos de Deploy
- [🐳 Modo Docker Compose (Standalone)](#-modo-docker-compose-standalone)
- [🐝 Modo Docker Swarm](#-modo-docker-swarm)

### 📋 Gerenciamento
- [👥 Gestão de Usuários](#-gestão-de-usuários)
- [🔒 Certificados SSL/TLS](#-certificados-ssltls)
- [📊 Dashboard e Métricas](#-dashboard-e-métricas)

### 🛠️ Referência
- [🧰 Comandos Makefile](#-comandos-makefile)
- [☁️ Configurando Serviços](#️-configurando-serviços-para-usar-o-traefik)
- [🔧 Troubleshooting](#-troubleshooting)

---

## ⚡ Guia Rápido de Deployment

### Para Docker Compose (Standalone)

```bash
# 1. Setup (cria arquivos de configuração)
make setup

# 2. Editar .env conforme necessário
vim .env

# 3. Iniciar
make compose-up

# 4. Acessar dashboard
# https://traefik.seudominio.com.br/dashboard/
```

### Para Docker Swarm (Cluster)

```bash
# 1. Setup
make setup

# 2. Criar rede overlay (se não existir)
# O Makefile cria automaticamente com make setup

# 3. Criar secrets e configs (certificados + credenciais)
make swarm-create-secrets
make swarm-create-configs

# 4. Deploy
make swarm-deploy

# 5. Acessar dashboard
# https://traefik.seudominio.com.br/dashboard/
```

---

## 🏗️ Arquitetura

### Fluxo de Tráfego

```
INTERNET ───> [Portas 80, 443] ───> TRAEFIK ───> REDE OVERLAY ───> SERVIÇO-ALVO
(HTTPS)                              (TLS Termination)     (Docker Swarm)
                                            │
                                            └──> Dashboard (Basic Auth)
```

### Modos de Deploy

| Modo | Comando | Uso Ideal | Gerenciamento |
|------|---------|-----------|---|
| **Docker Compose** | `make compose-up` | Desenvolvimento, single-node | Volumes locais |
| **Docker Swarm** | `make swarm-deploy` | Produção, multi-node | Secrets + Configs |

---

## 🔑 Secrets vs Configs: Entendendo a Diferença

### O Problema: Como distribuir dados em um Swarm?

Em um Docker Swarm com múltiplos nós, você precisa:

1. **Distribuir configurações** (traefik.yaml, dynamic.yaml) → Usar **Configs**
2. **Proteger dados sensíveis** (senhas, chaves) → Usar **Secrets**

### Docker Secrets

**Para:** Dados sensíveis que precisam ser **protegidos**

```bash
# Criar
docker secret create TRAEFIK_CREDENTIALS config/credentials
docker secret create TRAEFIK_SENAICIMATEC_KEY certs/senaicimatec_com_br/key.pem

# Características
✅ Criptografados em repouso no Swarm
✅ Apenas nós que precisam recebem o dado
✅ Impossível recuperar o valor depois de criado
✅ Requer recreação para atualizar
```

**Dados sensíveis no projeto:**
- `TRAEFIK_CREDENTIALS` → senhas do dashboard
- `TRAEFIK_*_KEY` → chaves privadas SSL/TLS
- `TRAEFIK_*_CRT` → certificados SSL/TLS

### Docker Configs

**Para:** Dados de **configuração** públicos que precisam ser **distribuídos**

```bash
# Criar
docker config create TRAEFIK_STATIC config/traefik-swarm.yaml
docker config create TRAEFIK_DYNAMIC config/dynamic.yaml

# Características
✅ Distribuídos a todos os nós
✅ Versionados automaticamente
✅ Histórico de mudanças
✅ Fácil atualizar (remover e recriar)
```

**Dados de configuração no projeto:**
- `TRAEFIK_STATIC` → traefik-swarm.yaml
- `TRAEFIK_DYNAMIC` → dynamic.yaml

### Fluxo Visual

```
┌─────────────────────────────────────────────────────────┐
│                Docker Swarm Manager                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Secrets (Criptografados):                             │
│  ├─ TRAEFIK_CREDENTIALS ─────┐                         │
│  ├─ TRAEFIK_SENAICIMATEC_KEY │                         │
│  └─ TRAEFIK_JBTH_KEY ────────┤ Apenas nós que         │
│                               │ precisam recebem       │
│  Configs (Abertos):          │                         │
│  ├─ TRAEFIK_STATIC ──────────┼──→ Todos os nós        │
│  └─ TRAEFIK_DYNAMIC ─────────┘                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
      ↓
  ┌─────────────────┬─────────────────┬─────────────────┐
  │  Nó 1           │  Nó 2           │  Nó N           │
  │  (Manager)      │  (Worker)       │  (Worker)       │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ /run/secrets/:  │ /run/secrets/:  │ /run/secrets/:  │
  │ - credentials   │ - credentials   │ - credentials   │
  │ - ...keys       │ - ...keys       │ - ...keys       │
  │                 │                 │                 │
  │ /var/lib/.../:  │ /var/lib/.../:  │ /var/lib/.../:  │
  │ - traefik.yaml  │ - traefik.yaml  │ - traefik.yaml  │
  │ - dynamic.yaml  │ - dynamic.yaml  │ - dynamic.yaml  │
  └─────────────────┴─────────────────┴─────────────────┘
```

---

- **Docker Engine** e **Docker Compose** (para modo standalone)
- **Docker Swarm** inicializado (para modo Swarm)
- Shell compatível com `bash` (Linux, macOS ou WSL2)
- **`htpasswd`**: Utilitário para gerar senhas hasheadas (parte do `apache2-utils`)

---

## 🚀 Instalação e Configuração

### 1. Clone o Repositório

```bash
git clone https://github.com/RafaelQSantos-RQS/traefik
cd traefik
```

### 2. Execute o Setup Inicial

```bash
make setup
```

**O que este comando faz:**

1. Cria o arquivo `.env` a partir do template (`.env.template`)
2. Detecta o hostname da máquina e pré-configura no `.env`
3. Gera o arquivo de credenciais (`config/credentials`)
4. Cria a rede Docker externa (se não existir)

> ⚠️ **Importante:** Após a primeira execução, edite o arquivo `.env` com suas configurações.

### 3. Configure o Arquivo `.env`

Abra o arquivo `.env` e configure:

```bash
# Versão do Traefik (SEMPRE fixe uma versão!)
TRAEFIK_VERSION=v3.6.9

# Domínio principal
DOMAIN=seudominio.com.br
TRAEFIK_HOST=traefik.${DOMAIN}

# Credenciais do Dashboard
DASH_USER=admin
DASH_PASS=sua_senha_segura

# Rede externa (Docker Compose)
EXTERNAL_DOCKER_NETWORK=web
```

> ⚠️ **Nota:** Os certificados agora são gerenciados via Docker Secrets. Veja a seção [Certificados SSL/TLS](#certificados-ssltls) para mais detalhes.

### 4. Finalize o Setup

```bash
make setup
```

---

## 🐳 Modo Docker Compose (Standalone)

### Configuração

O Traefik em modo standalone usa:

- **Rede externa**: `web` (criada automaticamente ou existente)
- **Provider**: Docker (via socket)
- **Descoberta automática**: Labels nos containers

### Rede Externa

Para criar a rede externa manualmente:

```bash
docker network create -d bridge web
```

### Iniciando

```bash
# Iniciar o Traefik
make compose-up

# Verificar status
make compose-status

# Ver logs
make compose-logs
```

### Parando

```bash
make compose-down
```

---

## 🐝 Modo Docker Swarm

### Visão Geral

O Docker Swarm permite executar o Traefik em modo cluster, com suporte a:
- **Routing Mesh**: Balanceamento automático de carga
- **Service Discovery**: Descoberta automática de serviços
- **Alta Disponibilidade**: Múltiplas réplicas (recomendado 1 para o Traefik)

### Rede Overlay

Crie a rede overlay para o Swarm:

```bash
docker network create -d overlay swarm-net --attachable
```

> ⚠️ **Importante:** Se houver conflito de rede (erro "invalid pool request"), use uma subnet diferente:
> ```bash
> docker network create -d overlay --attachable --subnet=10.10.0.0/24 swarm-net
> ```

### Configurando Secrets e Configs

Antes do deploy, você deve criar os secrets (certificados e credenciais) e configs (arquivos YAML). O Makefile facilita isso:

```bash
# Criar todos os secrets (credentials + certificados)
make swarm-create-secrets

# Criar configs para arquivos YAML
make swarm-create-configs
```

#### Verificar se tudo existe

```bash
# Verificar configs
make swarm-check-configs

# Verificar secrets
make swarm-check-secrets
```

### Deploy

```bash
# Deploy no Swarm (já verifica configs e secrets automaticamente)
make swarm-deploy

# Verificar status
make swarm-status

# Ver logs
make swarm-logs

# Remover do Swarm
make swarm-remove
```

### Routing Mesh: Host vs Ingress

No Swarm, as portas podem ser expostas de duas formas:

| Mode | Descrição | Use Quando |
|------|-----------|------------|
| `host` | Bind direto no nó | Quer evitar o routing mesh, alta performance single-node |
| `ingress` (padrão) | Routing mesh do Swarm | Multi-node, balanceamento automático |

**Exemplo com ingress (padrão):**
```yaml
ports:
  - target: 80
    published: 80
    protocol: tcp
    # mode: ingress é o padrão, pode omitir
  - target: 443
    published: 443
    protocol: tcp
```

**Exemplo com host:**
```yaml
ports:
  - target: 80
    published: 80
    protocol: tcp
    mode: host
  - target: 443
    published: 443
    protocol: tcp
    mode: host
```

---

## 🔐 Segurança

### TLS 1.3 Forçado

O projeto configura TLS 1.3 como versão mínima com ciphers seguros:

```yaml
tls:
  options:
    default:
      minVersion: "VersionTLS13"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
```

### Rate Limiting

Middleware configurado para prevenir ataques DDoS:

- **Average**: 100 requisições/segundo
- **Burst**: 50 requisições adicionais

### Credenciais em Docker Secret

As credenciais do dashboard são armazenadas em **Docker Secret** (`TRAEFIK_CREDENTIALS`), não em arquivo volume.

O arquivo local `config/credentials` ainda existe localmente para gerenciamento, mas as alterações são sincronizadas automaticamente para o Docker Secret.

Formato (htpasswd bcrypt):
```
admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
```

---

## 👥 Gestão de Usuários

### Comandos Disponíveis

```bash
# Adicionar usuário
make add-user USERNAME=novouser PASS=senha123

# Atualizar senha
make update-user USERNAME=admin PASS=nova_senha

# Deletar usuário
make delete-user USERNAME=admin

# Listar usuários
make list-users
```

### Formato do Arquivo de Credenciais

O arquivo `config/credentials` usa formato htpasswd:

```bash
# Gerar manualmente
htpasswd -nbm usuario senha
```

> ⚠️ **Importante:** Após adicionar/modificar usuários, reinicie o Traefik:
> ```bash
> make compose-restart  # Docker Compose
> make swarm-deploy      # Swarm (redeploy)
> ```

---

## 📊 Dashboard e Métricas

### Acesso ao Dashboard

O Dashboard está disponível em:

```
https://seudominio.com.br/dashboard/
```

**Autenticação:** Basic Auth (usuário/senha configurados no `.env`)

### Métricas Prometheus

Endpoint de métricas:

```
https://seudominio.com.br/metrics
```

### Configuração de Host

O host do dashboard é definido pela variável `TRAEFIK_HOST` no `.env`:

```bash
TRAEFIK_HOST=traefik.seudominio.com.br
```

Para testar localmente, adicione entries no `/etc/hosts`:

```
127.0.0.1 traefik.seudominio.com.br
```

---

## 🧰 Comandos Makefile

### 📋 Geral

| Comando | Descrição |
|---------|-----------|
| `make setup` | Gera configurações a partir dos templates |
| `make sync` | Sincroniza com repositório remoto |

### 👥 Usuários

| Comando | Descrição |
|---------|-----------|
| `make add-user` | Adiciona usuário ao dashboard |
| `make update-user` | Atualiza senha de usuário |
| `make delete-user` | Remove usuário do dashboard |
| `make list-users` | Lista usuários cadastrados |

### 🐳 Docker Compose

| Comando | Descrição |
|---------|-----------|
| `make compose-up` | Inicia o Traefik |
| `make compose-down` | Para o Traefik |
| `make compose-restart` | Reinicia o Traefik |
| `make compose-logs` | Mostra logs em tempo real |
| `make compose-status` | Verifica status dos containers |
| `make compose-pull` | Baixa novas versões das imagens |

### ☁️ Docker Swarm

| Comando | Descrição |
|---------|-----------|
| `make swarm-create-configs` | Cria configs do Swarm |
| `make swarm-create-secrets` | Cria todos os secrets (credentials + certificados) |
| `make swarm-update-configs` | Atualiza configs do Swarm |
| `make swarm-update-secrets` | Atualiza todos os secrets |
| `make swarm-remove-configs` | Remove configs do Swarm |
| `make swarm-remove-secrets` | Remove secrets do Swarm |
| `make swarm-check-configs` | Verifica se configs existem |
| `make swarm-check-secrets` | Verifica se secrets existem |
| `make swarm-deploy` | Deploy no Docker Swarm |
| `make swarm-remove` | Remove do Docker Swarm |
| `make swarm-status` | Status da stack no Swarm |
| `make swarm-logs` | Logs do Swarm |

---

## 📂 Estrutura de Arquivos

```
.
├── Makefile                      # Automação de comandos (setup, deploy, etc)
├── docker-compose.yaml          # Configuração para Docker Compose (standalone)
├── docker-stack.yml             # Configuração para Docker Swarm (com configs e secrets)
├── .env                         # Variáveis de ambiente (criado por make setup, ignorado pelo Git)
├── .env.template                # Template para .env (versionado no Git)
│
├── templates/                   # Templates para geração automática
│   ├── traefik.yaml.template    # Template da config estática
│   ├── dynamic.yaml.template    # Template da config dinâmica
│   ├── traefik-swarm.yaml.template
│   └── credentials.template
│
├── config/                      # Configurações geradas (valores reais)
│   ├── traefik.yaml             # Config estática para Docker Compose
│   ├── traefik-swarm.yaml       # Config estática para Docker Swarm
│   ├── dynamic.yaml             # Config dinâmica (ambos os modos)
│   ├── dynamic-swarm.yaml       # Config dinâmica alternativa
│   ├── credentials              # Arquivo de credenciais (htpasswd)
│   └── README.md                # Documentação dessa pasta
│
├── certs/                       # Certificados SSL/TLS (fonte para Docker Secrets)
│   ├── senaicimatec_com_br/
│   │   ├── senaicimatec_com_br.pem
│   │   └── senaicimatec_com_br.key
│   ├── jbth/
│   │   ├── full_chain_jbth.crt
│   │   └── jbth.com.br.key
│   ├── universidadesenaicimatec_edu_br/
│   │   ├── fullchain_universidadesenaicimatec.edu.brv2.pem
│   │   └── universidadesenaicimatec.edu.brv2.key
│   └── README.md                # Documentação dessa pasta
│
└── README.md                    # Este arquivo
```

### Entendendo a Estrutura

```
Docker Compose          │  Docker Swarm
────────────────────────┼──────────────────────────────────
Local volumes           │  Docker Secrets + Docker Configs
./config/ → volumes     │  ./config/ → docker config create
./certs/ → volumes      │  ./certs/ → docker secret create
.env → variáveis        │  .env → variáveis + secrets
```

---

## ⚙️ Docker Configs para Arquivo de Configuração

### O que são Docker Configs?

**Docker Configs** é um mecanismo do Docker Swarm para distribuir dados de configuração (não-sensíveis) entre nós do cluster. Diferentemente de volumes locais, configs garantem que:

- ✅ Configurações sejam consistentes em todos os nós do Swarm
- ✅ Atualizações automáticas quando o arquivo de configuração é alterado
- ✅ Histórico e versionamento de configurações
- ✅ Separação clara entre código, configuração e secrets

### Por que usar Configs?

**Antes (com volumes locais):**
```bash
# Cada nó precisa ter o arquivo traefik.yaml
# Sincronização manual de alterações entre nós
# Sem histórico de mudanças
volumes:
  - ./config/traefik-swarm.yaml:/etc/traefik/traefik.yaml:ro
```

**Depois (com Docker Configs):**
```bash
# Um único arquivo, distribuído automaticamente
# Versionamento automático de mudanças
# Sincronização garantida entre todos os nós
configs:
  - source: TRAEFIK_STATIC
    target: /etc/traefik/traefik.yaml
```

### Configuração no docker-stack.yml

O arquivo já está configurado corretamente:

```yaml
services:
  proxy:
    # ... outras configurações ...
    configs:
      - source: TRAEFIK_STATIC
        target: /etc/traefik/traefik.yaml
      - source: TRAEFIK_DYNAMIC
        target: /etc/traefik/dynamic.yaml

# Declaração de configs no final do arquivo
configs:
  TRAEFIK_STATIC:
    external: true
  TRAEFIK_DYNAMIC:
    external: true
```

### Fluxo de Trabalho com Configs

#### 1️⃣ Setup Inicial

```bash
# Setup cria os arquivos locais
make setup
```

Isso gera:
- `config/traefik.yaml` (configuração estática para Compose)
- `config/traefik-swarm.yaml` (configuração estática para Swarm)
- `config/dynamic.yaml` (configuração dinâmica)

#### 2️⃣ Criar Configs no Swarm

Antes de fazer deploy, os configs **devem existir** no Swarm:

```bash
# Criar configs do Traefik
make swarm-create-configs
```

#### 3️⃣ Deploy no Swarm

```bash
# Deploy (verifica se configs existem)
make swarm-deploy
```

#### 4️⃣ Atualizar Configs

Quando você modifica os arquivos YAML:

```bash
# Editar o arquivo
vim config/traefik-swarm.yaml

# Atualizar no Swarm
make swarm-update-configs

# Redeploy para aplicar mudanças
make swarm-deploy
```

### Entendendo os Dois Arquivos YAML

#### `traefik-swarm.yaml` (TRAEFIK_STATIC)

Configuração **estática** - define a estrutura do Traefik:

```yaml
# Portas de entrada (entry points)
entryPoints:
  web:      # HTTP (porta 80)
  websecure: # HTTPS (porta 443)

# Providers (descobre serviços)
providers:
  swarm:    # Descobre via Docker Swarm
  file:     # Lê arquivo dinâmico

# Dashboard e métricas
api:
  dashboard: true
metrics:
  prometheus:
    entryPoint: websecure

# Logs
log:
  format: json
  level: INFO
```

**Quando mudar:** Raramente. Apenas quando você quer:
- Adicionar novo entrypoint
- Mudar estrutura de logging
- Modificar provedor de serviços

#### `dynamic.yaml` (TRAEFIK_DYNAMIC)

Configuração **dinâmica** - define rotas, middlewares e certificados:

```yaml
http:
  # Middlewares (autenticação, rate-limit, etc)
  middlewares:
    basic-auth:
      basicAuth:
        usersFile: /etc/traefik/secrets/credentials

tls:
  # Certificados SSL/TLS
  certificates:
    - certFile: "/etc/traefik/certs/..."
      keyFile: "/etc/traefik/certs/..."
```

**Quando mudar:** Frequentemente:
- Adicionar novo certificado
- Modificar middlewares
- Ajustar rate-limiting

### Diferença entre Configs e Secrets

| Aspecto | **Configs** | **Secrets** |
|---------|-----------|-----------|
| **Tipo de dado** | Configurações públicas | Dados sensíveis |
| **Visibilidade** | Armazenados em texto plano | Criptografados em repouso |
| **Uso** | Arquivos YAML, certificados | Senhas, chaves privadas |
| **No projeto** | traefik.yaml, dynamic.yaml | credentials, certificados |

**Neste projeto:**
- ✅ **Configs** → `traefik-swarm.yaml`, `dynamic.yaml`
- ✅ **Secrets** → credenciais, certificados SSL

### Checklist: Antes do Deploy

```bash
# 1. Fazer setup
make setup

# 2. Criar todos os secrets (credentials + certificados)
make swarm-create-secrets

# 3. Criar configs para YAML
make swarm-create-configs

# 4. Verificar configs
make swarm-check-configs

# 5. Verificar secrets
make swarm-check-secrets

# 6. Deploy!
make swarm-deploy

# 7. Verificar status
make swarm-status
```

### Troubleshooting: Configs

**Problema:** "external config not found: TRAEFIK_STATIC"

```bash
# Solução: Criar o config
make swarm-create-configs
```

**Problema:** Mudanças em traefik.yaml não aparecem

```bash
# Solução: Atualizar e redeploy
make swarm-update-configs
make swarm-deploy
```

**Problema:** Atualizar certificados

```bash
# Solução: Atualizar secrets
make swarm-update-secrets
make swarm-deploy
```

---

## 🔒 Certificados SSL/TLS

### Gerenciamento com Makefile

O Makefile facilita o gerenciamento de certificados usando Docker Secrets:

#### Criar Secrets

```bash
# Criar todos os secrets de uma vez (credentials + todos os certificados)
make swarm-create-secrets
```

#### Atualizar Secrets

```bash
# Atualizar certificados ou credenciais
make swarm-update-secrets

# Redeploy para aplicar
make swarm-deploy
```

#### Verificar Secrets

```bash
make swarm-check-secrets
```

#### Listar Secrets

```bash
docker secret ls
```

#### Remover Secrets

```bash
make swarm-remove-secrets
```

> ⚠️ **Nota:** Após criar/atualizar secrets, faça redeploy do serviço:
> ```bash
> make swarm-deploy
> ```

### Credenciais do Dashboard

As credenciais são gerenciadas automaticamente pelo Makefile:

```bash
# Setup inicial (cria o secret automaticamente)
make setup

# Adicionar usuário (atualiza o secret automaticamente)
make add-user USERNAME=admin PASS=nova_senha

# Atualizar senha
make update-user USERNAME=admin PASS=senha_nova

# Deletar usuário
make delete-user USERNAME=admin
```

> ⚠️ **Nota:** Os comandos do Makefile atualizam automaticamente o Docker Secret. Não é necessário fazer isso manualmente.

### Configuração Manual

Adicione seus certificados no arquivo `config/dynamic.yaml`:

```yaml
tls:
  certificates:
    - certFile: "/etc/traefik/certs/seu-dominio/cert.pem"
      keyFile: "/etc/traefik/certs/seu-dominio/key.pem"
```

### Estrutura de Diretórios

> ⚠️ **Nota:** Os certificados são armazenados em Docker Secrets, não mais em volume. O diretório `certs/` é usado apenas como fonte para criar os secrets.

```
certs/
├── senaicimatec_com_br/
│   ├── senaicimatec_com_br.pem
│   └── senaicimatec_com_br.key
├── outro-dominio/
│   ├── fullchain.crt
│   └── dominio.key
└── ...
```

---

## ☁️ Configurando Serviços para Usar o Traefik

### Labels Obrigatórias

Para que um serviço seja descoberto pelo Traefik, adicione as seguintes labels no seu serviço:

### Exemplo com Docker Compose

```yaml
services:
  meu-servico:
    image: nginx:latest
    networks:
      - web  # Mesma rede do Traefik
    deploy:
      labels:
        # Habilita a descoberta pelo Traefik
        traefik.enable: "true"
        
        # Porta do serviço (obrigatório para services)
        traefik.http.services.meu-servico.loadbalancer.server.port: "80"
        
        # Router (opções comuns)
        traefik.http.routers.meu-servico.rule: "Host(`meusite.com.br`)"
        
        # Entrypoint (http ou https)
        traefik.http.routers.meu-servico.entrypoints: "websecure"
        
        # TLS (se usar HTTPS)
        traefik.http.routers.meu-servico.tls: "true"
```

### Exemplo com Docker Swarm

```yaml
services:
  meu-servico:
    image: nginx:latest
    networks:
      - swarm-net  # Rede overlay do Swarm
    deploy:
      labels:
        traefik.enable: "true"
        traefik.http.services.meu-servico.loadbalancer.server.port: "80"
        traefik.http.routers.meu-servico.rule: "Host(`meusite.com.br`)"
        traefik.http.routers.meu-servico.entrypoints: "websecure"
        traefik.http.routers.meu-servico.tls: "true"
```

### Labels Mais Comuns

| Label | Descrição | Exemplo |
|-------|-----------|---------|
| `traefik.enable` | Habilita/desabilita o serviço | `true` |
| `traefik.http.routers.<name>.rule` | Regra de roteamento | `Host(\`example.com\`)` |
| `traefik.http.routers.<name>.entrypoints` | EntryPoint | `web` ou `websecure` |
| `traefik.http.routers.<name>.tls` | Habilita TLS | `true` |
| `traefik.http.services.<name>.loadbalancer.server.port` | Porta do serviço | `8080` |
| `traefik.http.middlewares.<name>.basicauth.users` | Basic Auth | `user:pass` |
| `traefik.http.routers.<name>.middlewares` | Middlewares | `auth@file,rateLimit@file` |

### Regras de Routing

```yaml
# Single host
traefik.http.routers.app.rule: "Host(`app.example.com`)"

# Multiple hosts
traefik.http.routers.app.rule: "Host(`app.example.com`) || Host(`app2.example.com`)"

# Path
traefik.http.routers.app.rule: "PathPrefix(`/api`)"

# Host + Path
traefik.http.routers.app.rule: "Host(`app.example.com`) && PathPrefix(`/api`)"
```

### Conectando Serviços ao Traefik

**Docker Compose:**
```bash
# Rede deve ser a mesma configurada no Traefik
networks:
  - web  # Ou o nome da rede configurada
```

**Docker Swarm:**
```bash
# Usar a rede overlay
networks:
  - swarm-net
```

---

## 🎯 Boas Práticas

### 1. Versionamento de Configurações

```bash
# Antes de fazer mudanças, guarde backup
cp config/traefik-swarm.yaml config/traefik-swarm.yaml.backup
cp config/dynamic.yaml config/dynamic.yaml.backup

# Edite a configuração
vim config/traefik-swarm.yaml

# Atualize no Swarm
make swarm-update-configs

# Se algo quebrou, restaure
cp config/traefik-swarm.yaml.backup config/traefik-swarm.yaml
make swarm-update-configs
```

### 2. Teste Antes de Produção

```bash
# Use Docker Compose para testar mudanças
make compose-up

# Depois, migre para Swarm
make swarm-create-secrets
make swarm-create-configs
make swarm-deploy
```

### 3. Renovação de Certificados

```bash
# Quando renew um certificado
# 1. Substitua o arquivo em certs/
# 2. Atualize o secret
make swarm-update-secrets

# 3. Redeploy
make swarm-deploy
```

### 4. Monitoramento

```bash
# Configurar alertas para:
# - Certificados próximos de expirar
# - Taxa de erro > 1%
# - Latência > 500ms

# Ver métricas Prometheus
# https://traefik.seudominio.com.br/metrics

# Integrar com seu stack de monitoramento
# - Prometheus
# - Grafana
# - AlertManager
```

### 5. Segurança

```bash
# ✅ Fazer
# - Usar make swarm-create-secrets para criar secrets
# - Usar make swarm-check-secrets para verificar

# ❌ NÃO fazer
# - Commitar .env ou config/credentials no Git
# - Usar senhas fracas no dashboard
# - Armazenar chaves privadas em volumes públicos
# - Executar Traefik em modo debug em produção
```

### 6. Backup de Secrets e Configs

```bash
# Não há forma nativa de backup de secrets no Swarm
# SEMPRE mantenha cópias seguras em local externo:

# - Certificados em vault/backup seguro
# - Senhas em password manager
# - Configurações versionadas no Git
```

---

## 🔧 Troubleshooting

### Problema: "404 Not Found" no Dashboard

**Causa:** Rede incorreta ou labels não aplicadas corretamente.

**Solução:**
1. Verifique se o serviço está Traefik
 na mesma rede do2. Confirme que `traefik.enable=true` está setado
3. Verifique os logs: `make compose-logs` ou `make swarm-logs`

### Problema: "401 Unauthorized" no Dashboard

**Causa:** Credenciais incorretas ou arquivo de credenciais não encontrado.

**Solução:**
1. Verifique se o arquivo `config/credentials` existe
2. Teste as credenciais: `htpasswd -bv config/credentials usuario senha`
3. Atualize as credenciais: `make update-user USERNAME=admin PASS=nova_senha`
4. Reinicie o Traefik após modificar credenciais

### Problema: Certificado SSL inválido

**Causa:** Certificado não está no formato correto ou caminho incorreto.

**Solução:**
1. Verifique o formato PEM
2. Confirme o caminho no `dynamic.yaml`
3. Verifique se o certificado inclui a chain completa

### Problema: Swarm não descobre serviços

**Causa:** Rede overlay não configurada corretamente.

**Solução:**
1. Confirme que a rede existe: `docker network ls`
2. Verifique se o serviço está na rede `swarm-net`
3. Use `make swarm-logs` para ver erros

### Problema: "invalid pool request: Pool ov..."

**Causa:** Conflito de subnet entre redes Docker.

**Solução:**
```bash
# Remova a rede e recrie com subnet diferente
docker stack rm traefik
docker network rm swarm-net
docker network create --driver overlay --attachable --subnet=10.10.0.0/24 swarm-net
make swarm-deploy
```

### Problema: Rate Limiting bloqueando requisições

**Causa:** Limites muito baixos para sua aplicação.

**Solução:**
Ajuste em `config/dynamic.yaml`:
```yaml
middlewares:
  rate-limit:
    rateLimit:
      average: 1000  # Aumente se necessário
      burst: 200
```

---

## 📚 Referências

- [Documentação Oficial do Traefik](https://doc.traefik.io/traefik/)
- [Traefik v3 Migration Guide](https://doc.traefik.io/traefik/migrate/v3/)
- [Docker Swarm Mode](https://docs.docker.com/engine/swarm/)
- [Docker Compose](https://docs.docker.com/compose/)

---

## 📄 Licença

MIT License - See LICENSE file for details.
