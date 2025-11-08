# Modelo de Dados — DCR Service

## 📊 Visão Geral

O DCR Service utiliza **PostgreSQL** para persistência de dados estruturados. O modelo é normalizado e otimizado para consultas por `software_id`, `org_id` e `client_id`.

---

## 🗃️ Esquema de Banco de Dados

### DDL Completo

```sql
-- Extension para UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabela principal de registro de clientes
CREATE TABLE client_registry (
    client_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    software_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    software_name TEXT,
    org_name TEXT,
    
    -- Configurações OAuth/OIDC
    jwks_uri TEXT NOT NULL,
    redirect_uris JSONB NOT NULL,
    grant_types TEXT[] NOT NULL,
    response_types TEXT[] NOT NULL,
    token_endpoint_auth_method TEXT NOT NULL DEFAULT 'private_key_jwt',
    token_endpoint_auth_signing_alg TEXT DEFAULT 'PS256',
    request_object_signing_alg TEXT,
    id_token_signed_response_alg TEXT,
    
    -- Metadata adicional
    application_type TEXT DEFAULT 'web',
    scope TEXT,
    contacts JSONB,
    
    -- Registration Access Token (hash para segurança)
    rat_hash BYTEA NOT NULL,
    rat_expires_at TIMESTAMPTZ,
    
    -- Status e auditoria
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'deleted')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    
    -- Índices de performance
    CONSTRAINT valid_redirect_uris CHECK (jsonb_typeof(redirect_uris) = 'array')
);

-- Índices para consultas comuns
CREATE INDEX idx_client_registry_software_id ON client_registry(software_id);
CREATE INDEX idx_client_registry_org_id ON client_registry(org_id);
CREATE INDEX idx_client_registry_status ON client_registry(status) WHERE status = 'active';
CREATE INDEX idx_client_registry_created ON client_registry(created_at DESC);

-- Tabela de binding de certificados mTLS
CREATE TABLE client_cert_binding (
    id BIGSERIAL PRIMARY KEY,
    client_id UUID NOT NULL REFERENCES client_registry(client_id) ON DELETE CASCADE,
    
    -- Informações do certificado
    subject_dn TEXT NOT NULL,
    san_uri TEXT,
    san_dns TEXT,
    thumbprint_sha256 TEXT NOT NULL,
    issuer_dn TEXT,
    
    -- Validade do certificado
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL,
    
    -- Auditoria
    bound_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    -- Garantir unicidade do binding
    CONSTRAINT uq_client_cert UNIQUE (client_id, subject_dn)
);

CREATE INDEX idx_cert_binding_client ON client_cert_binding(client_id);
CREATE INDEX idx_cert_binding_subject ON client_cert_binding(subject_dn);
CREATE INDEX idx_cert_binding_thumbprint ON client_cert_binding(thumbprint_sha256);

-- Tabela de auditoria de SSA
CREATE TABLE ssa_audit (
    id BIGSERIAL PRIMARY KEY,
    
    -- Referência ao cliente (pode ser NULL se rejeitado)
    client_id UUID REFERENCES client_registry(client_id) ON DELETE SET NULL,
    
    -- Claims do SSA
    jti TEXT NOT NULL,
    iss TEXT NOT NULL,
    aud TEXT NOT NULL,
    iat TIMESTAMPTZ NOT NULL,
    exp TIMESTAMPTZ NOT NULL,
    software_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    
    -- Hash do SSA completo (para idempotência)
    ssa_sha256 BYTEA NOT NULL,
    
    -- Decisão de validação
    decision TEXT NOT NULL CHECK (decision IN ('approved', 'rejected', 'error')),
    rejection_reasons JSONB,
    
    -- Contexto da requisição
    requester_subject_dn TEXT,
    requester_ip TEXT,
    trace_id TEXT,
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Garantir idempotência por JTI
    CONSTRAINT uq_ssa_jti UNIQUE (jti)
);

CREATE INDEX idx_ssa_audit_jti ON ssa_audit(jti);
CREATE INDEX idx_ssa_audit_client ON ssa_audit(client_id);
CREATE INDEX idx_ssa_audit_software ON ssa_audit(software_id);
CREATE INDEX idx_ssa_audit_org ON ssa_audit(org_id);
CREATE INDEX idx_ssa_audit_created ON ssa_audit(created_at DESC);
CREATE INDEX idx_ssa_audit_decision ON ssa_audit(decision);

-- Tabela de eventos de auditoria (changelog)
CREATE TABLE audit_events (
    id BIGSERIAL PRIMARY KEY,
    
    -- Identificação
    event_type TEXT NOT NULL CHECK (event_type IN ('client_created', 'client_updated', 'client_deleted', 'cert_bound', 'cert_revoked')),
    entity_type TEXT NOT NULL DEFAULT 'client',
    entity_id TEXT NOT NULL,
    
    -- Dados do evento
    old_value JSONB,
    new_value JSONB,
    changes JSONB,
    
    -- Contexto
    actor TEXT, -- subject_dn ou user_id
    trace_id TEXT,
    
    -- Timestamp
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX idx_audit_events_type ON audit_events(event_type);
CREATE INDEX idx_audit_events_occurred ON audit_events(occurred_at DESC);
```

