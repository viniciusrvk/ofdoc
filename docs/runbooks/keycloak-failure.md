# Runbook: Falha no Keycloak Admin API

## 🎯 Objetivo

Diagnosticar e resolver problemas quando o Keycloak Authorization Server está retornando erros na Admin API, impedindo a criação/atualização de clients via DCR.

## 🚨 Alertas Relacionados

- `DCRKeycloakAdminAPIFailure`: Taxa de erro > 5% por 5 minutos
- `DCRUpstreamError`: Códigos 502/503 aumentando
- `KeycloakHighCPU`: CPU do Keycloak > 80%
- `KeycloakDatabaseConnectionFailure`: Pool de conexões esgotado

## 📊 Sintomas

- DCR retornando `502 upstream_failure` ou `503 service_unavailable`
- Métrica `dcr_errors_total{type="as_admin_failure"}` subindo
- Timeout em chamadas para Keycloak Admin API
- Logs mostrando `Connection refused` ou `Read timeout`

## 🔍 Diagnóstico

### 1. Verificar Health do Keycloak

```bash
# Health check
curl -f https://auth.example.com/health/ready
curl -f https://auth.example.com/health/live

# Verificar pods
kubectl get pods -n openfinance -l app=keycloak
kubectl describe pod keycloak-0 -n openfinance
```

### 2. Verificar Logs do Keycloak

```bash
kubectl logs -n openfinance -l app=keycloak --tail=200 | grep -E "ERROR|WARN|Exception"
```

Procure por:
- `OutOfMemoryError`
- `Database connection pool exhausted`
- `Transaction timeout`
- `Lock wait timeout exceeded`

### 3. Verificar Métricas do Keycloak

```bash
# Prometheus/Grafana
jvm_memory_used_bytes{app="keycloak"} / jvm_memory_max_bytes{app="keycloak"}
keycloak_database_connections_active
keycloak_request_duration_seconds{quantile="0.99"}
```

### 4. Verificar Database (PostgreSQL)

```bash
# Conexões ativas
kubectl exec -n openfinance postgres-0 -- psql -U keycloak -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='keycloak';"

# Locks
kubectl exec -n openfinance postgres-0 -- psql -U keycloak -c \
  "SELECT * FROM pg_locks WHERE NOT granted;"

# Queries lentas
kubectl exec -n openfinance postgres-0 -- psql -U keycloak -c \
  "SELECT pid, now() - pg_stat_activity.query_start AS duration, query \
   FROM pg_stat_activity \
   WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '30 seconds';"
```

## 🛠️ Resolução

### Cenário 1: Keycloak Pod Unhealthy

**Sintomas**: Readiness/Liveness probes falhando.

**Ação Imediata**:

1. **Reiniciar pod problemático**:

```bash
kubectl delete pod keycloak-0 -n openfinance
# StatefulSet irá recriar automaticamente
```

2. **Monitorar recovery**:

```bash
kubectl get pods -n openfinance -l app=keycloak -w
kubectl logs -n openfinance keycloak-0 -f
```

3. **Validar**:

```bash
curl -f https://auth.example.com/health/ready
```

### Cenário 2: Pool de Conexões Esgotado

**Sintomas**: `HikariPool connection timeout`, database connections > 90%.

**Ação**:

1. **Aumentar pool size temporariamente**:

```bash
kubectl set env statefulset/keycloak -n openfinance \
  DB_POOL_SIZE=50
```

2. **Restart para aplicar**:

```bash
kubectl rollout restart statefulset/keycloak -n openfinance
kubectl rollout status statefulset/keycloak -n openfinance
```

