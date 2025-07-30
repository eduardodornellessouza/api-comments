# Repositório Globo

## Clonar o repositório

```bash
git clone git@github.com:SelecaoGlobocom/eduardo_dornelles.git
```

## Criar credenciais Azure para o GitHub Actions

```bash
az ad sp create-for-rbac --name "gh-terraform-api-comments" \
  --role="Contributor" \
  --scopes="/subscriptions/dae6c8b4-a025-4ed1-85c4-9aed73f7eb6f" \
  --sdk-auth
```

## Build da imagem Docker

### Para desenvolvimento local

```bash
docker build -f ./api/Dockerfile.local -t api-comments:local ./api
```

### Para build multi-plataforma com push

```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t eduardods/api-comments:latest \
  -f ./api/Dockerfile.prod --push ./api
```

📦 Imagem disponível em:
[https://hub.docker.com/repository/docker/eduardods/api-comments/general](https://hub.docker.com/repository/docker/eduardods/api-comments/general)

---

## Acesso da aplicação local (dev)

```bash
http://localhost:3000/docs
```

---

## Criar Storage Account para armazenar o `terraform.tfstate`

### 1. Criar Resource Group

```bash
az group create -n terraform-rg -l brazilsouth
```

### 2. Criar Storage Account (nome único global)

```bash
az storage account create \
  --name tfstateeduardo20250730 \
  --resource-group terraform-rg \
  --location brazilsouth \
  --sku Standard_LRS \
  --access-tier Hot
```

### 3. Criar container para o estado

```bash
az storage container create \
  --name tfstate \
  --account-name tfstateeduardo20250730
```

---

## Criar infraestrutura AKS via Terraform

```bash
az login
az account set --subscription "dae6c8b4-a025-4ed1-85c4-9aed73f7eb6f"

cd terraform
terraform init
terraform plan
terraform apply -auto-approve

terraform output ingress_public_ip

az aks get-credentials --resource-group rg-api-comments --name aks-api-comments --overwrite-existing
kubectl get nodes
```

---

## Instalar Ingress NGINX

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.6.0 \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"="/healthz"

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

## Instalar stack de monitoramento (Prometheus + Grafana)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values ./helm/monitoring-values.yaml \
  --wait
```

---

## Instalar stack de logs (Loki + Promtail)

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values ./helm/loki-values.yaml \
  --wait
```

---

## Instalar a aplicação

```bash
PUBLIC_IP=$(terraform output -raw ingress_public_ip)

helm upgrade --install api-comments ./helm/api-comments \
  --namespace apis \
  --create-namespace \
  --set global.publicIP="$PUBLIC_IP"
```

---

## Destruir infraestrutura provisionada

```bash
terraform destroy -auto-approve
```

---

## Rodar pipeline local via Makefile

```bash
make build
make terraform-init
make terraform-plan
make terraform-apply
make cluster-connect
make install-ingress
make wait-ingress
make install-monitoring
make install-logs
make install-app
```

---

## Incluir IP público no `/etc/hosts`

```bash
echo "74.163.120.30 grafana.desafio-globo prometheus.desafio-globo alertmanager.desafio-globo loki.desafio-globo api-comments.desafio-globo" | sudo tee -a /etc/hosts
```

---

## Para destruir tudo

```bash
make destroy
```
