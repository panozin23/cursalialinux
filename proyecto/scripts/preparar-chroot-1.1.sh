#!/bin/bash
# preparar-chroot-1.1.sh — Deja la raíz de la ISO lista para construir la 1.1
#
# Tu constructor comprime DIRECTAMENTE cocina/moderna-kde/raiz. No usa
# live-build, así que la carpeta recetas/*/includes.chroot NO entra en la ISO.
# Este script copia todo ahí dentro, que es donde de verdad importa.
#
# Uso:  sudo bash preparar-chroot-1.1.sh
#
# Qué hace:
#   1. Instala la virtualización DENTRO de la raíz (necesita internet)
#   2. Copia programas, marca, estilos, documentación y widgets
#   3. Configura arranque con logo, Papirus y ajustes de usuario
#   4. Actualiza las diapositivas del instalador y la versión a 1.1
#
# Qué NO hace: no construye la ISO. Eso es el paso siguiente.
set -u

BASE=/home/euflo/PROYECTOS-CURSALIA/cursalialinux
RAIZ=$BASE/cocina/moderna-kde/raiz
REGISTRO=/tmp/preparar-chroot-1.1.txt

exec > >(tee "$REGISTRO") 2>&1

echo "══════════════════════════════════════════════"
echo " PREPARAR LA RAÍZ DE LA ISO — cursalialinux 1.1"
echo "══════════════════════════════════════════════"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: ejecutar con sudo."; exit 1; }
[ -d "$RAIZ" ]       || { echo "ERROR: no encuentro $RAIZ"; exit 1; }

echo
echo "  Raíz: $RAIZ"
echo "  Espacio libre: $(df -h "$RAIZ" | tail -1 | awk '{print $4}')"
echo

printf "Para continuar escribe exactamente  PREPARAR  y pulsa Enter: "
read -r R
[ "$R" = "PREPARAR" ] || { echo; echo "Cancelado. Nada se modificó."; exit 0; }

# ── Desmontar siempre al salir, pase lo que pase ─────────────────────
limpiar() {
  umount -l "$RAIZ/dev/pts" 2>/dev/null
  umount -l "$RAIZ/dev"     2>/dev/null
  umount -l "$RAIZ/proc"    2>/dev/null
  umount -l "$RAIZ/sys"     2>/dev/null
}
trap limpiar EXIT

# ═══ 1. VIRTUALIZACIÓN DENTRO DE LA RAÍZ ═══════════════════════════
echo
echo "── 1/5 · Instalando la virtualización en la raíz ──"
echo "   (así el Windows Studio funciona SIN internet en el equipo del usuario)"

mount --bind /dev     "$RAIZ/dev"
mount --bind /dev/pts "$RAIZ/dev/pts"
mount -t proc  proc   "$RAIZ/proc"
mount -t sysfs sys    "$RAIZ/sys"
cp -f /etc/resolv.conf "$RAIZ/etc/resolv.conf"

PAQUETES="qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
virt-manager virt-viewer swtpm swtpm-tools ovmf bridge-utils dnsmasq-base \
virtiofsd spice-vdagent genisoimage yad qemu-system-gui \
openssh-server netcat-openbsd"
# qemu-system-gui  → sin él, libvirt rechaza la máquina: "spice graphics are
#                    not supported" y "does not support video model qxl"
# openssh-server   → permite administrar el equipo desde otro, sin ir hasta él
# netcat-openbsd   → lo necesita virt-manager para ver máquinas de otra PC
#                    ("Error de salida del tunel SSH: nc: not found")

if chroot "$RAIZ" apt-get update -qq && \
   chroot "$RAIZ" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $PAQUETES; then
  echo "   ✅ virtualización instalada dentro de la ISO"
else
  echo "   ❌ falló la instalación. Revisa tu conexión y vuelve a ejecutar."
  exit 1
fi

# Que no arranque solo: el usuario lo activa desde el Windows Studio
# Antes se desactivaba libvirtd aquí, pensando que el Windows Studio lo
# activaría. Pero el paso 2 solo corre si FALTAN los paquetes, y en la ISO
# ya vienen: el servicio quedaba apagado y crear la máquina fallaba con
# "Failed to connect socket to /var/run/libvirt/libvirt-sock".
chroot "$RAIZ" systemctl enable libvirtd >/dev/null 2>&1 || true

