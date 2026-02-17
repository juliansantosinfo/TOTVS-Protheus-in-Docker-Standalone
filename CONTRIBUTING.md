# Guia de Contribuição e Manutenção

Bem-vindo ao projeto **TOTVS Protheus Standalone em Docker**! Este documento serve como bússola para desenvolvedores e mantenedores que desejam entender as entranhas do projeto e como contribuir de forma padronizada.

---

## 🏗️ 1. Estrutura do Projeto

O repositório está organizado para separar a inteligência de orquestração (scripts/docker) dos recursos proprietários da TOTVS.

```text
.
├── .github/workflows/    # CI/CD (Build, Teste e Deploy Automatizado)
├── scripts/              # O "Cérebro" da Automação
│   ├── build/            # Scripts de construção e setup de binários
│   ├── hooks/            # Git Hooks para padronização de commits e pushes
│   ├── test/             # Scripts de teste de integração
│   └── validation/       # Lints de código (Shell, Dockerfile, etc.)
├── totvs/                # Estrutura onde os binários residem
│   ├── resources/        # Templates de configuração (.ini, .sql, ODBC)
│   └── (demais pastas)   # Binários (não versionados, baixados via setup.sh)
├── Dockerfile            # Definição da imagem baseada em Oracle Linux
├── entrypoint.sh         # Script principal de orquestração do container
└── versions.env          # Única fonte de verdade para versões de imagem e recursos
```

---

## 🛠️ 2. Ciclo de Desenvolvimento (Workflow)

Para garantir a qualidade, seguimos este fluxo para qualquer alteração:

### Passo 1: Preparação do Ambiente
Sempre inicie instalando os hooks de validação e preparando os binários:
```bash
# Instala hooks de commit e pre-push
chmod +x scripts/hooks/install.sh
./scripts/hooks/install.sh

# Baixa os binários necessários (necessita acesso ao repositório de recursos)
./scripts/build/setup.sh
```

### Passo 2: Alteração de Código
*   **Scripts:** Use boas práticas Bash (sempre `set -e`).
*   **Docker:** Tente manter as camadas (layers) otimizadas.
*   **Versões:** Se atualizar o Protheus, altere apenas no `versions.env`.

### Passo 3: Validação Local
Antes de enviar, execute os lints:
```bash
./scripts/validation/lint-shell.sh
./scripts/validation/lint-dockerfile.sh
```

### Passo 4: Teste de Integração
É mandatório testar se o container sobe com sua alteração:
```bash
./scripts/build/build.sh
./scripts/test/test-run.sh
```

---

## 🚀 3. Como funciona o CI/CD (GitHub Actions)

O pipeline definido em `.github/workflows/deploy.yml` é rigoroso:

1.  **Trigger:** Dispara em pushes para `main` ou branches de versão (ex: `12.1.*`).
2.  **Lint:** Valida sintaxe de scripts e Dockerfile.
3.  **Setup:** Recupera binários via cache ou download.
4.  **Build & Test:** Constrói a imagem e executa o `test-run.sh`.
5.  **Deploy:** Se o teste passar, envia ao Docker Hub tagueando automaticamente com o nome da branch.

---

## 📝 4. Padrão de Commits

Utilizamos **Conventional Commits** para manter o Changelog organizado:
*   `feat:` Nova funcionalidade.
*   `fix:` Correção de bug.
*   `docs:` Alteração apenas em documentação.
*   `ci:` Alterações em workflows do GitHub.
*   `refactor:` Alteração de código que não corrige bug nem adiciona feature.

---

## 🔍 5. Manutenção do dia a dia

### Adicionar novos recursos (SQL, Configs)
Arquivos de configuração devem ser colocados em `totvs/resources/`. O `entrypoint.sh` é responsável por mover ou injetar esses arquivos no lugar correto durante a subida do container.

### Atualizar Versão do AppServer/DBAccess
1.  Atualize o valor correspondente no arquivo `versions.env`.
2.  Garanta que o arquivo `.tar.gz` correspondente esteja disponível no repositório de recursos (`GH_REPO` configurado no `setup.sh`).
3.  O CI/CD detectará a mudança no hash de `versions.env`, invalidará o cache e construirá a nova versão.

---

## ⚖️ 6. Licenciamento e Propriedade
*   Este projeto de orquestração é **MIT**.
*   Os binários TOTVS que este projeto manipula são de propriedade da **TOTVS S.A.** e o uso deve respeitar o EULA da detentora.

---
**Dúvidas?** Abra uma Issue ou procure os mantenedores listados no `README.md`.
