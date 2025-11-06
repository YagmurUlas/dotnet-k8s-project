#!/bin/bash

# Nexus Docker Registry Connector Yapılandırması

set -e

echo "Nexus Docker Registry Connector yapılandırılıyor..."

read -p "Nexus admin kullanıcı adı [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -sp "Nexus admin şifresi [admin123]: " ADMIN_PASS
ADMIN_PASS=${ADMIN_PASS:-admin123}
echo ""

NEXUS_URL="http://localhost:30081"

# Mevcut repository bilgilerini al
echo ""
echo "Mevcut Docker registry bilgileri alınıyor..."
REPO_INFO=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" "${NEXUS_URL}/service/rest/v1/repositories/docker-registry")

if [ -z "$REPO_INFO" ] || [ "$REPO_INFO" = "null" ]; then
    echo "Hata: Docker registry bulunamadı!"
    echo "Lütfen önce Nexus UI'dan Docker registry oluşturun."
    exit 1
fi

echo "Docker registry bulundu."

# Connector eklemek için repository'yi güncelle
echo ""
echo "Connector yapılandırması için Nexus UI kullanmanız gerekiyor:"
echo "1. Nexus UI'ya gidin: ${NEXUS_URL}"
echo "2. Settings → Repositories → docker-registry → Edit"
echo "3. Connectors bölümünde:"
echo "   - HTTP Connector ekleyin"
echo "   - Port: 5000"
echo "   - Save Repository"
echo ""
echo "Veya API ile yapılandırmak için repository detaylarını görebilirsiniz:"
echo ""
curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" "${NEXUS_URL}/service/rest/v1/repositories/docker-registry" | python3 -m json.tool 2>/dev/null || echo "$REPO_INFO"

