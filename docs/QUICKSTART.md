# Guia de Início Rápido — DCR Enterprise

> 🚀 **Comece aqui!** Este guia vai te ajudar a iniciar o desenvolvimento do DCR Enterprise em minutos.

---

## 📋 Pré-requisitos

Antes de começar, certifique-se de ter instalado:

- ✅ **Git** (para clonar o repositório)
- ✅ **Docker** e **Docker Compose** (ambiente local)
- ✅ **Java 21+** (JDK — recomendado: Amazon Corretto 21 ou OpenJDK 21)
- ✅ **Gradle** (build tool) ou use o wrapper `./gradlew`
- ✅ **Terraform** 1.6+ (para infraestrutura)
- ✅ **kubectl** e **Helm** (para Kubernetes)
- ✅ **AWS CLI** (configurado com credenciais)
- ✅ **Postman** ou **curl** (para testes de API)

---

## 🎯 Seu Papel no Projeto

Identifique qual engenheiro você é:

### 🔵 Engenheiro Backend (#1)
👉 Vá para [Início Backend](#-backend-engenheiro-1)

### 🟢 Engenheiro Infra/DevOps (#2)
👉 Vá para [Início Infra](#-infradevops-engenheiro-2)

### 🟠 Engenheiro Integração/QA (#3)
👉 Vá para [Início Integração](#-integraçãoqa-engenheiro-3)

---

## 🔵 Backend (Engenheiro #1)

### 1. Clone o Repositório

```bash
git clone https://github.com/viniciusrvk/doc.git dcr-enterprise
cd dcr-enterprise
```

### 2. Revise a Documentação

Leia na ordem:

1. [README Principal](../README.md) — visão geral
2. [Arquitetura](architecture/OVERVIEW.md) — componentes e fluxos
3. [API Spec](backend/API_SPEC.md) — endpoints e validações
4. [Modelo de Dados](backend/DATA_MODEL.md) — DDL Postgres
5. [Plano de Desenvolvimento - Sprints 2-3](DEVELOPMENT_PLAN.md#sprint-2-semanas-3-4-api-e-validação-ssa)

### 3. Setup do Ambiente Local

```bash
# Subir Postgres e Redis via Docker Compose
docker-compose up -d postgres redis

# Verificar se estão rodando
docker ps

# Conectar ao Postgres e criar database
docker exec -it dcr-postgres psql -U postgres -c "CREATE DATABASE dcr_registry;"

# Executar DDL (modelo de dados)
docker exec -i dcr-postgres psql -U postgres -d dcr_registry < docs/backend/schema.sql
```

### 4. Setup do Projeto Java

```bash
# Criar estrutura do projeto Spring Boot
mkdir -p src/main/java/com/dcr/enterprise/{controller,service,repository,model,config,dto,exception}
mkdir -p src/test/java/com/dcr/enterprise/{controller,service,repository}

# Editar build.gradle (adicionar dependências)
# - Spring Boot 3.2+
# - Spring Web
# - Spring Data JPA
# - PostgreSQL Driver
# - Nimbus JOSE+JWT
# - Resilience4j
# - OpenTelemetry
```

**build.gradle** (exemplo):

```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.0'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.dcr'
version = '1.0.0-SNAPSHOT'
sourceCompatibility = '21'

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.postgresql:postgresql'
    implementation 'com.nimbusds:nimbus-jose-jwt:9.37'
    implementation 'io.github.resilience4j:resilience4j-spring-boot3:2.1.0'
    implementation 'io.opentelemetry:opentelemetry-api:1.32.0'
    implementation 'io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter:2.0.0-alpha'
    
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.mockito:mockito-core'
}

test {
    useJUnitPlatform()
}
```

### 5. Implementar Primeira Feature (Sprint 2)

Seguir ordem do [Plano de Desenvolvimento - Sprint 2](DEVELOPMENT_PLAN.md#sprint-2-semanas-3-4-api-e-validação-ssa):

1. Controller `POST /register`
2. Service de validação SSA
3. Repository Postgres
4. Testes unitários

### 6. Executar Testes

```bash
./gradlew test
./gradlew bootRun
```

### 7. Testar com Postman

Importar coleção: `postman/DCR-Enterprise.postman_collection.json`

---

## 🟢 Infra/DevOps (Engenheiro #2)

### 1. Clone o Repositório

```bash
git clone https://github.com/viniciusrvk/doc.git dcr-enterprise
cd dcr-enterprise
```

### 2. Revise a Documentação

1. [README Principal](../README.md)
2. [Arquitetura](architecture/OVERVIEW.md)
3. [Guia Terraform](infrastructure/TERRAFORM_GUIDE.md)
4. [Plano de Desenvolvimento - Sprints 2-4](DEVELOPMENT_PLAN.md#sprint-2-semanas-3-4-api-e-validação-ssa)

### 3. Setup AWS CLI

```bash
# Configurar credenciais AWS
aws configure

# Validar acesso
aws sts get-caller-identity
```

### 4. Setup Terraform Backend (uma vez)

```bash
# Criar bucket para state remoto
aws s3 mb s3://dcr-terraform-state-dev
aws s3api put-bucket-versioning \
  --bucket dcr-terraform-state-dev \
  --versioning-configuration Status=Enabled

# Criar tabela DynamoDB para lock
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 5. Provisionar Ambiente Dev (Sprint 2)

```bash
cd terraform/environments/dev

# Inicializar Terraform
terraform init

# Validar
terraform validate

# Planejar
terraform plan -out=plan.tfplan

# Aplicar (VPC + RDS)
terraform apply plan.tfplan
```

### 6. Setup Kubernetes Local (opcional)

```bash
# Instalar minikube ou kind
brew install minikube  # macOS
# ou
brew install kind

# Iniciar cluster local
minikube start --cpus=4 --memory=8192

# Verificar
kubectl cluster-info
```

### 7. Deploy com Helm (Sprint 3+)

```bash
cd helm/dcr-service

# Criar namespace
kubectl create namespace dcr

# Deploy
helm install dcr-service . \
  --namespace dcr \
  -f values-dev.yaml

# Verificar
kubectl get pods -n dcr
```

---

## 🟠 Integração/QA (Engenheiro #3)

### 1. Clone o Repositório

```bash
git clone https://github.com/viniciusrvk/doc.git dcr-enterprise
cd dcr-enterprise
```

### 2. Revise a Documentação

1. [README Principal](../README.md)
2. [Arquitetura](architecture/OVERVIEW.md)
3. [API Spec](backend/API_SPEC.md)
4. [Plano de Desenvolvimento - Sprint 1+](DEVELOPMENT_PLAN.md#sprint-1-semanas-1-2-fundação)

### 3. Setup Ambiente Completo (Docker Compose)

```bash
# Subir todos os serviços
docker-compose up -d

# Verificar serviços
docker-compose ps

# Logs
docker-compose logs -f keycloak
```

### 4. Configurar Keycloak (Sprint 1)

```bash
# Acessar Keycloak Admin Console
open http://localhost:8080

# Credenciais padrão: admin / admin

# Criar realm "open-finance"
# Habilitar:
# - Client authentication: private_key_jwt
# - PAR required
# - mTLS binding
```

Seguir guia: [Keycloak FAPI Setup](../docs/backend/KEYCLOAK_SETUP.md) *(em breve)*

### 5. Gerar Certificados mTLS (Sprint 1)

```bash
# Executar script
./scripts/generate-mtls-certs.sh

# Verificar certificados gerados
ls -la certs/
```

### 6. Importar Coleção Postman

```bash
# Abrir Postman
# File > Import > postman/DCR-Enterprise.postman_collection.json

# Importar environment
# File > Import > postman/environments/dev.postman_environment.json
```

### 7. Executar Testes

```bash
# Teste manual via Postman
# 1. Selecionar environment "dev"
# 2. Executar request "POST Register - Success"
# 3. Verificar resposta 201

# Testes automatizados (Sprint 3+)
newman run postman/DCR-Enterprise.postman_collection.json \
  -e postman/environments/dev.postman_environment.json
```

---

## 📚 Recursos Úteis

### Documentação

- [Plano de Desenvolvimento Completo](DEVELOPMENT_PLAN.md)
- [Índice de Documentação](INDEX.md)
- [Resumo Executivo](EXECUTIVE_SUMMARY.md)

### Ferramentas

- [Postman](https://www.postman.com/downloads/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [IntelliJ IDEA](https://www.jetbrains.com/idea/)

### Referências Externas

- [RFC 7591 - OAuth 2.0 DCR](https://datatracker.ietf.org/doc/html/rfc7591)
- [RFC 7592 - OAuth 2.0 DCR Management](https://datatracker.ietf.org/doc/html/rfc7592)
- [FAPI-BR Spec](https://openfinancebrasil.atlassian.net/wiki/spaces/OF/overview)
- [Keycloak Docs](https://www.keycloak.org/documentation)

---

## 🆘 Problemas Comuns

### Postgres não conecta

```bash
# Verificar se está rodando
docker ps | grep postgres

# Reiniciar
docker-compose restart postgres

# Verificar logs
docker-compose logs postgres
```

### Keycloak não inicia

```bash
# Aumentar memória do Docker
# Docker Desktop > Settings > Resources > Memory: 4GB+

# Limpar volumes
docker-compose down -v
docker-compose up -d
```

### Build falha

```bash
# Limpar cache do Gradle
./gradlew clean build --refresh-dependencies
```

---

## 📞 Suporte

- **Slack**: `#dcr-development`
- **Email Time**: dcr-team@example.com
- **Documentação**: [docs/INDEX.md](INDEX.md)

---

## ✅ Checklist de Primeiro Dia

### Backend
- [ ] Repositório clonado
- [ ] Docker Compose rodando (Postgres + Redis)
- [ ] Projeto Java buildando
- [ ] Documentação lida (Arquitetura + API Spec)
- [ ] Primeiro teste unitário criado

### Infra
- [ ] Repositório clonado
- [ ] AWS CLI configurado
- [ ] Terraform inicializado
- [ ] Documentação lida (Arquitetura + Terraform Guide)
- [ ] VPC criada no ambiente dev

### Integração
- [ ] Repositório clonado
- [ ] Docker Compose rodando (todos os serviços)
- [ ] Keycloak configurado (realm + client)
- [ ] Certificados mTLS gerados
- [ ] Postman configurado
- [ ] Primeiro request testado

---

🎉 **Pronto para começar!** Qualquer dúvida, consulte o [Plano de Desenvolvimento](DEVELOPMENT_PLAN.md) ou peça ajuda no Slack.

---

**Mantido por**: Time DCR Enterprise  
**Última atualização**: 8 de novembro de 2025
