#!/bin/bash

set -e

echo "========================================="
echo "Kubernetes DevOps Kurulum Scripti"
echo "========================================="

# Renkli çıktı için
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Kubernetes cluster kontrolü
echo -e "${YELLOW}Kubernetes cluster kontrolü yapılıyor...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo "Hata: Kubernetes cluster'a bağlanılamıyor!"
    echo "Lütfen önce bir Kubernetes cluster kurun (kind, minikube, veya cloud provider)"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster bağlantısı başarılı${NC}"

# Helm kontrolü
echo -e "${YELLOW}Helm kontrolü yapılıyor...${NC}"
if ! command -v helm &> /dev/null; then
    echo "Helm bulunamadı. Kurulum yapılıyor..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
echo -e "${GREEN}✓ Helm hazır${NC}"

# Ingress controller kurulumu (NGINX)
echo -e "${YELLOW}NGINX Ingress Controller kuruluyor...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
echo -e "${GREEN}✓ Ingress Controller kuruldu (yaklaşık 1-2 dakika sürebilir)${NC}"

# Nexus kurulumu
echo -e "${YELLOW}Nexus Repository Manager kuruluyor...${NC}"
kubectl apply -f k8s/nexus/pvc.yaml
kubectl apply -f k8s/nexus/deployment.yaml
kubectl apply -f k8s/nexus/service.yaml
kubectl apply -f k8s/nexus/ingress.yaml
echo -e "${GREEN}✓ Nexus kuruldu${NC}"

# Jenkins kurulumu
echo -e "${YELLOW}Jenkins kuruluyor...${NC}"
kubectl apply -f k8s/jenkins/pvc.yaml
kubectl apply -f k8s/jenkins/serviceaccount.yaml
kubectl apply -f k8s/jenkins/deployment.yaml
kubectl apply -f k8s/jenkins/service.yaml
kubectl apply -f k8s/jenkins/ingress.yaml
echo -e "${GREEN}✓ Jenkins kuruldu${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Kurulum tamamlandı!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Servislerin hazır olması için birkaç dakika bekleyin..."
echo ""
echo "Nexus erişim bilgileri:"
echo "  URL: http://nexus.local (veya NodePort: http://localhost:30081)"
echo "  Varsayılan kullanıcı adı: admin"
echo "  İlk şifre: kubectl exec -it \$(kubectl get pod -l app=nexus -o jsonpath='{.items[0].metadata.name}') -- cat /nexus-data/admin.password"
echo ""
echo "Jenkins erişim bilgileri:"
echo "  URL: http://jenkins.local (veya NodePort: http://localhost:30080)"
echo "  İlk şifre: kubectl exec -it \$(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "Pod durumunu kontrol etmek için:"
echo "  kubectl get pods"
echo ""
echo "Servis durumunu kontrol etmek için:"
echo "  kubectl get svc"
echo ""

