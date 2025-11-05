# Hızlı Başlangıç Kılavuzu

Bu kılavuz, projeyi en hızlı şekilde çalıştırmak için adım adım talimatlar içerir.

## 1. Kubernetes Cluster Kurulumu (Kind ile)

```bash
# Kind kurulumu (macOS)
brew install kind

# Cluster oluştur
kind create cluster --name devops-cluster

# Bağlantıyı kontrol et
kubectl cluster-info
```

## 2. DevOps Araçlarını Kur

```bash
# Kurulum scriptini çalıştır
./setup.sh
```

## 3. Nexus Yapılandırması

### Nexus Pod'unun Hazır Olmasını Bekle

```bash
kubectl wait --for=condition=ready pod -l app=nexus --timeout=300s
```

### Admin Şifresini Al

```bash
./scripts/get-nexus-password.sh
```

### Nexus'a Giriş Yap

- URL: http://localhost:30081
- Kullanıcı adı: `admin`
- Şifre: Yukarıdaki komuttan aldığınız şifre

### Docker Registry Oluştur

1. **Settings** (⚙️) > **Repositories** > **Create repository**
2. **docker (hosted)** seçin
3. Ayarlar:
   - **Name**: `docker-registry`
   - **HTTP**: Port `5000`
   - **Allow anonymous docker pull**: ✅ (işaretli)
   - **Allow anonymous docker push**: ❌ (işaretsiz)
4. **Create repository**

### Kullanıcı Oluştur

1. **Settings** > **Users** > **Create local user**
2. Bilgiler:
   - **ID**: `jenkins-user`
   - **First name**: `Jenkins`
   - **Last name**: `User`
   - **Email**: `jenkins@example.com`
   - **Password**: Güçlü bir şifre belirleyin
3. **Roles** tabında:
   - `nx-repository-view-docker-docker-registry-read`
   - `nx-repository-view-docker-docker-registry-write`
   - `nx-repository-admin-docker-docker-registry-*`
4. **Create user**

### Registry Secret Oluştur

```bash
./scripts/create-nexus-registry-secret.sh
# Kullanıcı adı ve şifreyi girin
```

## 4. Jenkins Yapılandırması

### Jenkins Pod'unun Hazır Olmasını Bekle

```bash
kubectl wait --for=condition=ready pod -l app=jenkins --timeout=300s
```

### Admin Şifresini Al

```bash
./scripts/get-jenkins-password.sh
```

### Jenkins'e Giriş Yap

- URL: http://localhost:30080
- Şifre: Yukarıdaki komuttan aldığınız şifre

### Gerekli Plugin'leri Kur

1. **Manage Jenkins** > **Manage Plugins** > **Available**
2. Şu plugin'leri arayıp kurun:
   - Docker Pipeline
   - Kubernetes CLI
3. **Install without restart**

### Docker ve Helm Kurulumu

```bash
# Jenkins pod'una bağlan
kubectl exec -it $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- bash

# Pod içinde:
apt-get update
apt-get install -y docker.io curl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
exit
```

### Credentials Ekle

1. **Manage Jenkins** > **Credentials** > **System** > **Global credentials (unrestricted)**
2. **Add Credentials**:
   - **Kind**: `Username with password`
   - **ID**: `nexus-username`
   - **Username**: Nexus kullanıcı adı (örn: `jenkins-user`)
   - **Password**: Nexus şifresi
   - **Description**: `Nexus Docker Registry Username`
3. Tekrar **Add Credentials**:
   - **Kind**: `Username with password`
   - **ID**: `nexus-password`
   - **Username**: Nexus kullanıcı adı
   - **Password**: Nexus şifresi
   - **Description**: `Nexus Docker Registry Password`

### Pipeline Oluştur

1. **New Item** > **Pipeline**
2. **Item name**: `dotnet-webapp-pipeline`
3. **Pipeline** bölümü:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: Repository URL'iniz (örn: `https://github.com/kullanici/repo.git`)
   - **Branches to build**: `*/master` veya `*/main`
   - **Script Path**: `dotnet-core-hello-world-web-app/Jenkinsfile`
4. **Save**

## 5. İlk Deploy

### Pipeline'ı Çalıştır

1. Pipeline'ı seçin
2. **Build Now** tıklayın
3. İlerlemeyi **Console Output**'tan takip edin

### Uygulamayı Test Et

```bash
# Deployment durumunu kontrol et
kubectl get deployments

# Pod'ları kontrol et
kubectl get pods -l app.kubernetes.io/name=dotnet-webapp

# Uygulamaya erişim
kubectl port-forward svc/dotnet-webapp 8080:80
```

Tarayıcıda: http://localhost:8080 → "Hello World!" mesajını görmelisiniz.

## 6. Otomatik Deploy (Webhook)

### GitHub Webhook

1. Repository > **Settings** > **Webhooks** > **Add webhook**
2. **Payload URL**: `http://jenkins-ip:30080/github-webhook/`
3. **Content type**: `application/json`
4. **Events**: `Just the push event`
5. **Active**: ✅
6. **Add webhook**

### GitLab Webhook

1. Repository > **Settings** > **Webhooks**
2. **URL**: `http://jenkins-ip:30080/project/dotnet-webapp-pipeline`
3. **Trigger**: `Push events`
4. **Add webhook**

## Sorun Giderme

### Nexus Pod'u başlamıyor

```bash
kubectl logs -l app=nexus
kubectl describe pod -l app=nexus
```

### Jenkins Pod'u başlamıyor

```bash
kubectl logs -l app=jenkins
kubectl describe pod -l app=jenkins
```

### Pipeline başarısız oluyor

1. Jenkins Console Output'u kontrol edin
2. Docker build hatası varsa: Jenkins pod'unda Docker'in kurulu olduğundan emin olun
3. Helm hatası varsa: Helm'in kurulu olduğundan emin olun
4. Nexus push hatası varsa: Credentials'ları kontrol edin

### Uygulama çalışmıyor

```bash
# Pod loglarını kontrol et
kubectl logs -l app.kubernetes.io/name=dotnet-webapp

# Pod durumunu kontrol et
kubectl describe pod -l app.kubernetes.io/name=dotnet-webapp
```

## Sonraki Adımlar

- Ingress yapılandırması ile dış erişim sağlayın
- Monitoring ve logging ekleyin
- Production için güvenlik ayarlarını yapın
- CI/CD pipeline'ını genişletin (staging, production ortamları)

