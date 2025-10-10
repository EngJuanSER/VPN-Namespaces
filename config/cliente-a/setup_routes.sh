#!/bin/bash

# Script de configuración de rutas para cliente-a
# Este script configura las rutas necesarias para comunicarse con cliente-b-vod-server

echo "Configurando rutas para cliente-a..."

# Eliminar ruta existente si existe
ip route del 172.16.20.0/24 2>/dev/null || true

# Agregar ruta hacia la red de cliente-b-vod-server vía gateway-a
ip route add 172.16.20.0/24 via 172.16.10.10

# Verificar la ruta
if ip route get 172.16.20.2 | grep -q "172.16.10.10"; then
  echo "Ruta configurada correctamente"
else
  echo "Error al configurar la ruta"
  exit 1
fi

# Probar conectividad
echo "Probando conectividad con cliente-b-vod-server..."
ping -c 3 172.16.20.2 && echo "Conectividad: OK" || echo "Conectividad: FAIL"

echo "Configuración de rutas para cliente-a completada"
