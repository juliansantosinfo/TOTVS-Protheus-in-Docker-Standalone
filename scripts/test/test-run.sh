#!/bin/bash
#
# ==============================================================================
# SCRIPT: test-compose.sh
# DESCRIÇÃO: Testa a inicialização do container TOTVS Protheus Standalone
#            em modo embedded, verificando se todos os serviços sobem corretamente.
# AUTOR: Julian de Almeida Santos
# DATA: 2026-02-17
# USO: ./scripts/test/test-compose.sh [OPTIONS]
#
# Opções:
#   --image <image>          Imagem a testar (padrão: protheus-standalone:latest)
#   --timeout <seconds>      Timeout para aguardar serviços (padrão: 180)
#   --keep                   Manter container após teste
#   --help                   Exibir ajuda
#
# Exemplos:
#   ./scripts/test/test-compose.sh
#   ./scripts/test/test-compose.sh --image protheus-standalone:v2.1
#   ./scripts/test/test-compose.sh --timeout 300 --keep
# ==============================================================================

set -euo pipefail

# --- Carregar Versões Centralizadas ---
if [ -f "versions.env" ]; then
    source "versions.env"
else
    echo "🚨 Erro: Arquivo 'versions.env' não encontrado."
    exit 1
fi

# --- Cores para Output ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# --- Variáveis de Configuração ---
IMAGE_FULLNAME="${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_VERSION}"
CONTAINER_NAME="protheus-test-$$"
TIMEOUT=180
KEEP_CONTAINER=0

# Portas a verificar
readonly PORTS=(1234 1235 5555 7890 5432)
readonly PORT_NAMES=("AppServer TCP" "AppServer WebApp" "License Server" "DBAccess" "PostgreSQL")

# --- Funções Auxiliares ---
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERRO: $1${NC}" >&2
}

print_header() {
    echo ""
    echo "=========================================================="
    echo "  $1"
    echo "=========================================================="
}

show_help() {
    cat << EOF
TOTVS Protheus Standalone - Test Script

USO:
    ./scripts/test/test-compose.sh [OPTIONS]

OPÇÕES:
    --image <image>          Imagem a testar (padrão: protheus-standalone:latest)
    --timeout <seconds>      Timeout para aguardar serviços (padrão: 180)
    --keep                   Manter container após teste
    --help                   Exibir ajuda

EXEMPLOS:
    # Teste padrão
    ./scripts/test/test-compose.sh

    # Testar imagem específica
    ./scripts/test/test-compose.sh --image protheus-standalone:v2.1

    # Aumentar timeout e manter container
    ./scripts/test/test-compose.sh --timeout 300 --keep

PORTAS VERIFICADAS:
    1234  - AppServer TCP
    1235  - AppServer WebApp
    5555  - License Server
    7890  - DBAccess
    5432  - PostgreSQL

EOF
    exit 0
}

cleanup() {
    if [ $KEEP_CONTAINER -eq 0 ]; then
        print_info "Limpando recursos..."
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
            print_success "Container removido"
        fi
    else
        print_warning "Container mantido: $CONTAINER_NAME"
        print_info "Para remover: docker rm -f $CONTAINER_NAME"
    fi
}

# --- Processamento de Argumentos ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --image)
            IMAGE_FULLNAME="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --keep)
            KEEP_CONTAINER=1
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Argumento desconhecido: $1"
            echo "Use --help para ver as opções disponíveis"
            exit 1
            ;;
    esac
done

# Registra função de cleanup
trap cleanup EXIT

# --- Validações ---
print_header "VALIDAÇÕES PRÉ-TESTE"

# Verifica se Docker está disponível
if ! command -v docker &> /dev/null; then
    print_error "Docker não está instalado ou não está no PATH"
    exit 1
fi
print_success "Docker disponível: $(docker --version)"

# Verifica se a imagem existe
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_FULLNAME}$"; then
    print_error "Imagem não encontrada: $IMAGE_FULLNAME"
    print_info "Execute o build primeiro: ./scripts/build/build.sh"
    exit 1
fi
print_success "Imagem encontrada: $IMAGE_FULLNAME"

# --- Inicialização do Container ---
print_header "INICIANDO CONTAINER"

print_info "Container: $CONTAINER_NAME"
print_info "Imagem: $IMAGE_FULLNAME"
print_info "Modo: DATABASE_EMBEDDED=1"
print_info "Timeout: ${TIMEOUT}s"
echo ""

# Remove container anterior se existir
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_warning "Container anterior encontrado, removendo..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
fi

# Inicia o container
print_info "Iniciando container..."
if docker run -d \
    --name "$CONTAINER_NAME" \
    --ulimit nofile=65536:65536 \
    --ulimit nproc=65536:65536 \
    --ulimit memlock=-1:-1 \
    -e DATABASE_EMBEDDED=1 \
    -e DATABASE_RESTORE=1 \
    -e DATABASE_RESTORE_FULL=0 \
    -p 1234:1234 \
    -p 1235:1235 \
    -p 5555:5555 \
    -p 7890:7890 \
    -p 5432:5432 \
    "$IMAGE_FULLNAME" > /dev/null 2>&1; then
    print_success "Container iniciado"
else
    print_error "Falha ao iniciar container"
    exit 1
fi

# --- Aguarda Container Ficar Healthy ---
print_header "AGUARDANDO INICIALIZAÇÃO"

