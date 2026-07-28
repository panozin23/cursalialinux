#!/bin/sh
# ================================================================
#  Limpieza PROFUNDA del sistema (se ejecuta como root vía pkexec)
# ================================================================
echo "== Limpiando paquetes descargados =="
apt-get clean

echo "== Quitando paquetes huérfanos (autoremove) =="
DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y

echo "== Vaciando registros del sistema (journal, >3 días) =="
journalctl --vacuum-time=3d 2>/dev/null

echo "== Borrando temporales del sistema =="
rm -rf /tmp/* /var/tmp/* 2>/dev/null

echo "== Borrando registros antiguos comprimidos =="
find /var/log -type f \( -name "*.gz" -o -name "*.old" -o -name "*.1" -o -name "*.2" \) -delete 2>/dev/null

echo "== Vaciando logs grandes (sin borrarlos) =="
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null

echo "== Limpiando cachés de miniaturas de todos los usuarios =="
rm -rf /home/*/.cache/thumbnails/* /root/.cache/thumbnails/* 2>/dev/null

echo "OK — limpieza profunda terminada."
exit 0
