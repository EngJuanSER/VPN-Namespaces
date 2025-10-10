#!/bin/bash

# Script de configuración automática para gateway-b
# Este script configura WireGuard y las rutas necesarias

echo "Configurando gateway-b..."

# Habilitar IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "Warning: No se pudo habilitar IP forwarding"

# Limpiar cualquier configuración anterior de WireGuard
wg-quick down wg0 2>/dev/null || echo "No hay configuración WireGuard previa"

# Configurar WireGuard
if [ -f /etc/wireguard/wg0.conf ]; then
  echo "Iniciando WireGuard..."
  wg-quick up wg0 || {
    echo "Error: No se pudo iniciar WireGuard"
    exit 1
  }
else
  echo "Error: No se encontró la configuración de WireGuard"
  exit 1
fi

# Configurar reglas de NAT específicas para VPN
echo "Configurando reglas de NAT optimizadas..."
iptables -t nat -F POSTROUTING 2>/dev/null || echo "Warning: No se pudieron limpiar reglas NAT"

# Reglas para permitir acceso desde LAN local hacia VPN y otras redes
iptables -t nat -A POSTROUTING -s 172.16.20.0/24 -d 172.16.10.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.20.0/24 -d 10.0.0.0/24 -j MASQUERADE

# Reglas críticas para permitir acceso desde VPN hacia LAN local (orden importante)
iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -d 172.16.20.0/24 -j MASQUERADE

# Configurar rutas adicionales para Site-to-Site
echo "Configurando rutas para Site-to-Site..."
ip route add 172.16.10.0/24 dev wg0 2>/dev/null || echo "Ruta a oficina A ya existe"

# Configurar forwarding específico
iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT

# Verificar que la interfaz wg0 esté activa
if ip link show wg0 >/dev/null 2>&1; then
  echo "WireGuard configurado correctamente"
else
  echo "Error: WireGuard no se configuró correctamente"
  exit 1
fi

# Mostrar estado de WireGuard
echo "Estado de WireGuard:"
wg show

# Probar conectividad básica
echo "Probando conectividad con gateway-a..."
ping -c 3 10.0.0.1 >/dev/null 2>&1 && echo "Conectividad con gateway-a: OK" || echo "Conectividad con gateway-a: FAIL"

echo "Configuración de gateway-b completada exitosamente"
