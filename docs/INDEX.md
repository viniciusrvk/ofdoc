# Índice de Documentação — DCR Enterprise

**Índice central** para toda a documentação do projeto DCR Enterprise.

---

## 🗂️ Navegação Rápida

### 📌 Início
- [README Principal](../README.md) — Visão geral, quick start, recursos
- [Plano de Desenvolvimento](DEVELOPMENT_PLAN.md) — Cronograma completo
- [Diagrama de Gantt](GANTT_CHART.md) — Cronograma visual
- [Resumo Executivo](EXECUTIVE_SUMMARY.md) — Visão para stakeholders
- [Quickstart](QUICKSTART.md) — Setup rápido do ambiente

---

## 📚 Documentação por Categoria

### 🏗️ Arquitetura
| Documento | Descrição |
|-----------|-----------|
| [**Visão Geral da Arquitetura**](architecture/OVERVIEW.md) | Componentes, diagramas, fluxos, segurança em profundidade |

**Tópicos cobertos:**
- Edge Layer (API Gateway, mTLS)
- Application Layer (DCR Service)
- Authorization Server (Keycloak)
- Dados (Postgres, Redis, S3)
- Eventos (SNS/SQS)
- Observabilidade (OpenTelemetry)
- Resiliência e escalabilidade

---

### 💻 Backend (DCR Service)
| Documento | Descrição |
|-----------|-----------|
| [**Especificação da API**](backend/API_SPEC.md) | Endpoints REST, validações, políticas FAPI-BR, exemplos |
| [**Modelo de Dados**](backend/DATA_MODEL.md) | DDL PostgreSQL, índices, triggers, queries comuns |
| [**Guia de Desenvolvimento**](backend/DEVELOPMENT_GUIDE.md) | Setup, estrutura de código, testes (em breve) |

**Tópicos cobertos:**
- Endpoints: `POST /register`, `GET/PUT/DELETE /register/{client_id}`
- Validação de Software Statement Assertion (SSA)
- Políticas FAPI-BR (jwks_uri, private_key_jwt, PAR)
- Idempotência por JTI
- Rate limiting
- Modelagem de dados (client_registry, client_cert_binding, ssa_audit)

---

### ☁️ Infraestrutura
| Documento | Descrição |
|-----------|-----------|
| [**Guia Terraform**](infrastructure/TERRAFORM_GUIDE.md) | Módulos AWS (VPC, EKS, RDS, Redis, S3 WORM, SNS/SQS) |
| [**Guia Helm**](infrastructure/HELM_GUIDE.md) | Charts Kubernetes, configurações (em breve) |
| [**Pipeline CI/CD**](infrastructure/CICD.md) | GitLab CI ou GitHub Actions (em breve) |

**Tópicos cobertos:**
- Provisionamento de VPC multi-AZ
- Cluster EKS com node groups
- RDS PostgreSQL (multi-AZ, backups)
- ElastiCache Redis (cluster mode)
- S3 WORM com Object Lock (auditoria imutável)
- SNS/SQS para eventos
- KMS para criptografia
- Backend remoto (S3 + DynamoDB)

---

### 🔧 Operações
| Documento | Descrição |
|-----------|-----------|
| [**Observabilidade**](operations/OBSERVABILITY.md) | Traces, metrics, logs, dashboards (em breve) |
| [**Segurança**](operations/SECURITY.md) | mTLS, auditoria, hardening, compliance (em breve) |
| [**SLOs**](operations/SLO.md) | Service Level Objectives, SLIs, alertas (em breve) |

**Tópicos a serem cobertos:**
- OpenTelemetry: traces, métricas, logs estruturados
- Dashboards (Grafana, Datadog)
- Alertas (PagerDuty, Slack)
- mTLS end-to-end
- Auditoria imutável (S3 WORM)
- Conformidade regulatória

---

### 📋 Runbooks (Troubleshooting)
| Documento | Cenário |
|-----------|---------|
| [JWKS Indisponível](runbooks/jwks-unavailable.md) | Diretório fora do ar ou latência alta |
| [Falha no Keycloak](runbooks/keycloak-failure.md) | Admin API retornando erros |
| [Alta Latência](runbooks/high-latency.md) | p99 > 800ms |

**Runbooks adicionais (planejados):**
- Problemas de mTLS
- Redis down
- Postgres replication lag
- SNS/SQS backlog

---

### 🚀 Desenvolvimento
| Documento | Descrição |
|-----------|-----------|
| [**📋 Plano de Desenvolvimento**](DEVELOPMENT_PLAN.md) | **Cronograma completo (12-16 semanas)** |
| [**📊 Diagrama de Gantt**](GANTT_CHART.md) | **Visualização do cronograma (novo!)** |

