#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "=================================="
echo " OPENCLAW FULL INSTALLER v2"
echo " TERMUX + DEBIAN PROOT"
echo "=================================="

echo "[1/7] Actualizando Termux..."
pkg update -y && pkg upgrade -y
pkg install -y proot-distro git curl zstd unzip build-essential jq

echo "[2/7] Instalando Debian (si no existe)..."
proot-distro install debian || true

echo "[3/7] Configurando Debian..."

proot-distro login debian -- bash -c '

set -e

echo "Configurando DNS..."
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf

apt update -y
apt install -y curl git cmake build-essential unzip xdg-utils nano jq

cd /root

echo "[4/7] Detectando arquitectura..."
ARCH=$(uname -m)

if [ "$ARCH" = "aarch64" ]; then
    NODE_ARCH="linux-arm64"
elif [ "$ARCH" = "x86_64" ]; then
    NODE_ARCH="linux-x64"
else
    echo "Arquitectura no soportada: $ARCH"
    exit 1
fi

echo "Arquitectura detectada: $NODE_ARCH"

echo "[5/7] Obteniendo última versión estable de Node v25..."
NODE_VERSION=$(curl -s https://nodejs.org/dist/index.json | jq -r "[.[] | select(.version | startswith(\"v25.\"))][0].version")

if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" = "null" ]; then
    echo "No se pudo obtener versión de Node v25"
    exit 1
fi

echo "Descargando Node $NODE_VERSION..."

NODE_FILE="node-$NODE_VERSION-$NODE_ARCH.tar.xz"
NODE_URL="https://nodejs.org/dist/$NODE_VERSION/$NODE_FILE"

echo "URL: $NODE_URL"

curl -f -O $NODE_URL

if [ ! -f "$NODE_FILE" ]; then
    echo "Error: archivo no descargado."
    exit 1
fi

echo "Extrayendo..."
tar -xJf $NODE_FILE
rm $NODE_FILE

mv node-$NODE_VERSION-$NODE_ARCH node

echo "export PATH=/root/node/bin:\$PATH" >> /root/.bashrc
export PATH=/root/node/bin:$PATH

echo "Verificando Node..."
node -v
npm -v

echo "[6/7] Instalando OpenClaw..."
npm install -g openclaw

OPENCLAW_PATH=$(npm root -g)

echo "[7/7] Aplicando parche networkInterfaces..."

node -e "
const fs=require('fs');
const os=require('os');
fs.writeFileSync('/root/ni.json', JSON.stringify(os.networkInterfaces(), null, 2));
"

find $OPENCLAW_PATH -type f -name "*.js" -exec sed -i \
"s/os.networkInterfaces()/JSON.parse(require(\"fs\").readFileSync(\"\\/root\\/ni.json\"))/g" {} +

echo "Parche aplicado."

echo "Configurando override xdg-open..."
mv /usr/bin/xdg-open /usr/bin/xdg-open.bak 2>/dev/null || true
echo -e "#!/bin/sh\necho \$@ > /root/auth_url.txt" > /usr/bin/xdg-open
chmod +x /usr/bin/xdg-open

echo "Creando alias útiles..."
echo "alias openclaw-start=\"node \$(which openclaw) gateway\"" >> /root/.bashrc
echo "alias openclaw-onboard=\"node \$(which openclaw) onboard\"" >> /root/.bashrc

echo "Instalación completada dentro de Debian."
'

echo ""
echo "=================================="
echo " INSTALACIÓN COMPLETADA"
echo "=================================="
echo ""
echo "Para usar:"
echo "proot-distro login debian"
echo "source ~/.bashrc"
echo "openclaw-onboard"
echo "cat /root/auth_url.txt"
echo "openclaw-start"
echo ""
echo "Panel: http://localhost:18789"
echo ""
echo "=================================="
