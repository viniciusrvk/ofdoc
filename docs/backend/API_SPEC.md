# Especificação da API — DCR Service

## 📋 Visão Geral

A API do DCR Service implementa os padrões **RFC 7591** (OAuth 2.0 Dynamic Client Registration) e **RFC 7592** (OAuth 2.0 Dynamic Client Registration Management Protocol).

**Base URL (produção):**
```
https://api.detentora.com.br/openbanking/register
```

**Autenticação:**
- mTLS obrigatório (ICP-Brasil em produção)
- Registration Access Token (RAT) para endpoints de management

---

## 🔐 Autenticação e Segurança

### mTLS

Todos os endpoints requerem mTLS válido. O API Gateway valida a cadeia de certificados e injeta headers:

```http
X-SSL-Client-Verify: SUCCESS
X-Client-Subject-DN: CN=Org X,O=Org,C=BR,SERIALNUMBER=12345
X-Client-SAN: URI=https://org.example.com,DNS=org.example.com
```

### Registration Access Token (RAT)

Endpoints `GET`, `PUT`, `DELETE` requerem o RAT recebido no registro:

```http
Authorization: Bearer {registration_access_token}
```

---

## 📍 Endpoints

### 1. POST /register

**Descrição:** Registra um novo cliente OAuth/OIDC.

**Request:**

```http
POST /register HTTP/1.1
Host: api.detentora.com.br
Content-Type: application/json

{
  "software_statement": "eyJhbGciOiJQUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjEyMyJ9...",
  "jwks_uri": "https://tpp.example.com/jwks.json",
  "redirect_uris": [
    "https://tpp.example.com/callback"
  ],
  "grant_types": [
    "authorization_code",
    "client_credentials"
  ],
  "response_types": [
    "code"
  ],
  "token_endpoint_auth_method": "private_key_jwt",
  "token_endpoint_auth_signing_alg": "PS256",
  "request_object_signing_alg": "PS256",
  "id_token_signed_response_alg": "PS256",
  "application_type": "web",
  "scope": "openid accounts consents payments"
}
```

**Campos Obrigatórios:**
- `software_statement`: JWT assinado pelo Diretório
- `jwks_uri`: URI HTTPS com chaves públicas do cliente
- `redirect_uris`: array de URIs de callback
- `token_endpoint_auth_method`: deve ser `private_key_jwt`

**Response 201 Created:**

```json
{
  "client_id": "b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0",
  "client_secret_expires_at": 0,
  "client_id_issued_at": 1731062400,
  "registration_access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiMWYzYjNhMC04YzdlLTRiMWMtOWUzMy0yN2YxZjdlNWQxYTAiLCJpYXQiOjE3MzEwNjI0MDAsImV4cCI6MTczMzY1NDQwMH0.xyz",
  "registration_client_uri": "https://api.detentora.com.br/openbanking/register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0",
  "software_id": "soft-12345",
  "org_id": "org-67890",
  "jwks_uri": "https://tpp.example.com/jwks.json",
  "redirect_uris": [
    "https://tpp.example.com/callback"
  ],
  "grant_types": [
    "authorization_code",
    "client_credentials"
  ],
  "response_types": [
    "code"
  ],
  "token_endpoint_auth_method": "private_key_jwt",
  "token_endpoint_auth_signing_alg": "PS256",
  "request_object_signing_alg": "PS256",
  "id_token_signed_response_alg": "PS256"
}
```

**Erros:**

| Status | Error Code | Descrição |
|--------|------------|-----------|
| 400 | `invalid_software_statement` | SSA expirado, assinatura inválida ou claims faltando |
| 400 | `invalid_client_metadata` | Metadados não conformes (ex: `jwks` inline, grant_types inválido) |
| 400 | `invalid_redirect_uri` | URI de callback malformada |
| 401 | `invalid_client` | mTLS falhou ou certificado inválido |
| 429 | `too_many_requests` | Rate limit excedido |
| 502 | `upstream_failure` | Falha temporária no Authorization Server |

**Exemplo de Erro:**

