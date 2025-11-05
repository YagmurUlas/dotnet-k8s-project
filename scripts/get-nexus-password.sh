#!/bin/bash

# Nexus admin şifresini almak için script

POD_NAME=$(kubectl get pod -l app=nexus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "Nexus pod'u bulunamadı. Lütfen pod'un çalıştığından emin olun."
    exit 1
fi

echo "Nexus admin şifresini kontrol ediyorum..."

# Önce admin.password dosyasını kontrol et
PASSWORD=$(kubectl exec $POD_NAME -- cat /nexus-data/admin.password 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    # Dosya yoksa, log dosyalarında ara
    PASSWORD=$(kubectl logs $POD_NAME 2>/dev/null | grep -i "admin.password" | head -1 | awk '{print $NF}')
    
    if [ -z "$PASSWORD" ]; then
        echo ""
        echo "⚠️  admin.password dosyası bulunamadı."
        echo ""
        echo "Bu durumda Nexus varsayılan şifre kullanıyor olabilir:"
        echo "  Kullanıcı adı: admin"
        echo "  Şifre: admin123"
        echo ""
        echo "Ya da Nexus UI'ya ilk girişte şifre değiştirme ekranı çıkacaktır."
        echo ""
        echo "Nexus'a erişim:"
        echo "  http://localhost:30081"
        exit 0
    fi
fi

echo "$PASSWORD"

