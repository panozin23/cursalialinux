#!/bin/bash
# ================================================================
#  Centro de Bienvenida — cursalialinux  (catálogo completo)
#  Herramientas livianas: arrancan directo.
#  Herramientas pesadas: botón "Instalar" (descarga bajo demanda).
# ================================================================
SELF="/usr/local/bin/centro-cursalialinux"
LOGO="/usr/share/pixmaps/cursalialinux.png"

# Lanzar una app instalada
run() { setsid "$@" >/dev/null 2>&1 & }
# Botón que lanza (para yad fbtn)
L() { echo "bash -c 'setsid $1 >/dev/null 2>&1 &'"; }
# Botón que lanza como root (gparted, timeshift)
LR() { echo "bash -c 'setsid pkexec $1 >/dev/null 2>&1 &'"; }
# Botón que INSTALA bajo demanda: $SELF instalar <pkg> <nombre>
I() { echo "bash -c '$SELF instalar $1 \"$2\" &'"; }

# --- Instalador bajo demanda (abre terminal, descarga con permiso) ---
instalar_pkg() {
  PKG="$1"; NOM="$2"
  if dpkg -s "$PKG" >/dev/null 2>&1; then
    yad --info --center --window-icon="$LOGO" --image="$LOGO" --title="$NOM" \
        --text="<b>$NOM</b> ya está instalado.\nÁbrelo desde su Studio." --button="OK:0"
    return
  fi
  xfce4-terminal --title="Instalar $NOM" --hold -e "bash -c '
    echo \"=== Instalando $NOM ($PKG) ===\"
    echo \"Necesita conexión a internet. Se te pedirá tu contraseña.\"
    echo
    pkexec sh -c \"apt-get update && apt-get install -y $PKG\"
    echo
    echo \"Listo. Ya puedes abrir $NOM desde su Studio. Cierra esta ventana.\"
  '" &
}

