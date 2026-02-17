# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-br/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-br/).

## [1.0.0] - 2026-02-17

### Adicionado
- **Arquitetura Standalone**: Dockerfile baseado em Oracle Linux 8.5 para rodar AppServer, DBAccess e License Server.
- **Banco de Dados**: Suporte a PostgreSQL 15 embutido (embedded) e conexões externas (MSSQL, PostgreSQL e Oracle).
- **Orquestração**: Script `entrypoint.sh` para configuração dinâmica de arquivos `.ini` e ODBC.
- **CI/CD**: Workflow do GitHub Actions para build e push automatizado ao Docker Hub.
- **Automação**: Scripts de setup, build e limpeza dos binários TOTVS.
- **Qualidade**: Hooks de Git e scripts de validação (lint) para Dockerfile e Shell scripts.
- **Monitoramento**: Script de healthcheck para validar a disponibilidade dos serviços.
- **Documentação**: README completo com arquitetura e guia de início rápido.
- **Infraestrutura**: Configuração de `docker-compose.yaml` para deploy rápido.
- **Licença**: Adicionada licença MIT.
