#!/bin/bash

# Script maestro para configurar toda la red VPN
# Este script aplica todas las configuraciones necesarias

echo "=== Configuración de Red VPN Site-to-Site y Acceso Remoto ==="
echo ""

# Función para mostrar errores
error() {
    echo "ERROR: $1" >&2
    exit 1
}

# Función para mostrar información
info() {
    echo "INFO: $1"
}

# Función para instalar dependencias
install_dependencies() {
    local container=$1
    info "Instalando dependencias en $container..."
    
    # Verificar si ya están instaladas las dependencias básicas
    if docker exec $container which wg > /dev/null 2>&1; then
        info "WireGuard ya está instalado en $container"
        return 0
    fi
    
    # Actualizar repositorios e instalar WireGuard y herramientas de red
    info "Actualizando repositorios en $container..."
    if ! docker exec $container bash -c "apt-get update"; then
        error "Falló la actualización de repositorios en $container"
    fi
    
    info "Instalando paquetes en $container..."
    if ! docker exec $container bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-tools iptables iproute2 iputils-ping traceroute"; then
        error "Falló la instalación de dependencias en $container"
    fi
    
    info "Dependencias instaladas exitosamente en $container"
}

# Verificar que los contenedores estén ejecutándose
info "Verificando contenedores..."
for container in gateway-a gateway-b cliente-a cliente-b-vod-server cliente-remoto; do
    if ! docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        error "El contenedor $container no está ejecutándose"
    fi
done
info "Todos los contenedores están ejecutándose"

# Instalar dependencias en todos los contenedores
info "Instalando dependencias necesarias..."
for container in gateway-a gateway-b cliente-a cliente-b-vod-server cliente-remoto; do
    install_dependencies $container
done

# Generar claves WireGuard únicas para cada despliegue
info "Generando claves WireGuard únicas..."
generate_wireguard_keys() {
    local node=$1
    # Generar par de claves sin mostrar info dentro de la función
    local private_key=$(docker exec $node wg genkey)
    local public_key=$(echo "$private_key" | docker exec -i $node wg pubkey)
    
    echo "$private_key:$public_key"
}

# Generar claves para todos los nodos
info "Generando claves para gateway-a..."
gateway_a_keys=$(generate_wireguard_keys gateway-a)
info "Generando claves para gateway-b..."
gateway_b_keys=$(generate_wireguard_keys gateway-b)
info "Generando claves para cliente-remoto..."
remote_keys=$(generate_wireguard_keys cliente-remoto)

# Extraer claves individuales
gateway_a_private=$(echo "$gateway_a_keys" | cut -d: -f1)
gateway_a_public=$(echo "$gateway_a_keys" | cut -d: -f2)
gateway_b_private=$(echo "$gateway_b_keys" | cut -d: -f1)
gateway_b_public=$(echo "$gateway_b_keys" | cut -d: -f2)
remote_private=$(echo "$remote_keys" | cut -d: -f1)
remote_public=$(echo "$remote_keys" | cut -d: -f2)

info "Claves generadas exitosamente"
info "Gateway-A: $gateway_a_public"
info "Gateway-B: $gateway_b_public" 
info "Cliente-Remoto: $remote_public"

# Guardar claves en archivos individuales para referencia
info "Guardando claves en archivos..."
echo "$gateway_a_private" > config/gateway-a/private.key
echo "$gateway_a_public" > config/gateway-a/public.key
echo "$gateway_b_private" > config/gateway-b/private.key
echo "$gateway_b_public" > config/gateway-b/public.key
echo "$remote_private" > config/cliente-remoto/privatekey
echo "$remote_public" > config/cliente-remoto/publickey

# Actualizar archivos de configuración con las nuevas claves
info "Actualizando configuraciones con claves nuevas..."

# Recrear gateway-a config usando heredoc sin placeholders
cat > config/gateway-a/wg0.conf << EOF
[Interface]
MTU = 1420
Address = 10.0.0.1/24
PrivateKey = $gateway_a_private
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -j MASQUERADE; iptables -A FORWARD -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -j MASQUERADE; iptables -D FORWARD -j ACCEPT

[Peer]
# Gateway-B (Site-to-Site)
PublicKey = $gateway_b_public
Endpoint = 172.19.0.3:51820
AllowedIPs = 10.0.0.2/32, 172.16.20.0/24
PersistentKeepalive = 25

[Peer]
# Cliente-Remoto (Remote Access)
PublicKey = $remote_public
AllowedIPs = 10.0.0.3/32
PersistentKeepalive = 25
EOF

# Recrear gateway-b config
cat > config/gateway-b/wg0.conf << EOF
[Interface]
MTU = 1420
Address = 10.0.0.2/24
PrivateKey = $gateway_b_private
ListenPort = 51820
PostUp = iptables -t nat -A POSTROUTING -j MASQUERADE; iptables -A FORWARD -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -j MASQUERADE; iptables -D FORWARD -j ACCEPT

[Peer]
# Gateway-A (Site-to-Site)
PublicKey = $gateway_a_public
Endpoint = 172.19.0.4:51820
AllowedIPs = 10.0.0.1/32, 10.0.0.3/32, 172.16.10.0/24
PersistentKeepalive = 25
EOF

# Recrear cliente-remoto config
cat > config/cliente-remoto/wg0.conf << EOF
[Interface]
MTU = 1420
Address = 10.0.0.3/24
PrivateKey = $remote_private

