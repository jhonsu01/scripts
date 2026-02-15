#!/bin/bash
# ============================================================
#  Webmin Installer para Rocky Linux (proot-distro / Termux)
#
#  Método: tar.gz oficial + configuración manual
#  Evita: systemd, SSL/PEM, directorios faltantes
#  Compatible: Rocky Linux 9 en proot aarch64
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Webmin Installer - Rocky Linux/Termux  ║"
echo "║   Panel Web: http://localhost:10000      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Pedir credenciales ─────────────────────────────────────
echo -e "${CYAN}Configuración de acceso${NC}"
echo ""
read -p "Usuario admin [admin]: " WEBMIN_USER
WEBMIN_USER=${WEBMIN_USER:-admin}
read -s -p "Contraseña: " WEBMIN_PASS
echo ""

if [ -z "$WEBMIN_PASS" ]; then
    err "La contraseña no puede estar vacía"
fi

# ── Paso 1: Crear TODOS los directorios necesarios ────────
echo ""
echo -e "${BOLD}━━━ Paso 1/6: Preparando sistema de archivos ━━━${NC}"

mkdir -p /usr/local/webmin
mkdir -p /etc/webmin
mkdir -p /var/webmin/sessions
mkdir -p /var/webmin/modules
mkdir -p /var/log
mkdir -p /tmp
mkdir -p /run
mkdir -p /usr/local/bin
mkdir -p /etc/pam.d

# Crear /etc/shadow si no existe (necesario para autenticación)
if [ ! -f /etc/shadow ]; then
    touch /etc/shadow
    chmod 640 /etc/shadow
fi

log "Directorios creados"

# ── Paso 2: Instalar dependencias con dnf ─────────────────
echo ""
echo -e "${BOLD}━━━ Paso 2/6: Instalando dependencias ━━━${NC}"

dnf install -y \
    perl \
    perl-Net-SSLeay \
    perl-Data-Dumper \
    perl-Digest-MD5 \
    perl-Digest-SHA \
    perl-Time-HiRes \
    perl-Time-Local \
    perl-File-Path \
    perl-File-Basename \
    perl-Sys-Syslog \
    openssl \
    wget \
    tar \
    gzip \
    unzip \
    shared-mime-info \
    procps-ng \
    2>/dev/null || {
        warn "Algunos paquetes opcionales no estaban disponibles, continuando..."
    }

log "Dependencias instaladas"

# ── Paso 3: Descargar Webmin ──────────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 3/6: Descargando Webmin ━━━${NC}"

cd /tmp

# Limpiar descargas anteriores
rm -rf webmin-current* webmin-2* webmin-1* 2>/dev/null

info "Descargando webmin-current.tar.gz desde webmin.com..."
wget -q --show-progress https://www.webmin.com/download/webmin-current.tar.gz

if [ ! -f webmin-current.tar.gz ]; then
    err "Error: No se pudo descargar Webmin"
fi

log "Descarga completada"

# ── Paso 4: Extraer e instalar ────────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 4/6: Extrayendo e instalando ━━━${NC}"

tar xzf webmin-current.tar.gz

# Encontrar el directorio extraído
WEBMIN_DIR=$(ls -d /tmp/webmin-[0-9]* 2>/dev/null | head -1)

if [ -z "$WEBMIN_DIR" ] || [ ! -d "$WEBMIN_DIR" ]; then
    err "Error: No se encontró el directorio de Webmin extraído"
fi

WEBMIN_VERSION=$(basename "$WEBMIN_DIR" | sed 's/webmin-//')
info "Versión detectada: ${WEBMIN_VERSION}"

