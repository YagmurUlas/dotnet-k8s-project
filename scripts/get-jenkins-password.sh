#!/bin/bash

# Jenkins admin şifresini almak için script

POD_NAME=$(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "Jenkins pod'u bulunamadı. Lütfen pod'un çalıştığından emin olun."
    exit 1
fi

echo "Jenkins admin şifresini kontrol ediyorum..."

# initialAdminPassword dosyasını kontrol et
PASSWORD=$(kubectl exec $POD_NAME -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    echo ""
    echo "⚠️  initialAdminPassword dosyası bulunamadı."
    echo ""
    echo "Jenkins setup wizard kapalı olarak yapılandırılmış. Bu durumda:"
    echo "  - Jenkins varsayılan olarak admin/admin kullanıcısı ile çalışıyor olabilir"
    echo "  - Ya da şifre gerektirmiyor olabilir"
    echo ""
    echo "Jenkins'e erişim:"
    echo "  http://localhost:30080"
    echo ""
    echo "Eğer şifre gerekiyorsa, Jenkins UI'da 'Configure Jenkins' seçeneğinden şifre belirleyebilirsiniz."
    exit 0
fi

echo "$PASSWORD"

