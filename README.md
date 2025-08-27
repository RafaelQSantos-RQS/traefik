# Projeto Traefik: Proxy Reverso como Serviço

<p align="center"><img src="https://doc.traefik.io/traefik/assets/images/logo-traefik-proxy-logo.svg" width="auto" height="200px" alt="Traefik Logo"></p>

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/traefik-%232496ed.svg?style=for-the-badge&logo=traefikmesh&logoColor=white)

## 🎯 Visão Geral

Este projeto implanta uma instância do **Traefik Proxy** conteinerizada, pronta para operar como o ponto de entrada (edge router) da sua infraestrutura. O foco é ser uma solução robusta, segura e de fácil manutenção para ambientes on-premise.

A complexidade da gestão é abstraída por um `Makefile`, que serve como uma interface de controle padronizada, garantindo que as operações de setup, deploy e manutenção sejam consistentes e previsíveis.

## 🏗️ Arquitetura e Decisões de Design

A estabilidade de um sistema começa no seu design. O fluxo de tráfego foi pensado para ser simples e seguro:

```text
INTERNET  ───>  [Portas 80, 443]  ───>  TRAEFIK CONTAINER  ───>  REDE 'web' (Externa)  ───>  SERVIÇO-ALVO (Container)
 (HTTPS)                              (TLS Termination)
                                           │
                                           └──> API/Dashboard (Protegido por Basic Auth)
```

**Princípios Fundamentais:**

1. **Rede Externa Compartilhada:** O Traefik opera conectado a uma rede Docker externa (`web` por padrão). Isso o desacopla dos seus serviços. Ele não precisa estar no mesmo `docker-compose.yaml` que suas aplicações para gerenciá-las, o que é fundamental para a segregação de responsabilidades.
2. **Descoberta de Serviços via Docker Socket:** O proxy monitora o socket do Docker (`/var/run/docker.sock`) em modo somente leitura. Isso permite que ele detecte novos contêineres e configure rotas dinamicamente com base em *labels*, automatizando o processo de exposição de serviços.
3. **Segurança por Padrão (`Opt-In`):** A configuração `exposedByDefault: false` no `traefik.yaml` é intencional. Nenhum serviço é exposto à internet por acidente. Você deve explicitamente adicionar a label `traefik.enable=true` a um contêiner para que o Traefik passe a gerenciá-lo. A segurança deve ser deliberada, não acidental.
4. **Configuração em Camadas:**
      * **`traefik.yaml`:** Configuração estática. Define os pontos de entrada (entrypoints) e os provedores (providers). Isso raramente muda.
      * **`dynamic.yaml`:** Configuração dinâmica. Usada para elementos que mudam com mais frequência, como middlewares de autenticação.
      * **Labels do Docker:** A configuração mais dinâmica, aplicada diretamente nos seus contêineres de aplicação.

## ✅ Pré-requisitos

Antes de colocar a mão na massa, garanta que o sistema tenha o básico:

* **Docker Engine** e **Docker Compose**
* Um shell compatível com `bash` (Linux, macOS ou WSL2/Git Bash no Windows).
* **`htpasswd`:** O `Makefile` usa este utilitário (parte do `apache2-utils` no Debian/Ubuntu) para gerar o hash da senha do dashboard.

## 🚀 Configuração e Deploy

O processo é automatizado para minimizar erros. Siga os passos na ordem correta.

### 1\. Clone o Repositório

```bash
git clone https://github.com/RafaelQSantos-RQS/traefik
cd traefik
```

### 2\. Execute o Setup Inicial

O `Makefile` cuida de toda a preparação. Execute o comando:

```bash
make setup
```

**O que este comando faz?**

1. **Cria o arquivo de ambiente:** Se o arquivo `.env` não existir, ele será copiado a partir do template (`.env.template`).
2. **Configura o Host do Dashboard:** Ele detecta o hostname da máquina local e o pré-configura no arquivo `.env` para facilitar o acesso ao dashboard.
3. **PARA e EXIGE AÇÃO:** A primeira execução irá parar e pedir para você editar o arquivo `.env`. **Isto é um passo de segurança crucial.**

### 3\. Edite o Arquivo `.env`

Abra o arquivo `.env` e configure **todas** as variáveis para o seu ambiente. Preste atenção especial em:

* `TRAEFIK_VERSION`: Fixe uma versão estável (ex: `v3.0`). Não use `latest` em produção.
* `DOMAIN`: O seu domínio principal.
* `DASH_USER` e `DASH_PASS`: As credenciais que você usará para acessar o dashboard do Traefik.

### 4\. Finalize o Setup

Após editar o `.env`, rode o comando de setup novamente:

```bash
make setup
```

**O que ele faz agora?**

1. **Cria a estrutura de configuração:** Garante que o diretório `./config` exista.
2. **Gera as Configurações:** Cria os arquivos `traefik.yaml` e `dynamic.yaml` na pasta `./config` a partir dos templates.
3. **Protege o Dashboard:** Ele lê `DASH_USER` e `DASH_PASS` do seu `.env`, gera um hash seguro (bcrypt) para a senha e injeta as credenciais no `dynamic.yaml`.

Seu ambiente está configurado.

### 5\. Inicie o Serviço

Com tudo pronto, suba o contêiner:

```bash
make up
```

O Traefik estará rodando e pronto para rotear o tráfego para seus outros contêineres na rede `web`.

## 🧰 Gestão do Dia-a-Dia (Comandos)

Toda a interação é feita via `Makefile`. Use `make help` para ver a lista completa de comandos. Os essenciais são:

```bash
# Sobe os contêineres em background
make up

# Para e remove os contêineres
make down

# Reinicia a stack (down + up)
make restart

# Acompanha os logs em tempo real para diagnóstico
make logs

# Verifica o status dos contêineres
make status

# Baixa as imagens mais recentes definidas no .env
make pull

# Sincroniza com o repositório remoto (forcadamente)
make sync
```

## 📂 Estrutura do Projeto

Entender a estrutura dos arquivos é entender como o sistema funciona:

* `Makefile`: O coração da automação. Centraliza todas as operações, garantindo consistência.
* `docker-compose.yaml`: Define o serviço do Traefik, suas redes, volumes, portas e as labels para sua própria exposição (dashboard/métricas).
* `.env.template`: O esqueleto das variáveis de ambiente. Nunca armazene segredos aqui.
* `.env`: Arquivo local (ignorado pelo Git) que contém as configurações e segredos do seu ambiente.
* `templates/`: Contém os modelos base para os arquivos de configuração do Traefik.
  * `traefik.yaml.template`: Configuração estática.
  * `dynamic.yaml.template`: Configuração dinâmica.
* `config/`: Diretório (ignorado pelo Git) onde os arquivos de configuração finais, gerados pelo `make setup`, são armazenados.
* `certs/`: Diretório (ignorado pelo Git) destinado ao armazenamento de certificados SSL/TLS manuais. Cada certificado deve ter seu próprio subdiretório. A configuração para carregar esses certificados deve ser adicionada manualmente ao `dynamic.yaml` ou via labels do Docker.
