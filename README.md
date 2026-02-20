# TOTVS Protheus Standalone (All-in-One)

[![CI Status](https://github.com/juliansantosinfo/TOTVS-Protheus-in-Docker-Standalone/actions/workflows/deploy.yml/badge.svg)](https://github.com/juliansantosinfo/TOTVS-Protheus-in-Docker-Standalone/actions)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![MSSQL](https://img.shields.io/badge/MSSQL-Supported-red.svg)](https://www.microsoft.com/sql-server)
[![Oracle](https://img.shields.io/badge/Oracle-Supported-red.svg)](https://www.oracle.com/database/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Índice

- [Overview](#overview)
- [Arquitetura](#arquitetura)
- [Requisitos](#requisitos)
- [Início Rápido](#início-rápido)
- [Docker Compose (Recomendado)](#docker-compose-recomendado)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Estrutura de Diretórios](#estrutura-de-diretórios)
- [Portas Expostas](#portas-expostas)
- [Volumes](#volumes)
- [Exemplos de Uso](#exemplos-de-uso)
- [Health Check](#health-check)
- [Troubleshooting](#troubleshooting)
- [Limitações](#limitações)
- [Licença](#licença)

---

## 🎯 Overview

Este projeto fornece uma implementação **monolítica e automatizada** do ERP TOTVS Protheus em um único container Docker. Ao contrário da arquitetura de microserviços, o modo Standalone executa todos os componentes necessários dentro do mesmo container, orquestrados por scripts inteligentes:

- **AppServer** - Servidor de aplicação do Protheus (suporte a SmartClient HTML e REST).
- **DBAccess** - Middleware de conexão com banco de dados.
- **License Server** - Servidor de licenças virtualizado.
- **PostgreSQL** (opcional) - Banco de dados embarcado versão 15.

### 💡 Casos de Uso

✅ **Desenvolvimento Local** - Ambiente completo em minutos.
✅ **Demonstrações** - Setup rápido para apresentações comerciais.
✅ **Testes** - Ambientes descartáveis e reproduzíveis para QA.
✅ **Treinamento** - Laboratórios isolados para cada aluno.
✅ **CI/CD** - Validação de dicionários e compilações automatizadas.

⚠️ **Não recomendado para produção** - Para ambientes produtivos, recomenda-se uma arquitetura distribuída e orquestrada (Kubernetes/Swarm).

---

## 🏗️ Arquitetura

O container atua como um "mini-servidor" encapsulado, gerenciando internamente a comunicação entre os componentes TOTVS.

```text
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container (All-in-One)            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ License      │    │   DBAccess   │    │  AppServer   │   │
│  │ Server :5555 │◄───┤    :7890     │◄───┤ :1234 :1235  │   │
│  └──────────────┘    └──────┬───────┘    └──────────────┘   │
│                             │                               │
│                  ┌──────────▼──────────┐                    │
│                  │ PostgreSQL Embedded │ (Opcional)         │
│                  │       :5432         │                    │
│                  └─────────────────────┘                    │
└─────────────────────────────┬───────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Volumes de Dados │
                    │ (/protheus_data)  │
                    └───────────────────┘
```

---

## 📦 Requisitos

### Sistema
- Docker 20.10+ ou Docker Desktop.
- **Memória:** 4GB RAM mínimo (8GB recomendado para performance aceitável).
- **Disco:** 10GB espaço livre.

### ⚠️ Configuração de Kernel (Linux)
O Protheus requer limites elevados de descritores de arquivo. Se você executar em Linux nativo, garanta que o host permita:
```bash
ulimit -n 65536
```
No Docker Compose, isso é tratado via configuração `ulimits`.

---

### Opção A: Setup Automatizado (Recomendado)
Se você tem acesso ao repositório de recursos configurado:
```bash
chmod +x scripts/build/setup.sh
./scripts/build/setup.sh
```

### Opção B: Setup Manual
Organize os arquivos conforme a estrutura abaixo na raiz do projeto:

```text
./totvs/
├── protheus/
│   ├── bin/appserver/
│   │   ├── appsrvlinux
│   │   └── appserver.ini
│   └── apo/
│       └── *.rpo
├── dbaccess/
│   ├── multi/dbaccess64
│   └── tools/dbaccesscfg
├── licenseserver/
│   └── bin/appserver/
│       └── appsrvlinux
├── protheus_data/
│   ├── system/
│   └── systemload/
└── resources/
    ├── etc/
    │   ├── odbc.ini
    │   └── odbcinst.ini
    ├── postgres/
    │   ├── create_database.sql
    │   └── database_backup.sql.gz (opcional)
    └── mssql/
        ├── create_database.sql
        └── database_backup.bak (opcional)
```

---

## 🚀 Início Rápido (Docker Run)

### 0️⃣ Rápido e simples (PostgreSQL Embedded)

Ideal para testes rápidos onde você não quer configurar um banco externo.

**Linux / Mac:**

```bash
# Executar container
docker run -d \
  --name protheus \
  -p 1234:1234 \
  -p 1235:1235 \
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

**Widowns**

```powershell
# Executar container
docker run -d `
  --name protheus `
  -p 1234:1234 `
  -p 1235:1235 `
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

### 1️⃣ PostgreSQL Embedded (Recomendado para Dev)

**Linux / Mac:**

```bash
# Executar container
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -p 1234:1234 \
  -p 1235:1235 \
  -v protheus-data:/totvs/protheus_data \
  -v postgres-data:/var/lib/pgsql/15/data \
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

**Widowns**

```powershell
# Executar container
docker run -d `
  --name protheus `
  -e DATABASE_EMBEDDED=1 `
  -p 1234:1234 `
  -p 1235:1235 `
  -v protheus-data:/totvs/protheus_data `
  -v postgres-data:/var/lib/pgsql/15/data `
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

### 2️⃣ PostgreSQL Externo

**Linux / Mac:**

```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=POSTGRES \
  -e DATABASE_SERVER=postgres.example.com \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=postgres \
  -e DATABASE_PASSWORD=SenhaSegura123 \
  -e DATABASE_NAME=protheus \
  -e DATABASE_EMBEDDED=0 \
  -p 1234:1234 \
  -p 1235:1235 \
  -v protheus-data:/totvs/protheus_data \
  juliansantosinfo/totvs_protheus_standalone:latest
```

**Widowns**

```powershell
# Executar container
docker run -d `
  --name protheus `
  -e DATABASE_TYPE=POSTGRES `
  -e DATABASE_SERVER=postgres.example.com `
  -e DATABASE_PORT=5432 `
  -e DATABASE_USERNAME=postgres `
  -e DATABASE_PASSWORD=SenhaSegura123 `
  -e DATABASE_NAME=protheus `
  -e DATABASE_EMBEDDED=0 `
  -p 1234:1234 `
  -p 1235:1235 `
  -v protheus-data:/totvs/protheus_data `
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

### 3️⃣ Microsoft SQL Server Externo

**Linux / Mac:**

```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=MSSQL \
  -e DATABASE_SERVER=mssql.example.com \
  -e DATABASE_PORT=1433 \
  -e DATABASE_USERNAME=sa \
  -e DATABASE_PASSWORD=SenhaSegura123 \
  -e DATABASE_NAME=protheus \
  -e DATABASE_EMBEDDED=0 \
  -p 1234:1234 \
  -p 1235:1235 \
  -v protheus-data:/totvs/protheus_data \
  juliansantosinfo/totvs_protheus_standalone:latest
```

**Widowns**

```powershell
# Executar container
docker run -d `
  --name protheus `
  -e DATABASE_TYPE=MSSQL `
  -e DATABASE_SERVER=mssql.example.com `
  -e DATABASE_PORT=1433 `
  -e DATABASE_USERNAME=sa `
  -e DATABASE_PASSWORD=SenhaSegura123 `
  -e DATABASE_NAME=protheus `
  -e DATABASE_EMBEDDED=0 `
  -p 1234:1234 `
  -p 1235:1235 `
  -v protheus-data:/totvs/protheus_data `
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

### 4️⃣ Oracle Externo

**Linux / Mac:**

```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=ORACLE \
  -e DATABASE_SERVER=oracle.example.com \
  -e DATABASE_PORT=1521 \
  -e DATABASE_USERNAME=system \
  -e DATABASE_PASSWORD=SenhaSegura123 \
  -e DATABASE_NAME=ORCL \
  -e DATABASE_EMBEDDED=0 \
  -p 1234:1234 \
  -p 1235:1235 \
  -v protheus-data:/totvs/protheus_data \
  juliansantosinfo/totvs_protheus_standalone:latest
```

**Widowns**

```powershell
# Executar container
docker run -d `
  --name protheus `
  -e DATABASE_TYPE=ORACLE `
  -e DATABASE_SERVER=oracle.example.com `
  -e DATABASE_PORT=1521 `
  -e DATABASE_USERNAME=system `
  -e DATABASE_PASSWORD=SenhaSegura123 `
  -e DATABASE_NAME=ORCL `
  -e DATABASE_EMBEDDED=0 `
  -p 1234:1234 `
  -p 1235:1235 `
  -v protheus-data:/totvs/protheus_data `
  juliansantosinfo/totvs_protheus_standalone:latest

# Verificar logs
docker logs -f protheus
```

---

## 🐳 Docker Compose (Recomendado)

A maneira mais robusta de executar o projeto, garantindo persistência e configurações de limites.

Crie um arquivo `docker-compose.yaml` (ou use o fornecido no repositório):

```yaml
version: '3.8'

services:
  protheus:
    image: juliansantosinfo/totvs_protheus_standalone:latest
    container_name: protheus_standalone
    restart: unless-stopped
    
    environment:
      - DATABASE_EMBEDDED=1       # 1 para PostgreSQL interno
      - DATABASE_RESTORE=1        # Restaura backup base na 1ª execução
      - DATABASE_NAME=protheus
      - ENABLE_REST_SERVICE=1     # Habilita serviço REST na porta 8080
      
    ports:
      - "1234:1234" # TCP
      - "1235:1235" # WebApp
      - "8080:8080" # REST
      
    # CRÍTICO: Configuração necessária para o AppServer/LicenseServer
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc:
        soft: 65536
        hard: 65536

    volumes:
      - protheus_data:/totvs/protheus_data
      - postgres_data:/var/lib/pgsql/15/data

    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

volumes:
  protheus_data:
  postgres_data:
```

Executar:
```bash
docker-compose up -d
```

---

## 🔑 Variáveis de Ambiente

O comportamento do container é controlado via ENV vars:

### Configuração de Banco de Dados

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DATABASE_EMBEDDED` | `1` ativa PostgreSQL interno, `0` usa externo. | `1` |
| `DATABASE_TYPE` | Tipo do banco: `POSTGRES`, `MSSQL`, `ORACLE`. | `POSTGRES` |
| `DATABASE_SERVER` | Hostname ou IP do banco externo. | - |
| `DATABASE_PORT` | Porta do banco externo. | `5432`/`1433` |
| `DATABASE_USERNAME` | Usuário de conexão. | `postgres`/`sa` |
| `DATABASE_PASSWORD` | Senha de conexão. | - |
| `DATABASE_NAME` | Nome do banco/alias. | `protheus` |

### Funcionalidades Opcionais

| Variável | Descrição | Padrão | Valores |
|----------|-----------|--------|---------|
| `DATABASE_NAME` | Nome do banco de dados | `protheus` | Qualquer nome válido |
| `DATABASE_EMBEDDED` | Usar PostgreSQL interno | `1` | `0` (não), `1` (sim) |
| `DATABASE_RESTORE` | Restaurar backup na criação | `1` | `0` (não), `1` (sim) |
| `DATABASE_RESTORE_FULL` | Restaurar backup completo | `0` | `0` (base), `1` (full) |
| `ENABLE_REST_EMBEDDED` | REST no AppServer principal | `0` | `0` (não), `1` (sim) |
| `ENABLE_REST_SERVICE` | AppServer REST dedicado | `0` | `0` (não), `1` (sim) |
| `DEBUG_SCRIPT` | Modo debug do entrypoint | `0` | `0` (não), `1` (sim) |


#### REST Embedded no AppServer Principal
```bash
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -e ENABLE_REST_EMBEDDED=1 \
  -p 1234:1234 -p 1235:1235 \
  -p 8080:8080 \
  juliansantosinfo/totvs_protheus_standalone:latest
```

---

## 🔌 Portas Expostas

| Porta | Serviço | Descrição |
|-------|---------|-----------|
| `1234` | AppServer | Conexão TCP principal |
| `1235` | AppServer | Interface WebApp |
| `3234` | AppServer REST | Conexão TCP REST (se `ENABLE_REST_SERVICE=1`) |
| `3235` | AppServer REST | Interface WebApp REST (se `ENABLE_REST_SERVICE=1`) |
| `7890` | DBAccess | Middleware de banco de dados |
| `2234` | AppServer | RPC (Remote Procedure Call) |
| `5555` | License Server | Servidor de licenças |
| `8020` | Monitor | Interface de monitoramento |
| `8080` | REST | API REST (se `ENABLE_REST_*=1`) |
| `5432` | PostgreSQL | Banco de dados (se `DATABASE_EMBEDDED=1`) |

### Mapeamento de Portas

```bash
# Portas padrão
-p 1234:1234 -p 1235:1235

# Portas customizadas
-p 8080:1234 -p 8081:1235

# Expor PostgreSQL (se embedded)
-p 5432:5432
```

---

## 💾 Volumes

### Volumes Recomendados

```bash
# Dados do Protheus (obrigatório)
-v protheus-data:/totvs/protheus_data

# Dados do PostgreSQL (se embedded)
-v postgres-data:/var/lib/pgsql/15/data
```

### Backup de Volumes

```bash
# Backup
docker run --rm \
  -v protheus-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/protheus-backup.tar.gz /data

# Restore
docker run --rm \
  -v protheus-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/protheus-backup.tar.gz -C /
```

---

## 🏥 Health Check

O container inclui health check automático via script `/healthcheck.sh` que verifica se o AppServer está respondendo na porta 1234.

### Verificar Status

```bash
# Status do container
docker ps

# Logs do health check
docker inspect --format='{{json .State.Health}}' protheus | jq

# Executar health check manualmente
docker exec protheus /healthcheck.sh
```

### Health Check Manual

```bash
# Verificar AppServer (porta 1234)
docker exec protheus bash -c "timeout 1 bash -c 'echo > /dev/tcp/localhost/1234'"

# Verificar AppServer WebApp
curl -I http://localhost:1235

# Verificar DBAccess
docker exec protheus netstat -tuln | grep :7890

# Verificar License Server
docker exec protheus netstat -tuln | grep :5555

# Verificar PostgreSQL (se embedded)
docker exec protheus su - postgres -c "psql -c 'SELECT 1'"
```

---

## 🔧 Troubleshooting

### Container não inicia
Se o container iniciar e parar imediatamente, ative o modo debug e acompanhe os logs:

```bash
# Verificar logs
docker logs protheus

# Modo debug
docker run -e DEBUG_SCRIPT=1 juliansantosinfo/totvs_protheus_standalone:latest

# Verificar variáveis
docker exec protheus env | grep DATABASE
```

### Erro de conexão com banco

```bash
# Testar conectividade
docker exec protheus ping -c 3 seu-banco-server

# Verificar configuração ODBC
docker exec protheus cat /etc/odbc.ini

# Verificar DBAccess
docker exec protheus cat /totvs/dbaccess/multi/dbaccess.ini
```

### AppServer não responde

```bash
# Verificar processos
docker exec protheus ps aux | grep appserver

# Verificar portas
docker exec protheus netstat -tuln | grep 1234

# Reiniciar container
docker restart protheus
```

### PostgreSQL embedded não inicia

```bash
# Verificar permissões
docker exec protheus ls -la /var/lib/pgsql/15/data

# Verificar logs do PostgreSQL
docker exec protheus su - postgres -c "cat /var/lib/pgsql/15/data/log/postgresql-*.log"

# Reinicializar PostgreSQL
docker exec protheus su - postgres -c "pg_ctl restart -D /var/lib/pgsql/15/data"
```

### Logs por Serviço

Os logs são prefixados por serviço para facilitar identificação:

```
[licenseserver] Starting License Server...
[dbaccess] DBAccess starting...
[appserver] AppServer starting...
```

---

## ⚠️ Limitações

### Não Recomendado Para

❌ **Ambientes de Produção** - Use arquitetura distribuída  
❌ **Alta Disponibilidade** - Sem redundância de componentes  
❌ **Escalonamento Horizontal** - Todos os serviços em um container  
❌ **Múltiplos Ambientes** - Um container = um ambiente completo  

### Recomendações

✅ Use para desenvolvimento, testes e demonstrações  
✅ Persista volumes em produção  
✅ Configure backups regulares  
✅ Monitore consumo de recursos  
✅ Use secrets para senhas em produção  

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## 🤝 Desenvolvimento e Contribuição

Este projeto é Open Source e encorajamos contribuições!

*   Consulte o guia **[CONTRIBUTING.md](CONTRIBUTING.md)** para entender como configurar o ambiente de desenvolvimento, rodar os testes locais e submeter Pull Requests.
*   Utilizamos scripts de validação (`lint`) e testes de integração automatizados em todo push.

---

## 📄 Licença 

Distribuído sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Desenvolvido com ❤️ para a comunidade TOTVS Protheus**
