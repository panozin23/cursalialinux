#!/bin/bash
# p6-inspeccionar.sh — SOLO LECTURA. No modifica nada, no formatea nada.
# Monta nvme0n1p6 (Ubuntu viejo) en modo solo-lectura y escribe un informe.
# Uso:  sudo bash p6-inspeccionar.sh
set -u

INFORME=/tmp/informe-p6.txt
P6=/dev/nvme0n1p6
PUNTO=/mnt/p6-lectura

exec > >(tee "$INFORME") 2>&1

echo "══════════════════════════════════════════════"
echo " INFORME p6 — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ejecutar con sudo."
  exit 1
fi

echo
echo "── 1. Identidad de la partición ──"
blkid "$P6" || echo "(sin blkid)"

echo
echo "── 2. Montaje SOLO LECTURA ──"
mkdir -p "$PUNTO"
if mount -o ro,noexec,nodev "$P6" "$PUNTO"; then
  echo "montada en $PUNTO (ro)"
else
  echo "ERROR: no se pudo montar $P6"
  exit 1
fi

echo
echo "── 3. ¿Qué sistema es? ──"
cat "$PUNTO/etc/os-release" 2>/dev/null || echo "(sin /etc/os-release — puede no ser un sistema)"

echo
echo "── 4. Ocupación ──"
df -h "$PUNTO"

echo
echo "── 5. Raíz de la partición ──"
ls -la "$PUNTO"

echo
echo "── 6. Usuarios con carpeta personal ──"
ls -la "$PUNTO/home" 2>/dev/null || echo "(sin /home)"

echo
echo "── 7. Tamaño de cada carpeta personal ──"
du -sh "$PUNTO"/home/* 2>/dev/null || echo "(nada)"

echo
echo "── 8. Contenido de las carpetas personales (2 niveles) ──"
for u in "$PUNTO"/home/*; do
  [ -d "$u" ] || continue
  echo "  ▸ $u"
  find "$u" -maxdepth 2 -not -path '*/.*' -printf '     %y %10s  %p\n' 2>/dev/null | head -60
done

echo
echo "── 9. Archivos grandes (>50 MB) fuera del sistema ──"
find "$PUNTO/home" "$PUNTO/root" "$PUNTO/srv" "$PUNTO/opt" -xdev -type f -size +50M \
     -printf '%10sK  %p\n' 2>/dev/null | sort -rn | head -40 || true

echo
echo "── 10. Última vez que se usó (fecha de log) ──"
ls -la --time-style=long-iso "$PUNTO/var/log/" 2>/dev/null | tail -15

echo
echo "── 11. Desmontando ──"
umount "$PUNTO" && rmdir "$PUNTO" && echo "desmontada, sin cambios"

echo
echo "── 12. Estado de la ESP (nvme0n1p1, 100 MB) ──"
df -h /efi 2>/dev/null
echo "  Carpetas de arranque presentes:"
ls -la /efi/EFI/ 2>/dev/null
echo "  Tamaño de cada una:"
du -sh /efi/EFI/* 2>/dev/null

echo
echo "── 13. Entradas UEFI de la BIOS ──"
efibootmgr 2>/dev/null || echo "(efibootmgr no instalado)"

echo
echo "── 14. ¿GRUB tiene entradas de Ubuntu / p6? ──"
grep -n "menuentry\|nvme0n1p6\|1bb7c0a0" /boot/grub/grub.cfg 2>/dev/null | head -30 || echo "(nada)"

echo
echo "══════════════════════════════════════════════"
echo " Informe guardado en: $INFORME"
echo " NADA fue modificado."
echo "══════════════════════════════════════════════"
