# VPN-Namespaces: Implementación de VPN Site-to-Site y Remote Access

## Descripción del Proyecto

Este proyecto implementa una solución completa de VPN utilizando **WireGuard** en un entorno containerizado con **Docker**. La solución incluye conectividad Site-to-Site, acceso remoto, calidad de servicio (QoS) y herramientas de seguridad con IA.

**Desarrollado por:** Grupo Gemini Engineering  
**Universidad:** Universidad Distrital Francisco José de Caldas  
**Asignatura:** Redes de Comunicaciones III

## Arquitectura de Red

```
Internet Simulada (172.18.0.0/16)
│
├── Gateway-A (172.18.0.2) ──────VPN Tunnel──────── Gateway-B (172.18.0.3)
│   │                           (10.0.0.0/24)        │
│   └── Red-A (172.16.10.0/24)                      └── Red-B (172.16.20.0/24)
│       └── Cliente-A (172.16.10.2)                     └── Cliente-B-VOD (172.16.20.2)
│
└── Cliente-Remoto (172.18.0.4)
    └── Conecta vía VPN (10.0.0.3)
```

### Componentes de la Red

- **Gateway-A**: Router/VPN endpoint (10.0.0.1)
- **Gateway-B**: Router/VPN endpoint (10.0.0.2)  
- **Cliente-A**: Host en red oficina A
- **Cliente-B-VOD**: Servidor de Video on Demand
- **Cliente-Remoto**: Cliente VPN remoto (10.0.0.3)

## Estructura del Proyecto

```
VPN-Namespaces/
├── docker-compose.yml           # Definición de infraestructura
├── setup_network.sh             # Script maestro de configuración
├── validate_configuration.sh    # Script de validación y diagnóstico
├── Taller_1_Reporte.md         # Reporte técnico completo
├── README.md                    # Esta documentación
├── config/                      # Configuraciones y scripts
│   ├── gateway-a/
│   │   ├── wg0.conf                # Config WireGuard gateway-a
│   │   └── setup.sh                # Script de configuración
│   ├── gateway-b/
│   │   ├── wg0.conf                # Config WireGuard gateway-b
│   │   └── setup.sh                # Script de configuración
│   ├── cliente-remoto/
│   │   ├── wg0.conf                # Config WireGuard cliente
│   │   └── setup.sh                # Script de configuración
│   ├── cliente-a/
│   │   └── setup_routes.sh   # Script de rutas
│   └── cliente-b-vod-server/
│       └── setup_routes.sh   # Script de rutas
└── vod-data/                    # Contenido servidor VoD
```

## Inicio Rápido

### Prerrequisitos

- Docker y Docker Compose instalados
- Sistema Linux (recomendado) o WSL2
- Permisos sudo

### Instalación Automática

```bash
# 1. Clonar el repositorio
git clone https://github.com/EngJuanSER/VPN-Namespaces.git
cd VPN-Namespaces

# 2. Levantar la infraestructura
docker-compose up -d

# 3. Configurar automáticamente toda la red VPN
sudo ./setup_network.sh

# 4. Validar configuración (opcional)
./validate_configuration.sh
```

**Listo!** En menos de 2 minutos tendrás una red VPN completamente funcional.

### Validación Automática

El proyecto incluye un script de validación completa que verifica:

```bash
./validate_configuration.sh
```

**Verifica automáticamente:**
- ✅ Estado de contenedores
- ✅ Configuraciones WireGuard válidas
- ✅ Claves públicas correctamente emparejadas
- ✅ Conectividad de endpoints
- ✅ Conectividad completa Site-to-Site y Remote Access
- ✅ Configuración de scripts y permisos

### Verificación Rápida

```bash
# Validación completa automatizada
./validate_configuration.sh

# Verificar conectividad Site-to-Site
sudo docker exec cliente-a ping -c 4 172.16.20.2

# Verificar acceso remoto
sudo docker exec cliente-remoto ping -c 4 172.16.10.2
sudo docker exec cliente-remoto ping -c 4 172.16.20.2

# Ver estado de WireGuard
sudo docker exec gateway-a wg show
```

## Configuración Manual (Opcional)

Si prefieres configurar paso a paso o entender el proceso:

### 1. Configurar Gateways

```bash
# Gateway-A
sudo docker cp config/gateway-a/wg0.conf gateway-a:/etc/wireguard/
sudo docker exec gateway-a /etc/setup.sh

# Gateway-B
sudo docker cp config/gateway-b/wg0.conf gateway-b:/etc/wireguard/
sudo docker exec gateway-b /etc/setup.sh
```

### 2. Configurar Cliente Remoto

```bash
sudo docker cp config/cliente-remoto/wg0.conf cliente-remoto:/etc/wireguard/
sudo docker exec cliente-remoto /etc/setup.sh
```

### 3. Configurar Rutas entre Clientes

```bash
sudo docker exec cliente-a /etc/setup_routes.sh
sudo docker exec cliente-b-vod-server /etc/setup_routes.sh
```

## Características Implementadas

### VPN Site-to-Site
- Túnel seguro entre dos redes LAN
- Enrutamiento automático bidireccional
- Cifrado ChaCha20Poly1305

### VPN Remote Access  
- Cliente remoto con acceso a ambas redes
- Configuración Full Tunnel
- DNS personalizable

### Calidad de Servicio (QoS)
- **Traffic Shaping**: Token Bucket Filter
- **Traffic Policing**: Hierarchical Token Bucket  
- **Priority Queuing**: Colas de prioridad PRIO

