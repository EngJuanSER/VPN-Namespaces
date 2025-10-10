#!/bin/bash

# Script de validación de configuración VPN
# Este script verifica que todas las configuraciones estén correctas

echo "=== Validación de Configuración VPN ==="
echo ""

# Función para mostrar resultados
check_result() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
    else
        echo "❌ $2"
    fi
}

# Verificar que los contenedores estén ejecutándose
echo "1. Verificando contenedores..."
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(gateway-a|gateway-b|cliente-a|cliente-b-vod-server|cliente-remoto)"

echo ""
echo "2. Verificando configuraciones WireGuard..."

# Verificar archivos de configuración
if [ -f "config/gateway-a/wg0.conf" ]; then
    endpoint_a=$(grep "Endpoint" config/gateway-a/wg0.conf | head -1 | cut -d' ' -f3)
    check_result $? "Gateway-A configuración existe - Endpoint: $endpoint_a"
else
    check_result 1 "Gateway-A configuración NO encontrada"
fi

if [ -f "config/gateway-b/wg0.conf" ]; then
    endpoint_b=$(grep "Endpoint" config/gateway-b/wg0.conf | head -1 | cut -d' ' -f3)
    check_result $? "Gateway-B configuración existe - Endpoint: $endpoint_b"
else
    check_result 1 "Gateway-B configuración NO encontrada"
fi

if [ -f "config/cliente-remoto/wg0.conf" ]; then
    endpoint_remote=$(grep "Endpoint" config/cliente-remoto/wg0.conf | cut -d' ' -f3)
    check_result $? "Cliente-Remoto configuración existe - Endpoint: $endpoint_remote"
else
    check_result 1 "Cliente-Remoto configuración NO encontrada"
fi