# Limpiar instalación anterior
rm -rf /usr/local/webmin/*

# Copiar archivos a ubicación definitiva
cp -r ${WEBMIN_DIR}/* /usr/local/webmin/

log "Archivos instalados en /usr/local/webmin/"

# ── Paso 5: Configurar Webmin manualmente ─────────────────
echo ""
echo -e "${BOLD}━━━ Paso 5/6: Configurando Webmin ━━━${NC}"

WADIR="/usr/local/webmin"
CONFIG_DIR="/etc/webmin"
VAR_DIR="/var/webmin"
PERL=$(which perl)
PORT=10000

# Generar hash de contraseña con perl
SALT=$(${PERL} -e 'my @chars = ("a".."z","A".."Z","0".."9"); my $salt = ""; $salt .= $chars[rand @chars] for 1..16; print $salt;')
CRYPTED=$(${PERL} -e "print crypt('${WEBMIN_PASS}', '\\\$6\\\$${SALT}\\\$');")

# ── miniserv.conf (servidor web integrado)
cat > ${CONFIG_DIR}/miniserv.conf <<MEOF
port=${PORT}
root=${WADIR}
mimetypes=${WADIR}/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=${VAR_DIR}/miniserv.log
errorlog=${VAR_DIR}/miniserv.error
pidfile=${VAR_DIR}/miniserv.pid
logtime=168
pam=0
login=${WEBMIN_USER}
logout=${CONFIG_DIR}/logout-flag
listen=${PORT}
denyfile=\\.pl\$
log=1
blockhost_failures=3
blockhost_time=60
syslog=0
session=1
premodules=WebminCore
server=MiniServ/${WEBMIN_VERSION}
userfile=${CONFIG_DIR}/miniserv.users
passwd_file=/etc/shadow
passwd_uindex=0
passwd_pindex=1
passwd_cindex=2
passwd_mindex=4
passwd_mode=0
ssl=0
env_WEBMIN_CONFIG=${CONFIG_DIR}
env_WEBMIN_VAR=${VAR_DIR}
atboot=0
MEOF

# ── miniserv.users (credenciales)
echo "${WEBMIN_USER}:${CRYPTED}:0::::::" > ${CONFIG_DIR}/miniserv.users

# ── config (configuración general)
cat > ${CONFIG_DIR}/config <<CEOF
lang=es
log=1
logtime=168
logclear=1
loghost=0
logfiles=1
logfullfiles=0
logsec=10
risk_level=0
real_os_type=Rocky Linux
real_os_version=9
os_type=redhat-linux
os_version=9
referers_none=1
nofork=0
webprefix=
webprefixnoredir=0
lastchange=$(date +%s)
CEOF

# ── webmin.acl (permisos - acceso a todos los módulos)
MODULES=$(ls -d ${WADIR}/*/module.info 2>/dev/null | sed 's|.*/\([^/]*\)/module.info|\1|' | tr '\n' ' ')
echo "${WEBMIN_USER}: ${MODULES}" > ${CONFIG_DIR}/webmin.acl

# ── Archivo de versión
echo "${WEBMIN_VERSION}" > ${CONFIG_DIR}/version
cp ${CONFIG_DIR}/version ${WADIR}/version 2>/dev/null || true

