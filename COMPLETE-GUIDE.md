# Proje Dokümantasyonu - Tüm Adımlar

Bu dokümantasyon, projenin tüm aşamalarını, komutları, yapılandırmaları ve GUI işlemlerini içerir.

## 📋 İçindekiler

1. [Proje Özeti](#proje-özeti)
2. [Sistem Mimarisi](#sistem-mimarisi)
3. [Kurulum Adımları](#kurulum-adımları)
4. [GUI Yapılandırmaları](#gui-yapılandırmaları)
5. [Pipeline Detayları](#pipeline-detayları)
6. [Yapılandırma Dosyaları](#yapılandırma-dosyaları)
7. [Komutlar ve Scripts](#komutlar-ve-scripts)
8. [Troubleshooting](#troubleshooting)

## 🎯 Proje Özeti

Bu proje, .NET Core uygulamasının Kubernetes cluster'ında CI/CD pipeline ile otomatik deploy edilmesini sağlar.

### Kullanılan Teknolojiler

- **Kubernetes**: Kind cluster
- **CI/CD**: Jenkins
- **Container Registry**: Nexus Repository Manager
- **Package Manager**: Helm 3.x
- **Application**: .NET 6.0
- **Ingress**: Nginx Ingress Controller

## 🏗️ Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer                                │
│                    (Git Push/Commit)                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Git Repository                                │
│              (GitHub/GitLab Repository)                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            │ (Polling: Her 1 dakikada bir)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Jenkins Pipeline                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Checkout (Git'ten kod çekme)                          │  │
│  │ 2. Unit Tests (.NET test çalıştırma)                     │  │
│  │ 3. Build Docker Image (Docker build)                     │  │
│  │ 4. Push to Nexus (Docker image push)                     │  │
│  │ 5. Deploy to Kubernetes (Helm deploy)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────────┐            ┌──────────────────────┐
│   Nexus Repository   │            │   Kubernetes Cluster │
│                      │            │                      │
│  - Docker Registry   │            │  ┌────────────────┐  │
│  - Port: 5000        │            │  │  dotnet-webapp │  │
│  - HTTP (insecure)   │            │  │  Pods (2x)     │  │
└──────────────────────┘            │  └────────────────┘  │
                                    │                      │
                                    │  - Service           │
                                    │  - Ingress           │
                                    │  - Deployment        │
                                    └──────────────────────┘
```

### Bileşenler ve Bağlantılar

1. **Git Repository**: Jenkins tarafından polling ile kontrol edilir (her 1 dakikada bir)
2. **Jenkins**: CI/CD pipeline yönetimi (Docker, Helm, .NET SDK, kubectl ile)
3. **Nexus**: Docker image repository (Port 5000, HTTP insecure)
4. **Kubernetes**: Uygulama deployment (Helm ile)
5. **Port Forwarding**: Uygulamaya erişim için kullanılıyor (http://localhost:8080)

## 🚀 Kurulum Adımları

### Adım 1: Kind Cluster Kurulumu

```bash
# Kind kurulumu (macOS)
brew install kind

# Cluster oluşturma
kind create cluster --name devops-cluster --config kind-config.yaml

# Cluster durumunu kontrol
kubectl cluster-info
kubectl get nodes
```

**Create kind-config.yaml**: `kind-config.yaml`

### Adım 2: Ingress Controller Kurulumu

```bash
# Nginx Ingress Controller kurulumu
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Ingress Controller'ın hazır olmasını bekle
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Adım 3: Nexus Kurulumu

```bash
# PVC oluşturma
kubectl apply -f k8s/nexus/pvc.yaml

# Deployment ve Service
kubectl apply -f k8s/nexus/deployment.yaml
kubectl apply -f k8s/nexus/service.yaml

# Nexus'un hazır olmasını bekle
kubectl wait --for=condition=ready pod -l app=nexus --timeout=300s

# Ingress (Ingress Controller hazır olduktan sonra)
kubectl apply -f k8s/nexus/ingress.yaml
```

### Adım 4: Jenkins Kurulumu

```bash
# PVC oluşturma
kubectl apply -f k8s/jenkins/pvc.yaml

# ServiceAccount ve RBAC
kubectl apply -f k8s/jenkins/serviceaccount.yaml

# Deployment ve Service
kubectl apply -f k8s/jenkins/deployment.yaml
kubectl apply -f k8s/jenkins/service.yaml

# Jenkins'in hazır olmasını bekle
kubectl wait --for=condition=ready pod -l app=jenkins --timeout=300s

# Ingress
kubectl apply -f k8s/jenkins/ingress.yaml
```

### Adım 5: Port Forwarding

```bash
# Port forwarding başlat
./scripts/start-port-forwarding.sh
```

Script aşağıdakileri başlatır:
- Nexus: http://localhost:30081
- Jenkins: http://localhost:30080
- Dotnet Webapp: http://localhost:8080

## 🖥️ GUI Yapılandırmaları

### Nexus Docker Registry Yapılandırması

1. **Nexus UI'ya Erişim**:
   - URL: `http://localhost:30081`
   - Port forwarding: `kubectl port-forward svc/nexus 30081:8081`

2. **İlk Admin Şifresini Al**:
   ```bash
   ./scripts/get-nexus-password.sh
   ```
   Veya:
   ```bash
   kubectl exec -it $(kubectl get pod -l app=nexus -o jsonpath='{.items[0].metadata.name}') -- cat /nexus-data/admin.password
   ```

3. **Docker Registry Oluşturma**:
   - Connect to Nexus Console
    URL: http://localhost:30081/#admin/repository/repositories
   - Settings -> Repositories -> Create Repository
Select Recipe -> docker(hosted) -> Name: docker-registry -> Other connectors-> HTTP: 5000 -> Create repository

### Jenkins Yapılandırması

1. **Jenkins UI'ya Erişim**:
   - URL: `http://localhost:30080`
   - Port forwarding: `kubectl port-forward svc/jenkins 30080:8080`

2. **Admin Kullanıcı Oluşturma**:
   - **Manage Jenkins** menüsüne tıklayın (sol menü)
   - **Security** seçeneğine tıklayın
   - **Security Realm** bölümünde **Jenkins' own user database** seçeneğini seçin
   - **Allow users to sign up** seçeneğini işaretle
   - **Save** 
   - Sağ üstte **Sign up** linkine tıklayın
   - Admin kullanıcısı oluşturun:
     - **Username**: `admin`
     - **Password**: 
     - **Full name**: `Admin User`
     - **E-mail address**: `admin@example.com`
   - **Sign up** butonuna tıklayın
   - **Manage Jenkins** → **Configure Global Security** → **Allow users to sign up** seçeneğini kaldırın
   - **Save**

3. **Plugin Kurulumu**:
   - **Manage Jenkins** → **Manage Plugins** → **Available** sekmesi
   - Aşağıdaki plugin'leri arayıp kurun:
     - **Git Plugin**: Git repository'lerden kod çekmek için
     - **Pipeline Plugin**: Pipeline tanımları için (genellikle zaten yüklü)
     - **Docker Pipeline Plugin**: Docker build ve push işlemleri için
   - Plugin'leri seçip **Install without restart** veya **Download now and install after restart** seçeneğini seçin

4. **Pipeline Oluşturma**:
   - Ana sayfada **New Item** 
   - **Item name** alanına pipeline ismini yazın - ex:`dotnet-webapp-pipeline-v2`
   - **Pipeline** seçeneğini seçin
   - **OK** butonuna tıklayın
   - **Pipeline** bölümüne gidin
   - **Definition** dropdown'ından **Pipeline script from SCM**
   - **SCM** -> **Git**
   - **Repository URL** alanına Git repository URL'inizi yazın
   - **Credentials** alanını boş bırakın (public repo için)
   - **Branches to build** alanına `*/main` veya `*/master` hangisini kullanıyorsanız 
   - **Script Path** alanına `dotnet-core-hello-world-web-app/Jenkinsfile` yazın (bu projedeki script pathi)
   - **Save** butonuna tıklayın

5. **Pipeline Çalıştırma**:
   - Pipeline sayfasında **Build Now** butonuna tıklayın
   - **Build History** bölümünde çalışan build'i tıklayın
   - **Console Output** sekmesinden ilerlemeyi takip edin

## 🔄 Pipeline Detayları

### Jenkinsfile

**Dosya**: `dotnet-core-hello-world-web-app/Jenkinsfile`

**Trigger**: Polling (her 1 dakikada bir repository kontrol eder)

**Stages**:
1. **Checkout**: Git repository'den kod çekilir
2. **Unit Tests**: .NET testleri çalıştırılır
3. **Build Docker Image**: Docker image oluşturulur
4. **Push to Nexus**: Image Nexus'a push edilir
5. **Deploy to Kubernetes**: Helm ile Kubernetes'e deploy edilir

**Environment Variables**: Detaylar için `dotnet-core-hello-world-web-app/Jenkinsfile` dosyasına bakın.

### Pipeline Akışı

```
1. Developer → Git Push
   ↓
2. Jenkins (Polling) → Git Repository'den kod çeker
   ↓
3. Jenkins → Unit Tests çalıştırır
   ↓
4. Jenkins → Docker Image build eder
   ↓
5. Jenkins → Docker Image'ı Nexus'a push eder
   ↓
6. Jenkins → Helm ile Kubernetes'e deploy eder
   ↓
7. Kubernetes → Nexus'tan Docker Image çeker
   ↓
8. Kubernetes → Pod'ları başlatır
   ↓
9. User → Port forwarding ile uygulamaya erişir (http://localhost:8080)
```

## 📝 Yapılandırma Dosyaları

### Uygulama Dosyaları

- `dotnet-core-hello-world-web-app/Dockerfile`: Docker image tanımı
- `dotnet-core-hello-world-web-app/Jenkinsfile`: CI/CD pipeline tanımı
- `dotnet-core-hello-world-web-app/Program.cs`: .NET Core uygulama kodu
- `dotnet-core-hello-world-web-app/HelloWorld.csproj`: .NET proje dosyası

### Jenkinsfile

**Dosya**: `dotnet-core-hello-world-web-app/Jenkinsfile`

**Özellikler**:
- Polling trigger: Her 1 dakikada bir
- Docker build: DinD sidecar kullanır
- Nexus push: Insecure registry ile
- Helm deploy: ClusterIP dinamik olarak alınır

### Helm Chart

**Chart Yolu**: `dotnet-core-hello-world-web-app/helm/webapp/`

**Configuration dosyaları**:
- `dotnet-core-hello-world-web-app/helm/webapp/Chart.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/values.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/templates/deployment.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/templates/service.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/templates/ingress.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/templates/hpa.yaml`
- `dotnet-core-hello-world-web-app/helm/webapp/templates/_helpers.tpl`

**Not**: Pipeline'da ClusterIP dinamik olarak alınır ve override edilir.

### Kubernetes Yapılandırmaları

**Nexus** (`k8s/nexus/`):
- `k8s/nexus/pvc.yaml`: 10Gi persistent volume
- `k8s/nexus/deployment.yaml`: Nexus 3 deployment
- `k8s/nexus/service.yaml`: NodePort (30081, 30500) + ClusterIP
- `k8s/nexus/ingress.yaml`: Nginx ingress

**Jenkins** (`k8s/jenkins/`):
- `k8s/jenkins/pvc.yaml`: Jenkins data persistent volume
- `k8s/jenkins/serviceaccount.yaml`: RBAC permissions
- `k8s/jenkins/deployment.yaml`: Jenkins + DinD sidecar
- `k8s/jenkins/service.yaml`: NodePort (30080, 30498)
- `k8s/jenkins/ingress.yaml`: Nginx ingress

## 🔧 Komutlar ve Scripts

### Script Dosyaları

- `scripts/start-port-forwarding.sh`: Port forwarding başlatma scripti
- `scripts/get-nexus-password.sh`: Nexus admin şifresini alma scripti
- `scripts/get-jenkins-password.sh`: Jenkins admin şifresini alma scripti
- `scripts/configure-nexus-docker-connector.sh`: Nexus Docker registry yapılandırma scripti

### Port Forwarding

```bash
# Başlat
./scripts/start-port-forwarding.sh

# Durdur
pkill -f "kubectl port-forward"
```
### Manuel Port Forwarding

```bash
# Nexus
kubectl port-forward svc/nexus 30081:8081

# Jenkins
kubectl port-forward svc/jenkins 30080:8080

# Dotnet Webapp
kubectl port-forward svc/dotnet-webapp 8080:80
```
### Nexus
- **UI**: http://localhost:30081
- **Docker Registry**: `nexus-docker-registry.default.svc.cluster.local:5000`

### Jenkins
- **UI**: http://localhost:30080
- **Pipeline**: http://localhost:30080/job/dotnet-webapp-pipeline/

### Dotnet Webapp
- **Application**: http://localhost:8080 (port-forwarding ile)
- **Not**: Ingress tanımlı ancak aktif olarak port-forwarding kullanılıyor

### Nexus Yönetimi

```bash
# Admin şifresini al
./scripts/get-nexus-password.sh

# Docker registry yapılandır (API ile)
./scripts/configure-nexus-docker-connector.sh
```

### Jenkins Yönetimi

```bash
# Admin şifresini al
./scripts/get-jenkins-password.sh
```

### Kubernetes Yönetimi

#### Tüm Kaynakları Görüntüleme

```bash
# Tüm pod'ları listele
kubectl get pods --all-namespaces

# Tüm service'leri listele
kubectl get svc --all-namespaces

# Tüm deployment'ları listele
kubectl get deployments --all-namespaces

# Tüm ingress'leri listele
kubectl get ingress --all-namespaces

# Tüm PVC'leri listele
kubectl get pvc --all-namespaces

# Tüm namespace'leri listele
kubectl get namespaces

# Belirli bir namespace'deki tüm kaynakları görüntüle
kubectl get all -n default
```

#### Uygulama Kaynakları

```bash
# Pod durumunu kontrol et
kubectl get pods -l app.kubernetes.io/name=dotnet-webapp

# Pod loglarını görüntüle
kubectl logs -l app.kubernetes.io/name=dotnet-webapp

# Deployment durumunu kontrol et
kubectl get deployment dotnet-webapp

# Service durumunu kontrol et
kubectl get svc dotnet-webapp

# Image pull durumunu kontrol et
kubectl describe pod -l app.kubernetes.io/name=dotnet-webapp | grep -i "pulled\|pulling"
```

#### Nexus ve Jenkins Kaynakları

```bash
# Nexus pod'ları
kubectl get pods -l app=nexus

# Jenkins pod'ları
kubectl get pods -l app=jenkins

# Nexus service'leri
kubectl get svc -l app=nexus

# Jenkins service'leri
kubectl get svc -l app=jenkins
```

## 🐛 Troubleshooting

### Nexus Pod Başlamıyor

```bash
# Pod loglarını kontrol et
kubectl logs -l app=nexus

# Pod durumunu kontrol et
kubectl describe pod -l app=nexus
```

### Jenkins Pod Başlamıyor

```bash
# Pod loglarını kontrol et
kubectl logs -l app=jenkins -c jenkins

# Pod durumunu kontrol et
kubectl describe pod -l app=jenkins
```

### Uygulama Çalışmıyor

```bash
# Pod loglarını kontrol et
kubectl logs -l app.kubernetes.io/name=dotnet-webapp

# Pod durumunu kontrol et
kubectl describe pod -l app.kubernetes.io/name=dotnet-webapp

# Image pull durumunu kontrol et
kubectl describe pod -l app.kubernetes.io/name=dotnet-webapp | grep -i "pulled\|pulling"
```

### Image Pull BackOff

```bash
# Nexus service'inin çalıştığını kontrol et
kubectl get svc nexus-docker-registry

# ClusterIP'yi kontrol et
kubectl get svc nexus-docker-registry -o jsonpath='{.spec.clusterIP}'

# containerd config'ini kontrol et (Kind node içinde)
kubectl get nodes -o name | xargs -I {} docker exec {} cat /etc/containerd/config.toml | grep -A 5 "nexus"
```

## 📊 Önemli Notlar

### Image İsimleri
- **Docker Image**: `nexus-docker-registry.default.svc.cluster.local:5000/dotnet-webapp`
- **Helm Release**: `dotnet-webapp`
- **Kubernetes Service**: `dotnet-webapp`
- **Ingress Host**: `dotnet-webapp.local` (tanımlı ancak aktif kullanılmıyor)

### Port Numaraları
- **Nexus UI**: 30081
- **Jenkins UI**: 30080
- **Dotnet Webapp**: 8080 (port-forward)

### Credentials
- **Nexus Admin**: `admin` / `admin123` (test için)
- **Jenkins Admin**: Oluşturduğunuz kullanıcı

### Polling Trigger
- Jenkinsfile'da `pollSCM('*/1 * * * *')` tanımlı
- Her 1 dakikada bir repository kontrol eder
- Git push yapıldığında en geç 1 dakika içinde pipeline çalışır

### ClusterIP Kullanımı
- Pipeline'da ClusterIP dinamik olarak alınır
- `kubectl get svc nexus-docker-registry -o jsonpath='{.spec.clusterIP}'`
- DNS çözümleme sorunu nedeniyle ClusterIP kullanılıyor


