<p align="center">
  <img src="https://doc.traefik.io/traefik/assets/images/logo-traefik-proxy-logo.svg" width="auto" height="200px" alt="Traefik Logo">
</p>

# Traefik Stack para Desenvolvimento Local

Este repositório contém uma configuração pronta para usar do [Traefik](https://traefik.io/) como um reverse proxy para ambientes de desenvolvimento local.

A stack utiliza Docker e Docker Compose para facilitar a configuração e execução. Ela inclui:

  * Redirecionamento automático de HTTP para HTTPS.
  * Um dashboard seguro para visualizar e gerenciar suas rotas.
  * Configuração para certificados TLS locais usando `mkcert` para o domínio coringa `*.localhost.com`.

## Pré-requisitos

Antes de começar, garanta que você tenha as seguintes ferramentas instaladas:

  * [Docker](https://docs.docker.com/get-docker/)
  * [Docker Compose](https://docs.docker.com/compose/install/)
  * [mkcert](https://github.com/FiloSottile/mkcert)

## Configuração

Siga os passos abaixo para configurar e iniciar a stack.

### 1\. Gerar Certificados TLS Locais

Para habilitar o HTTPS em seu ambiente local, você precisará gerar certificados válidos para `*.localhost.com`. Usaremos o `mkcert` para isso.

**a. Instale a autoridade de certificação (CA) local do `mkcert`:**
Isso precisa ser feito apenas uma vez.

```bash
mkcert -install
```

**b. Crie os certificados para `*.localhost.com`:**
O `docker-compose.yaml` espera que os arquivos de certificado estejam no diretório `./certs`. Crie este diretório e, em seguida, gere os arquivos.

O arquivo `traefik.yml` está configurado para usar os seguintes nomes de arquivo para o certificado e a chave:

  * `_wildcard.localhost.com+2.pem`
  * `_wildcard.localhost.com+2-key.pem`

Execute os seguintes comandos para criar o diretório e gerar os arquivos com os nomes corretos:

```bash
mkdir -p certs
mkcert -cert-file certs/_wildcard.localhost.com+2.pem -key-file certs/_wildcard.localhost.com+2-key.pem "*.localhost.com" localhost 127.0.0.1 ::1
```

### 2\. Iniciar a Stack

Com os certificados no lugar, você pode iniciar a stack do Traefik usando Docker Compose:

```bash
docker-compose up -d
```

O serviço do Traefik será iniciado e configurado para gerenciar outros contêineres na mesma rede Docker.

## Como Usar

### Acessando o Dashboard do Traefik

Após iniciar a stack, você pode acessar o dashboard do Traefik em seu navegador através do seguinte endereço:

  * **URL:** [https://dashboard-traefik.localhost.com](https://www.google.com/search?q=https://dashboard-traefik.localhost.com)

Graças ao `mkcert`, seu navegador confiará no certificado e a conexão será segura.

### Adicionando Seus Próprios Serviços

Para colocar seus próprios serviços sob o gerenciamento do Traefik, basta adicionar o seguinte ao `docker-compose.yaml` do seu serviço:

1.  Conecte seu serviço à rede `web`:

    ```yaml
    networks:
      - web
    ```

2.  Adicione labels do Traefik para configurar o roteamento. Por exemplo:

    ```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.meu-servico.rule=Host(`meu-servico.localhost.com`)"
      - "traefik.http.routers.meu-servico.entrypoints=websecure"
      - "traefik.http.routers.meu-servico.tls=true"
      - "traefik.http.services.meu-servico.loadbalancer.server.port=80" # Porta interna do seu serviço
    ```

Lembre-se de definir a rede `web` como externa em seu arquivo `docker-compose.yaml`:

```yaml
networks:
  web:
    external: true
```

## Arquivos de Configuração

  * `docker-compose.yaml`: Define o serviço do Traefik, suas portas, volumes e configurações de rede.
  * `traefik.yml`: Arquivo de configuração estática do Traefik. Define os entrypoints (HTTP e HTTPS), provedores (Docker) e a configuração padrão de TLS.