#!/bin/bash
# crear-paquete.sh — Empaqueta lo propio de cursalialinux en un .deb
#
# En vez de reconstruir una ISO de 3,5 GB cada vez que cambia un botón,
# se genera un paquete de unos pocos MB. Quien ya tiene cursalialinux
# instalado recibe la mejora con "apt upgrade", sin reinstalar nada.
#
# Uso:  bash crear-paquete.sh [version]
#       Si no se indica versión, usa la del archivo VERSION.
#
# No necesita sudo.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
PAQUETE=cursalialinux-escritorio
VERSION="${1:-$(cat "$BASE/VERSION" 2>/dev/null || echo 1.1.0)}"
ARQ=all
SALIDA="$BASE/paquetes"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

echo "══════════════════════════════════════════════"
echo " PAQUETE $PAQUETE $VERSION"
echo "══════════════════════════════════════════════"

# ── Estructura del paquete ───────────────────────────────────────────
mkdir -p "$T/DEBIAN" \
         "$T/usr/bin" \
         "$T/usr/share/cursalialinux" \
         "$T/usr/share/doc/cursalialinux" \
         "$T/usr/share/pixmaps" \
         "$T/usr/share/applications" \
         "$T/usr/share/color-schemes" \
         "$T/usr/share/plasma/plasmoids" \
         "$T/lib/systemd/system" \
         "$T/etc/skel/.config/autostart" \
         "$T/etc/systemd/journald.conf.d" \
         "$T/etc/modprobe.d"

# ── Programas ────────────────────────────────────────────────────────
echo
echo "── Programas ──"
for p in centro-cursalialinux cursalia-windows.sh cursalia-windows-control.sh \
         cursalia-windows-iso.sh cursalia-icono-menu.sh cursalia-mantenimiento.sh \
         cursalia-informe.sh cursalia-cartera.sh virt-inspeccionar.sh virt-instalar.sh virt-crear-windows.sh; do
  if [ -f "$BASE/scripts/$p" ]; then
    install -m 755 "$BASE/scripts/$p" "$T/usr/bin/$p"
    printf '   ✅ %s\n' "$p"
  else
    printf '   ⚠️  falta: %s\n' "$p"
  fi
done

# ── Documentación ────────────────────────────────────────────────────
echo
echo "── Documentación ──"
copiar(){ [ -f "$BASE/documentacion/$1" ] && install -m 644 "$BASE/documentacion/$1" "$T/usr/share/doc/cursalialinux/$2" && printf '   ✅ %s\n' "$2"; }
copiar GUIA-WINDOWS-EN-CURSALIALINUX.md GUIA-WINDOWS.md
copiar LICENCIAS-Y-RESPONSABILIDAD.md   LICENCIAS-WINDOWS.md
copiar SEGURIDAD-WINDOWS-VIRTUAL.md     SEGURIDAD-WINDOWS.md
copiar CATALOGO-cursalialinux.md        CATALOGO.md
copiar CREDITOS.md                      CREDITOS.md

# ── Marca ────────────────────────────────────────────────────────────
echo
echo "── Marca y estilos ──"
install -m 644 "$BASE/marca/logo-256.png"          "$T/usr/share/pixmaps/cursalialinux.png"
install -m 644 "$BASE/marca/logo-96.png"           "$T/usr/share/pixmaps/cursalialinux-96.png"
install -m 644 "$BASE/marca/centro.css"            "$T/usr/share/cursalialinux/centro.css"
install -m 644 "$BASE/marca/cursalialinux.colors"  "$T/usr/share/color-schemes/cursalialinux.colors"
[ -d "$BASE/plasmoides" ] && cp -a "$BASE/plasmoides/." "$T/usr/share/plasma/plasmoids/"
echo "   ✅ logos, hoja de estilo, colores y widgets"

