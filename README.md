# Repositorio Globo
git clone git@github.com:SelecaoGlobocom/eduardo_dornelles.git
az ad sp create-for-rbac --name "gh-terraform-api-comments" \
  --role="Contributor" \
  --scopes="/subscriptions/dae6c8b4-a025-4ed1-85c4-9aed73f7eb6f" \
  --sdk-auth

# Build da Imagem Docker
  -> Para desenvolvimento local: docker build -f ./api/Dockerfile.local -t api-comments:local ./api
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t eduardods/api-comments:latest -f ./api/Dockerfile.prod --push  ./api
https://hub.docker.com/repository/docker/eduardods/api-comments/general

# Acesso da Aplicação para testes
http://localhost:3000/docs

# Criando a storage account para armazenar o tfstate
## 1. Criar resource group
az group create -n terraform-rg -l brazilsouth

## 2. Criar storage account (nome deve ser único globalmente, apenas minúsculas)
# Substitua por algo exclusivo, como:
az storage account create \
  --name tfstateeduardo20250730 \
  --resource-group terraform-rg \
  --location brazilsouth \
  --sku Standard_LRS \
  --access-tier Hot


## 3. Criar container para o estado
az storage container create \
  --name tfstate \
  --account-name tfstateeduardo20250730


# Inicio da Criação do Cluster AKS Free Tier
az login
az account set --subscription "dae6c8b4-a025-4ed1-85c4-9aed73f7eb6f"
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
terraform output ingress_public_ip
az aks get-credentials --resource-group rg-api-comments --name aks-api-comments --overwrite-existing
kubectl get nodes

# Instalando o NGINX no cluster
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

# Instalando a stack de monitoramento
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
		--namespace $(OBS_NAMESPACE) \
		--create-namespace \
		--values ./helm/monitoring-values.yaml \
		--wait

# Etapa 6 - Logs (Loki + Promtail)
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update
helm upgrade --install loki grafana/loki-stack \
		--namespace $(OBS_NAMESPACE) \
		--values ./helm/loki-values.yaml \
		--wait

# Instalando a aplicação
PUBLIC_IP=$(terraform output -raw ingress_public_ip)
helm upgrade --install api-comments ./helm/api-comments --namespace apis --create-namespace --set global.publicIP="$PUBLIC_IP"

# Destruir a estrutura criada na Azure
terraform destroy -auto-approve

# Pipeline local para testar a criação e deploy dos recursos
make build
make terraform-init && make terraform-plan && make terraform-apply
make cluster-connect && make install-ingress && make wait-ingress && make install-app
make install-monitoring && make install-logs

# Incluir IP Publico do Ingress NGINX no hosts local
echo "74.163.120.30 grafana.desafio-globo prometheus.desafio-globo alertmanager.desafio-globo loki.desafio-globo api-comments.desafio-globo" | sudo tee -a /etc/hosts

# Para destruir tudo
make destroy