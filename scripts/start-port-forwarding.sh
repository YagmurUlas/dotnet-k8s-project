#!/bin/bash

# Nexus ve Jenkins için port forwarding başlatma scripti

echo "Port forwarding başlatılıyor..."

# Önceki port forwarding'leri durdur
pkill -f "kubectl port-forward"

# Nexus port forwarding
kubectl port-forward svc/nexus 30081:8081 > /dev/null 2>&1 &
NEXUS_PID=$!

# Jenkins port forwarding
kubectl port-forward svc/jenkins 30080:8080 > /dev/null 2>&1 &
JENKINS_PID=$!

sleep 2

# Kontrol et
if ps -p $NEXUS_PID > /dev/null && ps -p $JENKINS_PID > /dev/null; then
    echo "✓ Port forwarding başarıyla başlatıldı!"
    echo ""
    echo "Nexus:  http://localhost:30081"
    echo "Jenkins: http://localhost:30080"
    echo ""
    echo "Port forwarding'i durdurmak için: ./scripts/stop-port-forwarding.sh"
    echo "Veya: pkill -f 'kubectl port-forward'"
else
    echo "✗ Port forwarding başlatılamadı"
    exit 1
fi