### Automatización Completa
- **Setup automático**: Un solo comando configura toda la infraestructura
- **Validación inteligente**: Script de diagnóstico que verifica configuración
- **Scripts modulares**: Configuración individual por componente
- **Instalación automática de dependencias**
- **Verificación automática de conectividad**
- **Infraestructura como Código (IaC)**

### Servidor VoD
- Nginx con contenido de streaming
- Pruebas de rendimiento con/sin QoS
- Métricas de ancho de banda y latencia

## Pruebas y Validación

### Validación Automatizada

```bash
# Script de validación completa (recomendado)
./validate_configuration.sh
```

Este script realiza verificaciones exhaustivas:
- **Contenedores**: Estado y conectividad
- **Configuraciones WireGuard**: Sintaxis y parámetros
- **Claves públicas**: Emparejamiento correcto entre peers
- **Endpoints**: Conectividad de red entre nodos
- **Conectividad VPN**: Site-to-Site y Remote Access
- **Scripts**: Permisos y configuración

### Conectividad Básica

```bash
# Ping entre gateways
sudo docker exec gateway-a ping -c 4 10.0.0.2

# Conectividad Site-to-Site
sudo docker exec cliente-a ping -c 4 172.16.20.2
sudo docker exec cliente-b-vod-server ping -c 4 172.16.10.2

# Acceso remoto
sudo docker exec cliente-remoto ping -c 4 172.16.10.2
sudo docker exec cliente-remoto ping -c 4 172.16.20.2
```

### Pruebas de Rendimiento

```bash
# Test de ancho de banda con iperf3
sudo docker exec -it cliente-a iperf3 -c 172.16.20.2 -t 30

# Descarga desde servidor VoD
sudo docker exec cliente-a wget -O /dev/null http://172.16.20.2/video.mp4

# Estadísticas de QoS
sudo docker exec gateway-a tc -s qdisc show dev wg0
```

### Estado de WireGuard

```bash
# Ver peers conectados
sudo docker exec gateway-a wg show
sudo docker exec gateway-b wg show
sudo docker exec cliente-remoto wg show

# Ver configuración
sudo docker exec gateway-a cat /etc/wireguard/wg0.conf
```

## Seguridad

### Características de Seguridad

- **Cifrado moderno**: ChaCha20Poly1305
- **Autenticación**: Claves públicas Curve25519
- **Perfect Forward Secrecy**: Rotación automática de claves
- **Firewall integrado**: iptables configurado automáticamente

### Claves de Configuración

Las configuraciones incluyen claves pre-generadas para fines educativos. En producción:

```bash
# Generar nuevas claves
wg genkey | tee private.key | wg pubkey > public.key
```

## QoS y Rendimiento

### Configuraciones de QoS Disponibles

```bash
# Traffic Shaping - Limitar a 15 Mbps
tc qdisc add dev wg0 root handle 1: tbf rate 15mbit burst 32kbit limit 65536

# Priority Queuing - 3 bandas de prioridad
tc qdisc add dev wg0 root handle 1: prio bands 3

# HTB - Control jerárquico
tc qdisc add dev wg0 root handle 1: htb default 30
tc class add dev wg0 parent 1: classid 1:1 htb rate 20mbit
```

### Métricas de Rendimiento

| Configuración | Throughput | Latencia | Jitter |
|---------------|------------|----------|--------|
| Sin QoS | >800 MB/s | <1ms | Variable |
| Con QoS (15Mbps) | ~14.4 Mbps | <2ms | Controlado |

## Troubleshooting

### Diagnóstico Rápido

```bash
# Diagnóstico automático completo
./validate_configuration.sh

# Si muestra errores, revisar logs específicos
sudo docker logs gateway-a
sudo docker logs gateway-b
```

### Problemas Comunes

**WireGuard no inicia:**
```bash
# Verificar permisos
sudo docker exec gateway-a chmod 600 /etc/wireguard/wg0.conf

# Revisar logs
sudo docker logs gateway-a
```

**Sin conectividad:**
```bash
# Diagnóstico completo
./validate_configuration.sh

# Verificar rutas manualmente
sudo docker exec cliente-a ip route

# Verificar firewall
sudo docker exec gateway-a iptables -L -v
```

**Rendimiento bajo:**
```bash
# Diagnóstico de configuración
./validate_configuration.sh

# Verificar QoS
sudo docker exec gateway-a tc qdisc show

# Test de conectividad directa
sudo docker exec cliente-a ping -c 10 172.16.10.10
```

### Reconfiguración Completa

Si necesitas reconfigurar desde cero:

```bash
# Limpiar configuración
docker-compose down
docker-compose up -d

# Reconfigurar automáticamente
sudo ./setup_network.sh

# Validar nueva configuración
./validate_configuration.sh
```

## Contribuir

1. Fork del repositorio
2. Crear rama para nueva característica (`git checkout -b feature/nueva-caracteristica`)
3. Commit de cambios (`git commit -am 'Agregar nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crear Pull Request

## Licencia

Este proyecto es desarrollado con fines educativos para la Universidad Distrital Francisco José de Caldas.

## Documentación Adicional

- [Reporte Técnico Completo](Taller_1_Reporte.md)
- [Documentación de WireGuard](https://www.wireguard.com/quickstart/)
- [Manual de Traffic Control](https://lartc.org/howto/)

---

**¿Necesitas ayuda?** Revisa el [reporte técnico completo](Taller_1_Reporte.md) para análisis detallado y ejemplos adicionales.