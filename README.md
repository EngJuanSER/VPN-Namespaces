# Taller de Ingeniería: Implementación de VPNs, QoS y Seguridad con Docker

**Universidad Distrital Francisco José De Caldas**
**Facultad de Ingeniería – Ingeniería de Sistemas**
**Asignatura:** Redes de comunicaciones III
**Presentado por:** Grupo Gemini Engineering

---

## Descripción del Proyecto

Este repositorio contiene la solución integral al Taller No. 1, implementada bajo el paradigma de **Infraestructura como Código (IaC)**. Utilizamos **Docker** y **Linux Network Namespaces** para simular un entorno de red realista, portátil y reproducible.

El laboratorio permite desplegar y evaluar:
1.  **Infraestructura VPN:** Escenarios Sitio a Sitio y Acceso Remoto utilizando **WireGuard**.
2.  **Servidor de Alto Consumo:** Un servidor de Video on Demand (Nginx).
3.  **Calidad de Servicio (QoS):** Implementación de modelado de tráfico (traffic shaping) con `tc` y evaluación de desempeño con `wget`/`iperf3`.
4.  **Seguridad Ofensiva y Defensiva:** Análisis de vulnerabilidades y despliegue de un IPS moderno (**CrowdSec**).

## Arquitectura

El entorno se define en `docker-compose.yml` y consta de:

*   **Redes:**
    *   `internet_simulada`: Red puente que conecta los gateways.
    *   `oficina-a` / `oficina-b`: LANs privadas aisladas.
*   **Nodos (Contenedores):**
    *   `gateway-a` / `gateway-b`: Routers/VPN endpoints (Ubuntu con capacidades de red extendidas).
    *   `cliente-a` / `cliente-b-vod-server`: Hosts en las LANs.
    *   `cliente-remoto`: Host externo (road warrior).

## Guía de Despliegue Rápido

Siga estos pasos para replicar el laboratorio en su máquina local.

### Prerrequisitos
*   Docker Engine y Docker Compose instalados.
*   Sistema operativo Linux (recomendado), macOS o Windows con WSL2.

### 1. Clonar el Repositorio
```bash
git clone <URL_DEL_REPOSITORIO>
cd taller-redes-vpn