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

# 4. Reiniciar
```bash
webmin-restart
```
