# Arquitetura — DCR Enterprise

## 📐 Visão Geral

O DCR Enterprise segue uma arquitetura de microsserviços com separação clara de responsabilidades:

```
┌─────────────────────────────────────────────────────┐
│                    EDGE LAYER                        │
│  - API Gateway (AWS API Gateway / NGINX Ingress)    │
│  - mTLS Termination                                 │
│  - WAF & Rate Limiting                              │
│  - Certificate Header Injection                     │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────┴────────────────────────────────┐
│               APPLICATION LAYER                      │
│                                                      │
│  ┌──────────────────────────────────────┐          │
│  │      DCR Service (Java 25)           │          │
│  │  - SSA Validation                    │          │
│  │  - Policy Engine (FAPI-BR)           │          │
│  │  - Client Registration Logic         │          │
│  │  - OpenTelemetry Instrumentation     │          │
│  └──────────┬────────────────────┬──────┘          │
│             │                    │                  │
└─────────────┼────────────────────┼──────────────────┘
              │                    │
    ┌─────────┴─────────┐  ┌──────┴────────┐
    │                   │  │                │
┌───▼────────┐  ┌──────▼──▼─────┐  ┌──────▼────────┐
│  Keycloak  │  │   PostgreSQL   │  │     Redis     │
│    (AS)    │  │   (Registry)   │  │    (Cache)    │
└────────────┘  └────────────────┘  └───────────────┘
                                              │
                     ┌────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
    ┌───▼────┐            ┌──────▼──────┐
    │  SNS   │───────────▶│     SQS     │
    │(Events)│            │  (Audit Q)  │
    └────────┘            └──────┬──────┘
                                 │
                          ┌──────▼──────┐
                          │ S3 WORM     │
                          │ (Audit Log) │
                          └─────────────┘
```

---

## 🏗️ Componentes Principais

### 1. API Gateway (Edge)

**Responsabilidades:**
- Terminação mTLS (TLS 1.3)
- Validação de cadeia de certificados (ICP-Brasil em produção)
- Injeção de headers do certificado cliente
- WAF e proteção DDoS
- Rate limiting por `org_id`
- Roteamento para DCR Service

**Headers Injetados:**
```
X-SSL-Client-Verify: SUCCESS
X-Client-Subject-DN: CN=Org X,O=Org,C=BR,SERIALNUMBER=12345
X-Client-SAN: URI=https://org.example.com,DNS=org.example.com
X-SSL-Client-Cert: -----BEGIN CERTIFICATE-----...
```

**Tecnologias:**
- AWS API Gateway + AWS WAF
- **OU** NGINX Ingress Controller + ModSecurity

---

### 2. DCR Service (Backend)

**Stack Tecnológica:**
- Java 25 (Virtual Threads para I/O)
- Spring Boot 3.x
- Spring Security
- Nimbus JOSE+JWT (validação SSA)
- Resilience4j (circuit breaker, retry)
- Micrometer + OpenTelemetry

**Camadas:**

```
┌─────────────────────────────────┐
│    Controllers (REST API)        │
│  - RegisterController            │
│  - ManagementController          │
│  - HealthController              │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│         Services                 │
│  - RegistrationService           │
│  - SSAValidationService          │
│  - PolicyEnforcementService      │
│  - KeycloakAdminService          │
│  - AuditEventService             │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│       Repositories               │
│  - ClientRepository (JPA)        │
│  - SSAAuditRepository            │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│    External Integrations         │
│  - DirectoryJwksClient (HTTP)    │
│  - KeycloakAdminClient (REST)    │
│  - RedisCache                    │
│  - SNSPublisher                  │
└──────────────────────────────────┘
```

**Fluxo de Processamento:**

1. **Extração de contexto mTLS** (headers do gateway)
2. **Verificação de idempotência** (Redis: `jti`)
3. **Validação SSA**
   - Download JWKS do Diretório (cache Redis)
   - Verificação de assinatura (PS256)
   - Validação de claims (`iat`, `exp`, `jti`, `aud`, `iss`)
4. **Aplicação de políticas FAPI-BR**
   - Exigir `jwks_uri` (proibir inline)
   - Validar `grant_types`, `response_types`
   - Forçar `private_key_jwt`
5. **Criação no Keycloak**
   - Admin API call
   - Binding de certificado (SubjectDN/SAN)
   - Configuração PAR
6. **Persistência**
   - Registro em `client_registry`
   - Binding em `client_cert_binding`
   - Auditoria em `ssa_audit`
7. **Publicação de eventos** (SNS)
8. **Resposta ao cliente**

---

### 3. Keycloak (Authorization Server)

**Configurações FAPI-BR:**
- Realm: `open-finance`
- Client authentication: `private_key_jwt`
- PAR (Pushed Authorization Request): **required**
- mTLS binding: certificate-bound tokens
- JWKS endpoint do AS publicado
- Discovery (`.well-known/openid-configuration`)

**Extensões/Customizações:**
- Event listener para auditoria
- Mapper customizado para claims FAPI
- Validador de JWKS URI (prevenir SSRF)

**Gestão de Chaves:**
- KMS (AWS KMS) ou CloudHSM
- Rotação automática de chaves (overlap de 30 dias)
- Publicação de múltiplos `kid` no JWKS

---

