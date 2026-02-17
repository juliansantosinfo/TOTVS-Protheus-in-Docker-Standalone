# TOTVS Protheus Standalone (All-in-One)

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![MSSQL](https://img.shields.io/badge/MSSQL-Supported-red.svg)](https://www.microsoft.com/sql-server)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Índice

- [Overview](#overview)
- [Arquitetura](#arquitetura)
- [Requisitos](#requisitos)
- [Início Rápido](#início-rápido)
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

Este projeto fornece uma implementação **monolítica** do ERP TOTVS Protheus em um único container Docker. Ao contrário da arquitetura de microserviços, o modo Standalone executa todos os componentes necessários dentro do mesmo container:

- **AppServer** - Servidor de aplicação do Protheus
- **DBAccess** - Middleware de conexão com banco de dados
- **License Server** - Servidor de licenças
- **PostgreSQL** (opcional) - Banco de dados embarcado

### 💡 Casos de Uso

✅ **Desenvolvimento Local** - Ambiente completo em minutos  
✅ **Demonstrações** - Setup rápido para apresentações  
✅ **Testes** - Ambientes descartáveis e reproduzíveis  
✅ **Treinamento** - Laboratórios isolados para cada aluno  
✅ **CI/CD** - Testes automatizados de integração  

⚠️ **Não recomendado para produção** - Use arquitetura distribuída

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ License      │  │   DBAccess   │  │  AppServer   │ │
│  │ Server       │  │              │  │              │ │
│  │ :5555        │  │   :7890      │  │ :1234 :1235  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│         │                  │                  │         │
│         └──────────────────┴──────────────────┘         │
│                            │                            │
│                  ┌─────────▼─────────┐                 │
│                  │   PostgreSQL      │                 │
│                  │   (Embedded)      │                 │
│                  │     :5432         │                 │
│                  └───────────────────┘                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Requisitos

### Obrigatórios
- Docker 20.10+ ou Docker Desktop
- 4GB RAM mínimo (8GB recomendado)
- 10GB espaço em disco
- Binários do Protheus na pasta `./totvs/`

### Estrutura de Arquivos Necessária
```
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

## 🚀 Início Rápido

### 1️⃣ PostgreSQL Embedded (Recomendado para Dev)

```bash
# Build da imagem
docker build -t protheus-standalone:latest .

# Executar container
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -p 1234:1234 \
  -p 1235:1235 \
  -v protheus-data:/totvs/protheus_data \
  -v postgres-data:/var/lib/pgsql/15/data \
  protheus-standalone:latest

# Verificar logs
docker logs -f protheus
```

### 2️⃣ PostgreSQL Externo

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
  protheus-standalone:latest
```

### 3️⃣ Microsoft SQL Server Externo

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
  protheus-standalone:latest
```

### 4️⃣ Oracle Externo

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
  protheus-standalone:latest
```

---

## 🔑 Variáveis de Ambiente

### Obrigatórias (Banco Externo)

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `DATABASE_TYPE` | Tipo de banco de dados | `POSTGRES`, `MSSQL`, `ORACLE` |
| `DATABASE_SERVER` | Endereço do servidor | `postgres.example.com` |
| `DATABASE_PORT` | Porta do banco | `5432`, `1433`, `1521` |
| `DATABASE_USERNAME` | Usuário do banco | `postgres`, `sa`, `system` |
| `DATABASE_PASSWORD` | Senha do banco de dados | `SenhaSegura123` |

### Opcionais

| Variável | Descrição | Padrão | Valores |
|----------|-----------|--------|---------|
| `DATABASE_NAME` | Nome do banco de dados | `protheus` | Qualquer nome válido |
| `DATABASE_EMBEDDED` | Usar PostgreSQL interno | `1` | `0` (não), `1` (sim) |
| `DATABASE_RESTORE` | Restaurar backup na criação | `1` | `0` (não), `1` (sim) |
| `DATABASE_RESTORE_FULL` | Restaurar backup completo | `0` | `0` (base), `1` (full) |
| `ENABLE_REST_EMBEDDED` | REST no AppServer principal | `0` | `0` (não), `1` (sim) |
| `ENABLE_REST_SERVICE` | AppServer REST separado | `0` | `0` (não), `1` (sim) |
| `DEBUG_SCRIPT` | Modo debug do entrypoint | `0` | `0` (não), `1` (sim) |

### Exemplos de Configuração

#### Desenvolvimento Local (Embedded)
```bash
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -e DATABASE_RESTORE_FULL=1 \
  -p 1234:1234 -p 1235:1235 \
  protheus-standalone:latest
```

#### Desenvolvimento Local (PostgreSQL Externo) 
```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=POSTGRES \
  -e DATABASE_SERVER=prod-db.internal \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=postgres \
  -e DATABASE_PASSWORD=${DB_PASSWORD} \
  -e DATABASE_NAME=protheus_prd \
  -e DATABASE_EMBEDDED=0 \
  -e DATABASE_RESTORE=0 \
  -p 1234:1234 -p 1235:1235 \
  protheus-standalone:latest
```

#### Desenvolvimento Local (MSSQL Externo)
```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=MSSQL \
  -e DATABASE_SERVER=mssql-prod.internal \
  -e DATABASE_PORT=1433 \
  -e DATABASE_USERNAME=sa \
  -e DATABASE_PASSWORD=${DB_PASSWORD} \
  -e DATABASE_NAME=protheus_prd \
  -e DATABASE_EMBEDDED=0 \
  -e DATABASE_RESTORE=0 \
  -p 1234:1234 -p 1235:1235 \
  protheus-standalone:latest
```

#### Desenvolvimento Local (Oracle com Service Name Customizado)
```bash
docker run -d \
  --name protheus \
  -e DATABASE_TYPE=ORACLE \
  -e DATABASE_SERVER=oracle.example.com \
  -e DATABASE_PORT=1521 \
  -e DATABASE_USERNAME=system \
  -e DATABASE_PASSWORD=${DB_PASSWORD} \
  -e DATABASE_NAME=PROTHEUSPRD \
  -e DATABASE_EMBEDDED=0 \
  -p 1234:1234 -p 1235:1235 \
  protheus-standalone:latest
```

#### AppServer REST Separado
```bash
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -e ENABLE_REST_SERVICE=1 \
  -p 1234:1234 -p 1235:1235 \
  -p 3234:3234 -p 3235:3235 \
  -p 8080:8080 \
  protheus-standalone:latest
```

#### REST Embedded no AppServer Principal
```bash
docker run -d \
  --name protheus \
  -e DATABASE_EMBEDDED=1 \
  -e ENABLE_REST_EMBEDDED=1 \
  -p 1234:1234 -p 1235:1235 \
  -p 8080:8080 \
  protheus-standalone:latest
```

---

## 📁 Estrutura de Diretórios

```
/totvs/
├── protheus/              # Binários do AppServer
│   ├── bin/appserver/     # Executável e configurações
│   └── apo/               # Repositório de objetos (RPO)
├── dbaccess/              # Middleware DBAccess
│   ├── multi/             # Binário dbaccess64
│   └── tools/             # Ferramentas de configuração
├── licenseserver/         # Servidor de licenças
│   └── bin/appserver/     # Executável
├── protheus_data/         # Dados do Protheus (VOLUME)
│   ├── system/            # Arquivos de sistema
│   └── systemload/        # Arquivos de carga
└── resources/             # Recursos de configuração
    ├── etc/               # Configurações ODBC
    ├── postgres/          # Scripts e backups PostgreSQL
    └── mssql/             # Scripts e backups MSSQL
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

## 📚 Exemplos de Uso

### Docker Compose

```yaml
version: '3.8'

services:
  protheus:
    image: protheus-standalone:latest
    container_name: protheus
    environment:
      DATABASE_EMBEDDED: 1
      DATABASE_RESTORE: 1
      DATABASE_RESTORE_FULL: 0
    ports:
      - "1234:1234"
      - "1235:1235"
    volumes:
      - protheus-data:/totvs/protheus_data
      - postgres-data:/var/lib/pgsql/15/data
    restart: unless-stopped
    healthcheck:
      test: ["/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10

volumes:
  protheus-data:
  postgres-data:
```

### Com PostgreSQL Externo

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: protheus
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  protheus:
    image: protheus-standalone:latest
    depends_on:
      - postgres
    environment:
      DATABASE_TYPE: POSTGRES
      DATABASE_SERVER: postgres
      DATABASE_PORT: 5432
      DATABASE_USERNAME: postgres
      DATABASE_PASSWORD: postgres
      DATABASE_NAME: protheus
      DATABASE_EMBEDDED: 0
      DATABASE_RESTORE: 0
    ports:
      - "1234:1234"
      - "1235:1235"
    volumes:
      - protheus-data:/totvs/protheus_data

volumes:
  protheus-data:
  postgres-data:
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

```bash
# Verificar logs
docker logs protheus

# Modo debug
docker run -e DEBUG_SCRIPT=1 protheus-standalone:latest

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

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Desenvolvido com ❤️ para a comunidade TOTVS Protheus**
