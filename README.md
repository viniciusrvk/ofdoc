# DCR Enterprise — Dynamic Client Registration para Open Finance Brasil

[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red.svg)](LICENSE)
[![Author](https://img.shields.io/badge/author-Roberto%20Vinicius%20Kuo-blue.svg)](https://github.com/viniciusrvk)
[![FAPI-BR](https://img.shields.io/badge/FAPI--BR-compliant-green.svg)](https://openfinancebrasil.atlassian.net/wiki/spaces/OF/overview)
[![RFC 7591](https://img.shields.io/badge/RFC-7591-orange.svg)](https://datatracker.ietf.org/doc/html/rfc7591)
[![RFC 7592](https://img.shields.io/badge/RFC-7592-orange.svg)](https://datatracker.ietf.org/doc/html/rfc7592)

> Solução enterprise de **Dynamic Client Registration (DCR)** para **Detentoras de Conta** no ecossistema **Open Finance Brasil**, com arquitetura resiliente, observável e em conformidade com padrões FAPI-BR, OIDC e OAuth 2.0.
> 
> **Autor**: Roberto Vinicius Kuo | [@viniciusrvk](https://github.com/viniciusrvk)

---

## 📋 Índice

- [🎯 Visão Geral](#-visão-geral)
- [🏗️ Arquitetura](#️-arquitetura)
  - [Componentes](#componentes)
  - [Diagramas](#diagramas)
- [🚀 Quick Start](#-quick-start)
- [📦 Recursos do Repositório](#-recursos-do-repositório)
- [� Plano de Desenvolvimento](#-plano-de-desenvolvimento)
- [�🔧 Configuração e Deploy](#-configuração-e-deploy)
  - [Pré-requisitos](#pré-requisitos)
  - [Deploy com Helm](#deploy-com-helm)
  - [Infraestrutura com Terraform](#infraestrutura-com-terraform)
- [🧪 Testes e Validação](#-testes-e-validação)
- [📊 Observabilidade](#-observabilidade)
- [🔒 Segurança](#-segurança)
- [📖 Documentação Completa](#-documentação-completa)
- [🛠️ Operação e Suporte](#️-operação-e-suporte)
- [📞 Contatos](#-contatos)

---

## 🎯 Visão Geral

O **DCR Enterprise** é uma solução completa para registro dinâmico de clientes OAuth/OIDC, permitindo que instituições participantes do Open Finance Brasil registrem aplicações de forma segura e automatizada no Authorization Server (AS) da Detentora de Conta.

### Principais Funcionalidades

✅ **Validação de Software Statement Assertion (SSA)** do Diretório Central  
✅ **Conformidade FAPI-BR** com políticas obrigatórias (`private_key_jwt`, PAR, mTLS)  
✅ **Integração com Keycloak** (Authorization Server)  
✅ **Auditoria imutável** com S3 WORM e retenção regulatória  
✅ **Idempotência** por `jti` do SSA  
✅ **Observabilidade** completa (traces, metrics, logs) com OpenTelemetry  
✅ **Alta disponibilidade** (99.9% SLO) e resiliência  
✅ **mTLS end-to-end** com certificados ICP-Brasil

### Stack Tecnológica

- **Backend**: Java 25, Spring Boot 3.x, Virtual Threads
- **Authorization Server**: Keycloak com FAPI extensions
- **Dados**: PostgreSQL (registry), Redis (cache), MongoDB (opcional)
- **Eventos**: AWS SNS/SQS
- **Auditoria**: S3 Object Lock (WORM)
- **Infraestrutura**: Kubernetes (EKS), Terraform, Helm
- **Observabilidade**: OpenTelemetry, Datadog/Prometheus

---

## 🏗️ Arquitetura

### Componentes

```
┌─────────────┐
│   TPP       │  Instituição Participante (mTLS)
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│   API Gateway (mTLS, WAF, Rate Limit)   │
└──────────────────┬──────────────────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌──────────────┐      ┌────────────────┐
│  DCR Service │◄────►│   Keycloak AS  │
│  (Java 25)   │      │  (FAPI-BR)     │
└──────┬───────┘      └────────────────┘
       │
   ┌───┼────┬──────┬────────┐
   ▼   ▼    ▼      ▼        ▼
┌────┐┌───┐┌────┐┌─────┐┌──────┐
│ PG ││RDS││S3  ││SNS/ ││OTel  │
│    ││   ││WORM││SQS  ││      │
└────┘└───┘└────┘└─────┘└──────┘
```

### Diagramas

Diagramas detalhados disponíveis em:

- 🎨 [**Arquitetura Completa (SVG)**](diagrams/architecture.svg)
- 🔄 [**Fluxo de Registro (SVG)**](diagrams/flowchart.svg)
- 📊 [**Sequence Diagram (SVG)**](diagrams/sequence.svg)

---

## 🚀 Quick Start

### Usando Docker Compose (Desenvolvimento)

```bash
# Clone o repositório
git clone https://github.com/viniciusrvk/doc.git
cd doc

# Suba o ambiente local
docker-compose up -d

# Teste o endpoint (com certificado mTLS)
curl --cert client.crt --key client.key \
  https://localhost:8443/openbanking/register \
  -H "Content-Type: application/json" \
  -d @postman/examples/register-success.json
```

### Usando Postman

Importe a coleção disponível em [`postman/DCR-Enterprise.postman_collection.json`](postman/DCR-Enterprise.postman_collection.json) com casos de:

- ✅ Registro com sucesso
- ❌ SSA inválido
- ❌ Metadados não conformes
- ❌ mTLS failure
- 🔄 Idempotência

---

## 📦 Recursos do Repositório

```
📁 dcr-enterprise/
├── 📄 README.md                    # Este arquivo
├── 📄 DCR_doc.md                   # Documentação técnica completa (legado)
├── 📁 diagrams/                    # Diagramas SVG
│   ├── architecture.svg
│   ├── flowchart.svg
│   └── sequence.svg
├── 📁 docs/                        # 📚 Documentação Organizada
│   ├── 📋 DEVELOPMENT_PLAN.md      # Plano de desenvolvimento (3 engenheiros, 16 semanas)
│   ├── architecture/
│   │   └── OVERVIEW.md             # Arquitetura detalhada
│   ├── backend/
│   │   ├── API_SPEC.md             # Especificação da API REST
│   │   ├── DATA_MODEL.md           # Modelagem de dados PostgreSQL
│   │   └── DEVELOPMENT_GUIDE.md    # Guia de desenvolvimento backend
│   ├── infrastructure/
│   │   ├── TERRAFORM_GUIDE.md      # Guia de módulos Terraform
│   │   ├── HELM_GUIDE.md           # Guia de Helm Charts
│   │   └── CICD.md                 # Pipeline CI/CD
│   ├── operations/
│   │   ├── OBSERVABILITY.md        # Métricas, logs e traces
│   │   ├── SECURITY.md             # Políticas de segurança
│   │   └── SLO.md                  # Service Level Objectives
│   └── runbooks/
│       ├── jwks-unavailable.md
│       ├── keycloak-failure.md
│       └── high-latency.md
├── 📁 helm/                        # Helm Charts
│   └── dcr-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           └── hpa.yaml
├── 📁 terraform/                   # Módulos Terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── redis/
│   │   ├── s3-worm/
│   │   └── sns-sqs/
│   └── environments/
│       ├── dev/
│       ├── qa/
│       └── prd/
├── 📁 postman/                     # Coleção Postman
│   ├── DCR-Enterprise.postman_collection.json
│   ├── environments/
│   │   ├── dev.postman_environment.json
│   │   └── prd.postman_environment.json
│   └── examples/
│       ├── register-success.json
│       ├── register-invalid-ssa.json
│       └── register-policy-violation.json
└── 📁 scripts/                     # Scripts utilitários
    ├── generate-mtls-certs.sh
    ├── test-conformance.sh
    └── backup-audit-logs.sh
```

---

## 📋 Plano de Desenvolvimento

### � Duração: 12-16 semanas

O projeto está estruturado para desenvolvimento modular com **3 áreas principais**:

- **Área 1 — Backend**: DCR Service (Java 25), validações SSA, políticas FAPI-BR
- **Área 2 — Infra/DevOps**: Terraform, Kubernetes, Helm, CI/CD, observabilidade
- **Área 3 — Integração/QA**: Keycloak, Redis, SNS/SQS, testes, Console React

### 📅 Fases do Projeto

1. **Fase 0: Fundação** (Semanas 1-2) — Setup de ambiente e decisões arquiteturais
2. **Fase 1: MVP Backend** (Semanas 3-6) — API funcional com validações SSA
3. **Fase 2: Infraestrutura Core** (Semanas 5-8) — Cloud e observabilidade
4. **Fase 3: Integrações Críticas** (Semanas 7-10) — Keycloak, cache, eventos
5. **Fase 4: Hardening & Compliance** (Semanas 11-14) — Segurança e conformidade
6. **Fase 5: Console & Go-Live** (Semanas 15-16) — Operação e produção

### 📖 Documentação Completa

👉 **[Ver Plano de Desenvolvimento Detalhado](docs/DEVELOPMENT_PLAN.md)**  
👉 **[Ver Diagrama de Gantt](docs/GANTT_CHART.md)** ⭐ Novo!

Inclui:
- Cronograma sprint por sprint
- Distribuição de tarefas por área
- Dependências críticas
- Critérios de aceitação
- Gestão de riscos
- **Diagrama de Gantt visual completo**

---

## 🔧 Configuração e Deploy

### Pré-requisitos

- **Kubernetes** 1.28+ (EKS recomendado)
- **Helm** 3.12+
- **Terraform** 1.6+
- **PostgreSQL** 14+ 
- **Redis** 7+
- **Keycloak** 23+ com extensões FAPI
- Certificados **ICP-Brasil** (produção)

### Deploy com Helm

```bash
# Adicionar repositório Helm
helm repo add dcr-enterprise https://charts.example.com/dcr
helm repo update

# Instalar em QA
helm install dcr-service dcr-enterprise/dcr-service \
  --namespace openfinance \
  --create-namespace \
  -f helm/dcr-service/values-qa.yaml

# Verificar status
kubectl get pods -n openfinance
kubectl logs -n openfinance -l app=dcr-service -f
```

Veja mais detalhes em [`helm/dcr-service/README.md`](helm/dcr-service/README.md).

### Infraestrutura com Terraform

```bash
cd terraform/environments/prd

# Inicializar
terraform init

# Planejar
terraform plan -out=plan.tfplan

# Aplicar
terraform apply plan.tfplan
```

Módulos disponíveis:
- ✅ VPC com subnets públicas/privadas
- ✅ EKS cluster com node groups
- ✅ RDS PostgreSQL com multi-AZ
- ✅ ElastiCache Redis
- ✅ S3 com Object Lock (WORM)
- ✅ SNS/SQS para eventos
- ✅ KMS para criptografia

Veja [`terraform/README.md`](terraform/README.md) para detalhes.

---

## 🧪 Testes e Validação

### Testes Unitários

```bash
./gradlew test
```

### Testes de Integração

```bash
./gradlew integrationTest
```

### Testes de Conformidade FAPI-BR

```bash
./scripts/test-conformance.sh
```

### Testes de Carga

```bash
k6 run tests/load/register-spike.js
```

### Validação com Postman

Execute a coleção completa:

```bash
newman run postman/DCR-Enterprise.postman_collection.json \
  -e postman/environments/qa.postman_environment.json \
  --reporters cli,json
```

---

## 📊 Observabilidade

### Métricas Principais

| Métrica | Descrição | SLO |
|---------|-----------|-----|
| `dcr_requests_total` | Total de requisições | - |
| `dcr_latency_ms_p99` | Latência p99 | < 800ms |
| `dcr_errors_total` | Total de erros | < 1% |
| `dcr_idempotent_replays` | Replays idempotentes | - |
| `dcr_jwks_cache_hit_ratio` | Hit ratio do cache JWKS | ≥ 70% |

### Dashboards

- **Grafana**: `docs/observability/grafana-dashboard.json`
- **Datadog**: `docs/observability/datadog-dashboard.json`

### Logs Estruturados

Todos os logs incluem:
- `trace_id` (distribuído)
- `client_id`
- `org_id`
- `jti` (SSA)
- `decision` (approved/rejected)

---

## 🔒 Segurança

### Controles Implementados

✅ **mTLS end-to-end** com validação ICP-Brasil  
✅ **Validação de assinatura SSA** (PS256)  
✅ **CRL/OCSP** checking  
✅ **Rate limiting** por organização  
✅ **WAF** no API Gateway  
✅ **Secrets management** com External Secrets  
✅ **Network policies** restritivas  
✅ **Auditoria imutável** (S3 WORM, 5 anos)  
✅ **KMS/HSM** para chaves do AS  

### Validações

- Container scanning (Trivy)
- SAST (SonarQube)
- DAST (OWASP ZAP)
- Pen test trimestral

---

## 📖 Documentação Completa

### 📚 Documentação Técnica Organizada

A documentação foi reorganizada por componente para facilitar a navegação:

#### 🏗️ Arquitetura
- [**Visão Geral da Arquitetura**](docs/architecture/OVERVIEW.md) — Componentes, fluxos, segurança

#### 💻 Backend
- [**Especificação da API**](docs/backend/API_SPEC.md) — Endpoints, payloads, validações, erros
- [**Modelo de Dados**](docs/backend/DATA_MODEL.md) — DDL PostgreSQL, índices, triggers
- [**Guia de Desenvolvimento**](docs/backend/DEVELOPMENT_GUIDE.md) — Setup, testes, boas práticas (em breve)

#### ☁️ Infraestrutura
- [**Guia Terraform**](docs/infrastructure/TERRAFORM_GUIDE.md) — Módulos AWS, provisionamento
- [**Guia Helm**](docs/infrastructure/HELM_GUIDE.md) — Charts Kubernetes (em breve)
- [**Pipeline CI/CD**](docs/infrastructure/CICD.md) — GitLab CI, GitHub Actions (em breve)

#### 🔧 Operações
- [**Observabilidade**](docs/operations/OBSERVABILITY.md) — Métricas, logs, traces (em breve)
- [**Segurança**](docs/operations/SECURITY.md) — mTLS, auditoria, hardening (em breve)
- [**SLOs**](docs/operations/SLO.md) — Service Level Objectives (em breve)

#### 📋 Runbooks
- [JWKS Indisponível](docs/runbooks/jwks-unavailable.md)
- [Falha no Keycloak](docs/runbooks/keycloak-failure.md)
- [Alta Latência](docs/runbooks/high-latency.md)

#### 🚀 Desenvolvimento
- [**📋 Plano de Desenvolvimento**](docs/DEVELOPMENT_PLAN.md) — Sprints, cronograma, distribuição de tarefas

### 📄 Documentação Legada

- [**DCR_doc.md**](DCR_doc.md) — Documentação técnica completa original (será migrada incrementalmente)

---

## 🛠️ Operação e Suporte

### Runbooks Disponíveis

- 📘 [JWKS do Diretório Indisponível](docs/runbooks/jwks-unavailable.md)
- 📘 [Falha no Keycloak Admin API](docs/runbooks/keycloak-failure.md)
- 📘 [Alta Latência (p99 > 800ms)](docs/runbooks/high-latency.md)
- 📘 [Problemas de mTLS](docs/runbooks/mtls-issues.md)

### Alertas Críticos

| Alerta | Threshold | Ação |
|--------|-----------|------|
| `DCRHighErrorRate` | > 5% 5xx em 5 min | Verificar logs e AS |
| `DCRHighLatency` | p99 > 1s por 5 min | Escalar pods, verificar cache |
| `DCRJWKSCacheMiss` | < 50% hit ratio | Verificar Diretório |
| `DCRAuditLag` | > 100 msgs em SQS | Escalar audit processor |

### Contatos de Plantão

- **Slack**: `#dcr-support`
- **PagerDuty**: `dcr-oncall`
- **Email**: `dcr-team@example.com`

---

## 📞 Contatos

- **Autor e Engenheiro**: Roberto Vinicius Kuo
- **GitHub**: [@viniciusrvk](https://github.com/viniciusrvk)
- **Email**: Disponível via GitHub

---

## 📄 Licença

Copyright © 2025 Roberto Vinicius Kuo

**Todos os direitos reservados.**

Este projeto e seu código-fonte são de propriedade exclusiva do autor, Roberto Vinicius Kuo. 

Nenhuma parte deste software pode ser reproduzida, distribuída, ou transmitida de qualquer forma ou por qualquer meio, incluindo fotocópia, gravação ou outros métodos eletrônicos ou mecânicos, sem a permissão prévia por escrito do autor, exceto no caso de breves citações incorporadas em análises críticas e certos outros usos não comerciais permitidos pela lei de direitos autorais.

Para solicitações de permissão, entre em contato através do perfil do GitHub: https://github.com/viniciusrvk

---

## 🎯 Roadmap

- [x] MVP com validação SSA e criação no Keycloak
- [x] Auditoria imutável com S3 WORM
- [x] Observabilidade com OpenTelemetry
- [ ] Console React para operação
- [ ] Suporte a MongoDB para arquivo de SSA
- [ ] Rotação automática de chaves do AS
- [ ] Conformidade DCR Management (PUT/DELETE)

---

**Última atualização**: 8 de novembro de 2025  
**Versão**: 1.0.0