```json
{
  "error": "invalid_software_statement",
  "error_description": "SSA signature validation failed: key not found in JWKS",
  "trace_id": "trace-abc123"
}
```

---

### 2. GET /register/{client_id}

**Descrição:** Recupera metadados de um cliente registrado.

**Request:**

```http
GET /register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 HTTP/1.1
Host: api.detentora.com.br
Authorization: Bearer {registration_access_token}
```

**Response 200 OK:**

```json
{
  "client_id": "b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0",
  "client_id_issued_at": 1731062400,
  "software_id": "soft-12345",
  "org_id": "org-67890",
  "jwks_uri": "https://tpp.example.com/jwks.json",
  "redirect_uris": [
    "https://tpp.example.com/callback"
  ],
  "grant_types": [
    "authorization_code",
    "client_credentials"
  ],
  "response_types": [
    "code"
  ],
  "token_endpoint_auth_method": "private_key_jwt",
  "status": "active"
}
```

**Erros:**

| Status | Error Code | Descrição |
|--------|------------|-----------|
| 401 | `invalid_token` | RAT inválido ou expirado |
| 403 | `forbidden` | mTLS não corresponde ao cliente |
| 404 | `not_found` | Cliente não existe |

---

### 3. PUT /register/{client_id}

**Descrição:** Atualiza metadados de um cliente. Apenas campos permitidos podem ser alterados.

**Request:**

```http
PUT /register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 HTTP/1.1
Host: api.detentora.com.br
Authorization: Bearer {registration_access_token}
Content-Type: application/json

{
  "redirect_uris": [
    "https://tpp.example.com/callback",
    "https://tpp.example.com/callback2"
  ],
  "scope": "openid accounts consents"
}
```

**Campos Atualizáveis:**
- `redirect_uris`
- `scope`
- `contacts` (futuro)

**Campos NÃO Atualizáveis:**
- `software_statement`
- `jwks_uri`
- `grant_types`
- `token_endpoint_auth_method`

**Response 200 OK:**
(mesma estrutura do GET)

**Erros:**

| Status | Error Code | Descrição |
|--------|------------|-----------|
| 400 | `invalid_client_metadata` | Tentativa de alterar campo imutável |
| 401 | `invalid_token` | RAT inválido |
| 403 | `forbidden` | mTLS não corresponde |

---

### 4. DELETE /register/{client_id}

**Descrição:** Remove um cliente registrado.

**Request:**

```http
DELETE /register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 HTTP/1.1
Host: api.detentora.com.br
Authorization: Bearer {registration_access_token}
```

**Response 204 No Content:**

(sem body)

**Erros:**

| Status | Error Code | Descrição |
|--------|------------|-----------|
| 401 | `invalid_token` | RAT inválido |
| 403 | `forbidden` | mTLS não corresponde |
| 404 | `not_found` | Cliente já deletado |

---

## 📝 Validações e Políticas FAPI-BR

### Validação do Software Statement Assertion (SSA)

O SSA é um JWT assinado pelo Diretório. Exemplo de claims:

```json
{
  "iss": "https://diretorio.openfinancebrasil.org.br",
  "iat": 1731062340,
  "exp": 1731066000,
  "jti": "unique-jti-12345",
  "aud": "https://api.detentora.com.br",
  "software_id": "soft-12345",
  "software_client_name": "App TPP",
  "software_version": "1.0.0",
  "software_client_uri": "https://tpp.example.com",
  "software_redirect_uris": [
    "https://tpp.example.com/callback"
  ],
  "software_jwks_uri": "https://tpp.example.com/jwks.json",
  "org_id": "org-67890",
  "org_name": "TPP Instituição"
}
```

**Validações Aplicadas:**

1. **Assinatura**: verificada com JWKS do Diretório (algoritmo PS256)
2. **Tempo**: `iat` dentro da janela de tolerância (60s), `exp` não expirado
3. **Idempotência**: `jti` não duplicado (cache Redis)
4. **Emissor**: `iss` corresponde ao Diretório esperado
5. **Audiência**: `aud` corresponde ao AS da Detentora
6. **Claims obrigatórias**: `software_id`, `org_id`, `software_jwks_uri`

