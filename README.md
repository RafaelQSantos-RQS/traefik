# Projeto Traefik: Proxy Reverso como Serviço

<p align="center"><img src="https://doc.traefik.io/traefik/assets/images/logo-traefik-proxy-logo.svg" width="auto" height="200px" alt="Traefik Logo"></p>

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/traefik-%232496ed.svg?style=for-the-badge&logo=traefikmesh&logoColor=white)

## 📜 Visão Geral

Este projeto implanta uma instância do **Traefik Proxy** conteinerizada, pronta para operar como o ponto de entrada (edge router) da sua infraestrutura. O foco é ser uma solução robusta, segura e de fácil manutenção para ambientes on-premise.

A complexidade da gestão é abstraída por um `Makefile`, que serve como uma interface de controle padronizada, garantindo que as operações de setup, deploy e manutenção sejam consistentes e previsíveis.

**Versão do Traefik:** v3.6.9

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

| Modo | Comando | Uso Ideal |
|------|---------|-----------|
| **Docker Compose** | `make up` | Desenvolvimento, single-node |
| **Docker Swarm** | `make deploy-stack` | Produção, multi-node |

---

## ✅ Pré-requisitos

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

# Diretório de certificados
CERTS_DIR=./certs
```

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
make up

# Verificar status
make status

# Ver logs
make logs
```

### Parando

```bash
make down
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
docker network create -d overlay traefik-web --attachable
```

### Deploy

```bash
# Deploy no Swarm
make deploy-stack

# Verificar status
make stack-status

# Ver logs
make stack-logs

# Remover do Swarm
make remove-stack
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

### Credenciais em Arquivo Separado

As credenciais do dashboard são armazenadas em arquivo separado, não no código:

```
config/credentials
```

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
> make restart  # Docker Compose
> make deploy-stack  # Swarm (redeploy)
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

| Comando | Descrição |
|---------|-----------|
| `make setup` | Gera configurações a partir dos templates |
| `make up` | Inicia o Traefik (Docker Compose) |
| `make down` | Para o Traefik |
| `make restart` | Reinicia o Traefik |
| `make logs` | Mostra logs em tempo real |
| `make status` | Verifica status dos containers |
| `make pull` | Baixa novas versões das imagens |
| `make sync` | Sincroniza com repositório remoto |
| `make add-user` | Adiciona usuário ao dashboard |
| `make update-user` | Atualiza senha de usuário |
| `make delete-user` | Remove usuário do dashboard |
| `make list-users` | Lista usuários cadastrados |
| `make deploy-stack` | Deploy no Docker Swarm |
| `make remove-stack` | Remove do Docker Swarm |
| `make stack-status` | Status da stack no Swarm |
| `make stack-logs` | Logs do Swarm |

---

## 📂 Estrutura de Arquivos

```
.
├── Makefile                      # Automação de comandos
├── docker-compose.yaml          # Deploy standalone
├── docker-stack.yml             # Deploy Swarm
├── .env                         # Configurações (ignorado pelo Git)
├── .env.template                # Template de variáveis
├── templates/                   # Templates para geração
│   ├── traefik.yaml.template
│   ├── dynamic.yaml.template
│   ├── traefik-swarm.yaml.template
│   └── credentials.template
├── config/                      # Configurações geradas
│   ├── traefik.yaml
│   ├── traefik-swarm.yaml
│   ├── dynamic.yaml
│   ├── dynamic-swarm.yaml
│   └── credentials
├── certs/                       # Certificados SSL/TLS
│   └── [seu-dominio]/
│       ├── cert.pem
│       └── key.pem
└── README.md
```

---

## 🔒 Certificados SSL/TLS

### Configuração Manual

Adicione seus certificados no arquivo `config/dynamic.yaml`:

```yaml
tls:
  certificates:
    - certFile: "/etc/traefik/certs/seu-dominio/cert.pem"
      keyFile: "/etc/traefik/certs/seu-dominio/key.pem"
```

### Estrutura de Diretórios

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

Para que um serviço seja descoberta pelo Traefik, adicione as seguintes labels no seu serviço:

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
      - traefik-web  # Rede overlay do Swarm
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
  - traefik-web
```

---

## 🔧 Troubleshooting

### Problema: "404 Not Found" no Dashboard

**Causa:** Rede incorreta ou labels não aplicadas corretamente.

**Solução:**
1. Verifique se o serviço está na mesma rede do Traefik
2. Confirme que `traefik.enable=true` está setado
3. Verifique os logs: `make logs`

### Problema: "401 Unauthorized" no Dashboard

**Causa:** Credenciais incorretas ou arquivo de credenciais não encontrado.

**Solução:**
1. Verifique se o arquivo `config/credentials` existe
2. Teste as credenciais: `htpasswd -bv config/credentials usuario senha`
3. Reinicie o Traefik após modificar credenciais

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
2. Verifique se o serviço está na rede `traefik-web`
3. Use `make stack-logs` para ver erros

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
