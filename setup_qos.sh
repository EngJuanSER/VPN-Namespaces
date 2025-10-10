#!/bin/bash

# Script para implementar políticas de QoS (Quality of Service)
# en la infraestructura VPN WireGuard

set -e

echo "=============================================="
echo "    Implementación de Políticas de QoS"
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
print_status "Verificando contenedores..."
if ! sudo docker ps | grep -q gateway-a || ! sudo docker ps | grep -q gateway-b; then
    print_error "Los contenedores de gateway no están corriendo"
    exit 1
fi

# 1. Traffic Shaping (TC) - Limitación de ancho de banda
print_status "Implementando Traffic Shaping (limitación de ancho de banda)..."

# Aplicar limitación en gateway-a
print_status "Aplicando límites de tráfico en gateway-a..."
sudo docker exec -it gateway-a bash -c "
    # Instalar dependencias si no existen
    apt-get update -qq && apt-get install -y iproute2

    # Eliminar configuraciones previas
    tc qdisc del dev wg0 root 2>/dev/null || true
    
    # Crear disciplina de cola HTB en wg0
    tc qdisc add dev wg0 root handle 1: htb default 12
    
    # Clase raíz: 10Mbit total para la interfaz
    tc class add dev wg0 parent 1: classid 1:1 htb rate 10mbit ceil 10mbit
    
    # Subclase para tráfico multimedia (alta prioridad): 5Mbit
    tc class add dev wg0 parent 1:1 classid 1:10 htb rate 5mbit ceil 8mbit prio 1
    
    # Subclase para tráfico general: 3Mbit
    tc class add dev wg0 parent 1:1 classid 1:11 htb rate 3mbit ceil 6mbit prio 2
    
    # Subclase para el resto del tráfico: 2Mbit
    tc class add dev wg0 parent 1:1 classid 1:12 htb rate 2mbit ceil 4mbit prio 3
    
    # Filtros para clasificar el tráfico
    # Tráfico multimedia (puertos 80, 443)
    tc filter add dev wg0 protocol ip parent 1: prio 1 u32 match ip dport 80 0xffff flowid 1:10
    tc filter add dev wg0 protocol ip parent 1: prio 1 u32 match ip dport 443 0xffff flowid 1:10
    
    # Tráfico SSH y VPN (puertos 22, 51820)
    tc filter add dev wg0 protocol ip parent 1: prio 2 u32 match ip dport 22 0xffff flowid 1:11
    tc filter add dev wg0 protocol ip parent 1: prio 2 u32 match ip dport 51820 0xffff flowid 1:11
    
    echo 'Configuración de Traffic Shaping aplicada en gateway-a'
    tc qdisc show dev wg0
    tc class show dev wg0
"

# Aplicar limitación en gateway-b
print_status "Aplicando límites de tráfico en gateway-b..."
sudo docker exec -it gateway-b bash -c "
    # Instalar dependencias si no existen
    apt-get update -qq && apt-get install -y iproute2

    # Eliminar configuraciones previas
    tc qdisc del dev wg0 root 2>/dev/null || true
    
    # Crear disciplina de cola HTB en wg0
    tc qdisc add dev wg0 root handle 1: htb default 12
    
    # Clase raíz: 10Mbit total para la interfaz
    tc class add dev wg0 parent 1: classid 1:1 htb rate 10mbit ceil 10mbit
    
    # Subclase para tráfico multimedia (alta prioridad): 5Mbit
    tc class add dev wg0 parent 1:1 classid 1:10 htb rate 5mbit ceil 8mbit prio 1
    
    # Subclase para tráfico general: 3Mbit
    tc class add dev wg0 parent 1:1 classid 1:11 htb rate 3mbit ceil 6mbit prio 2
    
    # Subclase para el resto del tráfico: 2Mbit
    tc class add dev wg0 parent 1:1 classid 1:12 htb rate 2mbit ceil 4mbit prio 3
    
    # Filtros para clasificar el tráfico
    # Tráfico multimedia (puertos 80, 443)
    tc filter add dev wg0 protocol ip parent 1: prio 1 u32 match ip dport 80 0xffff flowid 1:10
    tc filter add dev wg0 protocol ip parent 1: prio 1 u32 match ip dport 443 0xffff flowid 1:10
    
    # Tráfico SSH y VPN (puertos 22, 51820)
    tc filter add dev wg0 protocol ip parent 1: prio 2 u32 match ip dport 22 0xffff flowid 1:11
    tc filter add dev wg0 protocol ip parent 1: prio 2 u32 match ip dport 51820 0xffff flowid 1:11
    
    echo 'Configuración de Traffic Shaping aplicada en gateway-b'
    tc qdisc show dev wg0
    tc class show dev wg0
"

# 2. Priorización de tráfico
print_status "Implementando priorización de tráfico..."

