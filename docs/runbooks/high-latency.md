# Runbook: Alta Latência (p99 > 800ms)

## 🎯 Objetivo

Diagnosticar e resolver problemas de performance quando a latência p99 de requisições DCR ultrapassa o SLO de 800ms.

## 🚨 Alertas Relacionados

- `DCRHighLatency`: p99 > 1000ms por 5 minutos
- `DCRLatencySLOBreach`: p99 > 800ms por 10 minutos
- `DCRSlowRequests`: Requisições > 2s aumentando

## 📊 Sintomas

- Métrica `histogram_quantile(0.99, dcr_latency_ms_bucket)` > 800ms
- Clientes reportando timeouts ou lentidão
- Aumento no error budget SLO
- Traces distribuídos mostrando spans lentos

## 🔍 Diagnóstico

### 1. Identificar Componente Lento

```bash
# Verificar distribuição de latência por operação
dcr_latency_ms_bucket{operation="register"} 
dcr_latency_ms_bucket{operation="validate_ssa"}
dcr_latency_ms_bucket{operation="keycloak_create"}
dcr_latency_ms_bucket{operation="db_persist"}
```

### 2. Analisar Traces Distribuídos

```bash
# Datadog/Tempo
- Filtrar por duration > 1s
- Identificar span mais lento
- Verificar se é CPU-bound ou I/O-bound
```

### 3. Verificar Cache Hit Ratio

```bash
# JWKS Cache
dcr_jwks_cache_hit_ratio < 0.7

# Idempotency Cache
dcr_idempotency_cache_hit_ratio
```

### 4. Verificar Database

```bash
# Slow queries
kubectl exec -n openfinance postgres-0 -- psql -U dcr_admin -d dcr_registry -c \
  "SELECT query, mean_exec_time, calls FROM pg_stat_statements \
   ORDER BY mean_exec_time DESC LIMIT 10;"

# Active queries
kubectl exec -n openfinance postgres-0 -- psql -U dcr_admin -d dcr_registry -c \
  "SELECT pid, now() - query_start AS duration, state, query \
   FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC;"
```

### 5. Verificar Redis

```bash
# Latência do Redis
kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis --latency

# Comandos lentos
kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis SLOWLOG GET 10
```

### 6. Verificar Recursos do DCR

```bash
# CPU/Memória
kubectl top pod -n openfinance -l app=dcr-service

# Throttling (CPU limit)
kubectl describe pod -n openfinance -l app=dcr-service | grep -A 5 "Limits"
```

## 🛠️ Resolução

### Cenário 1: Cache Miss Alto (JWKS)

**Causa**: Cache Redis vazio/expirado, TTL muito baixo.

**Ação**:

1. **Verificar TTL atual**:

```bash
kubectl exec -n openfinance deployment/dcr-service -- env | grep JWKS_TTL
```

2. **Aumentar TTL** (se apropriado):

```bash
kubectl set env deployment/dcr-service -n openfinance \
  DCR_JWKS_TTL_SEC=600
```

3. **Warm up do cache**:

```bash
# Fazer algumas requisições de teste para popular
curl -X POST https://api.example.com/openbanking/register \
  --cert client.crt --key client.key \
  -d @test-request.json
```

4. **Monitorar**:

```bash
watch -n 5 'kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis --scan --pattern "jwks:*" | wc -l'
```

### Cenário 2: Database Lento

**Causa**: Queries sem índice, bloqueios, hardware insuficiente.

**Ação**:

1. **Identificar query lenta**:

```sql
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
WHERE query LIKE '%client_registry%'
ORDER BY mean_exec_time DESC LIMIT 5;
```

2. **Adicionar índices** (se ausentes):

```sql
-- Índice por software_id e org_id
CREATE INDEX CONCURRENTLY idx_client_registry_sw_org 
ON client_registry(software_id, org_id);

-- Índice por status
CREATE INDEX CONCURRENTLY idx_client_registry_status 
ON client_registry(status) WHERE status = 'active';
```

3. **Vacuum/Analyze**:

```sql
VACUUM ANALYZE client_registry;
VACUUM ANALYZE ssa_audit;
```

4. **Escalar RDS** (se necessário):

```bash
aws rds modify-db-instance \
  --db-instance-identifier dcr-registry-prd \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately
```

### Cenário 3: Keycloak Admin API Lento

**Causa**: Keycloak sobrecarregado, rede lenta.

**Ação**:

1. **Verificar latência do Keycloak**:

```bash
# Traces/Logs
grep "keycloak_create_client" dcr-service.log | grep "duration"
```

2. **Testar diretamente**:

```bash
time curl -X POST https://auth.example.com/admin/realms/open-finance/clients \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"clientId":"test"}'
```

