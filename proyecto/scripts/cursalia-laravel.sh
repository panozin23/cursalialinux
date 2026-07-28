#!/bin/bash
# ================================================================
#  Laravel (+ Filament) — cursalialinux
#  Crea un proyecto Laravel con la última versión, sin comandos.
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NEED="composer php-cli php-xml php-mbstring php-curl php-zip php-sqlite3 php-gd php-bcmath php-intl unzip git"

# 1) prerequisitos
falta=0; for p in $NEED; do dpkg -s "$p" >/dev/null 2>&1 || falta=1; done
if [ "$falta" = 1 ]; then
  yad --question --center --class=cursaliacentro --width=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --title="Laravel — instalar base" \
    --text="<big><b>🚀  Laravel</b></big>

Para crear proyectos Laravel se necesita <b>PHP + Composer</b>.

• Necesita <b>internet</b>
• Se te pedirá tu <b>contraseña</b>

¿Instalar ahora?" --button="Cancelar:1" --button="Instalar:0" || exit 0
  xfce4-terminal --title="Instalar base de Laravel" --hold -e "bash -c '
    echo \"Instalando PHP y Composer...\"; echo
    pkexec apt-get install -y $NEED
    echo; echo \"✅ Listo. Vuelve a abrir Laravel para crear tu proyecto.\"
  '"
  exit 0
fi

# 2) nombre + Filament
SEL=$(yad --form --center --class=cursaliacentro --width=540 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Nuevo proyecto Laravel" \
  --text="<big><b>🚀  Nuevo proyecto Laravel</b></big>\nSe creará en tu Carpeta personal." \
  --field="Nombre del proyecto (sin espacios):" "mi-proyecto" \
  --field="Incluir <b>Filament</b> (panel de administración):CHK" TRUE \
  --separator="|") || exit 0
NAME=$(echo "$SEL" | cut -d'|' -f1 | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')
FIL=$(echo "$SEL" | cut -d'|' -f2)
[ -z "$NAME" ] && exit 0
DEST="$HOME/$NAME"
if [ -e "$DEST" ]; then
  yad --error --center --class=cursaliacentro --width=440 --window-icon="$LOGO" \
    --title="Ya existe" --text="Ya existe una carpeta «$NAME».\nElige otro nombre." --button="OK:0"; exit 0
fi

# 3) crear proyecto (en terminal, se ve el progreso)
FILA=""
[ "$FIL" = "TRUE" ] && FILA='
    echo; echo "═══ Instalando Filament (panel admin) ═══"
    composer require filament/filament:"*" -W
    php artisan filament:install --panels --no-interaction
    echo; echo "Ahora crea tu usuario administrador (nombre, email y contraseña):"
    php artisan make:filament-user
    echo; echo "El panel estará en:  http://localhost:8000/admin"'

xfce4-terminal --title="Creando Laravel: $NAME" --hold -e "bash -c '
  cd \"$HOME\" || exit 1
  echo \"═══════════════════════════════════════════\"
  echo \"   Creando proyecto Laravel: $NAME\"
  echo \"   (última versión — puede tardar unos minutos)\"
  echo \"═══════════════════════════════════════════\"; echo
  composer create-project laravel/laravel \"$NAME\" || { echo; echo \"❌ Error al crear el proyecto.\"; exit 1; }
  cd \"$DEST\" || exit 1
  $FILA
  echo; echo \"═══ Iniciando el servidor de desarrollo ═══\"
  echo \"Tu proyecto:  http://localhost:8000\"
  ( sleep 3; setsid firefox-esr http://localhost:8000 >/dev/null 2>&1 & )
  php artisan serve
'"