# ── Lanzadores del menú ──────────────────────────────────────────────
R="$BASE/recetas/moderna-kde-config/includes.chroot"
for d in cursalialinux-centro cursalialinux-windows cursalialinux-windows-panel; do
  [ -f "$R/usr/share/applications/$d.desktop" ] && \
    install -m 644 "$R/usr/share/applications/$d.desktop" "$T/usr/share/applications/"
done
# Red de seguridad: si alguna receta vuelve a traer la ruta absoluta,
# aquí se quita. Los programas se llaman por su nombre y los busca el PATH.
sed -i 's|/usr/local/bin/||g' "$T/usr/share/applications/"*.desktop 2>/dev/null
echo "   ✅ 3 lanzadores del menú"

# ── Lanzador del Escritorio ──────────────────────────────────────────
# Va en /etc/skel para que todo usuario nuevo lo tenga ya correcto.
mkdir -p "$T/etc/skel/Desktop"
if [ -f "$R/etc/skel/Desktop/cursalialinux-centro.desktop" ]; then
  install -m 755 "$R/etc/skel/Desktop/cursalialinux-centro.desktop" "$T/etc/skel/Desktop/"
  sed -i 's|/usr/local/bin/||g' "$T/etc/skel/Desktop/cursalialinux-centro.desktop"
  echo "   ✅ lanzador del Escritorio"
fi

# ── Mantenimiento automático ─────────────────────────────────────────
for u in cursalia-mantenimiento.service cursalia-mantenimiento.timer; do
  [ -f "$R/etc/systemd/system/$u" ] && install -m 644 "$R/etc/systemd/system/$u" "$T/lib/systemd/system/$u"
done
sed -i 's|/usr/local/bin/||g' "$T/lib/systemd/system/"*.service 2>/dev/null
printf '[Journal]\nSystemMaxUse=100M\nSystemMaxFileSize=20M\n' > "$T/etc/systemd/journald.conf.d/99-cursalialinux.conf"
[ -f "$R/etc/skel/.config/autostart/cursalialinux-icono-menu.desktop" ] && \
  install -m 644 "$R/etc/skel/.config/autostart/cursalialinux-icono-menu.desktop" "$T/etc/skel/.config/autostart/"
install -m 644 "$R/etc/modprobe.d/cursalialinux-ntfs.conf" "$T/etc/modprobe.d/" 2>/dev/null
echo "   ✅ limpieza nocturna, límite de registros y NTFS tolerante"

# ── Datos de control ─────────────────────────────────────────────────
TAM=$(du -sk "$T" | cut -f1)
cat > "$T/DEBIAN/control" <<CTRL
Package: $PAQUETE
Version: $VERSION
Section: metapackages
Priority: optional
Architecture: $ARQ
Maintainer: cursalialinux <dpto.salud10@gmail.com>
Installed-Size: $TAM
Depends: yad, xdg-utils, papirus-icon-theme
Recommends: virt-manager, virt-viewer, qemu-system-x86, qemu-system-gui, libvirt-daemon-system, swtpm, ovmf, genisoimage
Homepage: https://github.com/USUARIO/cursalialinux
Description: Escritorio y herramientas propias de cursalialinux
 Reúne lo que distingue a cursalialinux de un Debian normal:
 .
  * Centro cursalialinux, con los Estudios y el catálogo de programas
  * Windows Studio, para ejecutar programas de Windows en una ventana
  * Marca Azul Hielo: logos, colores y hoja de estilo
  * Limpieza automática cada noche, para que el sistema no se degrade
  * Documentación en español sobre virtualización, licencias y seguridad
 .
 Se instala en cursalialinux y se actualiza con apt, sin reinstalar el
 sistema. Construido sobre Debian, KDE, GNU y decenas de proyectos libres.
CTRL

