#!/bin/bash
# p6-reclamar.sh — Reclama nvme0n1p6 (Ubuntu viejo, 46,6 GB) para cursalialinux.
#
#   1. Comprueba que la partición es EXACTAMENTE p6 (por UUID) y que no está montada.
#   2. Muestra qué hay dentro y EXIGE confirmación escrita antes de borrar.
#   3. Formatea ext4, etiqueta CURSALIA-ISOS.
#   4. La monta en ~/PROYECTOS-CURSALIA/cursalialinux/isos y lo deja en /etc/fstab.
#   5. Borra los restos de arranque de Ubuntu de la ESP y de la BIOS.
#   6. Regenera el menú de GRUB.
#
# NUNCA toca p1(Windows/ESP), p2, p3, p4, p5 (Windows), p7 (raíz) ni p8 (tus datos).
#
# Uso:  sudo bash p6-reclamar.sh
set -uo pipefail

# ── Datos fijos, verificados el 2026-07-25 ──────────────────────────────
P6=/dev/nvme0n1p6
UUID_ESPERADO=1bb7c0a0-cd00-4293-9117-f71cd8f4664f   # UUID actual del Ubuntu viejo
ETIQUETA=CURSALIA-ISOS
USUARIO=euflo
DESTINO=/home/euflo/PROYECTOS-CURSALIA/cursalialinux/isos
RESPALDO_FSTAB=/etc/fstab.antes-de-p6
# ────────────────────────────────────────────────────────────────────────

rojo()  { printf '\033[1;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[1;36m%s\033[0m\n' "$*"; }

abortar() { rojo "ABORTADO: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || abortar "hay que ejecutarlo con sudo."

azul "═══ PASO 1/6 · Comprobaciones de seguridad ═══"

[ -b "$P6" ] || abortar "$P6 no existe."

UUID_REAL=$(blkid -s UUID -o value "$P6" 2>/dev/null || true)
if [ "$UUID_REAL" != "$UUID_ESPERADO" ]; then
  rojo "El UUID de $P6 no es el esperado."
  echo "   esperado: $UUID_ESPERADO"
  echo "   real:     ${UUID_REAL:-(vacío)}"
  abortar "las particiones cambiaron. Revisa 'lsblk -f' antes de seguir."
fi
verde "✓ $P6 es la partición del Ubuntu viejo (UUID coincide)."

if findmnt -S "$P6" >/dev/null 2>&1; then
  abortar "$P6 está montada. Desmóntala primero: sudo umount $P6"
fi
verde "✓ no está montada."

RAIZ=$(findmnt -no SOURCE /)
[ "$RAIZ" != "$P6" ] || abortar "¡$P6 es la raíz del sistema! No se toca."
verde "✓ la raíz es $RAIZ (intacta)."

azul ""
azul "═══ PASO 2/6 · Qué se va a BORRAR ═══"
TMP=$(mktemp -d)
if mount -o ro "$P6" "$TMP" 2>/dev/null; then
  echo "Sistema que hay dentro:"
  grep PRETTY_NAME "$TMP/etc/os-release" 2>/dev/null || echo "  (no parece un sistema instalado)"
  echo
  echo "Ocupación:"
  df -h "$TMP" | tail -1
  echo
  echo "Carpetas personales y su tamaño:"
  du -sh "$TMP"/home/* 2>/dev/null || echo "  (ninguna)"
  echo
  echo "Archivos de más de 100 MB en /home, /root, /srv, /opt:"
  find "$TMP/home" "$TMP/root" "$TMP/srv" "$TMP/opt" -xdev -type f -size +100M \
       -printf '  %10s bytes  %p\n' 2>/dev/null | sort -rn | head -20 \
       || echo "  (ninguno)"
  umount "$TMP"
else
  echo "(no se pudo montar para inspeccionar; puede estar vacía o dañada)"
fi
rmdir "$TMP" 2>/dev/null || true

echo
rojo "TODO lo anterior se BORRARÁ de forma irreversible."
echo "Si hay algo que quieras salvar, corta ahora con Ctrl+C,"
echo "cópialo (sudo mount -o ro $P6 /mnt) y vuelve luego."
echo
printf 'Para continuar escribe exactamente  BORRAR P6  y pulsa Enter: '
read -r RESPUESTA
[ "$RESPUESTA" = "BORRAR P6" ] || abortar "no se confirmó (escribiste: '$RESPUESTA')."

azul ""
azul "═══ PASO 3/6 · Formateando ext4 ═══"
wipefs -a "$P6" >/dev/null || abortar "wipefs falló."
mkfs.ext4 -F -m 1 -L "$ETIQUETA" "$P6" || abortar "mkfs.ext4 falló."
UUID_NUEVO=$(blkid -s UUID -o value "$P6")
verde "✓ formateada. Etiqueta: $ETIQUETA · UUID nuevo: $UUID_NUEVO"

azul ""
azul "═══ PASO 4/6 · Montaje permanente en $DESTINO ═══"

# Si la carpeta destino tiene algo dentro, se aparta para no ocultarlo.
mkdir -p "$DESTINO"
if [ -n "$(ls -A "$DESTINO" 2>/dev/null)" ]; then
  APARTADO="${DESTINO}-contenido-anterior"
  mv "$DESTINO" "$APARTADO"
  mkdir -p "$DESTINO"
  rojo "La carpeta destino tenía archivos: los moví a $APARTADO"
fi

cp -a /etc/fstab "$RESPALDO_FSTAB"
verde "✓ respaldo de fstab en $RESPALDO_FSTAB"

# Limpia cualquier línea previa de esta partición o de este destino.
sed -i "\#$DESTINO#d" /etc/fstab
sed -i "/$UUID_ESPERADO/d" /etc/fstab

cat >> /etc/fstab <<EOF

# nvme0n1p6 — antes Ubuntu viejo, reclamada el $(date '+%Y-%m-%d') para ISOs de cursalialinux
UUID=$UUID_NUEVO $DESTINO ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
EOF
verde "✓ línea añadida a /etc/fstab (con 'nofail': si falla, el arranque NO se rompe)"

systemctl daemon-reload
mount "$DESTINO" || abortar "no se pudo montar $DESTINO. Revisa /etc/fstab (respaldo en $RESPALDO_FSTAB)."
chown "$USUARIO:$USUARIO" "$DESTINO"
chmod 755 "$DESTINO"
verde "✓ montada y con dueño $USUARIO:"
df -h "$DESTINO" | tail -1

azul ""
azul "═══ PASO 5/6 · Limpiando el arranque de Ubuntu ═══"

# Antes de borrar nada, hay que confirmar que SÍ existe el arranque propio.
PROPIO=""
for d in /efi/EFI/*/; do
  n=$(basename "$d")
  case "${n,,}" in
    debian|cursalialinux|boot) PROPIO="$n" ;;
  esac
