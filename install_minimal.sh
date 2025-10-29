#!/bin/bash

# Script de instalación mínima para evitar problemas de repositorios
echo "=== Instalación Mínima de Dependencias ==="

for container in gateway-a gateway-b cliente-remoto; do
    echo "Verificando $container..."
    
    # Verificar si WireGuard ya está instalado
    if docker exec $container which wg > /dev/null 2>&1; then
        echo "✅ WireGuard ya instalado en $container"
        continue
    fi
    
    echo "Instalando solo WireGuard en $container..."
    docker exec $container bash -c "
        apt-get update > /dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wireguard-tools > /dev/null 2>&1 || true
    "
    
    # Verificar instalación
    if docker exec $container which wg > /dev/null 2>&1; then
        echo "✅ WireGuard instalado en $container"
    else
        echo "❌ Fallo en $container - continuando de todas formas"
    fi
done

echo ""
echo "Instalación mínima completada. Ejecute:"
echo "sudo ./setup_network.sh"