chroot "$RAIZ" apt-get clean
echo "   Espacio que ocupa ahora la raíz: $(du -sh "$RAIZ" | cut -f1)"

limpiar
trap - EXIT

# ═══ 2. PROGRAMAS Y DOCUMENTACIÓN ══════════════════════════════════
echo
echo "── 2/5 · Copiando programas y documentación ──"

install -d "$RAIZ/usr/local/bin" "$RAIZ/usr/share/cursalialinux" \
           "$RAIZ/usr/share/doc/cursalialinux" "$RAIZ/usr/share/color-schemes" \
           "$RAIZ/usr/share/plasma/plasmoids" "$RAIZ/etc/skel/.config/autostart" \
           "$RAIZ/etc/initramfs-tools" "$RAIZ/etc/default"

for p in centro-cursalialinux cursalia-windows.sh cursalia-windows-control.sh \
         cursalia-windows-iso.sh cursalia-icono-menu.sh cursalia-mantenimiento.sh \
         cursalia-informe.sh \
         virt-inspeccionar.sh virt-instalar.sh virt-crear-windows.sh; do
  install -m 755 "$BASE/scripts/$p" "$RAIZ/usr/local/bin/$p" && printf '   ✅ %s\n' "$p"
done

install -m 644 "$BASE/documentacion/GUIA-WINDOWS-EN-CURSALIALINUX.md" "$RAIZ/usr/share/doc/cursalialinux/GUIA-WINDOWS.md"
install -m 644 "$BASE/documentacion/LICENCIAS-Y-RESPONSABILIDAD.md"   "$RAIZ/usr/share/doc/cursalialinux/LICENCIAS-WINDOWS.md"
install -m 644 "$BASE/documentacion/SEGURIDAD-WINDOWS-VIRTUAL.md"     "$RAIZ/usr/share/doc/cursalialinux/SEGURIDAD-WINDOWS.md"
install -m 644 "$BASE/documentacion/CATALOGO-cursalialinux.md"        "$RAIZ/usr/share/doc/cursalialinux/CATALOGO.md"
install -m 644 "$BASE/documentacion/CREDITOS.md"                      "$RAIZ/usr/share/doc/cursalialinux/CREDITOS.md"
echo "   ✅ 5 documentos (incluidos los créditos)"

# ── Limpieza automática cada noche a las 2 ──
install -d "$RAIZ/etc/systemd/system"
for u in cursalia-mantenimiento.service cursalia-mantenimiento.timer; do
  f="$BASE/recetas/moderna-kde-config/includes.chroot/etc/systemd/system/$u"
  [ -f "$f" ] && install -m 644 "$f" "$RAIZ/etc/systemd/system/$u"
done
chroot "$RAIZ" systemctl enable cursalia-mantenimiento.timer >/dev/null 2>&1 \
  && echo "   ✅ limpieza automática activada (2:00 de la madrugada)" \
  || ln -sf /etc/systemd/system/cursalia-mantenimiento.timer \
       "$RAIZ/etc/systemd/system/timers.target.wants/cursalia-mantenimiento.timer" 2>/dev/null

# ── NTFS tolerante: ntfs3 rechaza discos que Windows no cerró bien ──
install -d "$RAIZ/etc/modprobe.d"
install -m 644 "$BASE/recetas/moderna-kde-config/includes.chroot/etc/modprobe.d/cursalialinux-ntfs.conf" \
  "$RAIZ/etc/modprobe.d/" 2>/dev/null && echo "   ✅ discos NTFS externos montarán siempre"

# ── SSH encendido: la regla de oro es administrar desde el portátil ──
chroot "$RAIZ" systemctl enable ssh >/dev/null 2>&1 && echo "   ✅ SSH activado"

# ── Registros con techo, para que no crezcan sin freno ──
install -d "$RAIZ/etc/systemd/journald.conf.d"
printf '[Journal]\n# Sin esto los registros pueden llegar a cientos de MB.\nSystemMaxUse=100M\nSystemMaxFileSize=20M\n' \
  > "$RAIZ/etc/systemd/journald.conf.d/99-cursalialinux.conf"
echo "   ✅ registros limitados a 100 MB"

# ═══ 3. MARCA Y ASPECTO ════════════════════════════════════════════
echo
echo "── 3/5 · Marca, estilos y aspecto ──"

