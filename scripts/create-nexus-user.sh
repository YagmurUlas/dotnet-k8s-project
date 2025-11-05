#!/bin/bash

# Nexus kullanıcısı oluşturma scripti (API ile)

set -e

echo "Nexus kullanıcısı oluşturuluyor..."
echo ""

read -p "Nexus admin kullanıcı adı [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -sp "Nexus admin şifresi [admin123]: " ADMIN_PASS
ADMIN_PASS=${ADMIN_PASS:-admin123}
echo ""

read -p "Oluşturulacak kullanıcı ID [jenkins-user]: " USER_ID
USER_ID=${USER_ID:-jenkins-user}

read -p "Kullanıcı adı [Jenkins User]: " FIRST_NAME
FIRST_NAME=${FIRST_NAME:-Jenkins}

read -p "Kullanıcı soyadı [User]: " LAST_NAME
LAST_NAME=${LAST_NAME:-User}

read -p "Email [jenkins@example.com]: " EMAIL
EMAIL=${EMAIL:-jenkins@example.com}

read -sp "Kullanıcı şifresi: " USER_PASS
echo ""

NEXUS_URL="http://localhost:30081"

# Nexus API ile kullanıcı oluştur
echo ""
echo "Kullanıcı oluşturuluyor..."

curl -X POST "${NEXUS_URL}/service/rest/v1/security/users" \
  -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"${USER_ID}\",
    \"firstName\": \"${FIRST_NAME}\",
    \"lastName\": \"${LAST_NAME}\",
    \"emailAddress\": \"${EMAIL}\",
    \"password\": \"${USER_PASS}\",
    \"status\": \"active\",
    \"roles\": [
      \"nx-repository-view-docker-docker-registry-read\",
      \"nx-repository-view-docker-docker-registry-write\"
    ]
  }" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Kullanıcı başarıyla oluşturuldu: ${USER_ID}"
    echo ""
    echo "Kullanıcı bilgileri:"
    echo "  ID: ${USER_ID}"
    echo "  Email: ${EMAIL}"
    echo "  Şifre: [girdiğiniz şifre]"
    echo ""
    echo "Bu bilgileri Jenkins credentials için kullanabilirsiniz."
else
    echo ""
    echo "✗ Kullanıcı oluşturulurken hata oluştu"
    echo "Lütfen Nexus'a admin olarak giriş yaptığınızdan emin olun."
    exit 1
fi

