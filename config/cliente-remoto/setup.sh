#!/bin/bash

# Script de configuración automática para cliente-remoto
# Este script configura WireGuard para acceso remoto

echo "Configurando cliente-remoto..."

# Configurar WireGuard
if [ -f /etc/wireguard/wg0.conf ]; then
  echo "Iniciando WireGuard..."
  
  # Detener WireGuard si ya está en ejecución
  wg-quick down wg0 2>/dev/null || true
  
  # Ajustar MTU en la configuración (añadir MTU=1420)
  if ! grep -q "MTU" /etc/wireguard/wg0.conf; then
    sed -i '/\[Interface\]/a MTU = 1420' /etc/wireguard/wg0.conf
  fi
  
  # Usar wg-quick para configurar la interfaz (igual que en los gateways)
  wg-quick up wg0 2>/dev/null || echo "WireGuard ya está activo o hay un error"
else
  echo "Error: No se encontró la configuración de WireGuard"
  exit 1
fi

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

# Probar conectividad
echo "Probando conectividad..."
ping -c 3 10.0.0.1 && echo "Conectividad con gateway-a: OK" || echo "Conectividad con gateway-a: FAIL"

echo "Configuración de cliente-remoto completada exitosamente"
