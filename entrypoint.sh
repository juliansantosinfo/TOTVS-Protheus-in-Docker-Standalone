#!/bin/bash

################################################################################
# TOTVS Protheus Standalone - Entrypoint Script
################################################################################
# Descrição: Script de inicialização do container Docker do Protheus
# Autor: Julian de Almeida Santos
# Versão: 2.1
# Data: 2026-02-16
################################################################################

set -e              # Para execução em caso de erro
set -o pipefail     # Falha se qualquer comando no pipe falhar

################################################################################
# FUNÇÕES AUXILIARES
################################################################################

    # Função para imprimir cabeçalhos de seção
    print_header() {
        echo ""
        echo "======================================================================"
        echo "  $1"
        echo "======================================================================"
    }

    # Função para imprimir mensagens de sucesso
    print_success() {
        echo "✅ $1"
    }

    # Função para imprimir mensagens de erro
    print_error() {
        echo "❌ ERRO: $1" >&2
    }

    # Função para imprimir mensagens de aviso
    print_warning() {
        echo "⚠️  AVISO: $1"
    }

    # Função para imprimir mensagens informativas
    print_info() {
        echo "ℹ️  $1"
    }

    # Função para aguardar serviço iniciar verificando porta
    wait_for_port() {
        local service_name=$1
        local port=$2
        local timeout=${3:-30}
        
        print_info "Aguardando $service_name iniciar na porta $port..."
        
        for i in $(seq 1 $timeout); do
            if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
                print_success "$service_name iniciado com sucesso (porta $port)"
                return 0
            fi
            sleep 1
        done
        
        print_warning "Timeout aguardando $service_name após ${timeout}s (continuando...)"
        return 1
    }

    # Função para mascarar senhas em logs
    mask_password() {
        echo "********"
    }

################################################################################
# CONFIGURAÇÃO INICIAL
################################################################################

    print_header "INICIANDO TOTVS PROTHEUS STANDALONE"

    # Ativa modo debug se solicitado
    if [[ "${DEBUG_SCRIPT:-}" =~ ^(true|1|yes|y)$ ]]; then
        print_warning "Modo DEBUG ativado - senhas podem ser expostas nos logs"
        set -x
    fi

################################################################################
# DEFINIÇÃO DE VARIÁVEIS DE AMBIENTE
################################################################################

    print_header "CARREGANDO VARIÁVEIS DE AMBIENTE"

    # Variáveis de banco de dados
    export DATABASE_TYPE="${DATABASE_TYPE}"
    export DATABASE_SERVER="${DATABASE_SERVER}"
    export DATABASE_PORT="${DATABASE_PORT}"
    export DATABASE_USERNAME="${DATABASE_USERNAME}"
    export DATABASE_PASSWORD="${DATABASE_PASSWORD}"
    export DATABASE_NAME="${DATABASE_NAME:-protheus}"
    export DATABASE_EMBEDDED="${DATABASE_EMBEDDED:-1}"
    export DATABASE_RESTORE="${DATABASE_RESTORE:-1}"
    export DATABASE_RESTORE_FULL="${DATABASE_RESTORE_FULL:-0}"
    export ENABLE_REST_EMBEDDED="${ENABLE_REST_EMBEDDED:-0}"
    export ENABLE_REST_SERVICE="${ENABLE_REST_SERVICE:-0}"
    export DATABASE_ODBC_ALIAS=""

    print_info "DATABASE_TYPE: ${DATABASE_TYPE}"
    print_info "DATABASE_EMBEDDED: ${DATABASE_EMBEDDED}"
    print_info "DATABASE_RESTORE: ${DATABASE_RESTORE}"

################################################################################
# VALIDAÇÃO DE VARIÁVEIS OBRIGATÓRIAS
################################################################################

    print_header "VALIDANDO VARIÁVEIS OBRIGATÓRIAS"

    # Lista de variáveis que devem estar definidas
    if [[ "$DATABASE_EMBEDDED" = "1" ]]; then
        MANDATORY_VARS=()
    else
        MANDATORY_VARS=("DATABASE_TYPE" "DATABASE_SERVER" "DATABASE_PORT" "DATABASE_USERNAME" "DATABASE_PASSWORD")
    fi

    MISSING_VARS=0
    for var in "${MANDATORY_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            print_error "A variável de ambiente '$var' não está definida"
            MISSING_VARS=$((MISSING_VARS + 1))
        else
            # Mascara senha no log
            if [[ "$var" == "DATABASE_PASSWORD" ]]; then
                print_success "$var: $(mask_password)"
            else
                print_success "$var: ${!var}"
            fi
        fi
    done

    # Se houver variáveis faltando, aborta execução
    if [[ $MISSING_VARS -gt 0 ]]; then
        print_error "Faltam $MISSING_VARS variável(is) obrigatória(s)"
        print_error "Abortando inicialização"
        exit 1
    fi

    print_success "Todas as variáveis obrigatórias estão definidas"

