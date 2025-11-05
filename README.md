# Kubernetes DevOps Projesi

Bu proje, .NET Core uygulamasını Kubernetes cluster'a otomatik olarak deploy etmek için gerekli tüm yapılandırmaları içerir.

## Proje Yapısı

```
dotnet-webapp-k8s-project/
├── dotnet-core-hello-world-web-app/    # .NET Core uygulaması
│   ├── Dockerfile                      # Docker imajı tanımı
│   ├── Jenkinsfile                     # Jenkins CI/CD pipeline
│   └── helm/                           # Helm chart
│       └── webapp/
├── k8s/                                # Kubernetes deployment dosyaları
│   ├── nexus/                          # Nexus Repository Manager
│   └── jenkins/                        # Jenkins
└── setup.sh                            # Kurulum scripti
```

## Gereksinimler

- Kubernetes cluster (kind, minikube, veya cloud provider)
- kubectl yüklü ve yapılandırılmış
- Helm 3.x yüklü
- Docker (opsiyonel, lokal test için)

## Kurulum

### 1. Kubernetes Cluster Kurulumu

#### Seçenek A: Kind (Kolay - Önerilen)

```bash
# Kind kurulumu (macOS)
brew install kind

# Cluster oluştur
kind create cluster --name devops-cluster

# Cluster'ı kontrol et
kubectl cluster-info --context kind-devops-cluster
```

#### Seçenek B: Minikube

```bash
# Minikube kurulumu
brew install minikube  # macOS
# veya
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/

# Cluster başlat
minikube start

# Cluster'ı kontrol et
kubectl cluster-info
```

#### Seçenek C: Cloud Provider (EKS, AKS, GKE)

Cloud provider'ınızın dokümantasyonuna göre cluster oluşturun ve `kubectl` ile bağlanın.

### 2. DevOps Araçlarının Kurulumu

Kurulum scriptini çalıştırın:

```bash
chmod +x setup.sh
./setup.sh
```

Script şunları yapacak:
- NGINX Ingress Controller kurulumu
- Nexus Repository Manager kurulumu
- Jenkins kurulumu

### 3. Nexus Yapılandırması

#### Nexus'a Erişim

```bash
# Nexus pod'unun hazır olmasını bekleyin
kubectl wait --for=condition=ready pod -l app=nexus --timeout=300s

# İlk admin şifresini alın
kubectl exec -it $(kubectl get pod -l app=nexus -o jsonpath='{.items[0].metadata.name}') -- cat /nexus-data/admin.password
```

Nexus'a erişim:
- **NodePort**: `http://localhost:30081`
- **Ingress**: `http://nexus.local` (hosts dosyasına eklemek gerekebilir)

#### Nexus Docker Registry Yapılandırması

1. Nexus'a admin kullanıcısı ile giriş yapın
2. **Settings** > **Repositories** > **Create repository** 
3. **docker (hosted)** seçin
4. Ayarlar:
   - **Name**: `docker-registry`
   - **HTTP**: Port `5000` (zaten ayarlanmış)
   - **Allow anonymous docker pull**: `true` (geliştirme için)
   - **Allow anonymous docker push**: `false`
5. **Create repository** butonuna tıklayın

#### Nexus Kullanıcı Oluşturma

1. **Settings** > **Users** > **Create local user**
2. Kullanıcı bilgilerini girin (örn: `jenkins-user`)
3. **nx-repository-view-docker-docker-registry-read** ve **nx-repository-view-docker-docker-registry-write** rollerini verin
4. Bu kullanıcı bilgilerini Jenkins'te credentials olarak kaydedin

### 4. Jenkins Yapılandırması

#### Jenkins'e Erişim

```bash
# Jenkins pod'unun hazır olmasını bekleyin
kubectl wait --for=condition=ready pod -l app=jenkins --timeout=300s

# İlk admin şifresini alın
kubectl exec -it $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

Jenkins'e erişim:
- **NodePort**: `http://localhost:30080`
- **Ingress**: `http://jenkins.local`

#### Jenkins Plugin Kurulumu

1. Jenkins'e giriş yapın
2. **Manage Jenkins** > **Manage Plugins**
3. Şu pluginleri kurun:
   - **Git Plugin** (genellikle zaten yüklü)
   - **Docker Pipeline** 
   - **Kubernetes Plugin**
   - **Helm Plugin**

