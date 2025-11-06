# Hızlı Başlangıç Kılavuzu

Bu kılavuz, projeyi en hızlı şekilde çalıştırmak için adım adım talimatlar içerir.

## 1. Kubernetes Cluster Kurulumu (Kind ile)

```bash
# Kind kurulumu (macOS)
brew install kind

# Cluster oluştur (istediğiniz isimle)
kind create cluster --name webapp-k8s-cluster

# Bağlantıyı kontrol et
kubectl cluster-info --context kind-webapp-k8s-cluster
```

**Not:** Cluster adını istediğiniz gibi değiştirebilirsiniz. Örnek: `devops-cluster`, `webapp-k8s-cluster` vb.

## 2. DevOps Araçlarını Kur

```bash
# Kurulum scriptini çalıştır
cd /Users/yagmur/projects/dotnet-webapp-k8s-project
./setup.sh
```

Script şunları yapacak:
- NGINX Ingress Controller kurulumu
- Nexus Repository Manager kurulumu (PVC, Deployment, Service, Ingress)
- Jenkins kurulumu (PVC, ServiceAccount, RBAC, Deployment, Service, Ingress)

**Not:** Ingress dosyalarında deprecated annotation hatası alırsanız, script bunları otomatik olarak düzeltecektir.

### Port Forwarding Başlatma

Kind cluster'da NodePort servisleri direkt çalışmayabilir. Port forwarding için:

```bash
# Port forwarding scriptini çalıştır
./scripts/start-port-forwarding.sh
```

Bu script şunları yapacak:
- Nexus: http://localhost:30081
- Jenkins: http://localhost:30080

