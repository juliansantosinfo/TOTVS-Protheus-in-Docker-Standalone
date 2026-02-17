#!/bin/bash
#
# ==============================================================================
# SCRIPT: setup.sh
# DESCRIÇÃO: Script unificado para automatizar o download, montagem e extração 
#            dos pacotes do projeto TOTVS-Protheus-in-Docker a partir do GitHub.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-17
# USO: ./scripts/build/setup.sh
# ==============================================================================

# --- Configuração de Robustez (Boas Práticas Bash) ---
set -euo pipefail

# Caminho para o versions.env (assumindo execução da raiz ou de scripts/validation/)
if [ -f "versions.env" ]; then
    source "versions.env"
else
    echo "🚨 Erro: Arquivo 'versions.env' não encontrado."
    exit 1
fi

# --- CONFIGURAÇÕES GERAIS ---
GH_OWNER="juliansantosinfo"
GH_REPO="TOTVS-Protheus-in-Docker-Standalone-Resources"
GH_BRANCH="main"
GH_RELEASE="${RESOURCE_RELEASE:-}"

# --- FUNÇÃO: Exibir ajuda ---
mostrar_ajuda() {
    echo "Uso: $0"
}

# --- FUNÇÃO: Processar módulo ---
baixa_resources() {
    local GH_PATH DOWNLOAD_DIR DEST_DIR FILES API_URL

    GH_PATH="${GH_RELEASE}"
    DOWNLOAD_DIR="/tmp/standalone/${GH_RELEASE}"
    DEST_DIR="totvs"
    FILES=("totvs.tar.gz")

    API_URL="https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}"

    echo "=========================================="
    echo "🔧 Iniciando setup"
    echo "Repositório: ${GH_OWNER}/${GH_REPO}"
    echo "Pasta: ${GH_PATH}"
    echo "Branch: ${GH_BRANCH}"
    echo "=========================================="
    echo ""

    mkdir -p "${DOWNLOAD_DIR}" "${DEST_DIR}"

    # --- DOWNLOAD DOS ARQUIVOS ---

    echo "🔍 Consultando recursos locais no diretório de destino..."
    echo "Diretório de Destino: ${DEST_DIR}"

    RUN_DOWNLOAD=0
    for dir in dbaccess licenseserver protheus protheus_data; do
        if [ ! -d "${DEST_DIR}/${dir}" ]; then
            echo "❌ Diretório ${dir} não localizado!"
            RUN_DOWNLOAD=1
        else
            echo "✅ Diretório ${dir} localizado!"
        fi
    done
    
    if [[ "$RUN_DOWNLOAD" == "1" ]]; then
    
        echo "🔍 Consultando API do GitHub..."
        echo "URL: ${API_URL}"
    
        curl -s "${API_URL}" | jq -r '.[] | select(.type=="file") | .download_url' | while read -r file_url; do
            if [ -n "$file_url" ]; then
                file_name=$(basename "${file_url}")
                echo "⬇️  Baixando arquivo: ${file_name}"
                curl -sL "${file_url}" -o "${DOWNLOAD_DIR}/${file_name}"
                [[ $? -eq 0 ]] && echo "✅ Download concluído: ${file_name}" || echo "❌ Erro ao baixar ${file_name}"
            fi
        done
    else
        echo "⏭️ Ignorando download, arquivos disponíveus localmente."
    fi

    # --- JUNTA PARTES DIVIDIDAS ---
    echo ""
    echo "🧩 Verificando partes divididas..."
    for file in "${FILES[@]}"; do
        if ls "${DOWNLOAD_DIR}/${file}"* >/dev/null 2>&1; then
            echo "🔗 Montando ${file} a partir das partes..."
            cat "${DOWNLOAD_DIR}/${file}"* > "${DOWNLOAD_DIR}/${file}"
        else
            echo "⚠️ Nenhuma parte encontrada para ${file}"
        fi
    done

    # --- EXTRAÇÃO OU CÓPIA ---

    echo ""
    echo "📦 Iniciando extração dos arquivos..."
    for file in "${FILES[@]}"; do
        if [ -f "${DOWNLOAD_DIR}/${file}" ]; then
            echo "📂 Extraindo ${file} para ${DEST_DIR}"
            tar -xzf "${DOWNLOAD_DIR}/${file}" -C "${DEST_DIR}/"
        else
            echo "⚠️ Arquivo ${file} não encontrado para extração."
        fi
    done

    echo ""
    echo "------------------------------------------"
    echo "✅ Processo concluído."
    echo "Arquivos baixados em: ${DOWNLOAD_DIR}"
    echo "Arquivos finais em: ${DEST_DIR}"
    echo "------------------------------------------"
    echo ""
}

# Função auxiliar para remover arquivos e diretórios com verificação
remove_item() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "🧹 Removendo: $path"
    rm -rf "$path"
  else
    echo "ℹ️  Ignorado (não existe): $path"
  fi
}

# Executa o script clean.sh localizado no mesmo diretório que este script
# read -p "Deseja limpar os resources existentes antes de executar o setup (s/N)? " execute_clean
# echo ""

# if [[ "$execute_clean" =~ ^[Ss]$ ]]; then
#     "$(dirname "$0")/clean.sh"
# fi

# --- EXECUÇÃO PRINCIPAL ---
baixa_resources

echo "=========================================="
echo "🏁 Todos os módulos foram processados com sucesso!"
echo "=========================================="
echo ""
