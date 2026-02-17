################################################################################
# TOTVS Protheus Standalone - Dockerfile
################################################################################
# Descrição: Container com PostgreSQL embedded e suporte a MSSQL/Oracle externo
# Versão: 2.1
# Data: 2026-02-16
################################################################################

FROM oraclelinux:8.5

# Metadata
LABEL release="12.1.2510" \
      build="24.3.1.1" \
      dbapi="24.1.1.0" \
      licenseserver.version="3.7.0" \
      dbaccess.version="24.1.1.0" \
      postgres.version="15" \
      description="TOTVS Protheus Standalone com PostgreSQL Embutido" \
      maintainer="Julian de Almeida Santos <julian.santos.info@gmail.com>" \
      version="2.1"

WORKDIR /totvs

################################################################################
# VARIÁVEIS DE AMBIENTE
################################################################################

ARG PGDATA="/var/lib/pgsql/15/data"

ENV DATABASE_TYPE= \
    DATABASE_SERVER= \
    DATABASE_PORT= \
    DATABASE_USERNAME= \
    DATABASE_PASSWORD= \
    DATABASE_NAME=protheus \
    DATABASE_EMBEDDED=1 \
    DATABASE_RESTORE=1 \
    DATABASE_RESTORE_FULL=0 \
    ENABLE_REST_EMBEDDED=0 \
    ENABLE_REST_SERVICE=0 \
    DEBUG_SCRIPT=0 \
    PATH="$PATH:/opt/mssql-tools18/bin:/usr/pgsql-15/bin:/usr/lib/oracle/21/client64/bin" \
    PGDATA="$PGDATA" \
    LD_LIBRARY_PATH="/usr/lib/oracle/21/client64/lib:$LD_LIBRARY_PATH" \
    ORACLE_HOME="/usr/lib/oracle/21/client64"

################################################################################
# INSTALAÇÃO DE DEPENDÊNCIAS
################################################################################

# Atualiza sistema e remove conflitos
# unixODBC-utf16 causa conflitos com drivers ODBC modernos
RUN dnf update -y && \
    dnf remove -y unixODBC-utf16 unixODBC-utf16-devel && \
    dnf -qy module disable postgresql && \
    dnf install -y dmidecode nano tar glibc-locale-source glibc-langpack-pt && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Instala drivers MSSQL (para conexão com bancos externos)
RUN curl -s https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo && \
    ACCEPT_EULA=Y dnf install -y msodbcsql18 mssql-tools18 unixODBC-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Instala PostgreSQL Server + Client + ODBC Driver
RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf install -y postgresql15-server postgresql15-libs postgresql15-odbc && \
    ln -s /usr/pgsql-15/lib/psqlodbcw.so /usr/lib/psqlodbcw.so && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Instala Oracle Instant Client (Basic, ODBC, SQL*Plus)
RUN dnf install -y oracle-instantclient-release-el8 && \
    dnf install -y oracle-instantclient-basic \
                   oracle-instantclient-odbc \
                   oracle-instantclient-sqlplus && \
    dnf clean all && \
    rm -rf /var/cache/dnf

################################################################################
# CÓPIA DE ARQUIVOS
################################################################################

COPY ./totvs/resources/etc /etc
COPY ./totvs /totvs
COPY ./entrypoint.sh /entrypoint.sh
COPY ./healthcheck.sh /healthcheck.sh

RUN chmod +x /entrypoint.sh /healthcheck.sh

################################################################################
# INICIALIZAÇÃO DO POSTGRESQL
################################################################################

RUN localedef -c -i pt_BR -f ISO-8859-1 pt_BR.ISO-8859-1 && \
    localedef -c -i pt_BR -f ISO-8859-1 pt_BR.CP1252 && \
    # Inicializa o diretório de dados
    su - postgres -c "/usr/pgsql-15/bin/initdb -D $PGDATA --locale=pt_BR.ISO-8859-1 -E LATIN1" && \
    # Configura permissão para conexões externas
    echo "host all all 0.0.0.0/0 md5" >> /var/lib/pgsql/15/data/pg_hba.conf && \
    echo "listen_addresses='*'" >> /var/lib/pgsql/15/data/postgresql.conf && \
    # Inicia o banco para permitir execução de comandos SQL
    su - postgres -c "/usr/pgsql-15/bin/pg_ctl start -D $PGDATA -w" && \
    # Restaura backup do banco de dados
    tar -xzvf /totvs/resources/postgres/backup_base.tar.gz -C /totvs/resources/postgres && \
    su - postgres -c "psql -a -f /totvs/resources/postgres/backup.sql" && \
    rm -rf /totvs/resources/postgres/backup.sql && \
    # Para o banco de forma limpa para persistir a camada (layer) do Docker
    su - postgres -c "/usr/pgsql-15/bin/pg_ctl stop -D $PGDATA"

################################################################################
# EXPOSIÇÃO DE PORTAS
################################################################################

EXPOSE 1234 1235 3234 3235 7890 2234 5555 8020 5432 8080

################################################################################
# VOLUMES
################################################################################

VOLUME ["/totvs/protheus_data", "/var/lib/pgsql/15/data"]

################################################################################
# HEALTHCHECK
################################################################################

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=10 \
    CMD /healthcheck.sh

################################################################################
# ENTRYPOINT
################################################################################

ENTRYPOINT ["/bin/sh", "-c", "/entrypoint.sh"]