Port forwarding'i durdurmak için:
```bash
./scripts/stop-port-forwarding.sh
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

**Not:** Eğer admin.password dosyası bulunamazsa, script varsayılan şifreyi gösterecektir:
- Kullanıcı adı: `admin`
- Şifre: `admin123`

### Nexus'a Giriş Yap

- URL: http://localhost:30081 (port forwarding aktif olmalı)
- Kullanıcı adı: `admin`
- Şifre: `admin123` veya script'ten aldığınız şifre

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

**Seçenek 1: UI'dan (Manuel)**

1. Nexus UI'da sol üstteki **☰** (hamburger menü) ikonuna tıklayın
2. **Administration** → **Security** → **Users** yolunu izleyin
3. **Create user** butonuna tıklayın
4. Bilgiler:
   - **ID**: `jenkins-user`
   - **First name**: `Jenkins`
   - **Last name**: `User`
   - **Email**: `jenkins@example.com`
   - **Password**: Güçlü bir şifre belirleyin
5. **Roles** tabında:
   - `nx-repository-view-docker-docker-registry-read`
   - `nx-repository-view-docker-docker-registry-write`
   - `nx-repository-admin-docker-docker-registry-*` (opsiyonel)
6. **Create user**

**Seçenek 2: API ile (Otomatik - Önerilen)**

```bash
./scripts/create-nexus-user.sh
```

Script sizden gerekli bilgileri isteyecek ve kullanıcıyı otomatik oluşturacak.

**Not:** Test/geliştirme için admin kullanıcısını da kullanabilirsiniz (admin/admin123).

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

- URL: http://localhost:30080 (port forwarding aktif olmalı)
- İlk giriş: Setup wizard kapalı olduğu için direkt giriş yapabilirsiniz veya admin kullanıcısı oluşturmanız gerekebilir

**Not:** Jenkins deployment'ında setup wizard kapalı yapılandırılmıştır. Güvenlik devre dışı olabilir veya varsayılan admin/admin ile çalışıyor olabilir.

### Admin Kullanıcı Oluşturma

1. Jenkins'e giriş yapın (güvenlik devre dışıysa direkt erişebilirsiniz)
2. **Manage Jenkins** → **Configure Global Security**
3. **Enable security** işaretleyin
4. **Security Realm**: "Jenkins' own user database" seçin
5. **Allow users to sign up** işaretleyin (geçici olarak)
6. **Save**
7. Sağ üstte **Sign up** linkine tıklayın
8. Admin kullanıcısı oluşturun

### Gerekli Plugin'leri Kur

1. **Manage Jenkins** > **Manage Plugins** > **Available**
2. Şu plugin'leri arayıp kurun:
   - **Pipeline** (en önemli - Pipeline tipi proje oluşturmak için)
   - **Git Plugin** (genellikle zaten yüklü)
   - Docker Pipeline (opsiyonel)
   - Kubernetes CLI (opsiyonel)
3. **Install without restart**

**Önemli:** Pipeline plugin'i kurulmadan Pipeline tipi proje oluşturamazsınız!

### Docker ve Helm Kurulumu

**Not:** Jenkins deployment'ı otomatik olarak şunları kurar:
- Docker (Docker-in-Docker sidecar ile)
- Helm 3.x
- .NET SDK 6.0 (libicu-dev ile)

Kontrol etmek için:
```bash
# Jenkins pod'unda araçları kontrol et
kubectl exec $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- docker --version
kubectl exec $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- helm version --short
kubectl exec $(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- dotnet --version
```

**Docker DinD Yapılandırması:**
Jenkins deployment'ında Docker-in-Docker (DinD) sidecar container kullanılmaktadır. Bu sayede Jenkins içinde Docker build işlemleri yapılabilir.

### Credentials Ekle (Opsiyonel)

**Not:** Jenkinsfile'da Nexus kullanıcı bilgileri environment variable olarak tanımlanmıştır (admin/admin123). Test için credentials eklemeden kullanabilirsiniz.

Eğer credentials eklemek isterseniz:
1. **Manage Jenkins** → **Credentials** (eğer görünmüyorsa, güvenlik ayarlarını kontrol edin)
2. **System** → **Global credentials (unrestricted)**
3. **Add Credentials**:
   - **Kind**: `Username with password`
   - **ID**: `nexus-username`
   - **Username**: Nexus kullanıcı adı
   - **Password**: Nexus şifresi
   - **Description**: `Nexus Docker Registry Username`

**Alternatif:** Jenkinsfile'da parametreler kullanılabilir (şu an direkt environment variable kullanılıyor).

### Pipeline Oluştur

**Önemli:** Önce Pipeline plugin'inin kurulu olduğundan emin olun!

1. **New Item** tıklayın
2. **Pipeline** seçin (eğer görünmüyorsa, Pipeline plugin'ini kurun)
3. **Item name**: `dotnet-webapp-pipeline`
4. **OK**
5. **Pipeline** bölümünde:
   - **Definition**: `Pipeline script from SCM` seçin
   - **SCM**: `Git` seçin
   - **Repository URL**: Repository URL'iniz (örn: `https://github.com/YagmurUlas/dotnet-k8s-project`)
   - **Credentials**: Public repo ise boş bırakın
   - **Branches to build**: `*/main` veya `*/master`
   - **Script Path**: `dotnet-core-hello-world-web-app/Jenkinsfile` ⚠️ **Önemli:** Repository adını yazmayın, sadece dosya yolunu yazın!
6. **Save**

**Script Path Örnekleri:**
- ✅ Doğru: `dotnet-core-hello-world-web-app/Jenkinsfile`
- ❌ Yanlış: `dotnet-k8s-project/dotnet-core-hello-world-web-app/Jenkinsfile`

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
2. **Stage View** sekmesinden hangi stage'de hata olduğunu görün
3. **Docker build hatası** varsa:
   - Docker DinD sidecar'ın çalıştığını kontrol edin: `kubectl get pods -l app=jenkins`
   - Docker socket'i kontrol edin: `kubectl exec <jenkins-pod> -- ls -la /var/run/`
4. **Helm hatası** varsa: Helm'in kurulu olduğundan emin olun
5. **Nexus push hatası** varsa: Nexus kullanıcı bilgilerini kontrol edin (admin/admin123)
6. **.NET SDK hatası** varsa: `dotnet --version` komutuyla kontrol edin
7. **Pipeline sadece checkout çalışıyorsa**: Script Path'in doğru olduğundan emin olun

### Uygulama çalışmıyor

```bash
# Pod loglarını kontrol et
kubectl logs -l app.kubernetes.io/name=dotnet-webapp

# Pod durumunu kontrol et
kubectl describe pod -l app.kubernetes.io/name=dotnet-webapp
```

## Önemli Notlar

### Image İsimleri

- **Docker Image**: `nexus-docker-registry.default.svc.cluster.local:5000/dotnet-webapp`
- **Helm Release**: `dotnet-webapp`
- **Kubernetes Service**: `dotnet-webapp`
- **Ingress Host**: `dotnet-webapp.local`

### Pipeline Yapılandırması

Jenkinsfile'da şu bilgiler tanımlıdır:
- **Nexus Admin Kullanıcısı**: `admin` / `admin123` (test için)
- **Image Name**: `dotnet-webapp`
- **Helm Chart Path**: `helm/webapp`

### Port Forwarding

Kind cluster kullanıyorsanız, servislere erişim için port forwarding gereklidir:
```bash
# Başlat
./scripts/start-port-forwarding.sh
#Durdur
pkill -f "kubectl port-forward"
```

## Sonraki Adımlar

- Ingress yapılandırması ile dış erişim sağlayın
- Monitoring ve logging ekleyin
- Production için güvenlik ayarlarını yapın (admin kullanıcısı yerine özel kullanıcı)
- CI/CD pipeline'ını genişletin (staging, production ortamları)
- Webhook yapılandırması ile otomatik deploy

