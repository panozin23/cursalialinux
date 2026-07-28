#!/bin/bash
# ================================================================
#  Convertir y optimizar imágenes — cursalialinux
#  A WebP (ligero) y AVIF (el más ligero). Muestra cuánto ahorró.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

falta_pkg() {
  yad --question --center --class=cursaliacentro --width=460 --window-icon="$LOGO" --image="$LOGO" \
    --title="Falta un componente" \
    --text="Para convertir imágenes se necesita <b>$1</b>.\n¿Instalarlo ahora? (necesita internet)" || return 1
  xfce4-terminal --title="Instalar $1" --hold -e "bash -c 'pkexec apt-get install -y $2; echo; echo Listo. Cierra esta ventana y vuelve a abrir la herramienta.'"
  return 1
}

# comprobar conversores
command -v cwebp   >/dev/null 2>&1 || { falta_pkg "WebP" "webp"; exit 0; }
command -v avifenc >/dev/null 2>&1 || { falta_pkg "AVIF" "libavif-bin"; exit 0; }

# 1) elegir imágenes
FILES=$(yad --file --multiple --class=cursaliacentro --title="Elige las imágenes a convertir" \
  --window-icon="$LOGO" --width=820 --height=520 \
  --file-filter="Imágenes | *.jpg *.jpeg *.JPG *.JPEG *.png *.PNG *.bmp *.BMP *.tiff *.tif *.webp" \
  --file-filter="Todos los archivos | *" --separator="|") || exit 0
[ -z "$FILES" ] && exit 0

# 2) formato + calidad
SEL=$(yad --form --center --class=cursaliacentro --width=480 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Convertir imágenes" \
  --text="<big><b>🖼️  Convertir imágenes</b></big>
<b>AVIF</b> = el más ligero (mejor calidad/tamaño)
<b>WebP</b> = ligero, compatible con todo

Elige el formato y la calidad:" \
  --field="Formato:CB" "AVIF — el más ligero (recomendado)!WebP — ligero (compatible)" \
  --field="Calidad (mayor = mejor):NUM" "75!30..100!5" \
  --separator="|") || exit 0
FMT=$(echo "$SEL" | cut -d'|' -f1)
Q=$(echo "$SEL" | cut -d'|' -f2); Q=${Q%.*}

# 3) convertir cada una
RES=""; to=0; tn=0; nok=0
OLDIFS="$IFS"; IFS='|'
for f in $FILES; do
  IFS="$OLDIFS"
  [ -f "$f" ] || continue
  o=$(stat -c%s "$f")
  base="${f%.*}"
  case "$FMT" in
    AVIF*) out="${base}.avif"; avifenc -q "$Q" "$f" "$out" >/dev/null 2>&1 ;;
    *)     out="${base}.webp"; cwebp -q "$Q" "$f" -o "$out" >/dev/null 2>&1 ;;
  esac
  if [ -f "$out" ] && [ -s "$out" ]; then
    n=$(stat -c%s "$out"); to=$((to+o)); tn=$((tn+n)); nok=$((nok+1))
    pct=$(( o>0 ? 100 - 100*n/o : 0 ))
    RES="${RES}\n  ✅ $(basename "$f")  →  <b>$(basename "$out")</b>   ($((o/1024)) KB → $((n/1024)) KB, ${pct}% menos)"
  else
    RES="${RES}\n  ❌ $(basename "$f")  (no se pudo convertir)"
  fi
  IFS='|'
done
IFS="$OLDIFS"

# 4) resultado
if [ "$to" -gt 0 ]; then
  tpct=$(( 100 - 100*tn/to ))
  yad --info --center --class=cursaliacentro --width=680 --height=460 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="Conversión terminada" \
    --text="<big><b>✅ ${nok} imagen(es) convertida(s)</b></big>
Se guardaron <b>junto a las originales</b> (no se borró nada).
${RES}

<big><b>Total: $((to/1024)) KB → $((tn/1024)) KB  —  ahorro ${tpct}%</b></big>" \
    --button="OK:0"
else
  yad --error --center --class=cursaliacentro --width=440 --window-icon="$LOGO" \
    --title="Sin resultados" --text="No se pudo convertir ninguna imagen." --button="OK:0"
fi