install -m 644 "$BASE/marca/logo-96.png"           "$RAIZ/usr/share/pixmaps/cursalialinux-96.png"
install -m 644 "$BASE/marca/centro.css"            "$RAIZ/usr/share/cursalialinux/centro.css"
install -m 644 "$BASE/marca/cursalialinux.colors"  "$RAIZ/usr/share/color-schemes/cursalialinux.colors"
cp -a "$BASE/plasmoides/." "$RAIZ/usr/share/plasma/plasmoids/" 2>/dev/null
echo "   ✅ logo pequeño, hoja de estilo, esquema de color y widgets"

# Arranque: sin letras, con logo y fondo propio
install -m 644 "$BASE/recetas/moderna-kde-config/includes.chroot/etc/default/grub" "$RAIZ/etc/default/grub"
install -m 644 "$BASE/recetas/moderna-kde-config/includes.chroot/etc/initramfs-tools/modules" "$RAIZ/etc/initramfs-tools/modules"
echo "   ✅ arranque con logo y controladores de gráficos"

# Papirus e icono del menú para cada usuario nuevo
printf '[Icons]\nTheme=Papirus\n' > "$RAIZ/etc/skel/.config/kdeglobals"
install -m 644 "$BASE/recetas/moderna-kde-config/includes.chroot/etc/skel/.config/kwinrulesrc" "$RAIZ/etc/skel/.config/kwinrulesrc" 2>/dev/null
install -m 644 "$BASE/recetas/moderna-kde-config/includes.chroot/etc/skel/.config/autostart/cursalialinux-icono-menu.desktop" "$RAIZ/etc/skel/.config/autostart/" 2>/dev/null
echo "   ✅ Papirus por defecto e icono del menú"

# Lanzadores del menú de aplicaciones
for d in cursalialinux-centro cursalialinux-windows cursalialinux-windows-panel; do
  f="$BASE/recetas/moderna-kde-config/includes.chroot/usr/share/applications/$d.desktop"
  [ -f "$f" ] && install -m 644 "$f" "$RAIZ/usr/share/applications/"
done
echo "   ✅ lanzadores del menú"

# ═══ 3b. CONTROLADORES VIRTIO ══════════════════════════════════════
echo
echo "── 3b/5 · Controladores VirtIO para Windows ──"
# Sin este CD, el paso 2 del Windows Studio falla: Windows no puede ver el
# disco durante su instalación. El original de Red Hat pesa 754 MB; esta
# versión trae lo mismo sin los símbolos de depuración: 52 MB.
install -d "$RAIZ/var/lib/libvirt/images"
if [ -f "$BASE/marca/virtio-cursalia.iso" ]; then
  install -m 644 "$BASE/marca/virtio-cursalia.iso" "$RAIZ/var/lib/libvirt/images/virtio-win.iso"
  echo "   ✅ virtio-win.iso ($(du -h "$BASE/marca/virtio-cursalia.iso" | cut -f1)) — el usuario ya no descarga nada"
else
  echo "   ⚠️  falta marca/virtio-cursalia.iso — regenéralo con:"
  echo "        bash scripts/crear-virtio-reducido.sh"
fi

# Carpeta compartida para pasar archivos a Windows con un CD virtual
install -d -m 755 "$RAIZ/var/lib/libvirt/images/compartido"
echo "   ✅ carpeta compartida preparada"

# ═══ 4. DIAPOSITIVAS DEL INSTALADOR ════════════════════════════════
echo
echo "── 4/5 · Diapositivas del instalador ──"
MARCA="$RAIZ/etc/calamares/branding/cursalialinux"
if [ -d "$MARCA" ]; then
  cp -a "$MARCA/show.qml" "$MARCA/show.qml.antes-de-1.1" 2>/dev/null
  install -m 644 "$BASE/marca/calamares-show.qml" "$MARCA/show.qml"
  sed -i 's/^\(\s*version:\s*\).*/\11.1/;   s/^\(\s*shortVersion:\s*\).*/\11.1/;
          s/cursalialinux Moderna 1\.0/cursalialinux Moderna 1.1/;
          s/cursalialinux 1\.0/cursalialinux 1.1/' "$MARCA/branding.desc"
  echo "   ✅ 5 diapositivas nuevas + versión 1.1 en el instalador"
else
  echo "   ⚠️  no encuentro la marca de Calamares en la raíz"
fi