3. **Escalar Keycloak**:

```bash
kubectl scale statefulset keycloak -n openfinance --replicas=3
```

4. **Otimizar criação** (async se possível):

```java
// Considerar pattern async + callback
@Async
public CompletableFuture<ClientRepresentation> createClientAsync(...)
```

### Cenário 4: CPU Throttling

**Causa**: Limite de CPU muito baixo, pods sendo throttled.

**Ação**:

1. **Verificar throttling**:

```bash
kubectl describe pod -n openfinance dcr-service-xxx | grep -i throttl
```

2. **Aumentar CPU limit**:

```yaml
# values.yaml
resources:
  requests:
    cpu: "500m"
  limits:
    cpu: "2000m"  # era 1000m
```

3. **Aplicar**:

```bash
helm upgrade dcr-service ./helm/dcr-service -n openfinance -f values.yaml
```

4. **Monitorar**:

```bash
watch -n 2 'kubectl top pod -n openfinance -l app=dcr-service'
```

### Cenário 5: GC Pausas (Java)

**Causa**: Heap insuficiente, GC tuning inadequado.

**Ação**:

1. **Verificar GC logs**:

```bash
kubectl logs -n openfinance -l app=dcr-service | grep -i "GC pause"
```

2. **Aumentar heap**:

```bash
kubectl set env deployment/dcr-service -n openfinance \
  JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -Xmx2g"
```

3. **Habilitar GC logging detalhado** (temporário):

```bash
kubectl set env deployment/dcr-service -n openfinance \
  JAVA_OPTS="-XX:+UseG1GC -Xlog:gc*:file=/tmp/gc.log"
```

4. **Analisar com GCViewer**:

```bash
kubectl cp openfinance/dcr-service-xxx:/tmp/gc.log ./gc.log
# Usar GCViewer ou similar
```

### Cenário 6: Rede Lenta

**Causa**: Latência entre AZs, throttling de rede.

**Ação**:

1. **Medir latência inter-AZ**:

```bash
kubectl exec -n openfinance dcr-service-xxx -- \
  ping -c 10 dcr-redis.openfinance.svc.cluster.local
```

2. **Verificar placement**:

```bash
kubectl get pods -n openfinance -o wide -l app=dcr-service
kubectl get pods -n openfinance -o wide -l app=redis
```

3. **Forçar mesma AZ** (se aplicável):

```yaml
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: redis
        topologyKey: topology.kubernetes.io/zone
```

### Cenário 7: Carga Alta

**Causa**: Tráfego acima do esperado, HPA não escalando rápido.

**Ação**:

1. **Escalar manualmente** (imediato):

```bash
kubectl scale deployment dcr-service -n openfinance --replicas=10
```

2. **Ajustar HPA**:

```yaml
autoscaling:
  minReplicas: 5  # era 3
  maxReplicas: 20  # era 10
  targetCPUUtilizationPercentage: 60  # era 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0  # resposta mais rápida
      policies:
      - type: Pods
        value: 4  # adicionar 4 pods de uma vez
        periodSeconds: 15
```

3. **Aplicar**:

```bash
helm upgrade dcr-service ./helm/dcr-service -n openfinance -f values.yaml
```

## 📈 Monitoramento Pós-Incidente

```bash
# Latência voltou ao normal?
histogram_quantile(0.99, dcr_latency_ms_bucket) < 800

# Cache hit ratio recuperado?
dcr_jwks_cache_hit_ratio > 0.7

# Database sem queries lentas?
avg(pg_stat_statements_mean_exec_time) < 100
```

## 🔄 Escalação

**Nível 1** (0-10 min): DCR Team  
**Nível 2** (10-30 min): Tech Lead + SRE  
**Nível 3** (30+ min): Arquitetura + Vendor Support

## 📝 Post-Mortem

Template: `docs/post-mortems/YYYY-MM-DD-high-latency.md`

Incluir:
1. Componente bottleneck (cache, DB, Keycloak, CPU)
2. Latência p50/p95/p99 durante incidente
3. Duração e impacto (% de usuários)
4. MTTR e ações tomadas
5. Prevenção (HPA, índices, tuning)

## 🎓 Prevenção

- **Capacity planning**: Testes de carga regulares
- **Cache warming**: Popular cache após deploy
- **Database tuning**: Índices, vacuum regular
- **HPA agressivo**: Escalar antes de atingir limite
- **Circuit breaker**: Fail fast em dependências lentas
- **Alertas proativos**: p95 > 500ms, não esperar p99 > 800ms
- **SLI/SLO monitoring**: Dashboard dedicado

---

**Última atualização**: 2025-11-08  
**Owner**: DCR Team + SRE