################################################################################
# CONFIGURAÇÃO PARA BANCO EMBEDDED
################################################################################

    if [[ "$DATABASE_EMBEDDED" = "1" ]]; then
        print_header "CONFIGURANDO BANCO DE DADOS EMBEDDED"
        
        print_warning "[AVISO] DATABASE_EMBEDDED=1 ativo."
        print_warning "As seguintes variáveis serão sobrescritas para garantir o funcionamento local:"
        
        # Sobrescrita das variáveis
        export DATABASE_TYPE=POSTGRES
        export DATABASE_ODBC_ALIAS=POSTGRES
        export DATABASE_SERVER=127.0.0.1
        export DATABASE_PORT=5432
        export DATABASE_USERNAME=postgres
        export DATABASE_PASSWORD=postgres

        # Exibição dos novos valores para o usuário
        print_info "  -> DATABASE_TYPE      : $DATABASE_TYPE"
        print_info "  -> DATABASE_ODBC_ALIAS: $DATABASE_ODBC_ALIAS"
        print_info "  -> DATABASE_SERVER    : $DATABASE_SERVER"
        print_info "  -> DATABASE_PORT      : $DATABASE_PORT"
        print_info "  -> DATABASE_USERNAME  : $DATABASE_USERNAME"
        print_info "  -> DATABASE_PASSWORD  : $DATABASE_PASSWORD"
        print_info "----------------------------------------------------------------------"
    fi

################################################################################
# VALIDAÇÃO/CONFIGURAÇÃO PARA BANCO EXTERNO
################################################################################

    if [[ "$DATABASE_EMBEDDED" != "1" ]]; then
        print_header "CONFIGURANDO BANCO DE DADOS EXTERNO"
        
        print_warning "[AVISO] DATABASE_EMBEDDED=0 desativado."
        print_warning "Garanta que seguintes variáveis estão informadas corretamente para garantir o funcionamento:"

        # Exibição dos novos valores para o usuário
        print_info "  -> DATABASE_TYPE      : $DATABASE_TYPE"
        print_info "  -> DATABASE_ODBC_ALIAS: $DATABASE_ODBC_ALIAS"
        print_info "  -> DATABASE_SERVER    : $DATABASE_SERVER"
        print_info "  -> DATABASE_PORT      : $DATABASE_PORT"
        print_info "  -> DATABASE_USERNAME  : $DATABASE_USERNAME"
        print_info "  -> DATABASE_PASSWORD  : $DATABASE_PASSWORD"
        print_info "----------------------------------------------------------------------"

        print_header "VALIDANDO CONEXÃO COM BANCO DE DADOS EXTERNO"
        
        print_info "Verificando disponibilidade do banco em $DATABASE_SERVER:$DATABASE_PORT..."

        # Tenta conectar via TCP com timeout e retentativas
        MAX_RETRIES=10
        COUNT=0
        CONNECTED=0

        while [ $COUNT -lt $MAX_RETRIES ]; do
            if timeout 2 bash -c "</dev/tcp/${DATABASE_SERVER}/${DATABASE_PORT}" > /dev/null 2>&1; then
                print_success "Conexão TCP com o banco de dados estabelecida com sucesso!"
                CONNECTED=1
                break
            else
                COUNT=$((COUNT + 1))
                print_warning "Tentativa $COUNT/$MAX_RETRIES: Banco de dados não respondeu. Aguardando..."
                sleep 3
            fi
        done

        if [ $CONNECTED -eq 0 ]; then
            print_error "Não foi possível estabelecer conexão TCP com $DATABASE_SERVER na porta $DATABASE_PORT."
            print_error "Verifique se o banco de dados está rodando e se há conectividade de rede."
            exit 1
        fi
        
        print_info "----------------------------------------------------------------------"
    fi