# ═══ 5. VERSIÓN DEL SISTEMA ════════════════════════════════════════
echo
echo "── 5/5 · Versión del sistema ──"
sed -i 's/^VERSION_ID="1.0"/VERSION_ID="1.1"/; s/^VERSION="1.0 (Moderna)"/VERSION="1.1 (Moderna)"/' "$RAIZ/etc/os-release"
grep -E '^VERSION' "$RAIZ/etc/os-release" | sed 's/^/   /'

# ═══ COMPROBACIÓN FINAL ════════════════════════════════════════════
echo
echo "══════════════════════════════════════════════"
echo " COMPROBACIÓN"
echo "══════════════════════════════════════════════"
ok=0; total=0
comprobar(){ total=$((total+1)); printf '  %-44s ' "$1"
  if eval "$2"; then echo "✅"; ok=$((ok+1)); else echo "❌"; fi; }

comprobar "Windows Studio en el Centro"      "grep -q estudio_windows '$RAIZ/usr/local/bin/centro-cursalialinux'"
comprobar "cursalia-windows.sh"              "[ -x '$RAIZ/usr/local/bin/cursalia-windows.sh' ]"
comprobar "hoja de estilo del Centro"        "[ -f '$RAIZ/usr/share/cursalialinux/centro.css' ]"
comprobar "logo pequeño"                     "[ -f '$RAIZ/usr/share/pixmaps/cursalialinux-96.png' ]"
comprobar "arranque con logo (quiet splash)" "grep -q 'quiet splash' '$RAIZ/etc/default/grub'"
comprobar "Papirus por defecto"              "grep -q Papirus '$RAIZ/etc/skel/.config/kdeglobals'"
comprobar "virt-manager instalado"           "[ -x '$RAIZ/usr/bin/virt-manager' ]"
comprobar "virt-viewer instalado"            "[ -x '$RAIZ/usr/bin/virt-viewer' ]"
comprobar "swtpm (TPM emulado)"              "[ -x '$RAIZ/usr/bin/swtpm' ]"
comprobar "documentación"                    "[ -f '$RAIZ/usr/share/doc/cursalialinux/GUIA-WINDOWS.md' ]"
comprobar "diapositivas nuevas"               "grep -q 'Tus programas siguen contigo' '$RAIZ/etc/calamares/branding/cursalialinux/show.qml'"
comprobar "controladores VirtIO incluidos"    "[ -f '$RAIZ/var/lib/libvirt/images/virtio-win.iso' ]"
comprobar "asistente de imagen de Windows"   "[ -x '$RAIZ/usr/local/bin/cursalia-windows-iso.sh' ]"
comprobar "limpieza automática nocturna"     "[ -f '$RAIZ/etc/systemd/system/cursalia-mantenimiento.timer' ]"
comprobar "créditos a Debian, KDE y otros"   "[ -f '$RAIZ/usr/share/doc/cursalialinux/CREDITOS.md' ]"
comprobar "registros con límite"             "[ -f '$RAIZ/etc/systemd/journald.conf.d/99-cursalialinux.conf' ]"
comprobar "informe de equipo"                "[ -x '$RAIZ/usr/local/bin/cursalia-informe.sh' ]"
comprobar "script pregunta a libvirt"        "grep -q domcapabilities '$RAIZ/usr/local/bin/virt-crear-windows.sh'"
comprobar "netcat (túnel SSH remoto)"        "grep -q '^Package: netcat-openbsd$' '$RAIZ/var/lib/dpkg/status'"
comprobar "SSH para administrar en remoto"   "grep -q '^Package: openssh-server$' '$RAIZ/var/lib/dpkg/status'"
comprobar "libvirtd se activa solo"          "[ -L '$RAIZ/etc/systemd/system/multi-user.target.wants/libvirtd.service' ]"
comprobar "discos NTFS externos"             "[ -f '$RAIZ/etc/modprobe.d/cursalialinux-ntfs.conf' ]"
comprobar "versión 1.1"                      "grep -q 'VERSION_ID=\"1.1\"' '$RAIZ/etc/os-release'"

echo
echo "  $ok de $total comprobaciones correctas"
echo
if [ "$ok" -eq "$total" ]; then
  echo "  ✅ TODO LISTO. Ahora construye la ISO:"
  echo "       sudo bash $BASE/scripts/build-moderna.sh"
else
  echo "  ⚠️  Revisa lo marcado con ❌ antes de construir."
fi
echo
echo " Registro guardado en: $REGISTRO"
echo "══════════════════════════════════════════════"