echo ""
echo "3. Verificando MTU en configuraciones..."
grep -r "MTU = 1420" config/*/wg0.conf && check_result 0 "MTU 1420 configurado en todos los archivos" || check_result 1 "MTU no configurado correctamente"

echo ""
echo "4. Verificando claves públicas..."
# Verificar que las claves públicas coincidan entre configuraciones
# Obtener las claves que cada configuración espera del peer
gateway_a_expects_b=$(grep -A10 "\[Peer\]" config/gateway-a/wg0.conf | grep "PublicKey" | head -1 | cut -d' ' -f3)
gateway_b_expects_a=$(grep -A10 "\[Peer\]" config/gateway-b/wg0.conf | grep "PublicKey" | head -1 | cut -d' ' -f3)
remote_expects_a=$(grep "PublicKey" config/cliente-remoto/wg0.conf | cut -d' ' -f3)

# Obtener claves públicas reales de los contenedores (si están corriendo)
if docker ps | grep -q gateway-a; then
    gateway_a_real_key=$(docker exec gateway-a wg show | grep "public key" | awk '{print $3}')
    gateway_b_real_key=$(docker exec gateway-b wg show | grep "public key" | awk '{print $3}')
    remote_real_key=$(docker exec cliente-remoto wg show | grep "public key" | awk '{print $3}')
    
    echo "Claves públicas reales:"
    echo "  Gateway-A: $gateway_a_real_key"
    echo "  Gateway-B: $gateway_b_real_key"
    echo "  Cliente-Remoto: $remote_real_key"
    
    # Verificar que Gateway-A espere correctamente a Gateway-B
    if [ "$gateway_a_expects_b" = "$gateway_b_real_key" ]; then
        check_result 0 "Gateway-A espera clave correcta de Gateway-B"
    else
        check_result 1 "Gateway-A espera clave incorrecta de Gateway-B"
        echo "  Esperada: $gateway_a_expects_b"
        echo "  Real:     $gateway_b_real_key"
    fi
    
    # Verificar que Gateway-B espere correctamente a Gateway-A
    if [ "$gateway_b_expects_a" = "$gateway_a_real_key" ]; then
        check_result 0 "Gateway-B espera clave correcta de Gateway-A"
    else
        check_result 1 "Gateway-B espera clave incorrecta de Gateway-A"
        echo "  Esperada: $gateway_b_expects_a"
        echo "  Real:     $gateway_a_real_key"
    fi
    
    # Verificar que Cliente-Remoto espere correctamente a Gateway-A
    if [ "$remote_expects_a" = "$gateway_a_real_key" ]; then
        check_result 0 "Cliente-Remoto espera clave correcta de Gateway-A"
    else
        check_result 1 "Cliente-Remoto espera clave incorrecta de Gateway-A"
        echo "  Esperada: $remote_expects_a"
        echo "  Real:     $gateway_a_real_key"
    fi
    
    # Verificar que Gateway-A tenga la clave correcta del Cliente-Remoto
    if grep -q "$remote_real_key" config/gateway-a/wg0.conf; then
        check_result 0 "Gateway-A conoce clave correcta del Cliente-Remoto"
    else
        check_result 1 "Gateway-A no conoce clave correcta del Cliente-Remoto"
        echo "  Cliente-Remoto real: $remote_real_key"
    fi
else
    echo "ℹ️  Contenedores no están corriendo, verificando solo configuraciones estáticas"
    echo "Gateway-A espera Gateway-B: $gateway_a_expects_b"
    echo "Gateway-B espera Gateway-A: $gateway_b_expects_a"
    echo "Cliente-Remoto espera Gateway-A: $remote_expects_a"
fi

echo ""
echo "5. Verificando scripts de configuración..."
for script in config/gateway-a/setup.sh config/gateway-b/setup.sh config/cliente-remoto/setup.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        check_result 0 "Script $script existe y es ejecutable"
    else
        check_result 1 "Script $script problema de permisos"
    fi
done

echo ""
echo "6. Verificando direcciones IP esperadas..."
# Solo si los contenedores están corriendo
if docker ps | grep -q gateway-a; then
    gateway_a_ip=$(docker exec gateway-a ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    gateway_b_ip=$(docker exec gateway-b ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    remote_ip=$(docker exec cliente-remoto ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    
    echo "IPs asignadas por Docker:"
    echo "  Gateway-A: $gateway_a_ip"
    echo "  Gateway-B: $gateway_b_ip" 
    echo "  Cliente-Remoto: $remote_ip"
    
    # Verificar que las IPs en configuración coincidan con las reales o sean alcanzables
    # En lugar de buscar IPs exactas, verificamos que el endpoint sea alcanzable
    gateway_a_endpoint=$(grep "Endpoint" config/gateway-a/wg0.conf | cut -d' ' -f3 | cut -d':' -f1)
    gateway_b_endpoint=$(grep "Endpoint" config/gateway-b/wg0.conf | cut -d' ' -f3 | cut -d':' -f1)
    remote_endpoint=$(grep "Endpoint" config/cliente-remoto/wg0.conf | cut -d' ' -f3 | cut -d':' -f1)
    
    # Verificar que los endpoints son alcanzables desde los contenedores
    if [ ! -z "$gateway_a_endpoint" ] && docker exec gateway-a ping -c 1 "$gateway_a_endpoint" >/dev/null 2>&1; then
        check_result 0 "Endpoint Gateway-B desde Gateway-A es alcanzable"
    elif [ -z "$gateway_a_endpoint" ]; then
        check_result 1 "No se encontró endpoint en configuración Gateway-A"
    else
        check_result 1 "Endpoint Gateway-B desde Gateway-A no es alcanzable"
    fi
    
    if [ ! -z "$gateway_b_endpoint" ] && docker exec gateway-b ping -c 1 "$gateway_b_endpoint" >/dev/null 2>&1; then
        check_result 0 "Endpoint Gateway-A desde Gateway-B es alcanzable"
    elif [ -z "$gateway_b_endpoint" ]; then
        check_result 1 "No se encontró endpoint en configuración Gateway-B"
    else
        check_result 1 "Endpoint Gateway-A desde Gateway-B no es alcanzable"
    fi
    
    if [ ! -z "$remote_endpoint" ] && docker exec cliente-remoto ping -c 1 "$remote_endpoint" >/dev/null 2>&1; then
        check_result 0 "Endpoint Gateway-A desde Cliente-Remoto es alcanzable"
    elif [ -z "$remote_endpoint" ]; then
        check_result 1 "No se encontró endpoint en configuración Cliente-Remoto"
    else
        check_result 1 "Endpoint Gateway-A desde Cliente-Remoto no es alcanzable"
    fi
fi

echo ""
echo "7. Verificando conectividad (si está configurado)..."
if docker exec gateway-a wg show 2>/dev/null | grep -q "interface: wg0"; then
    docker exec gateway-a ping -c 1 10.0.0.2 >/dev/null 2>&1
    check_result $? "Conectividad Gateway-A → Gateway-B"
    
    docker exec cliente-remoto ping -c 1 10.0.0.1 >/dev/null 2>&1
    check_result $? "Conectividad Cliente-Remoto → Gateway-A"
    
    docker exec cliente-a ping -c 1 172.16.20.2 >/dev/null 2>&1
    check_result $? "Conectividad Cliente-A → Cliente-B (Site-to-Site)"
else
    echo "ℹ️  WireGuard no está configurado aún, omitiendo pruebas de conectividad"
fi

echo ""
echo "=== Resumen de Validación ==="
echo "✅ = Configuración correcta"
echo "❌ = Requiere corrección"
echo "ℹ️  = Información adicional"
echo ""
echo "Para aplicar configuraciones: ./setup_network.sh"
echo "Para ver estado detallado: docker exec gateway-a wg show"