################################################################################
# VALIDAÇÃO DE CONFLITO DE VARIÁVEIS 
################################################################################

    print_header "VALIDAÇÃO DE CONFLITO DE VARIÁVEIS"

    # Não permite iniciar o container com serviço REST EMBEDDED e STANDALONE AO MESMO TEMPO.
    # Ambos os serviços tentam utilizar a porta 8080 para o TOTVS Appserver.
    if [[ "$ENABLE_REST_EMBEDDED" == "1" ]] && [[ "$ENABLE_REST_SERVICE" == "1" ]]; then
        print_error "Conflito de configuração detectado!"
        print_error "As variáveis ENABLE_REST_EMBEDDED e ENABLE_REST_SERVICE"
        print_error "não podem estar ativas (1) simultaneamente devido ao conflito na porta 8080."
        exit 1
    fi

    # Se DATABASE_EMBEDDED for 1, o DATABASE_TYPE deve ser obrigatoriamente POSTGRES.
    # Isso evita que o container tente usar o PostgreSQL interno com configurações de MSSQL/Oracle.
    if [[ "$DATABASE_EMBEDDED" == "1" ]]; then
        if [[ -n "$DATABASE_TYPE" && "$DATABASE_TYPE" != "POSTGRES" ]]; then
            print_error "Conflito de configuração detectado!"
            print_error "Quando DATABASE_EMBEDDED=1, o DATABASE_TYPE não deve ser informado"
            print_error "ou deve ser obrigatoriamente POSTGRES."
            print_error "Valor atual detectado: DATABASE_TYPE=$DATABASE_TYPE"
            exit 1
        fi
    fi

################################################################################
# DEFINIÇÃO DE VALORES PADRÃO POR TIPO DE BANCO
################################################################################

    print_header "CONFIGURANDO VALORES PADRÃO PARA ${DATABASE_TYPE}"

    # Normaliza o tipo de banco para lowercase
    DB_TYPE_LOWER="$(echo "$DATABASE_TYPE" | tr '[:upper:]' '[:lower:]')"

    case "$DB_TYPE_LOWER" in
        mssql)
            print_info "Banco de dados: Microsoft SQL Server"
            export DATABASE_PORT="${DATABASE_PORT:-1433}"
            export DATABASE_USERNAME="${DATABASE_USERNAME:-sa}"
            export DATABASE_ODBC_ALIAS="MSSQL"
            ;;
        postgres|postgresql)
            print_info "Banco de dados: PostgreSQL"
            export DATABASE_PORT="${DATABASE_PORT:-5432}"
            export DATABASE_USERNAME="${DATABASE_USERNAME:-postgres}"
            export DATABASE_ODBC_ALIAS="POSTGRES"
            ;;
        oracle)
            print_info "Banco de dados: Oracle"
            export DATABASE_PORT="${DATABASE_PORT:-1521}"
            export DATABASE_USERNAME="${DATABASE_USERNAME:-system}"
            export DATABASE_ODBC_ALIAS="ORACLE"
            export TNS_ADMIN=/usr/lib/oracle/21/client64/lib/network/admin
            export TNS_FILE="$TNS_ADMIN"/tnsnames.ora
            export TNS_FILE_RESOURCE=/totvs/resources/oracle/tnsnames.ora
            ;;
        *)
            print_error "Tipo de banco de dados '${DATABASE_TYPE}' não é suportado"
            print_info "Tipos suportados: MSSQL, POSTGRES, ORACLE"
            exit 1
            ;;
    esac

    print_info "Porta: ${DATABASE_PORT}"
    print_info "Usuário: ${DATABASE_USERNAME}"
    print_info "Alias ODBC: ${DATABASE_ODBC_ALIAS}"