### 4. PostgreSQL (Dados Estruturados)

**Esquema:** Ver [DATA_MODEL.md](../backend/DATA_MODEL.md)

**Tabelas Principais:**
- `client_registry`: dados do cliente OAuth
- `client_cert_binding`: binding mTLS
- `ssa_audit`: histórico de validações SSA

**Características:**
- Multi-AZ em produção (RDS)
- Backups automáticos (PITR)
- Conexões via SSL/TLS
- Índices por `software_id`, `org_id`, `jti`

---

### 5. Redis (Cache e Estado Temporário)

**Uso:**
- Cache de JWKS do Diretório (TTL 5 min)
- Idempotência por `jti` (TTL 10 min)
- Rate limiting (sliding window)
- Opcional: cache de respostas GET

**Topologia:**
- Cluster Redis (3 masters + 3 réplicas) em produção
- ElastiCache Redis (AWS) ou self-managed
- Eviction policy: `allkeys-lru`

---

### 6. SNS/SQS (Eventos Assíncronos)

**Tópico SNS:** `dcr-events`

**Eventos Publicados:**
- `client_registered`
- `client_updated`
- `client_deleted`
- `validation_failed`

**Filas SQS:**
- `dcr-audit-queue`: processamento de auditoria
- `dcr-notifications-queue`: notificações (futuro)

**Processador de Auditoria:**
- Lambda ou pod Kubernetes dedicado
- Consome de SQS
- Grava em S3 WORM
- DLQ para falhas

---

### 7. S3 WORM (Auditoria Imutável)

**Bucket:** `dcr-audit-logs-{env}`

**Configurações:**
- Object Lock: modo **Compliance**
- Retenção: 5 anos (regulatório)
- Versionamento habilitado
- Criptografia: SSE-KMS

**Formato de Arquivo:**
```
s3://dcr-audit-logs-prd/
  year=2025/
    month=11/
      day=08/
        hour=12/
          audit-{uuid}.json
```

---

## 🔒 Segurança em Profundidade

### Camadas de Segurança

1. **Rede:**
   - VPC privada
   - Security Groups restritivos
   - Network Policies (Kubernetes)
   - WAF no edge

2. **Transporte:**
   - TLS 1.3 everywhere
   - mTLS para clientes
   - Certificate pinning (Diretório)

3. **Aplicação:**
   - Validação rigorosa de inputs
   - Sanitização de headers
   - Rate limiting
   - OWASP Top 10 mitigations

4. **Dados:**
   - Encryption at rest (KMS)
   - Encryption in transit
   - Secrets management (External Secrets)
   - Auditoria imutável

5. **Identidade:**
   - mTLS binding
   - Certificate validation (CRL/OCSP)
   - ICP-Brasil compliance

---

## 📊 Observabilidade

### Pilares

**1. Traces (OpenTelemetry)**
- Contexto distribuído (`trace_id`, `span_id`)
- Propagação W3C Trace Context
- Exportação para Datadog/Jaeger/Tempo

**2. Metrics (Micrometer)**
- Request rate, latency, errors (RED)
- Cache hit ratio
- Database connection pool
- JVM metrics

**3. Logs (Structured JSON)**
- Correlação com `trace_id`
- Níveis: ERROR, WARN, INFO
- Campos: timestamp, level, logger, message, trace_id, client_id, org_id

### Dashboards

- **SLO Dashboard**: disponibilidade, latência, taxa de erro
- **Operational Dashboard**: throughput, cache, DB, Keycloak
- **Security Dashboard**: mTLS failures, validações SSA, rate limit

---

## 🔄 Resiliência e Alta Disponibilidade

### Estratégias

**Circuit Breaker:**
- Keycloak Admin API
- Diretório JWKS
- PostgreSQL (fallback read-only)

**Retry Policies:**
- Exponential backoff
- Jitter para evitar thundering herd
- Idempotência garantida

**Timeouts:**
- HTTP clients: 5s
- Database queries: 500ms
- Redis operations: 200ms

**Redundância:**
- Multi-AZ deployment
- Réplicas de pods (min 3)
- Health checks (readiness, liveness)

**Degradação Graceful:**
- Cache stale (JWKS envelhecido por até 15 min)
- Modo somente leitura (se DB write falhar)
- Alertas proativos

---

## 📈 Escalabilidade

### Horizontal

- HPA baseado em CPU (> 70%) e latência (p95 > 500ms)
- Min replicas: 3
- Max replicas: 20
- Scale-down estabilizado (5 min)

### Vertical

- Tamanho de pods: 250m CPU / 512Mi → 1 CPU / 1Gi
- Database: escalonamento de RDS (read replicas)
- Redis: cluster mode para distribuir carga

### Limites

- Request body: 64 KiB
- Rate limit: 100 req/min por `org_id` (ajustável)
- Concurrent clients: ~500 organizações

---

## 🗂️ Documentação Relacionada

- [Modelo de Dados](../backend/DATA_MODEL.md)
- [Especificação da API](../backend/API_SPEC.md)
- [Guia de Infraestrutura](../infrastructure/TERRAFORM_GUIDE.md)
- [Observabilidade](../operations/OBSERVABILITY.md)
- [Segurança](../operations/SECURITY.md)
- [Runbooks](../runbooks/)

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
