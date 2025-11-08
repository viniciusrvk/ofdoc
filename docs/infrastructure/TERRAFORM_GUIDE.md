# Guia de Infraestrutura — Terraform

## 🏗️ Visão Geral

A infraestrutura do DCR Enterprise é provisionada via **Terraform** na **AWS**, seguindo princípios de Infrastructure as Code (IaC).

**Repositório:** `terraform/`

---

## 📁 Estrutura de Diretórios

```
terraform/
├── main.tf                 # Configuração principal
├── variables.tf            # Variáveis do módulo raiz
├── outputs.tf              # Outputs (endpoints, IDs)
├── backend.tf              # Configuração de backend remoto (S3)
├── versions.tf             # Versões de providers
├── modules/
│   ├── vpc/                # Rede (VPC, subnets, NAT)
│   ├── eks/                # Cluster Kubernetes
│   ├── rds/                # PostgreSQL (RDS)
│   ├── redis/              # ElastiCache Redis
│   ├── s3-worm/            # Bucket S3 com Object Lock
│   ├── sns-sqs/            # Mensageria (SNS + SQS)
│   ├── kms/                # Chaves de criptografia
│   └── api-gateway/        # API Gateway (opcional)
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    ├── qa/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    └── prd/
        ├── main.tf
        ├── terraform.tfvars
        └── backend.tf
```

---

## 🚀 Quick Start

### Pré-requisitos

- **Terraform** >= 1.6
- **AWS CLI** configurado
- Credenciais com permissões adequadas (Admin ou políticas específicas)

### Provisionamento de Ambiente

```bash
# Navegar para o ambiente desejado
cd terraform/environments/prd

# Inicializar Terraform (baixar providers e módulos)
terraform init

# Validar sintaxe
terraform validate

# Planejar mudanças
terraform plan -out=plan.tfplan

# Aplicar mudanças
terraform apply plan.tfplan

# Destruir (cuidado!)
terraform destroy
```

---

## 📦 Módulos

### 1. VPC

**Caminho:** `modules/vpc/`

**Recursos Provisionados:**
- VPC com CIDR customizável
- Subnets públicas (3 AZs)
- Subnets privadas (3 AZs)
- Internet Gateway
- NAT Gateways (1 por AZ)
- Route tables
- VPC Flow Logs (CloudWatch)

**Inputs:**