# ── Qué hacer al instalar y al desinstalar ───────────────────────────
cat > "$T/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    # Las ISOs 1.0 y 1.1 dejaron copias en /usr/local/bin, que tiene
    # PRIORIDAD sobre /usr/bin. Sin borrarlas, el sistema sigue usando
    # los programas viejos y las actualizaciones no surten efecto.
    for v in centro-cursalialinux cursalia-windows.sh cursalia-windows-control.sh \
             cursalia-windows-iso.sh cursalia-icono-menu.sh cursalia-mantenimiento.sh \
             cursalia-informe.sh cursalia-cartera.sh virt-inspeccionar.sh virt-instalar.sh virt-crear-windows.sh; do
        if [ -f "/usr/local/bin/$v" ] && [ -f "/usr/bin/$v" ]; then
            rm -f "/usr/local/bin/$v"
            echo "cursalialinux: quitada copia antigua /usr/local/bin/$v"
        fi
    done

    # Al borrar esas copias, todo lanzador que llevara escrita la ruta
    # /usr/local/bin/... se queda roto ("No se ha podido encontrar el
    # programa"). Se les quita la ruta: basta el nombre, lo encuentra el
    # PATH, que incluye /usr/local/bin y /usr/bin. Vale igual para los
    # lanzadores viejos de la ISO 1.0 (cursalia-studio-*, cursalia-fechahora…)
    # que no pertenecen a ningún paquete y nadie más va a arreglar.
    #
    # Solo se tocan los lanzadores de cursalialinux, nunca los de terceros.
    reparar_lanzadores() {
        [ -d "$1" ] || return 0
        for l in "$1"/cursalia*.desktop; do
            [ -f "$l" ] || continue
            if grep -q '^Exec=/usr/local/bin/' "$l"; then
                sed -i 's|^Exec=/usr/local/bin/|Exec=|' "$l"
                echo "cursalialinux: reparado el lanzador $l"
            fi
        done
    }

    reparar_lanzadores /usr/share/applications
    for base in /etc/skel /root /home/*; do
        reparar_lanzadores "$base/Desktop"
        reparar_lanzadores "$base/Escritorio"
        reparar_lanzadores "$base/.config/autostart"
        # Los iconos del Escritorio deben poder ejecutarse, o KDE
        # los muestra como un archivo de texto cualquiera.
        for esc in "$base/Desktop" "$base/Escritorio"; do
            [ -d "$esc" ] || continue
            chmod +x "$esc"/cursalia*.desktop 2>/dev/null || true
        done
    done

    # Activar la limpieza nocturna
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable cursalia-mantenimiento.timer >/dev/null 2>&1 || true
        systemctl start  cursalia-mantenimiento.timer >/dev/null 2>&1 || true
    fi
    # Refrescar el menú de aplicaciones
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    echo "cursalialinux: escritorio actualizado. Abre el Centro para ver las novedades."
fi
exit 0
POST

cat > "$T/DEBIAN/prerm" <<'PRE'
#!/bin/sh
set -e
if [ "$1" = "remove" ] && [ -d /run/systemd/system ]; then
    systemctl disable --now cursalia-mantenimiento.timer >/dev/null 2>&1 || true
fi
exit 0
PRE

chmod 755 "$T/DEBIAN/postinst" "$T/DEBIAN/prerm"

# El archivo de registros es configuración: que apt no lo pise si el
# usuario lo editó
printf "/etc/systemd/journald.conf.d/99-cursalialinux.conf\n/etc/modprobe.d/cursalialinux-ntfs.conf\n" > "$T/DEBIAN/conffiles"

# ── Construir ────────────────────────────────────────────────────────
mkdir -p "$SALIDA"
DEB="$SALIDA/${PAQUETE}_${VERSION}_${ARQ}.deb"
echo
echo "── Construyendo ──"
dpkg-deb --build --root-owner-group "$T" "$DEB" >/dev/null || { echo "ERROR al construir"; exit 1; }

echo
echo "══════════════════════════════════════════════"
echo " ✅ $DEB"
echo "    tamaño: $(du -h "$DEB" | cut -f1)"
echo "══════════════════════════════════════════════"
echo
echo " Para probarlo AQUÍ antes de publicarlo:"
echo "   sudo apt install $DEB"
echo
echo " Para publicarlo en el repositorio:"
echo "   bash scripts/publicar-repositorio.sh"
echo
