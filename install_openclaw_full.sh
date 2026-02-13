#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "==============================="
echo " OPENCLAW FULL INSTALLER"
echo " TERMUX + DEBIAN PROOT"
echo "==============================="

echo "[1/6] Actualizando Termux..."
pkg update -y && pkg upgrade -y
pkg install -y proot-distro git curl zstd unzip build-essential

echo "[2/6] Instalando Debian (si no existe)..."
proot-distro install debian || true

echo "[3/6] Configurando Debian e instalando dependencias..."

proot-distro login debian -- bash -c '

set -e

echo "Configurando DNS..."
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf

apt update -y
apt install -y curl git cmake build-essential unzip xdg-utils nano

cd /root

echo "[4/6] Instalando Node.js v25 ARM64..."
NODE_URL=$(curl -s https://nodejs.org/dist/latest-v25.x/ | grep linux-arm64.tar.xz | head -n 1 | cut -d "\"" -f 2)

curl -O https://nodejs.org/dist/latest-v25.x/$NODE_URL
tar -xJf $NODE_URL
rm $NODE_URL
mv node-v25.* node

echo "export PATH=/root/node/bin:\$PATH" >> /root/.bashrc
export PATH=/root/node/bin:$PATH

node -v
npm -v

echo "[5/6] Instalando OpenClaw..."
npm install -g openclaw

OPENCLAW_PATH=$(npm root -g)

echo "[6/6] Aplicando parche networkInterfaces..."

node -e "
const fs=require('fs');
const os=require('os');
fs.writeFileSync('/root/ni.json', JSON.stringify(os.networkInterfaces(), null, 2));
"

find $OPENCLAW_PATH -type f -name "*.js" -exec sed -i \
"s/os.networkInterfaces()/JSON.parse(require(\"fs\").readFileSync(\"\\/root\\/ni.json\"))/g" {} +

echo "Parche aplicado."

echo "Configurando xdg-open override..."
mv /usr/bin/xdg-open /usr/bin/xdg-open.bak 2>/dev/null || true
echo -e "#!/bin/sh\necho \$@ > /root/auth_url.txt" > /usr/bin/xdg-open
chmod +x /usr/bin/xdg-open

echo "Creando alias útiles..."
echo "alias openclaw-start=\"node \$(which openclaw) gateway\"" >> /root/.bashrc
echo "alias openclaw-onboard=\"node \$(which openclaw) onboard\"" >> /root/.bashrc

echo "Instalación completa dentro de Debian."
'

echo ""
echo "==============================================="
echo " INSTALACIÓN COMPLETA"
echo "==============================================="
echo ""
echo "Para usar:"
echo "1) proot-distro login debian"
echo "2) source ~/.bashrc"
echo "3) openclaw-onboard"
echo "4) Revisa la URL en: cat /root/auth_url.txt"
echo "5) openclaw-start"
echo ""
echo "Panel en:"
echo "http://localhost:18789"
echo ""
echo "==============================================="