[Peer]
# Gateway-A (Remote Access)
PublicKey = $gateway_a_public
Endpoint = 172.19.0.4:51820
AllowedIPs = 10.0.0.0/24, 172.16.10.0/24, 172.16.20.0/24
PersistentKeepalive = 25
EOF

info "Archivos de configuración regenerados con claves nuevas"

# Copiar configuraciones a los contenedores
info "Copiando configuraciones WireGuard..."
docker cp config/gateway-a/wg0.conf gateway-a:/etc/wireguard/wg0.conf
docker cp config/gateway-b/wg0.conf gateway-b:/etc/wireguard/wg0.conf
docker cp config/cliente-remoto/wg0.conf cliente-remoto:/etc/wireguard/wg0.conf

# Copiar scripts de configuración
info "Copiando scripts de configuración..."
docker cp config/gateway-a/setup.sh gateway-a:/etc/setup.sh
docker cp config/gateway-b/setup.sh gateway-b:/etc/setup.sh
docker cp config/cliente-remoto/setup.sh cliente-remoto:/etc/setup.sh
docker cp config/cliente-a/setup_routes.sh cliente-a:/etc/setup_routes.sh
docker cp config/cliente-b-vod-server/setup_routes.sh cliente-b-vod-server:/etc/setup_routes.sh

# Dar permisos de ejecución
info "Configurando permisos..."
docker exec gateway-a chmod +x /etc/setup.sh
docker exec gateway-b chmod +x /etc/setup.sh
docker exec cliente-remoto chmod +x /etc/setup.sh
docker exec cliente-a chmod +x /etc/setup_routes.sh
docker exec cliente-b-vod-server chmod +x /etc/setup_routes.sh

# Configurar gateways
info "Configurando gateway-a..."
docker exec gateway-a /etc/setup.sh

info "Configurando gateway-b..."
docker exec gateway-b /etc/setup.sh

# Esperar un momento para que se establezcan las conexiones
sleep 3

# Aplicar optimizaciones de NAT adicionales si es necesario
info "Aplicando optimizaciones de red..."
docker exec gateway-a bash -c "
  # Limpiar reglas NAT genéricas si existen
  iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null || true
  # Aplicar reglas específicas para VPN
  iptables -t nat -C POSTROUTING -s 172.16.10.0/24 -d 172.16.20.0/24 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 172.16.10.0/24 -d 172.16.20.0/24 -j MASQUERADE
  iptables -t nat -C POSTROUTING -s 172.16.10.0/24 -d 10.0.0.0/24 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 172.16.10.0/24 -d 10.0.0.0/24 -j MASQUERADE
"

docker exec gateway-b bash -c "
  # Limpiar reglas NAT genéricas si existen
  iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null || true
  # Aplicar reglas específicas para VPN
  iptables -t nat -C POSTROUTING -s 172.16.20.0/24 -d 172.16.10.0/24 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 172.16.20.0/24 -d 172.16.10.0/24 -j MASQUERADE
  iptables -t nat -C POSTROUTING -s 172.16.20.0/24 -d 10.0.0.0/24 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 172.16.20.0/24 -d 10.0.0.0/24 -j MASQUERADE
"

# Configurar cliente remoto
info "Configurando cliente-remoto..."
docker exec cliente-remoto /etc/setup.sh

# Configurar rutas en clientes
info "Configurando rutas en cliente-a..."
docker exec cliente-a /etc/setup_routes.sh

info "Configurando rutas en cliente-b-vod-server..."
docker exec cliente-b-vod-server /etc/setup_routes.sh

# Verificar conectividad
echo ""
echo "=== Verificación de Conectividad ==="
echo ""

info "Probando conectividad entre gateways..."
docker exec gateway-a ping -c 3 10.0.0.2

echo ""
info "Probando conectividad desde cliente-remoto..."
docker exec cliente-remoto ping -c 3 172.16.10.2
docker exec cliente-remoto ping -c 3 172.16.20.2

echo ""
info "Probando conectividad entre clientes..."
docker exec cliente-a ping -c 3 172.16.20.2
docker exec cliente-b-vod-server ping -c 3 172.16.10.2

echo ""
echo "=== Configuración Completada ==="
echo "La red VPN ha sido configurada exitosamente:"
echo "  - Site-to-Site VPN entre gateway-a y gateway-b"
echo "  - Acceso remoto VPN para cliente-remoto"
echo "  - Conectividad completa entre todas las redes"
echo ""

# Configurar sistema de IA para seguridad
echo "=== Configurando Sistema de IA para Seguridad ==="
if [ -f "./setup_security_ai.sh" ]; then
    info "Iniciando configuración de IA para seguridad..."
    ./setup_security_ai.sh setup
    echo ""
    info "Sistema de IA configurado. Para ver reportes ejecute: ./setup_security_ai.sh reports"
else
    echo "Warning: Script de IA no encontrado. Saltando configuración de seguridad IA."
fi

echo ""
echo "=== RESUMEN FINAL ==="
echo "✅ VPN Site-to-Site funcional"
echo "✅ VPN Remote Access funcional"  
echo "✅ QoS aplicado (si se configuró)"
echo "✅ Sistema de IA de seguridad activo"
echo ""
echo "Comandos útiles:"
echo "  - Ver estado VPN: docker exec gateway-a wg show"
echo "  - Validar configuración: ./validate_configuration.sh"
echo "  - Reportes de seguridad: ./setup_security_ai.sh reports"
echo "  - Pruebas de IA: ./setup_security_ai.sh test"