print_info "Aguardando container ficar healthy (timeout: ${TIMEOUT}s)..."
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Verifica se container ainda está rodando
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container parou de executar"
        print_info "Últimas linhas do log:"
        docker logs --tail 50 "$CONTAINER_NAME"
        exit 1
    fi
    
    # Verifica health status
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        print_success "Container está healthy após ${ELAPSED}s"
        break
    elif [ "$HEALTH_STATUS" = "unhealthy" ]; then
        print_error "Container está unhealthy"
        print_info "Últimas linhas do log:"
        docker logs --tail 50 "$CONTAINER_NAME"
        exit 1
    fi
    
    echo -n "."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "Timeout aguardando container ficar healthy"
    print_info "Últimas linhas do log:"
    docker logs --tail 50 "$CONTAINER_NAME"
    exit 1
fi

# --- Verificação de Portas ---
print_header "VERIFICANDO PORTAS"

ALL_PORTS_OK=1

for i in "${!PORTS[@]}"; do
    PORT="${PORTS[$i]}"
    NAME="${PORT_NAMES[$i]}"
    
    print_info "Verificando porta $PORT ($NAME)..."
    
    # Aguarda até 30 segundos para cada porta
    PORT_OK=0
    for attempt in {1..30}; do
        if docker exec "$CONTAINER_NAME" bash -c "timeout 1 bash -c 'echo > /dev/tcp/localhost/$PORT'" > /dev/null 2>&1; then
            print_success "Porta $PORT ($NAME) está respondendo"
            PORT_OK=1
            break
        fi
        sleep 1
    done
    
    if [ $PORT_OK -eq 0 ]; then
        print_error "Porta $PORT ($NAME) não está respondendo"
        ALL_PORTS_OK=0
    fi
done

# --- Verificação de Processos ---
print_header "VERIFICANDO PROCESSOS"

PROCESSES=("appsrvlinux" "dbaccess64" "postgres")
PROCESS_NAMES=("AppServer" "DBAccess" "PostgreSQL")

ALL_PROCESSES_OK=1

for i in "${!PROCESSES[@]}"; do
    PROCESS="${PROCESSES[$i]}"
    NAME="${PROCESS_NAMES[$i]}"
    
    print_info "Verificando processo $NAME..."
    
    if docker exec "$CONTAINER_NAME" pgrep -f "$PROCESS" > /dev/null 2>&1; then
        COUNT=$(docker exec "$CONTAINER_NAME" pgrep -f "$PROCESS" | wc -l)
        print_success "Processo $NAME está rodando ($COUNT instância(s))"
    else
        print_error "Processo $NAME não encontrado"
        ALL_PROCESSES_OK=0
    fi
done

# --- Verificação de Logs ---
print_header "VERIFICANDO LOGS"

print_info "Procurando por erros nos logs..."

# Busca por padrões de erro
ERROR_PATTERNS=("ERRO" "ERROR" "FATAL" "FAIL")
ERRORS_FOUND=0

for pattern in "${ERROR_PATTERNS[@]}"; do
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -i "$pattern" > /dev/null; then
        ERRORS_FOUND=1
        break
    fi
done

if [ $ERRORS_FOUND -eq 1 ]; then
    print_warning "Possíveis erros encontrados nos logs"
    print_info "Últimas linhas com erros:"
    docker logs "$CONTAINER_NAME" 2>&1 | grep -i -E "ERRO|ERROR|FATAL|FAIL" | tail -10
else
    print_success "Nenhum erro crítico encontrado nos logs"
fi

# --- Verificação de Banco de Dados ---
print_header "VERIFICANDO BANCO DE DADOS"

print_info "Testando conexão com PostgreSQL..."

if docker exec "$CONTAINER_NAME" su - postgres -c "psql -d protheus -c 'SELECT 1' > /dev/null 2>&1"; then
    print_success "Conexão com banco de dados OK"
    
    # Verifica se banco tem tabelas
    TABLE_COUNT=$(docker exec "$CONTAINER_NAME" su - postgres -c "psql -d protheus -tAc \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'\"" 2>/dev/null || echo "0")
    print_info "Tabelas no banco: $TABLE_COUNT"
else
    print_error "Falha ao conectar no banco de dados"
    ALL_PROCESSES_OK=0
fi

# --- Resultado Final ---
print_header "RESULTADO DO TESTE"

if [ $ALL_PORTS_OK -eq 1 ] && [ $ALL_PROCESSES_OK -eq 1 ]; then
    print_success "TODOS OS TESTES PASSARAM!"
    echo ""
    print_info "Container: $CONTAINER_NAME"
    print_info "Status: Rodando e saudável"
    print_info "Tempo total: ${ELAPSED}s"
    echo ""
    
    if [ $KEEP_CONTAINER -eq 1 ]; then
        print_info "Comandos úteis:"
        echo "  # Ver logs"
        echo "  docker logs -f $CONTAINER_NAME"
        echo ""
        echo "  # Acessar container"
        echo "  docker exec -it $CONTAINER_NAME bash"
        echo ""
        echo "  # Parar container"
        echo "  docker stop $CONTAINER_NAME"
        echo ""
        echo "  # Remover container"
        echo "  docker rm -f $CONTAINER_NAME"
    fi
    
    exit 0
else
    print_error "ALGUNS TESTES FALHARAM"
    echo ""
    print_info "Verifique os logs acima para mais detalhes"
    print_info "Para ver logs completos: docker logs $CONTAINER_NAME"
    exit 1
fi
