#!/bin/bash
#
# ==============================================================================
# SCRIPT: versions.sh
# DESCRIÇÃO: Valida se a versão definida nos Dockerfiles corresponde à versão
#            centralizada no arquivo versions.env.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-12
# USO: ./scripts/validation/versions.sh [--fix]
# ==============================================================================

set -u

# Caminho para o versions.env (assumindo execução da raiz ou de scripts/validation/)
if [ -f "versions.env" ]; then
    source "versions.env"
else
    echo "🚨 Erro: Arquivo 'versions.env' não encontrado."
    exit 1
fi

AUTO_FIX=false
if [[ "${1:-}" == "--fix" ]]; then
    AUTO_FIX=true
fi

EXIT_CODE=0

# Função de Validação
validate_service() {
    local version_var=$1
    local dockerfile="./Dockerfile"
    local expected_version="${!version_var}"

    if [ ! -f "$dockerfile" ]; then
        echo "⚠️  Aviso: Dockerfile não encontrado."
        exit 1
    fi

    # Extrai a versão atual (procura por LABEL release= ou LABEL version=)
    # 1. grep: busca a linha
    # 2. head: garante apenas a primeira ocorrência
    # 3. cut: pega o valor depois do =
    # 4. tr: remove aspas, espaços e barras invertidas de continuação de linha
    local actual_version=$(grep -iE "LABEL (release|version)=" "$dockerfile" | head -n 1 | cut -d'=' -f2 | tr -d '"' | tr -d "[:space:]" | tr -d "\\\\")
    
    # Identifica qual label está sendo usada para o possível fix
    local label_type=$(grep -iE -o "LABEL (release|version)=" "$dockerfile" | head -n 1 | cut -d' ' -f2 | cut -d'=' -f1)

    if [ "$actual_version" != "$expected_version" ]; then
        echo "❌ ERRO: Versão no Dockerfile ($actual_version) difere de versions.env ($expected_version)"
        EXIT_CODE=1
    else
        echo "✅ OK Versão correta ($expected_version)"
    fi
}

echo "🔍 Iniciando validação de versões..."
echo "-----------------------------------"

validate_service "IMAGE_VERSION"

echo "-----------------------------------"
if [ $EXIT_CODE -ne 0 ]; then
    echo "🛑 Validação falhou! a versão esta inconsistente."
    exit 1
else
    echo "🎉 A versão esta sincronizada."
    exit 0
fi
