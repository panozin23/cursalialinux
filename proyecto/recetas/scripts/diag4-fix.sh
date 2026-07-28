#!/bin/bash
# Prueba la SOLUCIÓN: un servicio que expone el medio de instalación en /run/live/medium
set -e
R=/home/euflo/cursalialinux-debian/raiz
W=/home/euflo/cursalialinux-debian/diagwork
OUTLOG=/tmp/claude-1000/-home-euflo/23a5567c-8927-46d6-9b93-97e255ad8c5b/scratchpad/diag4-serial.log
KVER=6.12.95+deb13-amd64

echo "== 1) Script + servicio que EXPONE el medio =="
mkdir -p "$R/usr/local/sbin"
cat > "$R/usr/local/sbin/cursalia-expose-medium" <<'EOF'
#!/bin/sh
# Garantiza que el medio de instalacion (con /live/filesystem.squashfs) este montado en /run/live/medium
T=/run/live/medium
[ -e "$T/live/filesystem.squashfs" ] && exit 0
mkdir -p "$T"
for d in $(blkid -o device 2>/dev/null); do
    mount -o ro "$d" "$T" 2>/dev/null || continue
    if [ -e "$T/live/filesystem.squashfs" ]; then
        exit 0
    fi
    umount "$T" 2>/dev/null
done
exit 0
EOF
chmod +x "$R/usr/local/sbin/cursalia-expose-medium"
cat > "$R/etc/systemd/system/cursalia-expose-medium.service" <<'EOF'
[Unit]
Description=cursalialinux: exponer el medio de instalacion
DefaultDependencies=no
After=local-fs.target
Before=display-manager.service calamares.service
ConditionKernelCommandLine=boot=live
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/cursalia-expose-medium
[Install]
WantedBy=multi-user.target
EOF

echo "== 2) Servicio de diagnóstico (verifica DESPUÉS de exponer) =="
cat > "$R/etc/systemd/system/diag.service" <<'EOF'
[Unit]
Description=cursalia diag
After=cursalia-expose-medium.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'sleep 4; { echo ===ZZZ-START; echo --MEDIUMLIVE; ls -la /run/live/medium/live/filesystem.squashfs 2>&1; echo --MOUNTS; grep -iE "run/live/medium" /proc/mounts; echo ===ZZZ-END; } > /dev/ttyS0 2>&1'
[Install]
WantedBy=multi-user.target
EOF
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/cursalia-expose-medium.service "$R/etc/systemd/system/multi-user.target.wants/cursalia-expose-medium.service"
ln -sf /etc/systemd/system/diag.service "$R/etc/systemd/system/multi-user.target.wants/diag.service"

echo "== 3) ISO de prueba =="
rm -rf "$W"; mkdir -p "$W/live" "$W/isolinux" "$W/.disk"
cp "$R/boot/vmlinuz-$KVER" "$W/live/vmlinuz"
cp "$R/boot/initrd.img-$KVER" "$W/live/initrd.img"
touch "$W/.disk/cursalia"
mksquashfs "$R" "$W/live/filesystem.squashfs" -comp gzip -Xcompression-level 1 -noappend -e proc -e sys -e run >/tmp/diag4mksq.log 2>&1
echo "   squashfs: $(du -h "$W/live/filesystem.squashfs" | cut -f1)"
cp /usr/lib/ISOLINUX/isolinux.bin "$W/isolinux/"
for c in ldlinux libcom32 libutil; do cp /usr/lib/syslinux/modules/bios/$c.c32 "$W/isolinux/"; done
cat > "$W/isolinux/isolinux.cfg" <<'CFG'
SERIAL 0 115200
DEFAULT live
PROMPT 0
TIMEOUT 10
LABEL live
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components console=ttyS0,115200 systemd.unit=multi-user.target
CFG
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid CURSALIA_DIAG \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
  -o "$W/diag.iso" "$W" >/dev/null 2>&1

echo "== 4) Arrancando y capturando =="
rm -f "$OUTLOG"
qemu-system-x86_64 -enable-kvm -m 3072 -smp 2 -machine pc \
  -cdrom "$W/diag.iso" -boot d -display none -serial file:"$OUTLOG" -no-reboot & QP=$!
sleep 90; kill $QP 2>/dev/null; sleep 1

echo "== RESULTADO (¿el medio quedó expuesto?) =="
awk '/ZZZ-START/{p=1} p{print} /ZZZ-END/{exit}' "$OUTLOG" | tr -d '\r' | grep -vE "^\[" | head -20
# limpieza de servicios de diag (dejo el expose-medium para el build real; quito solo el diag)
rm -f "$R/etc/systemd/system/diag.service" "$R/etc/systemd/system/multi-user.target.wants/diag.service"
echo "== fin =="