---

## 📋 Descrição das Tabelas

### client_registry

**Propósito:** Armazenar metadados de clientes OAuth/OIDC registrados.

**Campos Principais:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `client_id` | UUID | Identificador único do cliente (PK) |
| `software_id` | TEXT | ID do software no Diretório |
| `org_id` | TEXT | ID da organização no Diretório |
| `jwks_uri` | TEXT | URI HTTPS das chaves públicas |
| `redirect_uris` | JSONB | Array de URIs de callback |
| `grant_types` | TEXT[] | Tipos de grants permitidos |
| `token_endpoint_auth_method` | TEXT | Método de autenticação (`private_key_jwt`) |
| `rat_hash` | BYTEA | Hash SHA-256 do Registration Access Token |
| `status` | TEXT | Estado do cliente (active, inactive, suspended, deleted) |

**Consultas Comuns:**

```sql
-- Buscar cliente por ID
SELECT * FROM client_registry WHERE client_id = 'uuid-aqui' AND status = 'active';

-- Listar clientes por software
SELECT * FROM client_registry WHERE software_id = 'soft-123' ORDER BY created_at DESC;

-- Listar clientes por organização
SELECT * FROM client_registry WHERE org_id = 'org-456' AND status = 'active';

-- Verificar existência de redirect_uri
SELECT client_id FROM client_registry 
WHERE status = 'active' 
  AND redirect_uris @> '["https://example.com/callback"]'::jsonb;
```

---

### client_cert_binding

**Propósito:** Mapear clientes aos certificados mTLS autorizados.

**Campos Principais:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `client_id` | UUID | FK para `client_registry` |
| `subject_dn` | TEXT | Subject DN do certificado (ex: `CN=Org,O=Org,C=BR`) |
| `san_uri` | TEXT | Subject Alternative Name URI |
| `san_dns` | TEXT | Subject Alternative Name DNS |
| `thumbprint_sha256` | TEXT | Hash SHA-256 do certificado |
| `valid_from` | TIMESTAMPTZ | Data de início de validade |
| `valid_to` | TIMESTAMPTZ | Data de expiração |

**Consultas Comuns:**

```sql
-- Validar binding de certificado
SELECT cr.client_id, cr.status, ccb.subject_dn
FROM client_registry cr
JOIN client_cert_binding ccb ON cr.client_id = ccb.client_id
WHERE ccb.subject_dn = 'CN=Org,O=Org,C=BR'
  AND cr.status = 'active'
  AND ccb.valid_to > NOW();

-- Listar certificados expirados
SELECT * FROM client_cert_binding WHERE valid_to < NOW();
```

---

### ssa_audit

**Propósito:** Auditoria de todas as validações de SSA (aprovadas e rejeitadas).

**Campos Principais:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `jti` | TEXT | JWT ID (claim `jti` do SSA) — garante unicidade |
| `iss` | TEXT | Emissor (Diretório) |
| `iat` | TIMESTAMPTZ | Data de emissão |
| `exp` | TIMESTAMPTZ | Data de expiração |
| `ssa_sha256` | BYTEA | Hash SHA-256 do JWT completo |
| `decision` | TEXT | `approved`, `rejected`, `error` |
| `rejection_reasons` | JSONB | Motivos de rejeição (se aplicável) |
| `trace_id` | TEXT | ID de correlação (OpenTelemetry) |

**Exemplo de `rejection_reasons`:**

```json
{
  "validations": [
    {
      "field": "signature",
      "reason": "Invalid signature: key not found in JWKS"
    },
    {
      "field": "iat",
      "reason": "Issued at time too far in the future (clock skew > 60s)"
    }
  ]
}
```

**Consultas Comuns:**

```sql
-- Buscar por JTI (idempotência)
SELECT * FROM ssa_audit WHERE jti = 'unique-jti-12345';

-- Taxa de aprovação por organização
SELECT 
    org_id,
    COUNT(*) FILTER (WHERE decision = 'approved') AS approved,
    COUNT(*) FILTER (WHERE decision = 'rejected') AS rejected,
    COUNT(*) AS total
FROM ssa_audit
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY org_id;

-- SSAs rejeitados por motivo
SELECT 
    rejection_reasons->>'field' AS field,
    COUNT(*) AS count
FROM ssa_audit
WHERE decision = 'rejected'
  AND created_at > NOW() - INTERVAL '7 days'
GROUP BY field
ORDER BY count DESC;
```

---

### audit_events