#### Jenkins Credentials Yapılandırması

1. **Manage Jenkins** > **Credentials** > **System** > **Global credentials**
2. **Add Credentials** tıklayın
3. **Kind**: `Username with password`
4. **ID**: `nexus-username`
5. **Username**: Nexus kullanıcı adı
6. **Password**: Nexus şifresi
7. **Save**

Aynı şekilde `nexus-password` için de bir credential oluşturun (veya tek bir credential kullanın).

#### Jenkins Pipeline Oluşturma

1. **New Item** > **Pipeline** seçin
2. **Item name**: `dotnet-webapp-pipeline`
3. **Pipeline** bölümünde:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: Repository URL'iniz
   - **Credentials**: Gerekirse ekleyin
   - **Branches to build**: `*/master` veya `*/main`
   - **Script Path**: `dotnet-core-hello-world-web-app/Jenkinsfile`
4. **Save**

#### Jenkins'te Docker ve Helm Kurulumu

Jenkins pod'una bağlanıp gerekli araçları kurun:

```bash
# Jenkins pod'una bağlan
kubectl exec -it $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- bash

# Docker kurulumu (Debian/Ubuntu tabanlı)
apt-get update
apt-get install -y docker.io
systemctl start docker

# Helm kurulumu
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl zaten kurulu olmalı (kubeconfig mount edilmiş)
```

Alternatif olarak, Jenkins deployment'ını güncelleyerek Docker ve Helm'i container image'ına dahil edebilirsiniz.

### 5. Pipeline'ı Çalıştırma

1. Jenkins'te pipeline'ı seçin
2. **Build Now** tıklayın
3. Pipeline şunları yapacak:
   - Unit testleri çalıştırır
   - Docker imajı oluşturur
   - Imajı Nexus'a push eder
   - Helm ile Kubernetes'e deploy eder

### 6. Uygulamayı Test Etme

```bash
# Deployment durumunu kontrol et
kubectl get deployments

# Pod durumunu kontrol et
kubectl get pods -l app.kubernetes.io/name=dotnet-webapp

# Service durumunu kontrol et
kubectl get svc -l app.kubernetes.io/name=dotnet-webapp

# Uygulamaya erişim
kubectl port-forward svc/dotnet-webapp 8080:80
# Tarayıcıda: http://localhost:8080
```

## Otomatik Deploy

Master branch'e push/merge yapıldığında pipeline otomatik olarak çalışacaktır. Jenkins'te webhook yapılandırması yapmanız gerekebilir:

1. **Manage Jenkins** > **Configure System**
2. **GitHub** veya **GitLab** plugin yapılandırması
3. Repository ayarlarında webhook URL'i ekleyin

## Troubleshooting

### Nexus Pod'u başlamıyor

```bash
# Logları kontrol et
kubectl logs -l app=nexus

# PVC'yi kontrol et
kubectl get pvc
```

### Jenkins Pod'u başlamıyor

```bash
# Logları kontrol et
kubectl logs -l app=jenkins

# PVC'yi kontrol et
kubectl get pvc
```

### Docker push hatası

- Nexus Docker registry'nin port 5000'de çalıştığını kontrol edin
- Nexus kullanıcı bilgilerinin doğru olduğunu kontrol edin
- Jenkins'te Docker'in kurulu olduğunu kontrol edin

### Helm deploy hatası

- Helm'in Jenkins container'ında kurulu olduğunu kontrol edin
- kubectl'in çalıştığını kontrol edin: `kubectl get nodes`
- Helm chart'ın doğru path'te olduğunu kontrol edin

## Temizleme

Tüm kaynakları silmek için:

```bash
# Helm release'i sil
helm uninstall dotnet-webapp

# Jenkins'i sil
kubectl delete -f k8s/jenkins/

# Nexus'u sil
kubectl delete -f k8s/nexus/

# Ingress controller'ı sil
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Katkıda Bulunma

Bu proje bir değerlendirme projesidir. İyileştirme önerileri için issue açabilirsiniz.

## Lisans

Bu proje eğitim amaçlıdır.

