#!/bin/bash
# ================================================================
#  Buscador de imágenes libres (uso comercial) — cursalialinux
#  Usa Openverse (Creative Commons / dominio público). Sin claves.
#  Filtra por licencia comercial: TODO lo que muestra es seguro.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
API="https://api.openverse.org/v1/images/"
UA="cursalialinux/1.0"

guia() {
  yad --title="Guía de licencias — cursalialinux" --window-icon="$LOGO" --image="$LOGO" --center --width=560 \
    --text="<big><b>📜 Cómo usar imágenes sin problemas legales</b></big>

Este buscador solo muestra imágenes de <b>uso comercial</b>. Aun así, 3 reglas de oro:

  <b>1.</b> Algunas piden <b>dar crédito</b> al autor (atribución). La columna <b>Licencia</b> te lo indica:
        • <b>CC0 / PDM</b> = libre total, sin crédito.
        • <b>CC-BY</b> = puedes usarla, pero <b>debes dar crédito</b>.
  <b>2.</b> <b>Personas reconocibles, marcas, logos o productos</b> dentro de la foto
        pueden tener derechos aparte, aunque la foto sea libre.
  <b>3.</b> Ante la duda, abre la página de origen y <b>lee la licencia</b>.

Fuentes recomendadas: Openverse · Pixabay · Pexels · Unsplash." \
    --button="Entendido:0"
}

buscar() {
  Q=$(yad --entry --title="Buscar imágenes libres" --window-icon="$LOGO" --image="$LOGO" --center --width=480 \
      --text="<big><b>🔎 Imágenes libres para uso comercial</b></big>\n\n¿Qué buscas?  <i>(en inglés da más resultados: “office”, “nature”…)</i>") || exit 0
  [ -z "$Q" ] && exit 0
  QENC=$(printf '%s' "$Q" | jq -sRr @uri)
  JSON=$(curl -s -A "$UA" "${API}?q=${QENC}&license_type=commercial&page_size=30" 2>/dev/null)
  CNT=$(printf '%s' "$JSON" | jq -r '.result_count // 0' 2>/dev/null)
  if [ -z "$JSON" ] || [ "$CNT" = "0" ] || [ "$CNT" = "null" ]; then
    yad --info --center --window-icon="$LOGO" --title="Sin resultados" \
        --text="No se encontraron imágenes para «$Q»,\no no hay conexión a internet." --button="OK:0"
    return
  fi
  ROWS=$(printf '%s' "$JSON" | jq -r '.results[] | [ (.title // "sin título"), (((.license // "") | ascii_upcase) + " " + (.license_version // "")), (.creator // "desconocido"), (.foreign_landing_url // .url) ] | @tsv' 2>/dev/null)
  URL=$(printf '%s\n' "$ROWS" | yad --list --title="Imágenes libres — $Q" --window-icon="$LOGO" --center \
      --width=840 --height=540 --separator="" --print-column=4 \
      --text="<b>✅ Todas son de uso comercial.</b>  Elige una y pulsa <b>Abrir</b> para verla y descargarla desde su fuente (ahí confirmas la licencia)." \
      --column="Título" --column="Licencia" --column="Autor" --column="url":HD \
      --button="📜 Guía de licencias:2" --button="⬅ Buscar otra:3" --button="🌐 Abrir y descargar:0")
  RET=$?
  case $RET in
    0) [ -n "$URL" ] && setsid firefox-esr "$URL" >/dev/null 2>&1 & ;;
    2) guia; buscar ;;
    3) buscar ;;
  esac
}

case "$1" in
  guia) guia ;;
  *) buscar ;;
esac
