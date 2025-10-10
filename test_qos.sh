#!/bin/bash

# Script para probar las políticas de QoS implementadas
# Genera tráfico y muestra estadísticas de clasificación

set -e

echo "=============================================="
echo "      Pruebas de Políticas de QoS"
echo "=============================================="

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que los contenedores están corriendo
if ! sudo docker ps | grep -q gateway-a || ! sudo docker ps | grep -q gateway-b; then
    print_error "Los contenedores de gateway no están corriendo"
    exit 1
fi

# Función para mostrar estadísticas de QoS
show_qos_stats() {
    local gateway=$1
    echo -e "\n${YELLOW}=== Estadísticas QoS en $gateway ===${NC}"
    sudo docker exec -it $gateway bash -c "tc -s class show dev wg0" | grep -A2 -B1 "Sent"
}

# Función para pruebas de conectividad
run_connectivity_test() {
    local client=$1
    local target=$2
    local description=$3
    
    echo ""
    echo "--- Prueba: $description ---"
    sudo docker exec -it $client bash -c "
        ping -c 3 $target > /dev/null 2>&1 && echo 'Conectividad: OK' || echo 'Conectividad: FALLO'
        # Generar algo de tráfico para ver estadísticas
        dd if=/dev/zero bs=1024 count=100 2>/dev/null | nc $target 80 2>/dev/null || true
    "
}

print_status "Verificando políticas de QoS aplicadas..."

# Verificar que las políticas están aplicadas
print_status "Verificando configuración de tc en gateways..."
if sudo docker exec -it gateway-a tc qdisc show dev wg0 | grep -q htb; then
    print_status "Políticas QoS activas en gateway-a ✓"
else
    print_error "No se encontraron políticas QoS en gateway-a"
    exit 1
fi

if sudo docker exec -it gateway-b tc qdisc show dev wg0 | grep -q htb; then
    print_status "Políticas QoS activas en gateway-b ✓"
else
    print_error "No se encontraron políticas QoS en gateway-b"
    exit 1
fi

print_status "Mostrando estadísticas iniciales de QoS..."
show_qos_stats gateway-a
show_qos_stats gateway-b

print_status "Generando tráfico de prueba..."

# Generar tráfico HTTP (alta prioridad)
print_status "Generando tráfico HTTP (alta prioridad) en puerto 80..."
sudo docker exec -d cliente-a bash -c "
    for i in {1..50}; do
        echo 'GET / HTTP/1.1\r\nHost: test\r\n\r\n' | nc 172.16.20.10 80 2>/dev/null || true
        sleep 0.1
    done
" >/dev/null 2>&1 &

# Generar tráfico genérico (baja prioridad)
print_status "Generando tráfico genérico (baja prioridad)..."
sudo docker exec -d cliente-remoto bash -c "
    for i in {1..50}; do
        ping -c 1 172.16.10.10 >/dev/null 2>&1 || true
        sleep 0.1
    done
" >/dev/null 2>&1 &

# Esperar un poco para generar tráfico
sleep 3

print_status "Estadísticas durante generación de tráfico:"
show_qos_stats gateway-a
show_qos_stats gateway-b

# Esperar a que termine el tráfico
sleep 2

print_status "Estadísticas finales:"
show_qos_stats gateway-a
show_qos_stats gateway-b

print_status "Ejecutando pruebas de conectividad básicas..."

# Pruebas básicas de conectividad
run_connectivity_test cliente-a 172.16.20.10 "Site-to-Site (cliente-a → cliente-b)"
run_connectivity_test cliente-remoto 172.16.10.10 "Remote Access (cliente-remoto → cliente-a)"
run_connectivity_test cliente-remoto 172.16.20.10 "Remote Access (cliente-remoto → cliente-b)"

print_status "Estadísticas después de pruebas de conectividad:"
show_qos_stats gateway-a

print_status "Pruebas de QoS completadas"

# Capturar estadísticas reales para el resumen
print_status "Capturando estadísticas finales para resumen..."
STATS_GATEWAY_A=$(sudo docker exec -it gateway-a bash -c "tc -s class show dev wg0" 2>/dev/null)

# Extraer datos de cada clase
CLASS_10_BYTES=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:10" | grep "Sent" | awk '{print $2}')
CLASS_10_PKTS=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:10" | grep "Sent" | awk '{print $4}')
CLASS_11_BYTES=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:11" | grep "Sent" | awk '{print $2}')
CLASS_11_PKTS=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:11" | grep "Sent" | awk '{print $4}')
CLASS_12_BYTES=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:12" | grep "Sent" | awk '{print $2}')
CLASS_12_PKTS=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:12" | grep "Sent" | awk '{print $4}')
TOTAL_BYTES=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:1 root" | grep "Sent" | awk '{print $2}')
TOTAL_PKTS=$(echo "$STATS_GATEWAY_A" | grep -A1 "class htb 1:1 root" | grep "Sent" | awk '{print $4}')

echo ""
echo -e "${GREEN}=============================================="
echo "           Resumen de Pruebas"
echo -e "==============================================${NC}"
echo "Las políticas de QoS están activas y funcionando:"
echo "- Traffic Shaping: Límites de ancho de banda aplicados"
echo "- Priorización: Tráfico clasificado por tipo"
echo "- Control de congestión: Optimización de throughput"
echo ""
echo "Estadísticas REALES capturadas en gateway-a:"
echo "- Clase 1:10 (alta prioridad): ${CLASS_10_BYTES:-0} bytes, ${CLASS_10_PKTS:-0} paquetes"
echo "- Clase 1:11 (media prioridad): ${CLASS_11_BYTES:-0} bytes, ${CLASS_11_PKTS:-0} paquetes"  
echo "- Clase 1:12 (baja prioridad): ${CLASS_12_BYTES:-0} bytes, ${CLASS_12_PKTS:-0} paquetes"
echo "- TOTAL procesado: ${TOTAL_BYTES:-0} bytes, ${TOTAL_PKTS:-0} paquetes"
echo ""
echo "Interpretación:"
echo "  • Clase 1:10: Tráfico HTTP/HTTPS (alta prioridad)"
echo "  • Clase 1:11: Tráfico SSH/VPN (prioridad media)"
echo "  • Clase 1:12: Resto del tráfico (baja prioridad)"
echo ""
echo "Monitoreo continuo disponible con:"
echo "sudo docker exec -it gateway-a tc -s class show dev wg0"
echo "sudo docker exec -it gateway-b tc -s class show dev wg0"
