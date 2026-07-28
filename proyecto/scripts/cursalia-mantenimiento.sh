#!/bin/bash
# cursalia-mantenimiento.sh — Limpieza automática nocturna de cursalialinux.
#
# Se ejecuta solo, cada noche a las 2 de la madrugada. Si el equipo estaba
# apagado a esa hora, la tarea se recupera en el siguiente encendido.
#
# El usuario no tiene que hacer NADA. Esa es la idea: la distro se mantiene
# rápida sola, en vez de esperar que alguien se acuerde de limpiarla.
#
# Uso manual (por si alguien quiere adelantarlo):
#     sudo cursalia-mantenimiento.sh
#     sudo cursalia-mantenimiento.sh --ver    → solo informa, no borra nada
set -u

SOLO_VER=0
[ "${1:-}" = "--ver" ] && SOLO_VER=1

[ "$(id -u)" -eq 0 ] || { echo "ERROR: ejecutar con sudo."; exit 1; }

hacer(){ [ "$SOLO_VER" -eq 1 ] && echo "   (solo mirando) $1" || eval "$2" >/dev/null 2>&1; }
libre(){ df --output=avail -BM / | tail -1 | tr -dc '0-9'; }

ANTES=$(libre)
echo "══════════════════════════════════════════════"
echo " MANTENIMIENTO cursalialinux — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"
[ "$SOLO_VER" -eq 1 ] && echo " MODO INFORME: no se borra nada."

# ── 1. Paquetes que ya nadie usa ─────────────────────────────────────
# Incluye los núcleos antiguos, que ocupan ~300 MB cada uno.
echo
echo "── Paquetes sin usar ──"
N=$(apt-get -s autoremove --purge 2>/dev/null | grep -c '^Remv' || true)
echo "   a eliminar: ${N:-0}"
hacer "apt-get autoremove --purge -y" "DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y"

# ── 2. Paquetes descargados que ya se instalaron ─────────────────────
echo
echo "── Caché de descargas ──"
echo "   ocupa: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
hacer "apt-get clean" "apt-get clean"

# ── 3. Registros del sistema ─────────────────────────────────────────
echo
echo "── Registros del sistema ──"
echo "   ocupan: $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[MG]' | head -1)"
hacer "journalctl --vacuum-time=14d" "journalctl --vacuum-time=14d"

# ── 4. Miniaturas y cachés de cada usuario ───────────────────────────
echo
echo "── Miniaturas de imágenes ──"
T=0
for h in /home/*; do
  [ -d "$h" ] || continue
  for c in "$h/.cache/thumbnails" "$h/.thumbnails"; do
    [ -d "$c" ] || continue
    k=$(du -sk "$c" 2>/dev/null | cut -f1); T=$((T + ${k:-0}))
    # Solo las que no se han abierto en un mes: las recientes se siguen usando
    hacer "limpiar $c" "find '$c' -type f -atime +30 -delete"
  done
done
echo "   ocupan: $((T/1024)) MB"

# ── 5. Papelera con más de 30 días ───────────────────────────────────
echo
echo "── Papelera (más de 30 días) ──"
V=0
for h in /home/*; do
  d="$h/.local/share/Trash/files"
  [ -d "$d" ] || continue
  v=$(find "$d" -mindepth 1 -mtime +30 2>/dev/null | wc -l); V=$((V+v))
  hacer "vaciar lo viejo de $d" "find '$d' -mindepth 1 -mtime +30 -exec rm -rf {} + 2>/dev/null"
done
echo "   elementos antiguos: $V"

# ── 6. Informes de fallos antiguos ───────────────────────────────────
echo
echo "── Informes de fallos ──"
hacer "limpiar /var/crash" "find /var/crash -type f -mtime +7 -delete 2>/dev/null"
echo "   revisado"

DESPUES=$(libre)
echo
echo "══════════════════════════════════════════════"
if [ "$SOLO_VER" -eq 1 ]; then
  echo " Nada se modificó. Para limpiar de verdad:"
  echo "   sudo cursalia-mantenimiento.sh"
else
  G=$(( DESPUES - ANTES ))
  [ "$G" -gt 0 ] && echo " Espacio recuperado: ${G} MB" || echo " El sistema ya estaba limpio."
  echo " Espacio libre ahora: $((DESPUES/1024)) GB"
fi
echo "══════════════════════════════════════════════"
