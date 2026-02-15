#!/bin/bash
# ============================================================
#  Webmin Installer para Rocky Linux (proot-distro/Termux)
# ============================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Webmin Installer - Rocky Linux         ║"
echo "║   Panel Web en puerto 10000              ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Matar cockpit si está corriendo ────────────────────────
pkill cockpit-ws 2>/dev/null || true

# ── Pedir credenciales ─────────────────────────────────────
echo -e "${CYAN}[i]${NC} Configuración de acceso a Webmin"
echo ""
read -p "Usuario admin: " WEBMIN_USER
WEBMIN_USER=${WEBMIN_USER:-admin}
read -s -p "Contraseña: " WEBMIN_PASS
echo ""

echo ""
echo -e "${BOLD}━━━ Paso 1/4: Instalando dependencias ━━━${NC}"
dnf install -y perl perl-Net-SSLeay perl-Data-Dumper wget tar openssl
echo -e "${GREEN}[✓]${NC} Dependencias instaladas"

echo ""
echo -e "${BOLD}━━━ Paso 2/4: Descargando Webmin ━━━${NC}"
cd /tmp
rm -rf webmin-2.111* 2>/dev/null
wget -q --show-progress https://github.com/webmin/webmin/releases/download/2.111/webmin-2.111-minimal.tar.gz
echo -e "${GREEN}[✓]${NC} Descarga completada"

echo ""
echo -e "${BOLD}━━━ Paso 3/4: Instalando Webmin ━━━${NC}"
mkdir -p /usr/local
rm -rf /usr/local/webmin 2>/dev/null
tar xzf webmin-2.111-minimal.tar.gz
mv webmin-2.111 /usr/local/webmin

# Configuración automática (sin interacción)
mkdir -p /etc/webmin /var/webmin

cat > /etc/webmin/config <<EOF
port=10000
ssl=0
login=$WEBMIN_USER
logfile=/var/webmin/miniserv.log
pidfile=/var/webmin/miniserv.pid
logtime=168
pam=0
logout=/etc/webmin/logout-flag
listen=10000
log=1
blockhost_failures=3
blockhost_time=60
syslog=1
session=1
premodules=WebminCore
server=MiniServ/2.111
realm=Webmin Server
EOF

cat > /etc/webmin/miniserv.conf <<EOF
port=10000
root=/usr/local/webmin
mimetypes=/usr/local/webmin/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=/var/webmin/miniserv.log
errorlog=/var/webmin/miniserv.error
pidfile=/var/webmin/miniserv.pid
logtime=168
pam=0
ssl=0
env_WEBMIN_CONFIG=/etc/webmin
env_WEBMIN_VAR=/var/webmin
atboot=0
logout=/etc/webmin/logout-flag
listen=10000
log=1
blockhost_failures=3
blockhost_time=60
syslog=1
session=1
premodules=WebminCore
server=MiniServ/2.111
userfile=/etc/webmin/miniserv.users
keyfile=/etc/webmin/miniserv.pem
passwd_file=/etc/shadow
passwd_uindex=0
passwd_pindex=1
passwd_cindex=2
passwd_mindex=4
passwd_mode=0
preroot=$WEBMIN_USER=authentic-theme
EOF

# Crear usuario admin
CRYPTED=$(perl -e "print crypt('$WEBMIN_PASS', '\$6\$saltsalt\$');")
echo "${WEBMIN_USER}:${CRYPTED}:0" > /etc/webmin/miniserv.users

# Permisos del usuario
cat > /etc/webmin/webmin.acl <<EOF
${WEBMIN_USER}: acl adsl-client ajaxterm apache at backup-config bacula-backup bandwidth bind8 burner certmgr change-user cluster-copy cluster-cron cluster-passwd cluster-shell cluster-software cluster-useradmin cluster-usermin cluster-webmin cpan cron custom dfsadmin dhcpd dovecot exim exports fail2ban fdisk fetchmail file filemin filter firewall firewall6 firewalld fsdump grub heartbeat htaccess-htpasswd idmapd inetd init inittab ipfilter ipfw ipsec iscsi-client iscsi-server iscsi-target iscsi-tgtd jabber krb5 ldap-client ldap-server ldap-useradmin logrotate lpadmin lvm mailboxes mailcap man mon mount mysql net nis openslp package-updates pam pap passwd phpini postfix postgresql ppp-client pptp-client pptp-server proc procmail proftpd qmailadmin quota raid read-user-attr ruby-gems running-config samba sarg sendmail servers shell shorewall shorewall6 smart-status smf software spam squid sshd status stunnel syslog syslog-ng system-status tcpwrappers telnet time tunnel updown useradmin usermin vgetty virtual-server virtualmin-awstats virtualmin-dav virtualmin-git virtualmin-htpasswd virtualmin-init virtualmin-mailman virtualmin-nginx virtualmin-nginx-ssl virtualmin-registrar virtualmin-slavedns virtualmin-sqlite webmin webmincron webminlog webalizer xinetd xterm
EOF

# Crear directorio var
mkdir -p /var/webmin/sessions
echo "1" > /etc/webmin/version

echo -e "${GREEN}[✓]${NC} Webmin configurado"

echo ""
echo -e "${BOLD}━━━ Paso 4/4: Iniciando Webmin ━━━${NC}"
/usr/local/webmin/miniserv.pl /etc/webmin/miniserv.conf &
sleep 2

# Verificar que está corriendo
if curl -s http://localhost:10000 > /dev/null 2>&1; then
    echo -e "${GREEN}[✓]${NC} Webmin está corriendo"
else
    echo -e "${YELLOW}[!]${NC} Iniciando con método alternativo..."
    perl /usr/local/webmin/miniserv.pl /etc/webmin/miniserv.conf &
    sleep 2
fi

# Limpiar archivos temporales
rm -rf /tmp/webmin-2.111* 2>/dev/null

# ── Script de inicio/detención ─────────────────────────────
cat > /usr/local/bin/webmin-start <<'STARTEOF'
#!/bin/bash
echo "Iniciando Webmin..."
/usr/local/webmin/miniserv.pl /etc/webmin/miniserv.conf &
sleep 1
echo "Webmin corriendo en http://localhost:10000"
STARTEOF
chmod +x /usr/local/bin/webmin-start

cat > /usr/local/bin/webmin-stop <<'STOPEOF'
#!/bin/bash
echo "Deteniendo Webmin..."
kill $(cat /var/webmin/miniserv.pid 2>/dev/null) 2>/dev/null
echo "Webmin detenido"
STOPEOF
chmod +x /usr/local/bin/webmin-stop

# ── Resumen ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${BOLD}¡Webmin instalado exitosamente!${NC}${GREEN}                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Acceso:${NC} http://localhost:10000                        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Usuario:${NC} ${WEBMIN_USER}                                        ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-start${NC}  → Iniciar Webmin                       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${CYAN}webmin-stop${NC}   → Detener Webmin                       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
