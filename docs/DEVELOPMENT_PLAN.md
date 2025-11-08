# Plano de Desenvolvimento — DCR Enterprise

> **Duração estimada**: 12-16 semanas  
> **Metodologia**: Sprints de 2 semanas com entregas incrementais  
> **Abordagem**: Desenvolvimento modular com possibilidade de paralelização

---

## 📋 Índice

- [1. Visão Geral do Plano](#1-visão-geral-do-plano)
- [2. Áreas de Responsabilidade](#2-áreas-de-responsabilidade)
- [3. Fases do Projeto](#3-fases-do-projeto)
- [4. Cronograma Detalhado](#4-cronograma-detalhado)
- [5. Dependências Críticas](#5-dependências-críticas)
- [6. Critérios de Aceitação](#6-critérios-de-aceitação)
- [7. Riscos e Mitigações](#7-riscos-e-mitigações)

> 📊 **[Ver também: Diagrama de Gantt Completo](GANTT_CHART.md)**

---

## 1. Visão Geral do Plano

### Objetivos

- Implementar solução DCR completa e em conformidade com FAPI-BR
- Garantir observabilidade, segurança e resiliência desde o início
- Entregar em fases incrementais com valor agregado
- Possibilitar trabalho paralelo entre diferentes áreas do projeto

### Princípios

✅ **Infrastructure as Code** desde o dia 1  
✅ **Testes automatizados** em todas as camadas  
✅ **Segurança by design** (mTLS, auditoria, validações)  
✅ **Observabilidade** integrada (não deixar para depois)  
✅ **Documentação viva** (atualizada com o código)

---

## 2. Áreas de Responsabilidade

O projeto está organizado em **3 áreas principais** que podem ser desenvolvidas em paralelo conforme disponibilidade do time:

### Área 1 — Backend (DCR Service)
**Componentes:**
- DCR Service (Java 25, Spring Boot)
- Validação SSA e políticas FAPI-BR
- Integração com Keycloak Admin API
- Modelagem de dados (Postgres)
- APIs REST (endpoints DCR)

### Área 2 — Infraestrutura e DevOps
**Componentes:**
- Infraestrutura AWS (Terraform)
- Kubernetes/Helm charts
- API Gateway + mTLS
- Pipeline CI/CD (GitLab CI ou GitHub Actions)
- Observabilidade (OpenTelemetry, Datadog/Prometheus)

### Área 3 — Integração e Qualidade
**Componentes:**
- Integração com Keycloak (configuração FAPI)
- Cache Redis (estratégias e invalidação)
- Eventos SNS/SQS + Auditoria S3 WORM
- Testes de integração e conformidade
- Console React (operação)

---

## 3. Fases do Projeto

### Fase 0: Fundação (Semanas 1-2)
**Objetivo**: Ambiente de desenvolvimento e decisões arquiteturais  
**Entregáveis**:
- Repositório estruturado
- Ambientes locais (Docker Compose)
- Decisões de stack finalizadas
- Templates de documentação

### Fase 1: MVP Backend (Semanas 3-6)
**Objetivo**: DCR funcional com validações básicas  
**Entregáveis**:
- API `POST /register` funcional
- Validação SSA (assinatura, claims)
- Políticas FAPI-BR básicas
- Persistência Postgres
- Testes unitários

### Fase 2: Infraestrutura Core (Semanas 5-8)
**Objetivo**: Infra cloud e observabilidade  
**Entregáveis**:
- Módulos Terraform (VPC, EKS, RDS, Redis)
- Helm charts do DCR Service
- API Gateway com mTLS
- OpenTelemetry integrado
- Pipeline CI/CD básico

### Fase 3: Integrações Críticas (Semanas 7-10)
**Objetivo**: Keycloak, cache, eventos e auditoria  
**Entregáveis**:
- Keycloak configurado (FAPI-BR)
- Cache Redis (JWKS, idempotência)
- SNS/SQS + processador de auditoria
- S3 WORM para trilha imutável
- mTLS end-to-end validado

### Fase 4: Hardening & Compliance (Semanas 11-14)
**Objetivo**: Segurança, conformidade e resiliência  
**Entregáveis**:
- Testes de conformidade FAPI-BR
- Testes de carga (K6)
- Runbooks operacionais
- Alertas e dashboards
- Pen test e remediações

### Fase 5: Console & Go-Live (Semanas 15-16)
**Objetivo**: Ferramentas de operação e produção  
**Entregáveis**:
- Console React (consulta/gestão)
- Documentação final
- Ambiente de produção
- Treinamento do time de ops
- Go-live controlado

---

## 4. Cronograma Detalhado

### Sprint 1 (Semanas 1-2): Fundação

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Setup projeto Java 25 + Spring Boot | 8h |
| | Estrutura de pacotes e classes base | 8h |
| | Modelos de domínio (Client, SSA) | 8h |
| | Setup JUnit + Mockito | 4h |
| | Validações básicas de input | 8h |
| **Infra** | Repositório Git + branch strategy | 4h |
| | Docker Compose (Postgres, Redis, Keycloak) | 12h |
| | Makefile/scripts de automação | 4h |
| | Estrutura Terraform base | 8h |
| | Pipeline skeleton CI/CD | 8h |
| **Integração** | Setup Keycloak local (realm, configs) | 12h |
| | Documentação de integração | 8h |
| | Coleção Postman inicial | 8h |
| | Scripts de geração de certificados mTLS | 8h |

**Checkpoint Sprint 1:**
- [ ] Ambiente local rodando (Docker Compose)
- [ ] Projeto Java buildando e testando
- [ ] Keycloak acessível e configurado
- [ ] Certificados mTLS gerados

---

### Sprint 2 (Semanas 3-4): API e Validação SSA

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Controller `POST /register` | 8h |
| | Service de validação SSA (assinatura PS256) | 16h |
| | Validação de claims (iat, exp, jti, aud) | 8h |
| | Repository Postgres (client_registry) | 8h |
| | Testes unitários de validação | 8h |
| **Infra** | Terraform: módulo VPC | 12h |
| | Terraform: módulo RDS Postgres | 12h |
| | Helm chart inicial (deployment, service) | 12h |
| | Secrets management (External Secrets) | 4h |
| **Integração** | Mock do Diretório JWKS (WireMock) | 8h |
| | Cliente HTTP para JWKS (cache básico) | 8h |
| | Testes de integração SSA | 12h |
| | Casos de teste Postman (SSA inválido) | 8h |

**Checkpoint Sprint 2:**
- [ ] Validação SSA completa
- [ ] Persistência em Postgres local
- [ ] Testes passando
- [ ] Terraform VPC + RDS provisionado

---

### Sprint 3 (Semanas 5-6): Políticas FAPI-BR e Keycloak

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Policy Engine FAPI-BR | 16h |
| | Validação jwks_uri (proibir inline) | 4h |
| | Validação grant_types e response_types | 4h |
| | Validação token_endpoint_auth_method | 4h |
| | Cliente Keycloak Admin API | 12h |
| | Mapper de Client DTO → Keycloak | 8h |
| **Infra** | Terraform: módulo EKS | 16h |
| | Terraform: módulo ElastiCache Redis | 8h |
| | Helm: ConfigMaps e variables | 8h |
| | Pipeline: build e push de imagem | 8h |
| **Integração** | Configuração Keycloak FAPI (PAR, mTLS) | 12h |
| | Testes Admin API (create client) | 12h |
| | Binding de certificado (SubjectDN) | 8h |
| | Testes de políticas (casos negativos) | 8h |

**Checkpoint Sprint 3:**
- [ ] Políticas FAPI-BR aplicadas
- [ ] Criação de cliente no Keycloak funcional
- [ ] EKS cluster provisionado
- [ ] Redis disponível

---

### Sprint 4 (Semanas 7-8): Cache, Idempotência e mTLS

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Integração Redis (JWKS cache) | 8h |
| | Idempotência por jti (Redis) | 8h |
| | Tratamento de erros padronizado | 8h |
| | Rate limiting básico | 8h |
| | Logs estruturados (JSON) | 8h |
| **Infra** | API Gateway AWS (ou NGINX Ingress) | 16h |
| | Configuração mTLS no Gateway | 12h |
| | Truststore ICP-Brasil | 4h |
| | Sanitização de headers | 8h |
| **Integração** | Extração de headers do certificado | 8h |
| | Binding cert → client no Keycloak | 8h |
| | Testes mTLS end-to-end | 12h |
| | Testes de idempotência (replays) | 8h |

**Checkpoint Sprint 4:**
- [ ] Cache Redis funcionando (hit ratio > 70%)
- [ ] Idempotência validada
- [ ] mTLS configurado no gateway
- [ ] Headers do cert extraídos corretamente

---

### Sprint 5 (Semanas 9-10): Eventos, Auditoria e Observabilidade

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Integração OpenTelemetry (traces) | 12h |
| | Métricas customizadas (Micrometer) | 8h |
| | Correlação trace_id em logs | 4h |
| | Healthcheck endpoints | 4h |
| | Graceful shutdown | 4h |
| **Infra** | Terraform: módulos SNS/SQS | 8h |
| | Terraform: bucket S3 com Object Lock | 8h |
| | Configuração Datadog/Prometheus | 12h |
| | Dashboards Grafana | 8h |
| | Alertas básicos | 8h |
| **Integração** | Publisher SNS (eventos client_registered) | 8h |
| | Processador SQS → S3 WORM | 12h |
| | Formato de auditoria (JSON) | 4h |
| | Testes de eventos ponta a ponta | 12h |

**Checkpoint Sprint 5:**
- [ ] Eventos SNS/SQS fluindo
- [ ] Auditoria em S3 WORM
- [ ] Traces visíveis no Datadog/Jaeger
- [ ] Dashboards básicos funcionando

---

### Sprint 6 (Semanas 11-12): DCR Management e Resiliência

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Endpoint `GET /register/{client_id}` | 8h |
| | Endpoint `PUT /register/{client_id}` | 12h |
| | Endpoint `DELETE /register/{client_id}` | 8h |
| | Validação Registration Access Token | 8h |
| | Circuit breaker (Resilience4j) | 8h |
| | Retry policies | 4h |
| **Infra** | HPA (Horizontal Pod Autoscaler) | 8h |
| | PodDisruptionBudget | 4h |
| | NetworkPolicy restritiva | 8h |
| | Testes de failover (chaos) | 12h |
| | Backup automatizado RDS | 4h |
| **Integração** | Testes PUT/DELETE compliance | 12h |
| | Testes de resiliência (AS down) | 8h |
| | Validação de rollback | 8h |
| | Testes de recuperação | 8h |

**Checkpoint Sprint 6:**
- [ ] CRUD completo de clientes
- [ ] Resiliência validada (circuit breaker)
- [ ] HPA escalando corretamente
- [ ] Backups testados

---

### Sprint 7 (Semanas 13-14): Conformidade e Testes de Carga

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Ajustes de conformidade FAPI-BR | 12h |
| | Otimizações de performance | 8h |
| | Review de segurança (OWASP) | 8h |
| | Documentação de API (OpenAPI) | 8h |
| **Infra** | Ambiente de QA completo | 12h |
| | Testes de carga (K6 scripts) | 12h |
| | Análise de resultados e tuning | 8h |
| | Pipeline de conformidade | 8h |
| **Integração** | Suite de testes FAPI-BR | 16h |
| | Testes de conformidade DCR (RFC 7591/7592) | 12h |
| | Validação de certificados ICP | 8h |
| | Pen test preparação | 4h |

**Checkpoint Sprint 7:**
- [ ] Testes de conformidade passando
- [ ] Carga de 50 rps sustentada
- [ ] p99 < 800ms validado
- [ ] Ambiente QA estável

---

### Sprint 8 (Semanas 15-16): Console, Runbooks e Go-Live

| Área | Tarefas | Horas Est. |
|------|---------|------------|
| **Backend** | Ajustes finais de logs e métricas | 8h |
| | Review de código completo | 8h |
| | Documentação técnica final | 8h |
| | Treinamento time de ops | 8h |
| **Infra** | Ambiente de produção (Terraform) | 16h |
| | Runbooks operacionais | 12h |
| | Documentação de troubleshooting | 8h |
| | Plano de rollback | 4h |
| | Go-live checklist | 4h |
| **Integração** | Console React (básico) | 20h |
| | Testes E2E no console | 8h |
| | Documentação de operação | 8h |
| | Smoke tests produção | 4h |

**Checkpoint Sprint 8:**
- [ ] Console React funcional
- [ ] Runbooks completos
- [ ] Produção provisionada
- [ ] Go-live aprovado

---

## 5. Dependências Críticas

### Bloqueantes entre sprints

```
Sprint 1 → Sprint 2: Ambiente local funcional
Sprint 2 → Sprint 3: Validação SSA completa
Sprint 3 → Sprint 4: Keycloak Admin API integrado
Sprint 4 → Sprint 5: mTLS configurado
Sprint 5 → Sprint 6: Observabilidade básica
Sprint 6 → Sprint 7: CRUD completo
Sprint 7 → Sprint 8: Conformidade validada
```

### Dependências externas

- **Certificados ICP-Brasil**: necessários para QA/PRD (Sprint 4)
- **Credenciais AWS**: provisionamento desde Sprint 2
- **Acesso ao Diretório**: JWKS endpoint (pode ser mockado até Sprint 6)
- **Keycloak extensões FAPI**: validar compatibilidade Sprint 1

---

## 6. Critérios de Aceitação

### Por Sprint

Cada sprint deve entregar:
- [ ] Código revisado (PR aprovado)
- [ ] Testes automatizados (cobertura > 80%)
- [ ] Documentação atualizada
- [ ] Demo funcional
- [ ] Ambiente deployado (quando aplicável)

### Go-Live (Sprint 8)

- [ ] Todos os testes de conformidade passando
- [ ] SLOs validados (99.9% disponibilidade, p99 < 800ms)
- [ ] Auditoria S3 WORM funcionando
- [ ] Runbooks testados
- [ ] Equipe de ops treinada
- [ ] Plano de rollback aprovado
- [ ] Pen test executado e remediado
- [ ] Certificação FAPI-BR (se aplicável)

---

## 7. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Atraso em certificados ICP | Média | Alto | Usar certificados auto-assinados até Sprint 6 |
| Complexidade Keycloak FAPI | Alta | Alto | POC dedicada no Sprint 1; suporte da comunidade |
| Problemas de performance | Média | Médio | Testes de carga desde Sprint 5; profiling contínuo |
| Mudanças em specs FAPI-BR | Baixa | Alto | Monitorar fóruns; design flexível para políticas |
| Indisponibilidade de engenheiro | Média | Médio | Documentação viva; pair programming; backup cross-training |
| Falha em conformidade | Baixa | Alto | Testes automatizados desde Sprint 2; revisões regulares |

---

## 8. Comunicação e Cerimônias

### Daily Standup (15 min)
- O que foi feito ontem
- O que será feito hoje
- Bloqueios

### Sprint Planning (4h início do sprint)
- Review das tarefas
- Estimativas refinadas
- Compromisso do time

### Sprint Review (2h fim do sprint)
- Demo dos entregáveis
- Validação com stakeholders

### Sprint Retrospective (1.5h fim do sprint)
- O que funcionou
- O que melhorar
- Ações para próximo sprint

### Refinamento Técnico (2h meio do sprint)
- Revisão de arquitetura
- Decisões técnicas pendentes
- Dívidas técnicas

---

## 9. Métricas de Progresso

### Por Sprint
- Story points completados
- Cobertura de testes (meta: > 80%)
- Bugs encontrados/resolvidos
- Dívidas técnicas criadas/pagas

### Projeto Geral
- % funcionalidades completas
- Conformidade FAPI-BR (checklist)
- Performance (p99 latência)
- Disponibilidade (uptime)

---

## 10. Próximos Passos

1. **Kickoff do projeto** (todos os engenheiros)
2. **Setup de ferramentas** (Jira/GitHub Projects, Slack, repositório)
3. **Refinamento Sprint 1** (quebrar tarefas em subtarefas)
4. **Início do desenvolvimento** 🚀

---

**Autor**: Roberto Vinicius Kuo  
**Data**: 8 de novembro de 2025  
**Versão**: 1.0