################################################################################
# CONFIGURAÇÃO DO DBACCESS
################################################################################

    print_header "CONFIGURANDO DBACCESS"

    print_info "DBAccess é o middleware que conecta o AppServer ao banco de dados"

    # Verifica se o binário de configuração existe
    if [ ! -f /totvs/dbaccess/tools/dbaccesscfg ]; then
        print_error "Binário 'dbaccesscfg' não encontrado em /totvs/dbaccess/tools/"
        exit 1
    fi

    print_success "Binário 'dbaccesscfg' localizado"

    # Navega para o diretório do DBAccess
    print_info "Acessando diretório /totvs/dbaccess/multi"
    cd /totvs/dbaccess/multi || {
        print_error "Falha ao acessar diretório /totvs/dbaccess/multi"
        exit 1
    }

    # Executa configuração do DBAccess
    print_info "Executando configuração do DBAccess..."
    print_info "Parâmetros: -u ${DATABASE_USERNAME} -d ${DATABASE_TYPE} -a ${DATABASE_ODBC_ALIAS}"

    /totvs/dbaccess/tools/dbaccesscfg \
        -u "${DATABASE_USERNAME}" \
        -p "${DATABASE_PASSWORD}" \
        -d "${DATABASE_TYPE}" \
        -a "${DATABASE_ODBC_ALIAS}" \
        -c "/usr/lib64/libodbc.so" || {
        print_error "Falha ao configurar DBAccess"
        exit 1
    }

    # Retorna ao diretório raiz
    cd /totvs || exit 1

    print_success "DBAccess configurado com sucesso"

################################################################################
# CONFIGURAÇÃO DO ODBC
################################################################################

    print_header "CONFIGURANDO ODBC.INI"

    print_info "ODBC permite que aplicações se conectem a diferentes bancos de dados"
    print_info "Arquivo de configuração: /etc/odbc.ini"

    print_info "Configurando nome do Banco de Dados para: $DATABASE_NAME"
    sed -i "s/DATABASE_NAME/$DATABASE_NAME/g" /etc/odbc.ini

    case "$DB_TYPE_LOWER" in
        mssql)
            print_info "Configurando DSN para Microsoft SQL Server"
            sed -i "s/DATABASE_SERVER_MSSQL/${DATABASE_SERVER}/g" /etc/odbc.ini
            sed -i "s/DATABASE_PORT_MSSQL/${DATABASE_PORT}/g" /etc/odbc.ini
            ;;
        postgres|postgresql)
            print_info "Configurando DSN para PostgreSQL"
            sed -i "s/DATABASE_SERVER_POSTGRES/${DATABASE_SERVER}/g" /etc/odbc.ini
            sed -i "s/DATABASE_PORT_POSTGRES/${DATABASE_PORT}/g" /etc/odbc.ini
            ;;
        oracle)
            print_info "Configurando DSN para Oracle"
            sed -i "s/DATABASE_USERNAME_ORACLE/${DATABASE_USERNAME}/g" /etc/odbc.ini
            sed -i "s/DATABASE_PASSWORD_ORACLE/${DATABASE_PASSWORD}/g" /etc/odbc.ini
            cp -f "$TNS_FILE_RESOURCE" "$TNS_FILE"
            sed -i "s,DATABASE_SERVER,${DATABASE_SERVER},g" "$TNS_FILE"
            sed -i "s,DATABASE_PORT,${DATABASE_PORT},g" "$TNS_FILE"
            sed -i "s,DATABASE_NAME,${DATABASE_NAME},g" "$TNS_FILE"
            ;;
        *)
            print_error "Tipo de banco '${DATABASE_TYPE}' inválido para configuração ODBC"
            exit 1
            ;;
    esac

    print_success "ODBC configurado para ${DATABASE_TYPE}"

################################################################################
# CONFIGURAÇÃO DO APPSERVER.INI
################################################################################

    print_header "CONFIGURANDO APPSERVER.INI"

    print_info "AppServer é o servidor de aplicação do Protheus"
    print_info "Arquivo: /totvs/protheus/bin/appserver/appserver.ini"

    cp /totvs/resources/config/appserver.ini /totvs/protheus/bin/appserver/appserver.ini

    # Substitui placeholders no arquivo de configuração
    sed -i "s/DATABASE_TYPE/${DATABASE_TYPE}/g" /totvs/protheus/bin/appserver/appserver.ini
    sed -i "s/DATABASE_ODBC_ALIAS/${DATABASE_ODBC_ALIAS}/g" /totvs/protheus/bin/appserver/appserver.ini

    print_success "AppServer configurado para usar ${DATABASE_TYPE}"

    if [[ "$ENABLE_REST_EMBEDDED" -eq 1 ]]; then
        sed -i "s/;;//g" /totvs/protheus/bin/appserver/appserver.ini
    fi

