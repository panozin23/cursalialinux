#!/bin/bash
# ================================================================
#  Análisis SEO de una página (Lighthouse de Google) — cursalialinux
#  Le das una URL → porcentajes (SEO, rendimiento, accesibilidad) + errores.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 1) ¿está instalado Lighthouse? (usa Node + Chromium)
if ! command -v lighthouse >/dev/null 2>&1; then
  yad --question --center --class=cursaliacentro --width=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="Análisis SEO — instalar" \
    --text="<big><b>🔍  Análisis SEO (Lighthouse)</b></big>

Para analizar páginas se necesita instalar <b>Lighthouse</b> (usa Chromium en segundo plano).

• Necesita <b>internet</b> (es una descarga grande la primera vez)
• Se te pedirá tu <b>contraseña</b>

¿Instalar ahora?" --button="Cancelar:1" --button="Instalar:0" || exit 0
  xfce4-terminal --title="Instalar Análisis SEO" --hold -e "bash -c '
    echo \"Instalando Node.js, Chromium y Lighthouse... (puede tardar)\"; echo
    pkexec sh -c \"apt-get update && apt-get install -y nodejs npm chromium && npm install -g lighthouse\"
    echo; echo \"✅ Listo. Vuelve a abrir Análisis SEO. Puedes cerrar esta ventana.\"
  '"
  exit 0
fi

# 2) pedir la URL
URL=$(yad --entry --center --class=cursaliacentro --width=560 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Análisis SEO" \
  --text="<big><b>🔍  Analizar página web</b></big>\n\nEscribe la dirección de la página <i>(con https://)</i>:" \
  --entry-text="https://") || exit 0
[ -z "$URL" ] || [ "$URL" = "https://" ] && exit 0
case "$URL" in http*://*) ;; *) URL="https://$URL" ;; esac

# 3) analizar y abrir el informe
REP="$HOME/informe-seo.html"
xfce4-terminal --title="Analizando: $URL" --hold -e "bash -c '
  echo \"════════════════════════════════════════\"
  echo \"   Analizando: $URL\"
  echo \"   (esto tarda ~1 minuto, espera...)\"
  echo \"════════════════════════════════════════\"; echo
  export CHROME_PATH=\$(command -v chromium)
  lighthouse \"$URL\" --output=html --output-path=\"$REP\" \
    --chrome-flags=\"--headless --no-sandbox --disable-gpu\" \
    --only-categories=performance,accessibility,best-practices,seo --quiet
  if [ -f \"$REP\" ]; then
    echo; echo \"✅ Informe listo — abriéndolo en el navegador...\"
    setsid firefox-esr \"$REP\" >/dev/null 2>&1 &
  else
    echo; echo \"❌ No se pudo analizar. Revisa la dirección y tu internet.\"
  fi
  echo; echo \"Puedes cerrar esta ventana.\"
'"
