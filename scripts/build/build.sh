#!/bin/bash
#
# ==============================================================================
# SCRIPT: build.sh
# DESCRIÇÃO: Responsável por realizar o build da imagem Docker para o protheus
#            standalone e restaurar ou atualizar dependências da aplicação.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-17
# USO: ./build.sh [plain | auto | tty]
#      - Argumento 1 (progress): Controla o formato do output do Docker (padrão: auto).
# ==============================================================================

# --- Configuração de Robustez (Boas Práticas Bash) ---
# -e: Sai imediatamente se um comando falhar.
# -u: Trata variáveis não definidas como erro.
# -o pipefail: Garante que um pipeline (ex: cat | tar) falhe se qualquer comando falhar.
set -euo pipefail

# --- Variáveis de Configuração Global ---
readonly REQUIRED_FILE_NAME="Dockerfile"
readonly TOTVS_DIR="./totvs"

# --- Carregar Versões Centralizadas ---
if [ -f "versions.env" ]; then
    source "versions.env"
else
    echo "🚨 Erro: Arquivo 'versions.env' não encontrado."
    exit 1
fi

# --- Componentes da Docker Tag (Separados para fácil manutenção) ---
readonly DOCKER_IMAGE_TAG="${IMAGE_VERSION}"
readonly DOCKER_TAG="${DOCKER_USER}/${IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

# Argumento 2: Modo de Progresso do Docker Build (padrão: auto)
# Se não for fornecido, usa 'auto'. Se for fornecido, usa o valor, convertido para minúsculas.
DOCKER_PROGRESS_MODE="${1:-auto}"

# Verifica se é pedido de ajuda
if [[ "$DOCKER_PROGRESS_MODE" == "--help" ]] || [[ "$DOCKER_PROGRESS_MODE" == "-h" ]]; then
    echo "USO: ./scripts/build/build.sh [plain | auto | tty]"
    echo ""
    echo "OPÇÕES:"
    echo "  plain    - Output simples sem formatação"
    echo "  auto     - Detecta automaticamente (padrão)"
    echo "  tty      - Output formatado para terminal"
    echo ""
    echo "EXEMPLOS:"
    echo "  ./scripts/build/build.sh"
    echo "  ./scripts/build/build.sh plain"
    echo "  ./scripts/build/build.sh tty"
    exit 0
fi

DOCKER_PROGRESS_MODE=$(echo "$DOCKER_PROGRESS_MODE" | tr '[:upper:]' '[:lower:]')

# ----------------------------------------------------
#               SEÇÃO 0: VALIDAÇÃO E ACESSO AO DIRETÓRIO
# ----------------------------------------------------

# Obtém o nome do diretório atual.
CURRENT_DIR_NAME=$(basename "$PWD")

echo "🎯 Verificando o ambiente de execução..."

# 1. Verifica se já estamos no diretório correto.
if [ -f "$REQUIRED_FILE_NAME" ]; then
    echo "✅ Arquivo Dockerfile localizado com sucesso."
# 2. Caso contrário, é um erro.
else
    echo "🚨 ERRO DE AMBIENTE: Este script deve ser executado *dentro* do diretório raiz do projeto." >&2
    echo "❌ Erro: Arquivo Dokerfile não encontrado."
    echo "    Por favor, corrija sua localização e tente novamente." >&2
    exit 1 # Sai com código de erro.
fi

# ----------------------------------------------------
#               SEÇÃO 1: PREPARAÇÃO DOS RECURSOS
# ----------------------------------------------------

echo "🚀 Iniciando processo de build..."
echo "ℹ️ Docker Tag Completa: $DOCKER_TAG"
echo "ℹ️ Docker Progress Mode: $DOCKER_PROGRESS_MODE"
echo "🔍 Verificando o diretório '${TOTVS_DIR}'..."

# Verifica se os recursos existem.
RUN_DOWNLOAD=0
for dir in dbaccess licenseserver protheus protheus_data; do
    if [ ! -d "${TOTVS_DIR}/${dir}" ]; then
        echo "❌ Diretório ${dir} não localizado!"
        RUN_DOWNLOAD=1
    else
        echo "✅ Diretório ${dir} localizado!"
    fi
done

if [[ "$RUN_DOWNLOAD" = "1" ]]; then
    ./scripts/build/setup.sh
fi

# ----------------------------------------------------
#               SEÇÃO 2: EXECUÇÃO DO DOCKER BUILD
# ----------------------------------------------------

echo "🐳 Iniciando Docker build..."
# Executa o comando docker build, usando as flags para um build limpo e output legível.
# Usa a variável $DOCKER_TAG reconstruída.
docker build --progress="$DOCKER_PROGRESS_MODE" -t "$DOCKER_TAG" .
echo "✅ Docker build finalizado com sucesso. Imagem: $DOCKER_TAG"
echo "✅ Processo de build finalizado com sucesso!"