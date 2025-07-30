# Variáveis
IMAGE_NAME=eduardods/api-comments
CLUSTER_NAME=api-comments-aks
RESOURCE_GROUP=rg-api-comments
TERRAFORM_DIR=./terraform
HELM_CHART=./helm/api-comments
HELM_RELEASE=api-comments
OBS_NAMESPACE=monitoring

AZURE_CREDENTIALS_FILE := ../azure-credential.json

# Lê dados do arquivo e exporta como variáveis
AZURE_CLIENT_ID     := $(shell jq -r .clientId $(AZURE_CREDENTIALS_FILE))
AZURE_CLIENT_SECRET := $(shell jq -r .clientSecret $(AZURE_CREDENTIALS_FILE))
AZURE_TENANT_ID     := $(shell jq -r .tenantId $(AZURE_CREDENTIALS_FILE))
AZURE_SUBSCRIPTION  := $(shell jq -r .subscriptionId $(AZURE_CREDENTIALS_FILE))

.PHONY: all build push terraform-init terraform-plan terraform-apply cluster-connect install-ingress wait-ingress install-monitoring install-logs install-app destroy destroy-monitoring

# Execução completa encadeada
all:
	$(MAKE) build
	$(MAKE) push
	$(MAKE) terraform-init
	$(MAKE) terraform-plan
	$(MAKE) terraform-apply
	$(MAKE) cluster-connect
	$(MAKE) install-ingress
	$(MAKE) wait-ingress
	$(MAKE) install-monitoring
	$(MAKE) install-logs
	$(MAKE) install-app

# Etapa 1 - Build e Push da imagem Docker
build:
	docker build --platform linux/amd64 -t $(IMAGE_NAME):latest -f ./api/Dockerfile.prod --push ./api

push: 
	@echo "✅ Imagem Docker buildada e enviada."

# Etapa 2 - Terraform
terraform-init: 
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan: 
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

terraform-apply: 
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

# Etapa 3 - Conexão ao cluster AKS (com verificação)
cluster-connect: 
	@az login --service-principal \
	  --username "$(AZURE_CLIENT_ID)" \
	  --password "$(AZURE_CLIENT_SECRET)" \
	  --tenant "$(AZURE_TENANT_ID)"
	@az account set --subscription "$(AZURE_SUBSCRIPTION)"
	@if az aks show --resource-group $(RESOURCE_GROUP) --name $(CLUSTER_NAME) > /dev/null 2>&1; then \
		echo "🔗 Conectando ao AKS..."; \
		az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(CLUSTER_NAME) --overwrite-existing; \
		kubectl get nodes; \
	else \
		echo "❌ Cluster AKS '$(CLUSTER_NAME)' não encontrado no resource group '$(RESOURCE_GROUP)'."; \
		exit 1; \
	fi

# Etapa 4 - Ingress NGINX
install-ingress: 
	@helm repo add ingress-nginx https://kubernetes.github.io/helm-charts || true
	@helm repo update
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx \
		--create-namespace \
		--version 4.6.0 \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"="/healthz"

wait-ingress: 
	@echo "⏳ Aguardando o Ingress Controller ficar pronto..."
	kubectl wait --namespace ingress-nginx \
	  --for=condition=ready pod \
	  --selector=app.kubernetes.io/component=controller \
	  --timeout=120s

# Etapa 5 - Monitoramento (Prometheus + Grafana)
install-monitoring: 
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	@helm repo update
	@helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
		--namespace $(OBS_NAMESPACE) \
		--create-namespace \
		--values ./monitoring/monitoring-values.yaml
		--wait
	@echo "✅ Stack Prometheus/Grafana/Alertmanager instalada."

# Etapa 6 - Logs (Loki + Promtail)
install-logs: 
	@helm repo add grafana https://grafana.github.io/helm-charts || true
	@helm repo update
	@helm upgrade --install loki grafana/loki-stack \
		--namespace $(OBS_NAMESPACE) \
		--values ./monitoring/loki-values.yaml
		--wait
	@echo "✅ Stack Loki/Promtail instalada."

# Etapa 7 - Aplicação
install-app: 
	@helm upgrade --install $(HELM_RELEASE) $(HELM_CHART) \
		--namespace apis \
		--create-namespace 
	@echo "✅ Aplicação instalada com sucesso."

# Etapa final - destruir tudo
#destroy:
# 	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
