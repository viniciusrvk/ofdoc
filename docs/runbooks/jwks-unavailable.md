# Runbook: JWKS do Diretório Indisponível

## 🎯 Objetivo

Este runbook descreve os procedimentos para diagnosticar e resolver problemas quando o endpoint JWKS do Diretório Central do Open Finance Brasil está indisponível ou retornando erros.

## 🚨 Alertas Relacionados

- `DCRJWKSCacheMissRateHigh`: Taxa de cache miss > 50% por 10 minutos
- `DCRJWKSFetchFailure`: Falha ao buscar JWKS do Diretório
- `DCRValidationErrors`: Aumento de erros de validação de SSA

## 📊 Sintomas

- Métrica `dcr_jwks_cache_hit_ratio` caindo abaixo de 50-70%
- Logs mostrando erros de conexão ao endpoint JWKS do Diretório
- Aumento de rejeições de SSA válidos (erro `invalid_software_statement`)
- Latência p99 aumentando devido a timeouts nas chamadas JWKS

## 🔍 Diagnóstico

### 1. Verificar Métricas

```bash
# Datadog/Grafana
dcr_jwks_cache_hit_ratio < 0.5
dcr_errors_total{type="jwks_fetch_failure"}
```

### 2. Verificar Logs

```bash
kubectl logs -n openfinance -l app=dcr-service --tail=100 | grep "JWKS"
```

Procure por:
- `Failed to fetch JWKS from directory`
- `Connection timeout to directory.openfinancebrasil.org.br`
- `SSL handshake error`

### 3. Testar Conectividade

```bash
# De dentro de um pod DCR
kubectl exec -n openfinance deployment/dcr-service -- curl -v \
  https://directory.sandbox.openfinancebrasil.org.br/jwks

# Verificar DNS
kubectl exec -n openfinance deployment/dcr-service -- nslookup \
  directory.openfinancebrasil.org.br

# Verificar rota de rede
kubectl exec -n openfinance deployment/dcr-service -- traceroute \
  directory.openfinancebrasil.org.br
```

### 4. Verificar Status do Diretório

```bash
# Status público do Open Finance Brasil
curl https://status.openfinancebrasil.org.br/api/v1/status
```

## 🛠️ Resolução

### Cenário 1: Indisponibilidade Temporária do Diretório

**Impacto**: SSAs novos não podem ser validados, mas cache mantém operação parcial.

**Ação Imediata**:

1. **Aumentar TTL do cache temporariamente** (se cache ainda tem entradas válidas):

```bash
kubectl set env deployment/dcr-service -n openfinance \
  DCR_JWKS_TTL_SEC=1800
```

2. **Monitorar recovery**:

```bash
watch -n 10 'kubectl logs -n openfinance -l app=dcr-service --tail=1 | grep JWKS'
```

3. **Comunicar ao time**:

```
Slack: #dcr-support
"🟡 Diretório JWKS indisponível. Cache operando com TTL estendido (30 min).
Novos SSAs podem falhar. Monitorando recovery."
```

**Rollback**:

Quando Diretório voltar:

```bash
kubectl set env deployment/dcr-service -n openfinance \
  DCR_JWKS_TTL_SEC=300
```

### Cenário 2: Problema de Rede/Firewall

**Sintomas**: Timeout, connection refused, DNS resolution failure.

**Ação**:

1. **Verificar Network Policies**:

```bash
kubectl get networkpolicies -n openfinance
kubectl describe networkpolicy dcr-service -n openfinance
```

Garantir egress para porta 443:

```yaml
egress:
- to:
  - namespaceSelector: {}
  ports:
  - protocol: TCP
    port: 443
```

2. **Verificar Security Groups** (AWS):

```bash
# Listar security groups do node group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=dcr-*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]'

# Validar regra de saída HTTPS
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[*].IpPermissionsEgress'
```

3. **Adicionar regra se necessário**:

```bash
aws ec2 authorize-security-group-egress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### Cenário 3: Cache Redis Indisponível

**Sintomas**: Todas as requisições fetcham JWKS (cache miss 100%).

**Ação**:

1. **Verificar Redis**:

```bash
kubectl get pods -n openfinance -l app=redis
kubectl logs -n openfinance -l app=redis --tail=50
```

2. **Testar conectividade**:

```bash
kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis -p 6379 PING
```

3. **Reiniciar Redis** (se necessário):

```bash
kubectl rollout restart statefulset/redis -n openfinance
```

### Cenário 4: Chave JWKS Rotacionada

**Sintomas**: SSAs assinados com novo `kid` são rejeitados.

**Ação**:

1. **Forçar refresh do cache**:

```bash
kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis FLUSHDB

# Ou deletar chaves específicas
kubectl exec -n openfinance deployment/dcr-service -- \
  redis-cli -h dcr-redis --scan --pattern "jwks:directory:*" | xargs redis-cli DEL
```

2. **Validar novo JWKS**:

```bash
curl https://directory.openfinancebrasil.org.br/jwks | jq '.keys[] | {kid, alg, use}'
```

3. **Verificar que DCR está fetchando**:

```bash
kubectl logs -n openfinance -l app=dcr-service -f | grep "Fetched JWKS"
```

## 📈 Monitoramento Pós-Incidente

```bash
# Verificar cache hit ratio
dcr_jwks_cache_hit_ratio > 0.7

# Verificar taxa de erro de validação SSA
rate(dcr_errors_total{type="ssa_invalid"}[5m]) < 0.01

# Latência de registro
histogram_quantile(0.99, dcr_latency_ms_bucket) < 800
```

## 🔄 Escalação

**Nível 1** (0-15 min): Time DCR  
**Nível 2** (15-30 min): Tech Lead + Infra  
**Nível 3** (30+ min): Contato Open Finance Brasil (suporte externo)

### Contatos

- **Open Finance BR Suporte**: `suporte@openbankingbrasil.org.br`
- **Status Page**: `https://status.openfinancebrasil.org.br`
- **Slack Oficial**: `#openfinance-suporte`

## 📝 Post-Mortem

Após resolução, documentar:

1. **Hora do incidente** e detecção
2. **Causa raiz** (Diretório down, rede, cache, rotação chave)
3. **Impacto** (% de requisições afetadas)
4. **Tempo de resolução** (MTTR)
5. **Ações corretivas** (ex.: aumentar TTL padrão, alertas antecipados)

Template: `docs/post-mortems/YYYY-MM-DD-jwks-incident.md`

## 🎓 Prevenção

- **Alertas proativos**: `cache_hit_ratio < 0.7` por 5 min
- **Health check do Diretório**: monitorar externamente
- **TTL otimizado**: balancear entre freshness e resiliência
- **Fallback**: considerar JWKS backup estático para emergências críticas (requer aprovação de segurança)

---

**Última atualização**: 2025-11-08  
**Owner**: DCR Team
