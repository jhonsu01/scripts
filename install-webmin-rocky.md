```bash
curl -fsSL https://raw.githubusercontent.com/jhonsu01/scripts/refs/heads/main/install-webmin-rocky_v5.sh  | bash
```
```bash
perl -e "print 'root:' . crypt('TuContraseña', '\$6\$saltsalt\$') . ':0::::::::' . \"\n\"" > /etc/webmin/miniserv.users
```

```bash
sed -i 's/^[^:]*:/root:/' /etc/webmin/webmin.acl
```
```bash
webmin-restart
```

# 1. Crear el directorio que falta
```bash
mkdir -p /etc/webmin/webmin
```
# 2. Copiar config del módulo webmin
```bash
cp /usr/local/webmin/webmin/defaultacl /etc/webmin/webmin/config 2>/dev/null
```
```bash
touch /etc/webmin/webmin/config
```

# 3. Activar el tema moderno (Authentic Theme)
```bash
sed -i '/^theme=/d' /etc/webmin/config
```
```bash
echo "theme=authentic-theme" >> /etc/webmin/config
```
```bash
echo "preroot=authentic-theme" >> /etc/webmin/miniserv.conf
```

# 4. Instalar módulo de procesos
```bash
dnf install -y perl-Proc-ProcessTable 2>/dev/null || true
```
# 5. Crear config del módulo system-status para evitar el error del dashboard
```bash
mkdir -p /etc/webmin/system-status
```
```bash
cat > /etc/webmin/system-status/config <<'EOF'
collect_interval=none
no_collect=1
collect_cron=0
EOF
```
# 6. Crear config del módulo proc
```bash
mkdir -p /etc/webmin/proc
```
```bash
cat > /etc/webmin/proc/config <<'EOF'
listing_type=1
EOF
```

# 7. Reiniciar
```bash
webmin-restart
```