| Variável | Tipo | Descrição | Padrão |
|----------|------|-----------|--------|
| `vpc_cidr` | string | CIDR da VPC | `10.0.0.0/16` |
| `public_subnet_cidrs` | list(string) | CIDRs das subnets públicas | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` |
| `private_subnet_cidrs` | list(string) | CIDRs das subnets privadas | `["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]` |
| `enable_nat_gateway` | bool | Criar NAT Gateways | `true` |

**Outputs:**
- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`

**Exemplo de Uso:**

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  enable_nat_gateway    = true
  
  tags = {
    Environment = "prd"
    Project     = "dcr-enterprise"
  }
}
```

---

### 2. EKS

**Caminho:** `modules/eks/`

**Recursos Provisionados:**
- Cluster EKS (Kubernetes 1.28+)
- Node groups (managed)
- IAM roles e policies
- Security groups
- OIDC provider (para IRSA)
- Add-ons: vpc-cni, kube-proxy, coredns

**Inputs:**

| Variável | Tipo | Descrição |
|----------|------|-----------|
| `cluster_name` | string | Nome do cluster |
| `cluster_version` | string | Versão Kubernetes (ex: `1.28`) |
| `vpc_id` | string | ID da VPC |
| `subnet_ids` | list(string) | IDs das subnets privadas |
| `node_instance_types` | list(string) | Tipos de instâncias (ex: `["t3.medium"]`) |
| `node_desired_size` | number | Número desejado de nodes |
| `node_min_size` | number | Mínimo de nodes |
| `node_max_size` | number | Máximo de nodes |

**Outputs:**
- `cluster_id`
- `cluster_endpoint`
- `cluster_certificate_authority_data`
- `node_group_id`

**Exemplo de Uso:**

```hcl
module "eks" {
  source = "../../modules/eks"
  
  cluster_name     = "dcr-prd-cluster"
  cluster_version  = "1.28"
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids
  
  node_instance_types = ["t3.large"]
  node_desired_size   = 6
  node_min_size       = 3
  node_max_size       = 20
  
  tags = {
    Environment = "prd"
  }
}
```

---

### 3. RDS (PostgreSQL)

**Caminho:** `modules/rds/`

**Recursos Provisionados:**
- RDS PostgreSQL (14+)
- Multi-AZ (produção)
- Automated backups
- Encryption at rest (KMS)
- Security group

**Inputs:**

| Variável | Tipo | Descrição |
|----------|------|-----------|
| `identifier` | string | Nome da instância |
| `engine_version` | string | Versão PostgreSQL (ex: `14.10`) |
| `instance_class` | string | Classe da instância (ex: `db.t3.medium`) |
| `allocated_storage` | number | Tamanho em GB |
| `db_name` | string | Nome do banco |
| `username` | string | Usuário master |
| `password` | string | Senha (usar secrets!) |
| `vpc_id` | string | ID da VPC |
| `subnet_ids` | list(string) | IDs das subnets privadas |
| `multi_az` | bool | Habilitar Multi-AZ |

**Outputs:**
- `db_instance_endpoint`
- `db_instance_id`
- `db_name`

**Exemplo de Uso:**

```hcl
module "rds" {
  source = "../../modules/rds"
  
  identifier        = "dcr-prd-db"
  engine_version    = "14.10"
  instance_class    = "db.r6g.xlarge"
  allocated_storage = 100
  db_name           = "dcr_registry"
  username          = "dcr_admin"
  password          = var.db_password # usar AWS Secrets Manager
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  multi_az   = true
  
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  tags = {
    Environment = "prd"
  }
}
```

---

### 4. Redis (ElastiCache)

**Caminho:** `modules/redis/`

**Recursos Provisionados:**
- ElastiCache Redis cluster
- Cluster mode ou replication group
- Security group
- Subnet group

**Inputs:**

| Variável | Tipo | Descrição |
|----------|------|-----------|
| `cluster_id` | string | Nome do cluster |
| `node_type` | string | Tipo de node (ex: `cache.r6g.large`) |
| `num_cache_nodes` | number | Número de nodes (ou shards) |
| `engine_version` | string | Versão Redis (ex: `7.0`) |
| `vpc_id` | string | ID da VPC |
| `subnet_ids` | list(string) | IDs das subnets privadas |

**Outputs:**
- `redis_endpoint`
- `redis_port`

**Exemplo de Uso:**

```hcl
module "redis" {
  source = "../../modules/redis"
  
  cluster_id       = "dcr-prd-cache"
  node_type        = "cache.r6g.large"
  num_cache_nodes  = 3
  engine_version   = "7.0"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  tags = {
    Environment = "prd"
  }
}
```

---

### 5. S3 WORM (Auditoria)

**Caminho:** `modules/s3-worm/`

**Recursos Provisionados:**
- Bucket S3 com Object Lock
- Versioning habilitado
- Encryption (SSE-KMS)
- Lifecycle policies
- Bucket policy (acesso restrito)

**Inputs:**

| Variável | Tipo | Descrição |
|----------|------|-----------|
| `bucket_name` | string | Nome do bucket |
| `retention_days` | number | Dias de retenção (ex: 1825 = 5 anos) |
| `kms_key_id` | string | ID da chave KMS |

**Outputs:**
- `bucket_id`
- `bucket_arn`

**Exemplo de Uso:**

```hcl
module "s3_worm" {
  source = "../../modules/s3-worm"
  
  bucket_name    = "dcr-prd-audit-logs"
  retention_days = 1825 # 5 anos
  kms_key_id     = module.kms.key_id
  
  tags = {
    Environment = "prd"
    Compliance  = "5-year-retention"
  }
}
```

---

### 6. SNS/SQS

**Caminho:** `modules/sns-sqs/`

**Recursos Provisionados:**
- Tópico SNS
- Filas SQS (incluindo DLQ)
- Subscriptions (SNS → SQS)
- Policies de acesso

**Inputs:**

| Variável | Tipo | Descrição |
|----------|------|-----------|
| `topic_name` | string | Nome do tópico SNS |
| `queue_name` | string | Nome da fila SQS |
| `dlq_name` | string | Nome da DLQ |
| `max_receive_count` | number | Tentativas antes de DLQ |

**Outputs:**
- `sns_topic_arn`
- `sqs_queue_url`
- `dlq_url`

**Exemplo de Uso:**

```hcl
module "messaging" {
  source = "../../modules/sns-sqs"
  
  topic_name         = "dcr-prd-events"
  queue_name         = "dcr-prd-audit-queue"
  dlq_name           = "dcr-prd-audit-dlq"
  max_receive_count  = 3
  
  tags = {
    Environment = "prd"
  }
}
```

---

## 🔧 Configurações de Backend

### Backend S3 (State Remoto)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "dcr-terraform-state-prd"
    key            = "dcr-enterprise/prd/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}
```

### Criar Backend (uma vez)

```bash
# Criar bucket e tabela DynamoDB
aws s3 mb s3://dcr-terraform-state-prd
aws s3api put-bucket-versioning \
  --bucket dcr-terraform-state-prd \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## 🔐 Segurança

### Secrets Management

**Nunca** commitar secrets! Usar:

1. **AWS Secrets Manager:**

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "dcr/prd/db-password"
}

locals {
  db_password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

2. **Variáveis de ambiente:**

```bash
export TF_VAR_db_password="$(aws secretsmanager get-secret-value --secret-id dcr/prd/db-password --query SecretString --output text)"
terraform apply
```

### IAM Roles Minimalistas

Seguir princípio de least privilege:

```hcl
# Exemplo: role para pods do DCR Service
resource "aws_iam_role" "dcr_service" {
  name = "dcr-service-prd"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub": "system:serviceaccount:dcr:dcr-service"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dcr_sns" {
  role       = aws_iam_role.dcr_service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess" # ajustar para permissões específicas
}
```

---

## 📊 Outputs e Integração

### Outputs Principais

```hcl
# outputs.tf
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "redis_endpoint" {
  value = module.redis.redis_endpoint
}

output "s3_audit_bucket" {
  value = module.s3_worm.bucket_id
}

output "sns_topic_arn" {
  value = module.messaging.sns_topic_arn
}
```

### Usar Outputs em Helm

```bash
# Exportar outputs do Terraform
terraform output -json > outputs.json

# Injetar em values.yaml
cat outputs.json | jq -r '.rds_endpoint.value' # jdbc:postgresql://...
```

---

## 🧪 Testes

### Validação

```bash
terraform fmt -check -recursive
terraform validate
tflint
```

### Dry-run

```bash
terraform plan -out=plan.tfplan
terraform show plan.tfplan
```

---

## 📚 Documentação Relacionada

- [Helm Charts](HELM_GUIDE.md)
- [Pipeline CI/CD](CICD.md)
- [Arquitetura](../architecture/OVERVIEW.md)

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
