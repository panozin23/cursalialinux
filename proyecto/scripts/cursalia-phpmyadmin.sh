#!/bin/bash
# ================================================================
#  phpMyAdmin — manejar bases de datos MySQL/MariaDB con ventana
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NEED="php-cli php-mysql php-mbstring php-zip php-gd mariadb-server wget unzip"
PMADIR="$HOME/phpmyadmin"

# 1) prerequisitos
falta=0; for p in $NEED; do dpkg -s "$p" >/dev/null 2>&1 || falta=1; done
if [ "$falta" = 1 ]; then
  yad --question --center --class=cursaliacentro --width=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="phpMyAdmin — instalar base" \
    --text="<big><b>🗄️  phpMyAdmin</b></big>

Para manejar bases de datos se necesita <b>PHP y MariaDB</b>.

• Necesita <b>internet</b>
• Se te pedirá tu <b>contraseña</b>

¿Instalar ahora?" --button="Cancelar:1" --button="Instalar:0" || exit 0
  xfce4-terminal --title="Instalar base de phpMyAdmin" --hold -e "bash -c '
    echo \"Instalando PHP y MariaDB...\"; echo
    pkexec apt-get install -y $NEED
    echo; echo \"✅ Listo. Vuelve a abrir phpMyAdmin.\"
  '"
  exit 0
fi

# 2) preparar y arrancar phpMyAdmin
yad --info --center --class=cursaliacentro --width=540 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top --timeout=7 --timeout-indicator=bottom \
  --title="phpMyAdmin" \
  --text="<big><b>🗄️  phpMyAdmin</b></big>

Se abrirá en el navegador. Entra con:

    Usuario:  <b>cursalia</b>
    Contraseña:  <b>cursalia</b>

(Se te pedirá tu contraseña del sistema para preparar la base de datos.)" --button="Continuar:0"

xfce4-terminal --title="phpMyAdmin" --hold -e "bash -c '
  echo \"═══ Preparando base de datos ═══\"
  pkexec /usr/local/sbin/cursalia-db-admin || { echo \"❌ No se pudo preparar la base de datos.\"; exit 1; }
  mkdir -p \"$PMADIR\"; cd \"$PMADIR\" || exit 1
  if [ ! -f index.php ]; then
    echo; echo \"═══ Descargando phpMyAdmin (última versión) ═══\"
    wget -q --show-progress https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O pma.zip || { echo \"❌ No se pudo descargar.\"; exit 1; }
    unzip -q pma.zip && mv phpMyAdmin-*-all-languages/* . && rm -rf phpMyAdmin-*-all-languages pma.zip
    cp config.sample.inc.php config.inc.php
    SECRET=\$(head -c 24 /dev/urandom | base64 | tr -d \"/+=\" | head -c 32)
    printf \"\n\\\$cfg['\''blowfish_secret'\''] = '\''%s'\'';\n\" \"\$SECRET\" >> config.inc.php
  fi
  echo; echo \"═══ Abriendo phpMyAdmin ═══\"
  echo \"Entra con  usuario: cursalia   contraseña: cursalia\"
  ( sleep 3; setsid firefox-esr http://localhost:8081 >/dev/null 2>&1 & )
  php -S localhost:8081
'"
