#!/bin/bash

# Nexus Docker Registry için Kubernetes secret oluşturma scripti

set -e

echo "Nexus Docker Registry Secret Oluşturuluyor..."

read -p "Nexus kullanıcı adı: " NEXUS_USER
read -sp "Nexus şifresi: " NEXUS_PASS
echo ""

# Docker registry secret oluştur
kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-docker-registry.default.svc.cluster.local:5000 \
  --docker-username=$NEXUS_USER \
  --docker-password=$NEXUS_PASS \
  --docker-email=admin@example.com \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret oluşturuldu: nexus-registry-secret"
echo "Bu secret'ı deployment'larda imagePullSecrets olarak kullanabilirsiniz."