# Aplicar priorización en gateway-a
print_status "Aplicando priorización de tráfico en gateway-a..."
sudo docker exec -it gateway-a bash -c "
    # SFQ en cada clase para distribución justa entre flujos
    tc qdisc add dev wg0 parent 1:10 handle 10: sfq perturb 10
    tc qdisc add dev wg0 parent 1:11 handle 11: sfq perturb 10
    tc qdisc add dev wg0 parent 1:12 handle 12: sfq perturb 10
    
    # Ajustar iptables para ToS (Type of Service) - marcado de paquetes
    # Marcar tráfico multimedia como AF41 (alta prioridad)
    iptables -t mangle -F
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j DSCP --set-dscp-class AF41
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j DSCP --set-dscp-class AF41
    
    # Marcar tráfico SSH y VPN como AF31 (prioridad media)
    iptables -t mangle -A PREROUTING -p tcp --dport 22 -j DSCP --set-dscp-class AF31
    iptables -t mangle -A PREROUTING -p udp --dport 51820 -j DSCP --set-dscp-class AF31
    
    echo 'Configuración de priorización de tráfico aplicada en gateway-a'
    iptables -t mangle -L -v
"

# Aplicar priorización en gateway-b
print_status "Aplicando priorización de tráfico en gateway-b..."
sudo docker exec -it gateway-b bash -c "
    # SFQ en cada clase para distribución justa entre flujos
    tc qdisc add dev wg0 parent 1:10 handle 10: sfq perturb 10
    tc qdisc add dev wg0 parent 1:11 handle 11: sfq perturb 10
    tc qdisc add dev wg0 parent 1:12 handle 12: sfq perturb 10
    
    # Ajustar iptables para ToS (Type of Service) - marcado de paquetes
    # Marcar tráfico multimedia como AF41 (alta prioridad)
    iptables -t mangle -F
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j DSCP --set-dscp-class AF41
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j DSCP --set-dscp-class AF41
    
    # Marcar tráfico SSH y VPN como AF31 (prioridad media)
    iptables -t mangle -A PREROUTING -p tcp --dport 22 -j DSCP --set-dscp-class AF31
    iptables -t mangle -A PREROUTING -p udp --dport 51820 -j DSCP --set-dscp-class AF31
    
    echo 'Configuración de priorización de tráfico aplicada en gateway-b'
    iptables -t mangle -L -v
"

# 3. Control de congestión
print_status "Implementando control de congestión..."

# Aplicar control de congestión en gateway-a
print_status "Aplicando control de congestión en gateway-a..."
sudo docker exec -it gateway-a bash -c "
    # Instalar dependencias adicionales si no existen
    apt-get install -y procps

    # Configurar BBR como algoritmo de control de congestión
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || echo 'BBR no disponible, usando cubic'
    sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null || echo 'Error al configurar control de congestión'
    
    # Ajustar parámetros de red para optimizar el rendimiento
    sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
    sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true
    
    echo 'Configuración de control de congestión aplicada en gateway-a'
    sysctl -a | grep -E 'tcp_congestion|rmem|wmem' | grep -v compat
"

# Aplicar control de congestión en gateway-b
print_status "Aplicando control de congestión en gateway-b..."
sudo docker exec -it gateway-b bash -c "
    # Instalar dependencias adicionales si no existen
    apt-get install -y procps

    # Configurar BBR como algoritmo de control de congestión
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || echo 'BBR no disponible, usando cubic'
    sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null || echo 'Error al configurar control de congestión'
    
    # Ajustar parámetros de red para optimizar el rendimiento
    sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
    sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true
    
    echo 'Configuración de control de congestión aplicada en gateway-b'
    sysctl -a | grep -E 'tcp_congestion|rmem|wmem' | grep -v compat
"

print_status "Todas las políticas de QoS han sido aplicadas correctamente!"

echo ""
echo "=============================================="
echo "        Resumen de Políticas de QoS"
echo "=============================================="
echo "1. Traffic Shaping:"
echo "   - Límite total: 10 Mbit/s por gateway"
echo "   - Tráfico multimedia (HTTP/HTTPS): 5 Mbit/s (prioridad alta)"
echo "   - Tráfico SSH/VPN: 3 Mbit/s (prioridad media)"
echo "   - Resto del tráfico: 2 Mbit/s (prioridad baja)"
echo ""
echo "2. Priorización de tráfico:"
echo "   - Marcado DSCP para diferentes tipos de tráfico"
echo "   - Multimedia (AF41): Alta prioridad"
echo "   - SSH/VPN (AF31): Prioridad media"
echo "   - SFQ para distribución justa de ancho de banda entre flujos"
echo ""
echo "3. Control de congestión:"
echo "   - Algoritmo BBR/CUBIC para optimizar throughput"
echo "   - Buffers TCP optimizados para mejor rendimiento"
echo "=============================================="
echo ""
echo "Para probar las políticas de QoS:"
echo "1. Genere tráfico simultáneo entre oficinas"
echo "2. Compare velocidades con 'iperf3' entre diferentes tipos de tráfico"
echo "3. Monitoree con 'tc -s class show dev wg0' en los gateways"
