#!/bin/bash
#
# ==============================================================================
# SCRIPT: clean.sh
# DESCRIÇÃO: Remove arquivos e diretórios temporários gerados pelos módulos
#            do sistema (appserver, dbaccess, licenseserver, smartview, mssql, 
#            postgres, oracle).
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-17
# USO: ./scripts/build/clean.sh [modulo]
# ==============================================================================

# --- Configuração de Robustez (Boas Práticas Bash) ---
set -euo pipefail

IFS=$'\n\t'

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

# Função para limpar um diretório específico
limpar() {
  local dir="$1"
  case "$dir" in
    appserver)
      remove_item "totvs/protheus"
      remove_item "totvs/protheus_data"
      ;;
    dbaccess)
      remove_item "totvs/dbaccess"
      ;;
    licenseserver)
      remove_item "totvs/licenseserver"
      ;;
    *)
      echo "❌ Erro: diretório inválido '$dir'. Use: appserver, dbaccess, licenseserver, smartview, mssql, postgres ou oracle."
      exit 1
      ;;
  esac
}

echo "============================================="
echo "🧼 Iniciando limpeza de arquivos temporários..."
echo "============================================="
echo ""

# Se nenhum argumento for passado, limpar todos
if [[ $# -eq 0 ]]; then
  for dir in appserver dbaccess licenseserver; do
    echo "🔹 Limpando '$dir'..."
    limpar "$dir"
    echo ""
  done
else
  limpar "$1"
fi

echo ""
echo "✅ Limpeza concluída com sucesso!"
echo ""