**Propósito:** Changelog de todas as operações de criação, atualização e deleção de clientes.

**Campos Principais:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_type` | TEXT | Tipo do evento (`client_created`, `client_updated`, etc.) |
| `entity_id` | TEXT | ID da entidade afetada (client_id) |
| `old_value` | JSONB | Estado anterior (para updates/deletes) |
| `new_value` | JSONB | Estado novo (para creates/updates) |
| `actor` | TEXT | Quem executou (SubjectDN ou user_id) |
| `trace_id` | TEXT | Correlação com traces |

**Consultas Comuns:**

```sql
-- Histórico de mudanças de um cliente
SELECT * FROM audit_events 
WHERE entity_id = 'b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0'
ORDER BY occurred_at DESC;

-- Últimas deleções
SELECT * FROM audit_events 
WHERE event_type = 'client_deleted'
ORDER BY occurred_at DESC
LIMIT 10;
```

---

## 🔄 Triggers e Automações

### Trigger: Atualizar `updated_at`

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_client_registry_updated_at
    BEFORE UPDATE ON client_registry
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cert_binding_updated_at
    BEFORE UPDATE ON client_cert_binding
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### Trigger: Auditoria Automática

```sql
CREATE OR REPLACE FUNCTION audit_client_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_events (event_type, entity_type, entity_id, old_value, actor)
        VALUES ('client_deleted', 'client', OLD.client_id::text, row_to_json(OLD), current_setting('app.current_actor', true));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_events (event_type, entity_type, entity_id, old_value, new_value, actor)
        VALUES ('client_updated', 'client', NEW.client_id::text, row_to_json(OLD), row_to_json(NEW), current_setting('app.current_actor', true));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_events (event_type, entity_type, entity_id, new_value, actor)
        VALUES ('client_created', 'client', NEW.client_id::text, row_to_json(NEW), current_setting('app.current_actor', true));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_client_registry_changes
    AFTER INSERT OR UPDATE OR DELETE ON client_registry
    FOR EACH ROW
    EXECUTE FUNCTION audit_client_changes();
```

---

## 📈 Retenção e Particionamento

### Particionamento por Data (Futuro)

Para `ssa_audit` e `audit_events`, considerar particionamento mensal quando volume > 10M registros:

```sql
-- Exemplo de particionamento (PostgreSQL 10+)
CREATE TABLE ssa_audit_2025_11 PARTITION OF ssa_audit
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
```

### Política de Retenção

- `client_registry`: retenção indefinida (soft delete)
- `client_cert_binding`: retenção até 30 dias após expiração do certificado
- `ssa_audit`: retenção de 5 anos (regulatório) + arquivamento em S3 WORM
- `audit_events`: retenção de 7 anos (regulatório)

---

## 🔐 Segurança

### Criptografia

- **At-rest**: RDS encryption habilitado (KMS)
- **In-transit**: SSL/TLS obrigatório
- **Campos sensíveis**: `rat_hash` usa SHA-256

### Permissões (Row-Level Security - futuro)

```sql
-- Exemplo de RLS para multi-tenancy
ALTER TABLE client_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY org_isolation ON client_registry
    USING (org_id = current_setting('app.current_org_id', true));
```

---

## 📊 Monitoramento

### Queries Lentas

```sql
-- Top 10 queries mais lentas (pg_stat_statements)
SELECT 
    query,
    mean_exec_time,
    calls,
    total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Tamanho das Tabelas

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🧪 Dados de Teste

### Insert de Cliente de Exemplo

```sql
INSERT INTO client_registry (
    client_id,
    software_id,
    org_id,
    software_name,
    org_name,
    jwks_uri,
    redirect_uris,
    grant_types,
    response_types,
    token_endpoint_auth_method,
    rat_hash,
    status
) VALUES (
    'b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0',
    'soft-12345',
    'org-67890',
    'App TPP Exemplo',
    'TPP Instituição',
    'https://tpp.example.com/jwks.json',
    '["https://tpp.example.com/callback"]'::jsonb,
    ARRAY['authorization_code', 'client_credentials'],
    ARRAY['code'],
    'private_key_jwt',
    decode('abcdef1234567890', 'hex'), -- exemplo de hash
    'active'
);

INSERT INTO client_cert_binding (
    client_id,
    subject_dn,
    san_uri,
    thumbprint_sha256,
    valid_from,
    valid_to
) VALUES (
    'b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0',
    'CN=TPP Org,O=TPP,C=BR,SERIALNUMBER=12345',
    'https://tpp.example.com',
    'a1b2c3d4e5f6...',
    '2024-01-01',
    '2026-01-01'
);
```

---

## 📚 Documentação Relacionada

- [Especificação da API](API_SPEC.md)
- [Guia de Desenvolvimento](DEVELOPMENT_GUIDE.md)
- [Arquitetura](../architecture/OVERVIEW.md)

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
