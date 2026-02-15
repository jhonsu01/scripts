#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  Rocky Linux Installer para Termux (aarch64)
#  Usa proot-distro (método oficial y estable)
# ============================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   Rocky Linux Installer para Termux      ║"
    echo "║   Arquitectura: aarch64 (ARM64)          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# ── Verificaciones ──────────────────────────────────────────
banner

info "Verificando entorno..."

# Verificar que estamos en Termux
if [ ! -d "/data/data/com.termux" ]; then
    err "Este script debe ejecutarse dentro de Termux."
    exit 1
fi

# Verificar arquitectura
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    warn "Tu arquitectura es ${ARCH}. Este script está optimizado para aarch64."
    echo -n "¿Deseas continuar de todos modos? (s/n): "
    read -r resp
    [ "$resp" != "s" ] && exit 0
fi

log "Entorno: Termux | Arquitectura: ${ARCH}"

# ── Paso 1: Actualizar repositorios ────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 1/5: Actualizando repositorios ━━━${NC}"
apt update -y && apt upgrade -y
log "Repositorios actualizados"

# ── Paso 2: Instalar dependencias ──────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 2/5: Instalando dependencias ━━━${NC}"
pkg install -y proot-distro wget curl
log "Dependencias instaladas (proot-distro, wget, curl)"

# ── Paso 3: Instalar Rocky Linux ──────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 3/5: Instalando Rocky Linux ━━━${NC}"

# Verificar si ya está instalado
if proot-distro list 2>/dev/null | grep -q "rockylinux.*installed"; then
    warn "Rocky Linux ya está instalado."
    echo -n "¿Deseas reinstalar? (s/n): "
    read -r resp
    if [ "$resp" = "s" ]; then
        info "Eliminando instalación anterior..."
        proot-distro remove rockylinux || true
        proot-distro install rockylinux
        log "Rocky Linux reinstalado correctamente"
    else
        log "Se conserva la instalación existente"
    fi
else
    info "Descargando e instalando Rocky Linux (esto puede tardar unos minutos)..."
    proot-distro install rockylinux
    log "Rocky Linux instalado correctamente"
fi

# ── Paso 4: Configuración inicial ─────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 4/5: Configuración inicial ━━━${NC}"

info "Configurando Rocky Linux (actualización de paquetes, locale, herramientas básicas)..."

proot-distro login rockylinux -- /bin/bash -c '
    # Actualizar paquetes
    dnf update -y 2>/dev/null || yum update -y

    # Instalar herramientas básicas
    dnf install -y \
        vim \
        nano \
        curl \
        wget \
        git \
        procps-ng \
        net-tools \
        which \
        passwd \
        sudo \
        2>/dev/null || true

    # Configurar locale
    if command -v localectl &>/dev/null; then
        localectl set-locale LANG=es_CO.UTF-8 2>/dev/null || true
    fi

    # Configurar zona horaria (Colombia)
    ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime 2>/dev/null || true

    echo ""
    echo "=== Rocky Linux configurado ==="
    cat /etc/os-release | head -4
'

log "Configuración inicial completada"

# ── Paso 5: Crear scripts de acceso rápido ─────────────────
echo ""
echo -e "${BOLD}━━━ Paso 5/5: Creando scripts de acceso rápido ━━━${NC}"

# Script de inicio rápido
LAUNCH_SCRIPT="$PREFIX/bin/rocky"
cat > "$LAUNCH_SCRIPT" << 'LAUNCH_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Lanzador rápido de Rocky Linux
proot-distro login rockylinux "$@"
LAUNCH_EOF
chmod +x "$LAUNCH_SCRIPT"
log "Comando rápido creado: rocky"

# Script de inicio con usuario personalizado
LAUNCH_USER_SCRIPT="$PREFIX/bin/rocky-user"
cat > "$LAUNCH_USER_SCRIPT" << 'LAUNCH_USER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Lanzador de Rocky Linux con usuario personalizado
# Uso: rocky-user <nombre_usuario>
if [ -z "$1" ]; then
    echo "Uso: rocky-user <nombre_usuario>"
    echo "Primero crea el usuario dentro de Rocky: useradd -m -G wheel <nombre>"
    exit 1
fi
proot-distro login rockylinux --user "$1"
LAUNCH_USER_EOF
chmod +x "$LAUNCH_USER_SCRIPT"
log "Comando con usuario: rocky-user <nombre>"

# Script de compartir almacenamiento
LAUNCH_SHARED_SCRIPT="$PREFIX/bin/rocky-shared"
cat > "$LAUNCH_SHARED_SCRIPT" << 'LAUNCH_SHARED_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Lanzador con acceso a almacenamiento del dispositivo
proot-distro login rockylinux --bind /sdcard:/mnt/sdcard "$@"
LAUNCH_SHARED_EOF
chmod +x "$LAUNCH_SHARED_SCRIPT"
log "Comando con almacenamiento: rocky-shared"

# ── Resumen final ──────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${BOLD}¡Rocky Linux instalado exitosamente!${NC}${GREEN}               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Comandos disponibles:${NC}                                ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}rocky${NC}          → Entrar como root                   ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}rocky-shared${NC}   → Entrar con acceso a /sdcard        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}rocky-user${NC} usr → Entrar como usuario específico      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Gestión con proot-distro:${NC}                             ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}proot-distro login rockylinux${NC}   → Login manual       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}proot-distro remove rockylinux${NC}  → Desinstalar        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}proot-distro reset rockylinux${NC}   → Reiniciar          ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}proot-distro list${NC}               → Ver distros        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Tip:${NC} Para crear un usuario normal dentro de Rocky:"
echo -e "  ${CYAN}rocky${NC}  (entrar primero)"
echo -e "  ${CYAN}useradd -m -G wheel jhon${NC}"
echo -e "  ${CYAN}passwd jhon${NC}"
echo -e "  ${CYAN}exit${NC}"
echo -e "  ${CYAN}rocky-user jhon${NC}  (entrar como jhon)"
echo ""
