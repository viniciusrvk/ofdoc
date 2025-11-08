# Terraform Modules for DCR Enterprise

Este diretório contém módulos Terraform para provisionar a infraestrutura completa do DCR Enterprise na AWS.

## 📋 Estrutura

```
terraform/
├── main.tf              # Configuração principal
├── variables.tf         # Variáveis
├── outputs.tf          # Outputs
├── modules/            # Módulos reutilizáveis
│   ├── vpc/           # VPC e redes
│   ├── eks/           # Kubernetes cluster
│   ├── rds/           # PostgreSQL
│   ├── redis/         # ElastiCache Redis
│   ├── s3-worm/       # S3 com Object Lock
│   ├── sns-sqs/       # Mensageria
│   ├── kms/           # Criptografia
│   └── irsa/          # IAM Roles for Service Accounts
└── environments/       # Configurações por ambiente
    ├── dev/
    ├── qa/
    └── prd/
```

## 🚀 Como Usar

### Pré-requisitos

- Terraform >= 1.6
- AWS CLI configurado
- Permissões adequadas na AWS

### Inicializar

```bash
cd environments/prd
terraform init
```

### Planejar

```bash
terraform plan -out=plan.tfplan
```

### Aplicar

```bash
terraform apply plan.tfplan
```

### Destruir (cuidado!)

```bash
terraform destroy
```

## 📦 Recursos Provisionados

### Rede
- VPC com subnets públicas e privadas em múltiplas AZs
- NAT Gateways para acesso à internet
- Security Groups

### Compute
- EKS Cluster (Kubernetes 1.28+)
- Node Groups com auto-scaling
- IRSA para permissions granulares

### Dados
- RDS PostgreSQL 14 (Multi-AZ em produção)
- ElastiCache Redis 7
- S3 com Object Lock WORM (Compliance mode)

### Eventos
- SNS Topic para eventos DCR
- SQS Queue com DLQ para auditoria

### Segurança
- KMS para criptografia
- IAM Roles com least privilege
- Network Policies

## 🔧 Configuração por Ambiente

### Development

```hcl
environment              = "dev"
eks_node_desired_size   = 2
eks_node_min_size       = 2
eks_node_max_size       = 5
rds_instance_class      = "db.t3.small"
redis_node_type         = "cache.t3.micro"
```

### Production

```hcl
environment              = "prd"
eks_node_desired_size   = 6
eks_node_min_size       = 6
eks_node_max_size       = 20
rds_instance_class      = "db.r6g.xlarge"
redis_node_type         = "cache.r6g.large"
```

## 📊 Outputs

Após aplicar, você terá:

- `cluster_endpoint`: Endpoint do EKS
- `database_endpoint`: Endpoint do PostgreSQL
- `cache_endpoint`: Endpoint do Redis
- `audit_bucket`: Nome do bucket S3
- `sns_events_topic`: ARN do tópico SNS
- `dcr_service_role_arn`: ARN da role IAM

## 🔒 Segurança

- Todos os recursos são criptografados em repouso (KMS)
- Secrets são gerenciados via AWS Secrets Manager
- Network isolation com Security Groups
- S3 Bucket com Object Lock em modo Compliance (5 anos)

## 📝 Notas

- **State remoto**: configurado para S3 + DynamoDB lock
- **Multi-AZ**: habilitado em produção para HA
- **Backup**: RDS com backup diário e retenção configurável
- **Monitoring**: CloudWatch integrado

## 🛠️ Troubleshooting

### Estado corrompido

```bash
terraform state pull > backup.tfstate
terraform state push backup.tfstate
```

### Importar recurso existente

```bash
terraform import module.rds.aws_db_instance.this dcr-registry-prd
```

## 📞 Suporte

Para questões sobre infraestrutura, contate: `infra-team@example.com`