################################################################################
# CONFIGURAÇÃO DO APPSERVER.INI REST
################################################################################

    if [[ "$ENABLE_REST_SERVICE" = "1" ]]; then

        print_header "CONFIGURANDO APPREST.INI RERST"

        print_info "AppServer é o servidor de aplicação do Protheus"
        print_info "Arquivo: /totvs/protheus/bin/appserver/appserver-rest.ini"

        cp /totvs/resources/config/appserver-rest.ini /totvs/protheus/bin/appserver/appserver-rest.ini

        # Substitui placeholders no arquivo de configuração
        sed -i "s/DATABASE_TYPE/${DATABASE_TYPE}/g" /totvs/protheus/bin/appserver/appserver-rest.ini
        sed -i "s/DATABASE_ODBC_ALIAS/${DATABASE_ODBC_ALIAS}/g" /totvs/protheus/bin/appserver/appserver-rest.ini

        print_success "AppServer REST configurado para usar ${DATABASE_TYPE}"

    fi

################################################################################
# INICIALIZAÇÃO DO BANCO EMBEDDED (SE APLICÁVEL)
################################################################################

    if [ "$DATABASE_EMBEDDED" = "1" ]; then
        print_header "INICIALIZANDO POSTGRESQL EMBEDDED"
        
        print_info "Modo embedded: PostgreSQL será executado dentro do container"
        
        # Verifica e ajusta permissões do diretório de dados
        if [ -d "$PGDATA" ]; then
            print_info "Ajustando permissões do diretório de dados: $PGDATA"
            chown -R postgres:postgres "$PGDATA"
            chmod 700 "$PGDATA"
        else
            print_warning "Diretório PGDATA não encontrado: $PGDATA"
        fi
        
        # Remove arquivo de lock se existir (pode ocorrer em restart)
        if [ -f "$PGDATA/postmaster.pid" ]; then
            print_info "Removendo arquivo de lock antigo"
            rm -f "$PGDATA/postmaster.pid"
        fi
        
        # Inicia o PostgreSQL
        print_info "Iniciando servidor PostgreSQL..."
        su - postgres -c "/usr/pgsql-15/bin/pg_ctl start -D $PGDATA -w"
        
        print_info "Aguardando PostgreSQL estabilizar..."
        sleep 10

        if [[ "$DATABASE_RESTORE_FULL" = "1" ]]; then
            # Verifica se o arquivo de controle de restauração do banco de dados existe
            if [[ ! -f /var/lib/pgsql/15/data/.restored ]]; then
                tar -xzvf /totvs/resources/postgres/backup_full.tar.gz -C /totvs/resources/postgres
                su - postgres -c "psql -a -f /totvs/resources/postgres/backup.sql"
                rm -rf /totvs/resources/postgres/backup.sql
                touch /var/lib/pgsql/15/data/.restored
            fi
        fi
    fi