**Inclui:**
- Estrutura por áreas (Backend, Infra, Integração)
- 8 sprints detalhados
- Distribuição de tarefas por área
- Dependências críticas
- Critérios de aceitação por sprint
- Gestão de riscos
- Cerimônias ágeis
- **Diagrama de Gantt visual completo**

---

## 🧭 Guias de Início Rápido

### Para Desenvolvedores Backend
1. Ler [Arquitetura](architecture/OVERVIEW.md)
2. Revisar [API Spec](backend/API_SPEC.md)
3. Entender [Modelo de Dados](backend/DATA_MODEL.md)
4. Seguir [Plano de Desenvolvimento - Sprint 2](DEVELOPMENT_PLAN.md#sprint-2-semanas-3-4-api-e-validação-ssa)

### Para Engenheiros de Infra
1. Ler [Arquitetura](architecture/OVERVIEW.md)
2. Revisar [Guia Terraform](infrastructure/TERRAFORM_GUIDE.md)
3. Seguir [Plano de Desenvolvimento - Sprint 2-4](DEVELOPMENT_PLAN.md#sprint-2-semanas-3-4-api-e-validação-ssa)

### Para QA/Integração
1. Ler [Arquitetura](architecture/OVERVIEW.md)
2. Revisar [API Spec](backend/API_SPEC.md)
3. Configurar ambiente local (Docker Compose)
4. Importar [Coleção Postman](../postman/DCR-Enterprise.postman_collection.json)
5. Seguir [Plano de Desenvolvimento - Sprint 3+](DEVELOPMENT_PLAN.md#sprint-3-semanas-5-6-políticas-fapi-br-e-keycloak)

---

## 📦 Recursos Adicionais

### Diagramas
- [Arquitetura Completa (SVG)](../diagrams/architecture.svg)
- [Fluxo de Registro (SVG)](../diagrams/flowchart.svg)
- [Sequence Diagram (SVG)](../diagrams/sequence.svg)

### Coleção Postman
- [DCR-Enterprise.postman_collection.json](../postman/DCR-Enterprise.postman_collection.json)
- Ambientes: [dev](../postman/environments/dev.postman_environment.json), [prd](../postman/environments/prd.postman_environment.json)
- Exemplos: [sucesso](../postman/examples/register-success.json), [SSA inválido](../postman/examples/register-invalid-ssa.json), [violação de política](../postman/examples/register-policy-violation.json)

### Helm Charts
- [Chart.yaml](../helm/dcr-service/Chart.yaml)
- [values.yaml](../helm/dcr-service/values.yaml)
- Templates: [deployment](../helm/dcr-service/templates/deployment.yaml), [service](../helm/dcr-service/templates/service.yaml), [hpa](../helm/dcr-service/templates/hpa.yaml)

### Terraform
- [main.tf](../terraform/main.tf)
- [variables.tf](../terraform/variables.tf)
- Módulos: [VPC](../terraform/modules/vpc/), [EKS](../terraform/modules/eks/), [RDS](../terraform/modules/rds/), [Redis](../terraform/modules/redis/)

---

## 📄 Documentação Legada

- [**DCR_doc.md**](../DCR_doc.md) — Documentação técnica completa original

> **Nota**: A documentação está sendo migrada incrementalmente do arquivo legado para documentos organizados por componente. Consulte o DCR_doc.md para tópicos ainda não migrados.

---

## 🔄 Status da Documentação

| Categoria | Status | Cobertura |
|-----------|--------|-----------|
| 📋 Plano de Desenvolvimento | ✅ Completo | 100% |
| 🏗️ Arquitetura | ✅ Completo | 100% |
| 💻 Backend - API Spec | ✅ Completo | 100% |
| 💻 Backend - Modelo de Dados | ✅ Completo | 100% |
| 💻 Backend - Dev Guide | 🔄 Em breve | 0% |
| ☁️ Infra - Terraform | ✅ Completo | 100% |
| ☁️ Infra - Helm | 🔄 Em breve | 0% |
| ☁️ Infra - CI/CD | 🔄 Em breve | 0% |
| 🔧 Ops - Observabilidade | 🔄 Em breve | 0% |
| 🔧 Ops - Segurança | 🔄 Em breve | 0% |
| 🔧 Ops - SLOs | 🔄 Em breve | 0% |
| 📋 Runbooks | ⚠️ Parcial | 40% |

---

## 📝 Contribuindo

Para adicionar ou atualizar documentação:

1. Mantenha estrutura organizada por categoria
2. Use Markdown com exemplos práticos
3. Adicione links cruzados entre documentos
4. Atualize este índice
5. Revise com o time

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