### Políticas de Metadados (FAPI-BR)

**1. JWKS URI obrigatório:**
- Campo `jwks` inline é **PROIBIDO**
- `jwks_uri` deve ser HTTPS

**2. Token Endpoint Authentication:**
- Método obrigatório: `private_key_jwt`
- Algoritmo: `PS256` (recomendado) ou `ES256`

**3. Grant Types:**
- Permitidos: `authorization_code`, `client_credentials`
- Proibidos: `password`, `implicit`

**4. Response Types:**
- Permitidos: `code`
- Proibidos: `token`, `id_token`

**5. Request Object:**
- Assinatura obrigatória (`request_object_signing_alg`)
- PAR (Pushed Authorization Request) required no AS

**6. Redirect URIs:**
- HTTPS obrigatório (exceto localhost em dev)
- Validação contra `software_redirect_uris` do SSA

---

## 🔄 Idempotência

### Controle por JTI

Requisições com o mesmo `jti` do SSA são consideradas duplicatas:

**1ª requisição:**
```
POST /register
SSA.jti = "unique-jti-12345"
→ 201 Created (novo registro)
```

**2ª requisição (< 10 min):**
```
POST /register
SSA.jti = "unique-jti-12345"
→ 201 Created (replay seguro, mesma resposta)
```

**Implementação:**
- Cache Redis: `idempotency:ssa:jti:{jti}` → `{client_id}`
- TTL: 600 segundos
- Resposta idêntica à primeira requisição

---

## 📊 Rate Limiting

### Por Organização

```
Limite: 100 requisições/minuto por org_id
Window: sliding window de 60 segundos
```

**Resposta quando excedido:**

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 45
Content-Type: application/json

{
  "error": "too_many_requests",
  "error_description": "Rate limit exceeded for org_id=org-67890. Retry after 45 seconds.",
  "trace_id": "trace-xyz789"
}
```

---

## 🧪 Exemplos de Uso

### Registro Bem-Sucedido

```bash
curl -X POST https://api.detentora.com.br/openbanking/register \
  --cert tpp-cert.pem \
  --key tpp-key.pem \
  -H "Content-Type: application/json" \
  -d '{
    "software_statement": "eyJhbGc...",
    "jwks_uri": "https://tpp.example.com/jwks.json",
    "redirect_uris": ["https://tpp.example.com/callback"],
    "grant_types": ["authorization_code"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "private_key_jwt"
  }'
```

### Consulta de Cliente

```bash
curl -X GET https://api.detentora.com.br/openbanking/register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 \
  --cert tpp-cert.pem \
  --key tpp-key.pem \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

### Atualização de Redirect URIs

```bash
curl -X PUT https://api.detentora.com.br/openbanking/register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 \
  --cert tpp-cert.pem \
  --key tpp-key.pem \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  -H "Content-Type: application/json" \
  -d '{
    "redirect_uris": [
      "https://tpp.example.com/callback",
      "https://tpp.example.com/callback2"
    ]
  }'
```

### Deleção de Cliente

```bash
curl -X DELETE https://api.detentora.com.br/openbanking/register/b1f3b3a0-8c7e-4b1c-9e33-27f1f7e5d1a0 \
  --cert tpp-cert.pem \
  --key tpp-key.pem \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

---

## 🔍 Trace ID e Debugging

Todas as respostas incluem `trace_id` para correlação em logs:

```json
{
  "error": "invalid_software_statement",
  "error_description": "...",
  "trace_id": "trace-abc123def456"
}
```

Use o `trace_id` para buscar logs detalhados no sistema de observabilidade.

---

## 📚 Documentação Relacionada

- [Modelo de Dados](DATA_MODEL.md)
- [Guia de Desenvolvimento](DEVELOPMENT_GUIDE.md)
- [Políticas de Segurança](../operations/SECURITY.md)
- [Runbooks de Troubleshooting](../runbooks/)

---

**OpenAPI Spec:** Ver [openapi.yaml](../../postman/openapi.yaml)  
**Coleção Postman:** Ver [DCR-Enterprise.postman_collection.json](../../postman/DCR-Enterprise.postman_collection.json)

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
