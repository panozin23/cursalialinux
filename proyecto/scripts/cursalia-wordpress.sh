#!/bin/bash
# ================================================================
#  WordPress local — cursalialinux
#  Instala WordPress (última versión) en tu PC, sin comandos.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NEED="php-cli php-mysql php-xml php-mbstring php-curl php-gd php-zip mariadb-server unzip wget"
WPDIR="$HOME/wordpress-local"

# 1) prerequisitos
falta=0; for p in $NEED; do dpkg -s "$p" >/dev/null 2>&1 || falta=1; done
if [ "$falta" = 1 ]; then
  yad --question --center --class=cursaliacentro --width=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="WordPress local — instalar base" \
    --text="<big><b>🌐  WordPress local</b></big>

Para WordPress se necesita <b>PHP y una base de datos (MariaDB)</b>.

• Necesita <b>internet</b>
• Se te pedirá tu <b>contraseña</b>

¿Instalar ahora?" --button="Cancelar:1" --button="Instalar:0" || exit 0
  xfce4-terminal --title="Instalar base de WordPress" --hold -e "bash -c '
    echo \"Instalando PHP y MariaDB...\"; echo
    pkexec apt-get install -y $NEED
    echo; echo \"✅ Listo. Vuelve a abrir WordPress local.\"
  '"
  exit 0
fi

# 2) instalar + iniciar WordPress
yad --info --center --class=cursaliacentro --width=520 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top --timeout=6 --timeout-indicator=bottom \
  --title="WordPress local" \
  --text="<big><b>🌐  Preparando WordPress local</b></big>

Se te pedirá la contraseña para preparar la base de datos.
Al final se abrirá el navegador con el <b>asistente de WordPress</b>
(elige idioma → pon un título, usuario y contraseña de tu sitio)." --button="Continuar:0"

xfce4-terminal --title="WordPress local" --hold -e "bash -c '
  echo \"═══ Preparando base de datos ═══\"
  pkexec /usr/local/sbin/cursalia-wp-db || { echo \"❌ No se pudo preparar la base de datos.\"; exit 1; }
  mkdir -p \"$WPDIR\"; cd \"$WPDIR\" || exit 1
  if [ ! -f wp-load.php ]; then
    echo; echo \"═══ Descargando WordPress (última versión) ═══\"
    wget -q --show-progress https://es.wordpress.org/latest-es_ES.tar.gz -O wp.tar.gz || wget -q https://wordpress.org/latest.tar.gz -O wp.tar.gz
    tar xzf wp.tar.gz --strip-components=1 && rm -f wp.tar.gz
    cp wp-config-sample.php wp-config.php
    sed -i \"s/database_name_here/wp_local/; s/username_here/wp_local/; s/password_here/wp_local_pass/\" wp-config.php
  fi
  echo; echo \"═══ Iniciando WordPress ═══\"
  echo \"Tu sitio:  http://localhost:8080\"
  ( sleep 3; setsid firefox-esr http://localhost:8080 >/dev/null 2>&1 & )
  php -S localhost:8080
'"