# ── Insertar ruta de Perl en scripts CGI
info "Insertando rutas de Perl en scripts..."
(cd ${WADIR} && WEBMIN_CONFIG=${CONFIG_DIR} WEBMIN_VAR=${VAR_DIR} ${PERL} -e '
use File::Find;
my $perl = "'${PERL}'";
find(sub {
    return unless -f $_ && /\.(cgi|pl)$/;
    open(F, "<", $_) or return;
    my @l = <F>;
    close(F);
    return unless @l && $l[0] =~ /^#!\/\S*perl/;
    $l[0] = "#!" . $perl . "\n";
    open(F, ">", $_) or return;
    print F @l;
    close(F);
}, ".");
') 2>/dev/null
log "Rutas de Perl configuradas"

# ── Post-instalación de módulos
info "Ejecutando post-instalación de módulos..."
(cd ${WADIR} && WEBMIN_CONFIG=${CONFIG_DIR} WEBMIN_VAR=${VAR_DIR} ${PERL} ${WADIR}/run-postinstalls.pl) 2>/dev/null || true

# ── Crear logout-flag
touch ${CONFIG_DIR}/logout-flag

# ── Ajustar permisos
chmod 600 ${CONFIG_DIR}/miniserv.users
chmod 644 ${CONFIG_DIR}/miniserv.conf
chmod 644 ${CONFIG_DIR}/config
chmod 644 ${CONFIG_DIR}/webmin.acl

# ── Configurar tema si existe
if [ -d "${WADIR}/authentic-theme" ]; then
    mkdir -p ${CONFIG_DIR}/authentic-theme
    echo "settings_right_default_tab_webmin=/" > ${CONFIG_DIR}/authentic-theme/settings.js 2>/dev/null || true
fi

log "Webmin configurado correctamente"

# ── Paso 6: Iniciar Webmin ────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Paso 6/6: Iniciando Webmin ━━━${NC}"

# Matar proceso anterior si existe
if [ -f ${VAR_DIR}/miniserv.pid ]; then
    kill $(cat ${VAR_DIR}/miniserv.pid) 2>/dev/null || true
    rm -f ${VAR_DIR}/miniserv.pid
fi
pkill -f "miniserv.pl" 2>/dev/null || true
sleep 1

# Iniciar miniserv.pl
info "Iniciando servidor Webmin en puerto ${PORT}..."
${PERL} ${WADIR}/miniserv.pl ${CONFIG_DIR}/miniserv.conf 2>${VAR_DIR}/miniserv.error &
sleep 3

# Verificar que está corriendo
if [ -f ${VAR_DIR}/miniserv.pid ] && kill -0 $(cat ${VAR_DIR}/miniserv.pid 2>/dev/null) 2>/dev/null; then
    log "Webmin está corriendo (PID: $(cat ${VAR_DIR}/miniserv.pid))"
elif pgrep -f "miniserv.pl" > /dev/null 2>&1; then
    log "Webmin está corriendo"
else
    warn "Webmin no pudo iniciar. Log de error:"
    cat ${VAR_DIR}/miniserv.error 2>/dev/null || echo "Sin log disponible"
    echo ""
    warn "Intenta iniciar manualmente: webmin-start"
fi

# ── Crear scripts de conveniencia ──────────────────────────
cat > /usr/local/bin/webmin-start <<'EOF'
#!/bin/bash
PERL=$(which perl)
PID_FILE="/var/webmin/miniserv.pid"
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo "Webmin ya está corriendo (PID: $(cat $PID_FILE))"
    echo "Accede en: http://localhost:10000"
else
    rm -f "$PID_FILE"
    $PERL /usr/local/webmin/miniserv.pl /etc/webmin/miniserv.conf 2>/var/webmin/miniserv.error &
    sleep 2
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Webmin iniciado (PID: $(cat $PID_FILE))"
        echo "Accede en: http://localhost:10000"
    else
        echo "Error al iniciar. Revisa: cat /var/webmin/miniserv.error"
    fi
fi
EOF
chmod +x /usr/local/bin/webmin-start

cat > /usr/local/bin/webmin-stop <<'EOF'
#!/bin/bash
PID_FILE="/var/webmin/miniserv.pid"
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
    echo "Webmin detenido"
else
    pkill -f "miniserv.pl" 2>/dev/null && echo "Webmin detenido" || echo "Webmin no estaba corriendo"
fi
EOF
chmod +x /usr/local/bin/webmin-stop

cat > /usr/local/bin/webmin-restart <<'EOF'
#!/bin/bash
webmin-stop
sleep 1
webmin-start
EOF
chmod +x /usr/local/bin/webmin-restart

cat > /usr/local/bin/webmin-status <<'EOF'
#!/bin/bash
PID_FILE="/var/webmin/miniserv.pid"
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo "Webmin ACTIVO (PID: $(cat $PID_FILE)) - http://localhost:10000"
else
    echo "Webmin INACTIVO - Usa: webmin-start"
fi
EOF
chmod +x /usr/local/bin/webmin-status

# ── Limpiar temporales ─────────────────────────────────────
rm -rf /tmp/webmin-current.tar.gz /tmp/webmin-[0-9]* 2>/dev/null

# ── Resumen ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${BOLD}¡Webmin instalado exitosamente!${NC}${GREEN}                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}URL:${NC}      http://localhost:10000                     ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Usuario:${NC}  ${WEBMIN_USER}                                       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Versión:${NC}  ${WEBMIN_VERSION}                                     ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}SSL:${NC}      Desactivado (compatible con proot)          ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-start${NC}    → Iniciar                            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-stop${NC}     → Detener                            ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-restart${NC}  → Reiniciar                          ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-status${NC}   → Ver estado                         ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
