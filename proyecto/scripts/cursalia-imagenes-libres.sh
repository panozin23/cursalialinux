#!/bin/bash
# ================================================================
#  Recursos libres (uso comercial) — cursalialinux
#  Imágenes y música por Openverse (CC / dominio público, sin claves).
#  Videos, fuentes e íconos: sitios gratis y comerciales recomendados.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
IMG_API="https://api.openverse.org/v1/images/"
AUD_API="https://api.openverse.org/v1/audio/"
UA="cursalialinux/1.0"
SELF="/usr/local/bin/cursalia-imagenes-libres"

guia() {
  yad --class=cursaliacentro --title="Guía de licencias — cursalialinux" --window-icon="$LOGO" --image="$LOGO" --center --width=580 \
    --text="<big><b>📜 Cómo usar recursos sin problemas legales</b></big>

Todo lo que muestra este buscador es de <b>uso comercial</b>. Aun así, 3 reglas de oro:

  <b>1.</b> Algunos piden <b>dar crédito</b> al autor (atribución). Mira la columna <b>Licencia</b>:
        • <b>CC0 / PDM</b> = libre total, sin crédito.
        • <b>CC-BY</b> = puedes usarlo, pero <b>debes dar crédito</b>.
  <b>2.</b> <b>Personas reconocibles, marcas, logos o productos</b> pueden tener derechos aparte.
  <b>3.</b> Ante la duda, abre la página de origen y <b>lee la licencia</b>.

Fuentes: Openverse · Pixabay · Pexels · Unsplash · Google Fonts · Mixkit." \
    --button="Entendido:0"
}

# Buscador Openverse genérico. $1=API $2=título $3=arg-de-vuelta
buscar_openverse() {
  local api="$1" titulo="$2" volver="$3"
  local Q QENC JSON CNT ROWS URL RET
  Q=$(yad --entry --class=cursaliacentro --title="$titulo" --window-icon="$LOGO" --image="$LOGO" --center --width=500 \
      --text="<big><b>🔎 $titulo</b></big>\n\n¿Qué buscas?  <i>(en inglés da más resultados: “office”, “happy music”…)</i>") || { menu; return; }
  [ -z "$Q" ] && { menu; return; }
  QENC=$(printf '%s' "$Q" | jq -sRr @uri)
  JSON=$(curl -s -4 --max-time 25 -A "$UA" "${api}?q=${QENC}&license_type=commercial&page_size=30" 2>/dev/null)
  CNT=$(printf '%s' "$JSON" | jq -r '.result_count // 0' 2>/dev/null)
  if [ -z "$JSON" ] || [ "$CNT" = "0" ] || [ "$CNT" = "null" ]; then
    yad --info --center --class=cursaliacentro --window-icon="$LOGO" --title="Sin resultados" \
        --text="No se encontró nada para «$Q»,\no no hay conexión a internet." --button="OK:0"
    "$SELF" "$volver"; return
  fi
  ROWS=$(printf '%s' "$JSON" | jq -r '.results[] | [ (.title // "sin título"), (((.license // "") | ascii_upcase) + " " + (.license_version // "")), (.creator // "desconocido"), (.foreign_landing_url // .url) ] | @tsv' 2>/dev/null)
  URL=$(printf '%s\n' "$ROWS" | yad --list --class=cursaliacentro --title="$titulo — $Q" --window-icon="$LOGO" --center \
      --width=860 --height=560 --separator="" --print-column=4 \
      --text="<b>✅ Todo es de uso comercial.</b>  Elige uno y pulsa <b>Abrir</b> para verlo y descargarlo desde su fuente (ahí confirmas la licencia)." \
      --column="Título" --column="Licencia" --column="Autor" --column="url":HD \
      --button="📜 Guía:2" --button="⬅ Menú:3" --button="🌐 Abrir y descargar:0")
  RET=$?
  case $RET in
    0) [ -n "$URL" ] && { setsid firefox-esr "$URL" >/dev/null 2>&1 & }; "$SELF" "$volver" ;;
    2) guia; "$SELF" "$volver" ;;
    3) menu ;;
  esac
}