################################################################################
# VERIFICAÇÃO/CRIAÇÃO DO BANCO DE DADOS EXTERNO
################################################################################

    if [ "$DATABASE_EMBEDDED" != "1" ]; then

        # --- Desativando as flags ---
        set +e             # O script NÃO vai mais parar em caso de erro
        set +o pipefail    # Erros em pipes serão ignorados pelo código de saída final

        print_header "VERIFICANDO CONEXÃO COM BANCO DE DADOS EXTERNO ${DATABASE_TYPE}"

        case "$DB_TYPE_LOWER" in
            mssql)
                print_info "Testando conexão com SQL Server..."
                if sqlcmd -S ${DATABASE_SERVER},${DATABASE_PORT} -U sa -P ${DATABASE_PASSWORD} -d ${DATABASE_NAME} -C -Q "SELECT 1/1" -b 2>/dev/null; then
                    print_success "Banco '$DATABASE_NAME' existe e está acessível"
                else
                    print_warning "Banco '$DATABASE_NAME' não encontrado ou inacessível"
                    print_info "Criando banco de dados..."
                    sqlcmd -S ${DATABASE_SERVER},${DATABASE_PORT} -U sa -P ${DATABASE_PASSWORD} -d master -C -i /totvs/resources/mssql/create_database.sql
                    print_success "Banco criado com sucesso"
                fi
                ;;
            postgres|postgresql)
                export PGPASSWORD=${DATABASE_PASSWORD}
                print_info "Testando conexão com PostgreSQL externo..."
                if psql -h ${DATABASE_SERVER} -U ${DATABASE_USERNAME} -d ${DATABASE_NAME} -v ON_ERROR_STOP=1 -c "SELECT 1" 2>/dev/null; then
                    print_success "Banco '$DATABASE_NAME' existe e está acessível"
                else
                    print_warning "Banco '$DATABASE_NAME' não encontrado"
                    if [[ "$DATABASE_RESTORE" = "1" ]]; then
                        print_info "Restaurando banco de dados..."
                        if [[ "$DATABASE_RESTORE_FULL" = "1" ]]; then
                            tar -xzvf /totvs/resources/postgres/backup_full.tar.gz -C /totvs/resources/postgres
                        else
                            tar -xzvf /totvs/resources/postgres/backup_base.tar.gz -C /totvs/resources/postgres
                        fi
                        su - postgres -c "export PGPASSWORD='${DATABASE_PASSWORD}'; psql -a -h ${DATABASE_SERVER} -p ${DATABASE_PORT} -U postgres -d postgres -f /totvs/resources/postgres/backup.sql"
                        rm -rf /totvs/resources/postgres/backup.sql
                        print_success "Banco restaurado com sucesso"
                    else
                        print_info "Criando banco de dados..."
                        su - postgres -c "export PGPASSWORD='${DATABASE_PASSWORD}'; psql -a -h ${DATABASE_SERVER} -p ${DATABASE_PORT} -U postgres -d postgres -f /totvs/resources/postgres/create_database.sql"
                        print_success "Banco criado com sucesso"
                    fi
                fi
                ;;
            oracle)
                print_warning "NOT IMPLEMENTED!!!"
                ;;
            *)
                print_error "Tipo de banco de dados '${DATABASE_TYPE}' não é suportado"
                print_info "Tipos suportados: MSSQL, POSTGRES, ORACLE"
                exit 1
                ;;
        esac

        # --- Reativando as flags ---
        set -e             # O script volta a parar no primeiro erro
        set -o pipefail    # Erros em pipes voltam a ser detectados
    fi

################################################################################
# INICIALIZAÇÃO DO LICENSE SERVER
################################################################################

    print_header "INICIANDO LICENSE SERVER"

    print_info "License Server gerencia as licenças do Protheus"
    print_info "Porta: 5555"

    /totvs/licenseserver/bin/appserver/appsrvlinux 2>&1 | sed 's/^/[licenseserver] /' &
    LICENSESERVER_PID=$!

    print_info "PID do License Server: $LICENSESERVER_PID"

    # Aguarda o serviço iniciar
    wait_for_port "License Server" 5555 30

################################################################################
# INICIALIZAÇÃO DO DBACCESS
################################################################################

    print_header "INICIANDO DBACCESS"

    print_info "DBAccess é o middleware entre AppServer e banco de dados"
    print_info "Porta: 7890"

    /totvs/dbaccess/multi/dbaccess64 2>&1 | sed 's/^/[dbaccess] /' &
    DBACCESS_PID=$!

    print_info "PID do DBAccess: $DBACCESS_PID"

    # Aguarda o serviço iniciar
    wait_for_port "DBAccess" 7890 30

################################################################################
# INICIALIZAÇÃO DO APPSERVER REST
################################################################################

    if [[ "$ENABLE_REST_SERVICE" = "1" ]]; then

        print_header "INICIANDO APPSERVER REST"

        print_info "AppServer REST é o servidor REST do Protheus"
        print_info "Porta HTTP: 8080"

        /totvs/protheus/bin/appserver/appsrvlinux -ini=appserver-rest.ini 2>&1 | sed 's/^/[apprest] /' &
        APPREST_PID=$!

        print_info "PID do AppServer REST: $APPREST_PID"

    fi

################################################################################
# INICIALIZAÇÃO DO APPSERVER
################################################################################

    print_header "INICIANDO APPSERVER"

    print_info "AppServer é o servidor principal do Protheus"
    print_info "Porta TCP: 1234"
    print_info "Porta WebApp: 1235"
    print_info ""
    print_success "TOTVS Protheus Standalone iniciado com sucesso!"
    print_info "Logs do AppServer serão exibidos abaixo:"
    print_info ""

    # Inicia o AppServer como processo principal (exec substitui o shell)
    exec /totvs/protheus/bin/appserver/appsrvlinux 2>&1 | sed 's/^/[appserver] /'
