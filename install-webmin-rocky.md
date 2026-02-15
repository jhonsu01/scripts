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