done

if [ -z "$PROPIO" ]; then
  rojo "No encontré la carpeta de arranque de cursalialinux/Debian en la ESP."
  rojo "Por precaución NO borro nada del arranque. p6 ya quedó reclamada."
else
  verde "✓ arranque propio presente: /efi/EFI/$PROPIO"

  if [ -d /efi/EFI/ubuntu ]; then
    LIB=$(du -sh /efi/EFI/ubuntu | cut -f1)
    tar -czf "/root/respaldo-efi-ubuntu-$(date +%Y%m%d).tar.gz" -C /efi/EFI ubuntu 2>/dev/null \
      && verde "✓ respaldo previo: /root/respaldo-efi-ubuntu-$(date +%Y%m%d).tar.gz"
    rm -rf /efi/EFI/ubuntu
    verde "✓ borrada /efi/EFI/ubuntu (libera $LIB)"
  else
    echo "  (no había /efi/EFI/ubuntu)"
  fi

  if command -v efibootmgr >/dev/null; then
    echo "  Entradas UEFI actuales:"
    efibootmgr | sed 's/^/    /'
    # Borra sólo entradas cuyo nombre contenga 'ubuntu' (sin distinguir mayúsculas).
    while read -r NUM NOMBRE; do
      [ -n "$NUM" ] || continue
      echo "  → borrando entrada UEFI Boot$NUM ($NOMBRE)"
      efibootmgr -b "$NUM" -B >/dev/null
    done < <(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? \(.*[Uu][Bb][Uu][Nn][Tt][Uu].*\)$/\1 \2/p')
    echo "  Entradas UEFI después:"
    efibootmgr | sed 's/^/    /'
  else
    echo "  (efibootmgr no instalado: instálalo con 'apt install efibootmgr' si quieres limpiar la BIOS)"
  fi
fi

echo
echo "Espacio en la ESP ahora:"
df -h /efi | tail -1

azul ""
azul "═══ PASO 6/6 · Regenerando el menú de GRUB ═══"
if command -v update-grub >/dev/null; then
  update-grub
elif command -v grub-mkconfig >/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
else
  rojo "GRUB no encontrado; salta este paso."
fi

echo
verde "══════════════════════════════════════════════════════"
verde " LISTO"
verde "══════════════════════════════════════════════════════"
echo " p6 (46,6 GB) → ext4 '$ETIQUETA' montada en:"
echo "   $DESTINO"
echo " Se monta sola en cada arranque (UUID=$UUID_NUEVO)."
echo " Respaldo de fstab: $RESPALDO_FSTAB"
echo
echo " Comprueba con:  lsblk -f  ·  df -h  ·  findmnt $DESTINO"
