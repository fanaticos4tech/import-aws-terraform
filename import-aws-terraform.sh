#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------
# Configurações (pode sobrescrever via variável de ambiente)
# -------------------------------------------------------
AWS_PROFILE=${AWS_PROFILE:-default}
AWS_REGION=${AWS_REGION:-us-east-1}
OUTPUT_DIR=${OUTPUT_DIR:-tf-import-temp}
WORK_DIR=$(pwd)

# -------------------------------------------------------
# Lista de serviços AWS para importar (ajuste conforme necessário)
# Use 'terraformer import aws list' para ver todos os serviços suportados
# -------------------------------------------------------
RESOURCES=(
  "ec2_instance"
  "vpc"  
  "s3"
  "rds"
  "iam"
)

# -------------------------------------------------------
# Checagem de pré-requisitos
# -------------------------------------------------------
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI não encontrada. Instale e configure antes."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform não encontrado. Instale antes."; exit 1; }
command -v terraformer >/dev/null 2>&1 || { echo "❌ Terraformer não encontrado. Instale-o manualmente conforme README."; exit 1; }

# -------------------------------------------------------
# Preparar diretório temporário e inicializar Terraform
# -------------------------------------------------------
rm -rf "${WORK_DIR}/${OUTPUT_DIR}"
mkdir -p "${WORK_DIR}/${OUTPUT_DIR}"
cd "${WORK_DIR}/${OUTPUT_DIR}"

# Criar main.tf temporário para baixar o provider AWS
echo "terraform {" > main.tf
cat <<EOF >> main.tf
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = "${AWS_REGION}"
  profile = "${AWS_PROFILE}"
}
EOF

echo "🚀 Inicializando Terraform para baixar provider AWS..."
terraform init -upgrade -input=false -no-color

# -------------------------------------------------------
# Importar cada serviço com Terraformer
# -------------------------------------------------------
for service in "${RESOURCES[@]}"; do
  echo "🚀 Importando serviço: ${service}..."
  terraformer import aws \
    --resources="${service}" \
    --regions="${AWS_REGION}" \
    --profile="${AWS_PROFILE}" \
    --connect=true || echo "⚠️ Falha ao importar ${service}, pulando."
done

# -------------------------------------------------------
# Mover .tf e state para o diretório do projeto
# -------------------------------------------------------
echo "📦 Movendo arquivos gerados para: ${WORK_DIR}"
if compgen -G "aws/*.tf" > /dev/null; then
  mv aws/*.tf "${WORK_DIR}/"
  mv aws/terraform.tfstate* "${WORK_DIR}/"
else
  echo "⚠️ Nenhum arquivo .tf gerado." 
fi

# Limpa temporários
echo "✅ Importação concluída!"
rm -rf aws
rm main.tf
rm .terraform.lock.hcl 2>/dev/null || true
rm -rf .terraform
cd "${WORK_DIR}"

echo "👉 Agora:
     terraform init
     terraform plan"