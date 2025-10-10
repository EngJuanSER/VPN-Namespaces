#!/bin/bash

# Script de configuración de rutas para cliente-b-vod-server
# Este script configura las rutas necesarias para comunicarse con cliente-a

echo "Configurando rutas para cliente-b-vod-server..."

# Eliminar ruta existente si existe
ip route del 172.16.10.0/24 2>/dev/null || true

# Agregar ruta hacia la red de cliente-a vía gateway-b
ip route add 172.16.10.0/24 via 172.16.20.10

# Verificar la ruta
if ip route get 172.16.10.2 | grep -q "172.16.20.10"; then
  echo "Ruta configurada correctamente"
else
  echo "Error al configurar la ruta"
  exit 1
fi

# Probar conectividad
echo "Probando conectividad con cliente-a..."
ping -c 3 172.16.10.2 && echo "Conectividad: OK" || echo "Conectividad: FAIL"

echo "Configuración de rutas para cliente-b-vod-server completada"
