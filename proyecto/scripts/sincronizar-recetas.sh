#!/bin/bash
# sincronizar-recetas.sh — Lleva todo lo propio de cursalialinux a las recetas.
#
# Los originales viven en scripts/, documentacion/, marca/ y plasmoides/.
# Este script los copia a recetas/*/includes.chroot/, que es lo que live-build
# mete dentro de la ISO.
#
# EJECUTAR SIEMPRE ANTES DE CONSTRUIR UNA ISO. Solo copia: no borra ni
# modifica los originales.
#
# (Antes se llamaba sincronizar-windows-studio.sh; se renombró al crecer
#  para cubrir también marca, estilos y widgets.)
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"

echo "══════════════════════════════════════════════"
echo " SINCRONIZAR → RECETAS DE LA ISO"
echo "══════════════════════════════════════════════"

TOTAL=0

for EDICION in moderna-kde ligera-xfce; do
  D="$BASE/recetas/$EDICION-config/includes.chroot"
  [ -d "$(dirname "$D")" ] || { echo; echo "» $EDICION: receta no encontrada, se omite"; continue; }

  echo; echo "── $EDICION ──"
  mkdir -p "$D/usr/local/bin" "$D/usr/share/applications" \
           "$D/usr/share/doc/cursalialinux" "$D/usr/share/pixmaps" \
           "$D/usr/share/cursalialinux" "$D/usr/share/color-schemes" \
           "$D/usr/share/plasma/plasmoids" "$D/etc/skel/.config"

  # ── Programas ──
  for p in centro-cursalialinux cursalia-windows.sh cursalia-windows-control.sh \
           cursalia-icono-menu.sh cursalia-cartera.sh virt-inspeccionar.sh virt-instalar.sh \
           virt-crear-windows.sh; do
    if [ -f "$BASE/scripts/$p" ]; then
      install -m 755 "$BASE/scripts/$p" "$D/usr/local/bin/$p"; TOTAL=$((TOTAL+1))
    else
      printf '  ⚠️  falta el programa: %s\n' "$p"
    fi
  done
  echo "  ✅ programas"

  # ── Documentación ──
  copiar_doc(){ [ -f "$BASE/documentacion/$1" ] && \
    install -m 644 "$BASE/documentacion/$1" "$D/usr/share/doc/cursalialinux/$2" && TOTAL=$((TOTAL+1)); }
  copiar_doc GUIA-WINDOWS-EN-CURSALIALINUX.md GUIA-WINDOWS.md
  copiar_doc LICENCIAS-Y-RESPONSABILIDAD.md   LICENCIAS-WINDOWS.md
  copiar_doc SEGURIDAD-WINDOWS-VIRTUAL.md     SEGURIDAD-WINDOWS.md
  copiar_doc CATALOGO-cursalialinux.md        CATALOGO.md
  echo "  ✅ documentación"

  # ── Marca: logos, hoja de estilo, esquema de color ──
  [ -f "$BASE/marca/logo-96.png" ]  && install -m 644 "$BASE/marca/logo-96.png"  "$D/usr/share/pixmaps/cursalialinux-96.png" && TOTAL=$((TOTAL+1))
  [ -f "$BASE/marca/logo-256.png" ] && install -m 644 "$BASE/marca/logo-256.png" "$D/usr/share/pixmaps/cursalialinux.png"    && TOTAL=$((TOTAL+1))
  [ -f "$BASE/marca/centro.css" ]   && install -m 644 "$BASE/marca/centro.css"   "$D/usr/share/cursalialinux/centro.css"     && TOTAL=$((TOTAL+1))
  [ -f "$BASE/marca/cursalialinux.colors" ] && install -m 644 "$BASE/marca/cursalialinux.colors" "$D/usr/share/color-schemes/" && TOTAL=$((TOTAL+1))
  echo "  ✅ marca (logos, estilo, colores)"

  # ── Lanzadores del menú ──
  cat > "$D/usr/share/applications/cursalialinux-centro.desktop" <<'DESK'
[Desktop Entry]
Name=Centro cursalialinux
Comment=Estudios para desarrollo web y creación de contenido
Exec=centro-cursalialinux
Icon=/usr/share/pixmaps/cursalialinux.png
Terminal=false
Type=Application
Categories=X-CursalialinuxStudios;System;
StartupNotify=true
StartupWMClass=cursaliacentro
DESK

  cat > "$D/usr/share/applications/cursalialinux-windows.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Version=1.0
Name=Windows
GenericName=Programas de Windows
Comment=Abre tu máquina de Windows en una ventana
Exec=cursalia-windows.sh
Icon=/usr/share/icons/Papirus/64x64/apps/distributor-logo-windows.svg
Terminal=false
Categories=System;
Keywords=windows;virtual;programa;salmi;soaps;snis;office;
StartupNotify=true
StartupWMClass=virt-viewer
Actions=Apagar;Dejar;

[Desktop Action Apagar]
Name=Abrir y apagar del todo al cerrar
Exec=cursalia-windows.sh --apagar

[Desktop Action Dejar]
Name=Abrir y dejar encendida al cerrar
Exec=cursalia-windows.sh --dejar
DESK

  cat > "$D/usr/share/applications/cursalialinux-windows-panel.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Version=1.0
Name=Panel de Windows
GenericName=Control de la máquina virtual
Comment=Cortar o dar internet, pasar archivos e instantáneas
Exec=cursalia-windows-control.sh
Icon=preferences-system-network
Terminal=false
Categories=System;
Keywords=windows;red;internet;instantanea;snapshot;virtual;cd;archivos;
StartupNotify=true
DESK
  echo "  ✅ 3 lanzadores del menú"
  TOTAL=$((TOTAL+3))

  # ── Widgets propios ──
  if [ -d "$BASE/plasmoides" ]; then
    for p in "$BASE"/plasmoides/*/; do
      [ -d "$p" ] || continue
      cp -a "$p" "$D/usr/share/plasma/plasmoids/"
      printf '  ✅ widget: %s\n' "$(basename "$p")"
      TOTAL=$((TOTAL+1))
    done
  fi

  # ── Ajustes que hereda cada usuario nuevo ──
  if [ "$EDICION" = "moderna-kde" ]; then
    printf '[Icons]\nTheme=Papirus\n' > "$D/etc/skel/.config/kdeglobals"
    mkdir -p "$D/etc/skel/.config/autostart"
    cat > "$D/etc/skel/.config/autostart/cursalialinux-icono-menu.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Ajustar el icono del menú
Comment=Pone el logo de cursalialinux en el lanzador de aplicaciones
Exec=cursalia-icono-menu.sh
Icon=cursalialinux
Terminal=false
NoDisplay=true
X-KDE-autostart-phase=2
OnlyShowIn=KDE;
DESK
    echo "  ✅ Papirus + icono del menú (KDE)"
    TOTAL=$((TOTAL+2))
  else
    mkdir -p "$D/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
    cat > "$D/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'CFG'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita"/>
    <property name="IconThemeName" type="string" value="Papirus"/>
  </property>
</channel>
CFG
    echo "  ✅ Papirus (XFCE)"
    TOTAL=$((TOTAL+1))
  fi
done

echo
echo "══════════════════════════════════════════════"
echo " $TOTAL archivos sincronizados"
echo "══════════════════════════════════════════════"
echo
echo " Los paquetes de virtualización NO van en la ISO: se instalan"
echo " bajo demanda desde el Windows Studio del Centro."
echo
