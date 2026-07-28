#!/bin/bash
# ================================================================
#  Servidor web local — cursalialinux
#  Muestra tu página web en el navegador, sin terminal.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 1) elegir la carpeta del sitio
DIR=$(yad --file --directory --class=cursaliacentro \
  --title="Elige la carpeta de tu página web" \
  --window-icon="$LOGO" --width=780 --height=520) || exit 0
[ -z "$DIR" ] && exit 0

# 2) tipo de sitio + puerto
SEL=$(yad --form --center --class=cursaliacentro --width=500 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Servidor web local" \
  --text="<big><b>🌐  Servidor web local</b></big>
Carpeta: <b>${DIR}</b>

<b>Estático</b> = páginas HTML/CSS/JS
<b>Dinámico</b> = páginas con PHP" \
  --field="Tipo de sitio:CB" "Estático (HTML/CSS/JS)!Dinámico (PHP)" \
  --field="Puerto:NUM" "8000!1024..65535!1" --separator="|") || exit 0
TIPO=$(echo "$SEL" | cut -d'|' -f1)
PORT=$(echo "$SEL" | cut -d'|' -f2); PORT=${PORT%.*}

# 3) iniciar el servidor
case "$TIPO" in
  Din*)
    if ! command -v php >/dev/null 2>&1; then
      yad --error --center --class=cursaliacentro --width=420 --window-icon="$LOGO" \
        --title="Falta PHP" --text="Para sitios PHP se necesita instalar PHP." --button="OK:0"; exit 0
    fi
    ( cd "$DIR" && setsid php -S "localhost:${PORT}" >/tmp/cursalia-serv.log 2>&1 ) &
    SPID=$! ;;
  *)
    setsid python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory "$DIR" >/tmp/cursalia-serv.log 2>&1 &
    SPID=$! ;;
esac
sleep 2

# comprobar que arrancó
if ! kill -0 "$SPID" 2>/dev/null; then
  yad --error --center --class=cursaliacentro --width=460 --window-icon="$LOGO" \
    --title="No se pudo iniciar" \
    --text="No se pudo iniciar el servidor (¿puerto ${PORT} ocupado?).\nIntenta con otro puerto." --button="OK:0"
  exit 0
fi

# abrir el navegador
setsid firefox-esr "http://localhost:${PORT}" >/dev/null 2>&1 &

# 4) ventana de control — mientras esté abierta, el servidor vive
yad --info --center --class=cursaliacentro --width=560 --height=320 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Servidor web activo" \
  --text="<big><b>✅  Servidor web activo</b></big>

Tu página está abierta en el navegador, en:
<big><b>http://localhost:${PORT}</b></big>

Carpeta: ${DIR}

Edita tus archivos y <b>recarga el navegador</b> para ver los cambios.

⚠️  Cuando termines, pulsa <b>Detener</b> para apagar el servidor." \
  --button="🛑  Detener servidor:0"

# al cerrar, apagar el servidor
pkill -P "$SPID" 2>/dev/null
kill "$SPID" 2>/dev/null