estudio_web() {
  yad --title="Web Studio — cursalialinux" --center --width=560 --height=520 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>💻  Web Studio</b></big>\nDesarrollo web" --form --columns=1 \
    --field="VSCodium — editor de código!text-editor:fbtn"        "$(L codium)" \
    --field="Terminal de desarrollo!utilities-terminal:fbtn"      "$(L xfce4-terminal)" \
    --field="Firefox — navegador/pruebas!web-browser:fbtn"        "$(L firefox-esr)" \
    --field="FileZilla — FTP/SFTP!network-server:fbtn"            "$(L filezilla)" \
    --field="Bluefish — editor web!text-html:fbtn"               "$(L bluefish)" \
    --field="Git-cola — control de versiones!applications-development:fbtn" "$(L git-cola)" \
    --field="SQLite Browser — bases de datos!accessories-database:fbtn" "$(L sqlitebrowser)" \
    --field="Meld — comparar código!text-x-generic:fbtn"          "$(L meld)" \
    --field="📥 Chromium — otro navegador (instalar)!web-browser:fbtn" "$(I chromium Chromium)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_video() {
  yad --title="Video Studio — cursalialinux" --center --width=560 --height=560 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🎬  Video Studio</b></big>\nEdición, grabación, karaoke" --form --columns=1 \
    --field="Shotcut — editor de video!multimedia-video-player:fbtn"   "$(L shotcut)" \
    --field="VLC — reproductor!multimedia-video-player:fbtn"           "$(L vlc)" \
    --field="Cheese — cámara web!camera-web:fbtn"                      "$(L cheese)" \
    --field="🎤 Aegisub — subtítulos y KARAOKE!text-x-generic:fbtn"    "$(L aegisub)" \
    --field="🎤 Subtitle Editor — subtítulos!text-x-generic:fbtn"      "$(L subtitleeditor)" \
    --field="SimpleScreenRecorder — grabar pantalla!camera-video:fbtn" "$(L simplescreenrecorder)" \
    --field="HandBrake — convertir video!media-optical:fbtn"           "$(L ghb)" \
    --field="📥 Kdenlive — editor profesional (instalar)!applications-multimedia:fbtn" "$(I kdenlive Kdenlive)" \
    --field="📥 OpenShot — editor fácil (instalar)!applications-multimedia:fbtn"       "$(I openshot-qt OpenShot)" \
    --field="📥 OBS Studio — grabar/transmitir (instalar)!camera-video:fbtn"           "$(I obs-studio 'OBS Studio')" \
    --field="📥 🎤 Performous — cantar karaoke (instalar)!applications-games:fbtn"      "$(I performous Performous)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_imagenes() {
  yad --title="Imágenes y Diseño — cursalialinux" --center --width=560 --height=480 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🖼️  Imágenes y Diseño</b></big>\nGráficos, fotos, logos" --form --columns=1 \
    --field="GIMP — edición de imágenes!image-x-generic:fbtn"    "$(L gimp)" \
    --field="Inkscape — vectores y logos!image-svg+xml:fbtn"     "$(L inkscape)" \
    --field="Krita — dibujo digital!applications-graphics:fbtn"  "$(L krita)" \
    --field="Darktable — fotografía RAW!camera-photo:fbtn"       "$(L darktable)" \
    --field="Scribus — maquetación (revistas)!x-office-document:fbtn" "$(L scribus)" \
    --field="RawTherapee — revelado RAW!camera-photo:fbtn"       "$(L rawtherapee)" \
    --field="📥 Blender — 3D y animación (instalar)!applications-graphics:fbtn" "$(I blender Blender)" \
    --field="📥 digiKam — organizar fotos (instalar)!image-x-generic:fbtn"      "$(I digikam digiKam)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_audio() {
  yad --title="Audio Studio — cursalialinux" --center --width=560 --height=460 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🎙️  Audio Studio</b></big>\nMúsica, podcast, grabación" --form --columns=1 \
    --field="Audacity — editor de audio!audio-x-generic:fbtn"   "$(L audacity)" \
    --field="LMMS — producción musical!audio-x-generic:fbtn"    "$(L lmms)" \
    --field="Hydrogen — caja de ritmos!audio-x-generic:fbtn"    "$(L hydrogen)" \
    --field="MuseScore — partituras!audio-x-generic:fbtn"       "$(L musescore3)" \
    --field="Mixxx — mezcla DJ!audio-x-generic:fbtn"            "$(L mixxx)" \
    --field="Rosegarden — secuenciador MIDI!audio-x-generic:fbtn" "$(L rosegarden)" \
    --field="Kid3 — etiquetas de MP3!audio-x-generic:fbtn"      "$(L kid3)" \
    --field="📥 Ardour — estudio de grabación pro (instalar)!audio-x-generic:fbtn" "$(I ardour Ardour)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_oficina() {
  yad --title="Oficina — cursalialinux" --center --width=560 --height=480 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>📄  Oficina</b></big>\nCompatible con Word, Excel y PowerPoint" --form --columns=1 \
    --field="Writer — documentos (Word)!x-office-document:fbtn"          "$(L 'libreoffice --writer')" \
    --field="Calc — hojas de cálculo (Excel)!x-office-spreadsheet:fbtn"  "$(L 'libreoffice --calc')" \
    --field="Impress — presentaciones (PowerPoint)!x-office-presentation:fbtn" "$(L 'libreoffice --impress')" \
    --field="Draw — dibujo y diagramas!x-office-drawing:fbtn"            "$(L 'libreoffice --draw')" \
    --field="Base — bases de datos!accessories-database:fbtn"            "$(L 'libreoffice --base')" \
    --field="Math — fórmulas!x-office-document:fbtn"                     "$(L 'libreoffice --math')" \
    --field="Evince — leer PDF!application-pdf:fbtn"                     "$(L evince)" \
    --field="Xournal++ — anotar PDF / apuntes!application-pdf:fbtn"      "$(L xournalpp)" \
    --field="📥 Calibre — libros electrónicos (instalar)!accessories-dictionary:fbtn" "$(I calibre Calibre)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_internet() {
  yad --title="Internet — cursalialinux" --center --width=560 --height=360 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🌐  Internet</b></big>\nNavegar, correo, descargas" --form --columns=1 \
    --field="Firefox — navegador!web-browser:fbtn"          "$(L firefox-esr)" \
    --field="qBittorrent — descargas!applications-internet:fbtn" "$(L qbittorrent)" \
    --field="FileZilla — FTP/SFTP!network-server:fbtn"      "$(L filezilla)" \
    --field="📥 Chromium — otro navegador (instalar)!web-browser:fbtn"      "$(I chromium Chromium)" \
    --field="📥 Thunderbird — correo electrónico (instalar)!mail-message-new:fbtn" "$(I thunderbird Thunderbird)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

estudio_sistema() {
  yad --title="Sistema — cursalialinux" --center --width=560 --height=400 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🛠️  Sistema</b></big>\nMantenimiento y utilidades" --form --columns=1 \
    --field="🧹 Limpieza cursalialinux — un clic!edit-clear:fbtn"   "$(L cursalia-limpieza)" \
    --field="BleachBit — limpiador avanzado!edit-clear:fbtn"        "$(L bleachbit)" \
    --field="GParted — particiones de disco!drive-harddisk:fbtn"    "$(LR gparted)" \
    --field="Timeshift — respaldos del sistema!document-save:fbtn"  "$(LR timeshift-gtk)" \
    --field="Gestor de archivos!system-file-manager:fbtn"           "$(L thunar)" \
    --field="Monitor del sistema!utilities-system-monitor:fbtn"     "$(L xfce4-taskmanager)" \
    --button="⬅ Volver:bash -c '$SELF &'" --button="Cerrar:1"
}

menu_principal() {
  yad --title="Centro cursalialinux" --center --width=620 --height=620 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>Bienvenido a cursalialinux</b></big>
Tu sistema para <b>desarrollo web</b> y <b>creación de contenido</b>.

Elige un Estudio:" --form --columns=1 \
    --field="💻   Web Studio — desarrollo web!applications-development:fbtn"        "bash -c '$SELF web &'" \
    --field="🎬   Video Studio — edición, grabación, karaoke!applications-multimedia:fbtn" "bash -c '$SELF video &'" \
    --field="🖼️   Imágenes y Diseño — gráficos y fotos!applications-graphics:fbtn" "bash -c '$SELF imagenes &'" \
    --field="🎙️   Audio Studio — música y podcast!audio-x-generic:fbtn"           "bash -c '$SELF audio &'" \
    --field="📄   Oficina — Word, Excel, PowerPoint!applications-office:fbtn"       "bash -c '$SELF oficina &'" \
    --field="🌐   Internet — navegar, correo, descargas!applications-internet:fbtn" "bash -c '$SELF internet &'" \
    --field="🛠️   Sistema — mantenimiento y limpieza!applications-system:fbtn"      "bash -c '$SELF sistema &'" \
    --button="Cerrar:1"
}

case "$1" in
  web) estudio_web ;;
  video) estudio_video ;;
  imagenes) estudio_imagenes ;;
  audio) estudio_audio ;;
  oficina) estudio_oficina ;;
  internet) estudio_internet ;;
  sistema) estudio_sistema ;;
  instalar) instalar_pkg "$2" "$3" ;;
  *) menu_principal ;;
esac