buscar() { buscar_openverse "$IMG_API" "Imágenes libres" imagenes; }
audio()  { buscar_openverse "$AUD_API" "Música y sonidos libres" audio; }

# Sitios de recursos gratis y comerciales (abre en el navegador)
enlaces() {
  yad --form --class=cursaliacentro --center --width=560 --height=540 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="Más recursos libres" \
    --text="<big><b>🌐  Sitios de recursos gratis (uso comercial)</b></big>\nElige uno para abrirlo en el navegador:" \
    --columns=1 \
    --field="🎥  Videos — Pexels Videos!video-x-generic:fbtn"        "bash -c 'setsid firefox-esr https://www.pexels.com/es-es/videos/ >/dev/null 2>&1 &'" \
    --field="🎥  Videos — Mixkit (clips gratis)!video-x-generic:fbtn" "bash -c 'setsid firefox-esr https://mixkit.co/free-stock-video/ >/dev/null 2>&1 &'" \
    --field="🎥  Videos — Pixabay!video-x-generic:fbtn"              "bash -c 'setsid firefox-esr https://pixabay.com/es/videos/ >/dev/null 2>&1 &'" \
    --field="🎵  Música — Pixabay Music!audio-x-generic:fbtn"         "bash -c 'setsid firefox-esr https://pixabay.com/es/music/ >/dev/null 2>&1 &'" \
    --field="🎵  Música — Mixkit (canciones/efectos)!audio-x-generic:fbtn" "bash -c 'setsid firefox-esr https://mixkit.co/free-stock-music/ >/dev/null 2>&1 &'" \
    --field="🔤  Fuentes — Google Fonts!font-x-generic:fbtn"          "bash -c 'setsid firefox-esr https://fonts.google.com/ >/dev/null 2>&1 &'" \
    --field="🔤  Fuentes — Fontshare!font-x-generic:fbtn"             "bash -c 'setsid firefox-esr https://www.fontshare.com/ >/dev/null 2>&1 &'" \
    --field="🎨  Íconos — Tabler Icons!image-x-generic:fbtn"          "bash -c 'setsid firefox-esr https://tabler.io/icons >/dev/null 2>&1 &'" \
    --field="🎨  Íconos — SVG Repo!image-x-generic:fbtn"              "bash -c 'setsid firefox-esr https://www.svgrepo.com/ >/dev/null 2>&1 &'" \
    --button="⬅ Menú:3" --button="Cerrar:1"
  [ $? = 3 ] && menu
}

menu() {
  pkill -f "class=cursaliacentro" 2>/dev/null; sleep 0.15
  yad --class=cursaliacentro --title="Recursos libres — cursalialinux" --center --width=580 --height=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🎁  Recursos libres para tus proyectos</b></big>
Imágenes, música, videos, fuentes e íconos — <b>gratis y de uso comercial</b>.

Elige una opción:" \
    --form --columns=1 \
    --field="🖼️   Imágenes libres (buscar y descargar)!image-x-generic:fbtn"      "bash -c '$SELF imagenes &'" \
    --field="🎵  Música y efectos de sonido (buscar)!audio-x-generic:fbtn"        "bash -c '$SELF audio &'" \
    --field="🌐  Videos, fuentes e íconos (sitios web)!applications-internet:fbtn" "bash -c '$SELF enlaces &'" \
    --field="📜  Guía de licencias!text-x-generic:fbtn"                            "bash -c '$SELF guia &'" \
    --button="Cerrar:1"
}

case "$1" in
  guia)     guia ;;
  audio)    audio ;;
  enlaces)  enlaces ;;
  imagenes) buscar ;;
  menu)     menu ;;
  *)        buscar ;;    # compatibilidad: sin argumento = buscar imágenes
esac