3. **Investigar queries lentas** (ver seção Diagnóstico #4).

4. **Permanente**: Atualizar `values.yaml` do Helm:

```yaml
keycloak:
  database:
    poolSize: 50
    connectionTimeout: 10000
```

### Cenário 3: CPU/Memória Alta

**Sintomas**: Keycloak lento, timeouts, GC frequente.

**Ação**:

1. **Verificar recursos**:

```bash
kubectl top pod -n openfinance -l app=keycloak
```

2. **Escalar horizontalmente**:

```bash
kubectl scale statefulset keycloak -n openfinance --replicas=3
```

3. **Ou aumentar recursos verticalmente**:

```yaml
# helm/values.yaml
resources:
  requests:
    cpu: "2000m"
    memory: "4Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"
```

```bash
helm upgrade keycloak ./helm/keycloak -n openfinance -f values.yaml
```

4. **Heap dump** (se OutOfMemoryError):

```bash
kubectl exec -n openfinance keycloak-0 -- \
  jmap -dump:format=b,file=/tmp/heap.hprof 1

kubectl cp openfinance/keycloak-0:/tmp/heap.hprof ./heap.hprof
```

Analisar com Eclipse MAT ou VisualVM.

### Cenário 4: Transações/Locks no Database

**Sintomas**: `Lock wait timeout exceeded`, queries bloqueadas.

**Ação**:

1. **Identificar sessões bloqueadas**:

```sql
SELECT 
  blocked_locks.pid AS blocked_pid,
  blocking_locks.pid AS blocking_pid,
  blocked_activity.usename AS blocked_user,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_statement,
  blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted AND blocking_locks.granted;
```

2. **Terminar sessão bloqueante** (CUIDADO!):

```sql
SELECT pg_terminate_backend(<blocking_pid>);
```

3. **Restart Keycloak** (se persistir):

```bash
kubectl rollout restart statefulset/keycloak -n openfinance
```

### Cenário 5: Admin API Credentials Inválidas

**Sintomas**: `401 Unauthorized` em logs do DCR.

**Ação**:

1. **Validar secret**:

```bash
kubectl get secret dcr-secrets -n openfinance -o jsonpath='{.data.keycloak_client_secret}' | base64 -d
```

2. **Testar credenciais manualmente**:

```bash
curl -X POST https://auth.example.com/realms/master/protocol/openid-connect/token \
  -d "client_id=admin-cli" \
  -d "client_secret=<secret>" \
  -d "grant_type=client_credentials"
```

3. **Regenerar se necessário**:

```bash
# No Keycloak Admin UI
# Clients → admin-cli → Credentials → Regenerate Secret

# Atualizar secret no K8s
kubectl create secret generic dcr-secrets \
  --from-literal=keycloak_client_secret=<new_secret> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart DCR para pegar novo secret
kubectl rollout restart deployment/dcr-service -n openfinance
```

### Cenário 6: Rate Limiting no Admin API

**Sintomas**: `429 Too Many Requests`.

**Ação**:

1. **Verificar configuração de rate limit** no Keycloak.

2. **Implementar retry com backoff** no DCR (já deve existir):

```java
@Retry(name = "keycloakAdmin", fallbackMethod = "fallbackCreateClient")
@CircuitBreaker(name = "keycloakAdmin")
public ClientRepresentation createClient(ClientRepresentation client) {
    // ...
}
```

3. **Reduzir carga** (temporário):

```bash
# Reduzir replicas do DCR
kubectl scale deployment dcr-service -n openfinance --replicas=2
```

## 📈 Monitoramento Pós-Incidente

```bash
# Taxa de sucesso Admin API
rate(dcr_keycloak_admin_success_total[5m]) / rate(dcr_keycloak_admin_total[5m]) > 0.99

# Latência Admin API
histogram_quantile(0.99, dcr_keycloak_admin_latency_ms_bucket) < 500

# Health Keycloak
up{job="keycloak"} == 1
```

## 🔄 Escalação

**Nível 1** (0-10 min): DCR Team + Keycloak Admin  
**Nível 2** (10-30 min): Tech Lead + DBA  
**Nível 3** (30+ min): Vendor Support (Red Hat SSO se aplicável)

### Contatos

- **Keycloak Docs**: `https://www.keycloak.org/docs/latest/`
- **Red Hat SSO**: `support.redhat.com` (se enterprise)

## 📝 Post-Mortem

Template: `docs/post-mortems/YYYY-MM-DD-keycloak-failure.md`

Incluir:
1. Causa raiz (DB, CPU, bug, config)
2. Impacto (% de registros falhados, duração)
3. MTTR (tempo até recovery)
4. Ações preventivas

## 🎓 Prevenção

- **HPA para Keycloak**: escalar com CPU/memória
- **Connection pooling otimizado**: baseline 20-30
- **Database tuning**: índices, autovacuum
- **Alertas antecipados**: CPU > 70%, connections > 80%
- **Chaos engineering**: testes de falha do Keycloak
- **Circuit breaker** no DCR para falhas rápidas

---

**Última atualização**: 2025-11-08  
**Owner**: DCR Team + Keycloak Admins
