# 🛡️ Seguridad — cursalialinux

Estado de la seguridad de la distro y qué falta por hacer.
Última revisión: **2026-07-25**

---

## Cortafuegos (ufw)

**Política de toda la distro — las dos ediciones:**

| | |
|---|---|
| Entrante | **DENEGAR** |
| Saliente | **PERMITIR** |
| Reenvío | **DENEGAR** |
| IPv6 | Sí |
| Reglas abiertas | **ninguna** |

Es la misma base que usan Ubuntu y Linux Mint. Todo lo que sale funciona con
normalidad (navegar, actualizar, `git`, `npm`, `docker pull`); nadie puede
conectarse al equipo desde fuera. Si el usuario necesita abrir un puerto, lo
hace desde la interfaz gráfica.

### Dónde está configurado

| Fichero | Qué hace |
|---|---|
| `recetas/*/hooks/normal/0400-cortafuegos.hook.chroot` | Fija la política y deja ufw activado desde el primer arranque |
| `recetas/*/package-lists/cursalialinux.list.chroot` | Instala `ufw` + la interfaz gráfica |

**Interfaz gráfica por edición:**

- **Moderna (KDE)** → `plasma-firewall`, integrado en *Preferencias del Sistema*
- **Ligera (XFCE)** → `gufw` (GTK), en el menú como *Cortafuegos*

> El hook **no llama a `ufw enable` ni a `iptables`**: edita los ficheros de
> configuración directamente. Si llamara a iptables dentro del chroot tocaría
> el cortafuegos de la máquina que construye el ISO, no el del sistema nuevo.

---

## Docker

`docker.io` va en las dos ediciones. Docker escribe **sus propias reglas de
iptables** y por defecto se salta ufw: un contenedor lanzado con `-p 8080:80`
queda accesible desde toda la red local aunque ufw diga "denegar entrante".
Es un fallo conocido de Docker, no de ufw.

El hook `0400` lo corrige añadiendo la cadena `DOCKER-USER` a
`/etc/ufw/after.rules`:

```
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -i docker0 -j RETURN     # tráfico que nace en contenedores
-A DOCKER-USER -i br-+    -j RETURN     # redes docker creadas por el usuario
-A DOCKER-USER -j DROP                  # lo que llega de fuera: se corta
```

Los contenedores siguen funcionando igual (salida a internet, entre ellos, y
acceso desde el propio equipo con `localhost`). Lo que deja de ocurrir es que
sus puertos se publiquen solos hacia otros equipos de la red.

---

## Puertos: qué escucha el sistema

Revisado sobre Moderna instalada:

| Puerto | Servicio | Alcance | Riesgo |
|---|---|---|---|
| 1716 TCP/UDP | `kdeconnectd` | **Todas las interfaces** | El único servicio expuesto |
| 631 | CUPS (impresión) | Solo `127.0.0.1` | Ninguno |
| 20360, 41395 | VS Code / VSCodium | Solo `127.0.0.1` | Ninguno |

**No hay servidor SSH instalado** en ninguna edición. Es lo correcto para un
escritorio: no hay nada que atacar por ahí.

### KDE Connect

Con el cortafuegos activo y sin reglas, **KDE Connect deja de ver el móvil**.
Es el comportamiento buscado: se abre solo si el usuario lo pide.

```bash
sudo ufw allow 1714:1764/tcp
sudo ufw allow 1714:1764/udp
```

---

## Comprobar que funciona

Tras instalar desde un ISO nuevo:

```bash
sudo ufw status verbose
```

Debe responder:

```
Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)
```

Y que la cadena de Docker se aplicó:

```bash
sudo iptables -L DOCKER-USER -n
```

---

## Actualizaciones de seguridad automáticas

Se instalan solos **solo los parches de seguridad de Debian**. Nada más.

| | |
|---|---|
| Paquete | `unattended-upgrades` |
| Configurado en | `recetas/*/hooks/normal/0410-actualizaciones-seguridad.hook.chroot` |
| Qué se actualiza | `stable-security` (main + non-free-firmware) |
| Qué **no** | backports, VSCodium, VS Code, y el resto de `stable` |
| Reinicio automático | **No.** Es un escritorio; lo decide el usuario |

### ⚠️ Trampa del nombre en clave — leer antes de tocar nada

Es el fallo más peligroso que tiene una distro derivada, porque **no da ningún
error**.

El `/etc/apt/apt.conf.d/50unattended-upgrades` que trae Debian filtra así:

```
"origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
```

`${distro_codename}` sale de `/etc/os-release`. En cursalialinux vale
**`moderna`**, así que busca un repositorio llamado `moderna-security`… que no
existe. Los repositorios reales se llaman `trixie-security`.

Comprobado sobre el sistema instalado:

| Filtro | Repositorios que casan |
|---|---|
| `codename=moderna-security` (el de Debian) | **0** ❌ |
| `archive=stable-security` (el nuestro) | **2** ✔ |

Con el filtro de serie, `unattended-upgrades` se ejecutaría cada día, no
encontraría nada, **no instalaría ni un solo parche y no avisaría de nada**.
Actualizaciones automáticas solo en apariencia.

**La solución** está en `/etc/apt/apt.conf.d/52cursalialinux-unattended`, que
el hook escribe. Filtra por `archive=` en vez de por `codename=`:

```
#clear Unattended-Upgrade::Origins-Pattern;
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,archive=stable-security,label=Debian-Security";
};
```

Como `archive` no depende del nombre en clave, **seguirá funcionando cuando la
base pase a Debian 14** sin tocar nada. El `#clear` borra la lista rota de
Debian; el número 52 hace que este fichero se lea después del 50 y mande.

> **Regla general para cursalialinux:** cualquier configuración que use
> `${distro_codename}` está rota en esta distro. Filtrar siempre por
> `archive=` / `origin=` / `label=`.

### Comprobar que funciona

```bash
apt-config dump | grep Origins-Pattern
```

No hace falta `sudo`. Debe salir **una sola** línea con contenido:

```
Unattended-Upgrade::Origins-Pattern:: "origin=Debian,archive=stable-security,label=Debian-Security";
```

Si aparecen además líneas con `moderna-security`, el fichero 52 no se aplicó
o le falta el `#clear`.

> No usar `unattended-upgrades --dry-run --debug | grep 'allowed origins'`:
> el texto cambia entre versiones y da falsos negativos. `apt-config dump`
> muestra la configuración ya fusionada, que es lo que apt usa de verdad.

---

## El registro sale vacío (`rsyslog` no está instalado)

ufw escribe su registro a través de syslog. Como **`rsyslog` no está en
ninguna de las dos listas de paquetes**, `/var/log/ufw.log` no se crea nunca
y los avisos van solo al journal de systemd.

Efecto visible: la pestaña **"Registro"** de gufw (Ligera) y el registro de
`plasma-firewall` (Moderna) aparecen **siempre vacíos**, aunque el cortafuegos
esté bloqueando tráfico. No afecta a la protección, solo a poder revisarla.

**Resuelto (2026-07-25):** se añadió `rsyslog` a las dos listas de paquetes.
En las ISOs nuevas `/var/log/ufw.log` se crea solo y la pestaña funciona.

En un sistema ya instalado sin `rsyslog`, lo bloqueado se consulta así:

```bash
sudo journalctl -k --grep '\[UFW '
```

---

## Ojo con `systemctl is-active ufw`

Después de un `ufw enable` manual, `systemctl is-active ufw` responde
**`inactive`** aunque el cortafuegos esté funcionando. No es un fallo: `ufw
enable` llama directamente a `ufw-init` y no pasa por systemd, así que la
unidad nunca se marca como arrancada. Tras reiniciar se muestra correctamente,
porque el servicio está `enabled`.

**Para comprobar de verdad si está activo, usar siempre `sudo ufw status`**,
nunca `systemctl`.

---

## Pendiente

- [ ] **Validar los hooks en una construcción real.** La sintaxis `sh` de los
      dos está comprobada, y el `apt.conf` del 0410 se validó con
      `apt-config dump`. Lo que **no** se ha probado son las reglas de
      `after.rules` con `iptables-restore --test` (requiere root). Se verá al
      construir el primer ISO.
- [ ] Decidir si `plasma-firewall` debe aparecer destacado en el
      *centro-cursalialinux*, para que el usuario sepa que existe.
- [ ] Revisar permisos de `sudo` y política de contraseñas del instalador
      (Calamares) — aún sin tocar.
- [ ] Repasar si alguna otra configuración de la distro usa
      `${distro_codename}` (ver la trampa del nombre en clave).

---

## 🚨 ATENCIÓN: los hooks NO llegan al ISO todavía

**Estado real a 2026-07-25: lo escrito en `recetas/` no tiene ningún efecto.**

`scripts/build-real.sh` **no usa live-build**. Lo que hace es coger una raíz ya
cocinada de `cocina/`, comprimirla con `mksquashfs` y armar el ISO. Nunca lee
`recetas/`, así que **los hooks `0400` y `0410` jamás se ejecutan**.

Los hooks no se tiran: siguen siendo la referencia de qué hay que aplicar. Pero
mientras se construya recalentando raíces, **hay que aplicarlos dentro de las
raíces de `cocina/`**, no esperar a live-build.

### Otros problemas detectados el mismo día

| # | Problema | Estado |
|---|---|---|
| 1 | `build-real.sh` (y `build-moderna.sh`, `prueba-visual.sh`, `verify-final.sh`, `diag4-fix.sh`) apuntan a `/home/euflo/cursalialinux-debian/`, ruta que ya no existe | ✅ Resuelto 2026-07-25 con el puente de enlaces `~/cursalialinux-debian` (ver «Puente de nombres» más abajo). Las rutas dentro de los scripts siguen sin corregir a propósito |
| 1b | Falta el archivo `grub-iso.cfg` que copian `build-real.sh` y `build-moderna.sh` en su paso 4. Vivía solo en las carpetas de trabajo del p6 y **no está en el respaldo de SANSUNG2** | ⚠️ Reconstruido 2026-07-25 como `recetas/grub-iso-ligera.cfg` y `recetas/grub-iso-moderna.cfg` (espejo del menú isolinux de cada script; sintaxis validada con `grub-script-check`). **Todavía sin probar arrancando**: hay que verificarlo con `prueba-visual.sh` en QEMU/UEFI antes de publicar un ISO nuevo |
| 1c | `build-moderna.sh` usaba `W=/run/media/euflo/SANSUNG2/iso-real-build`; en cursalialinux el disco monta en `/media/euflo/SANSUNG2`, y además obligaba a tener el disco externo puesto | ✅ Arreglado 2026-07-25: ahora `W=.../cursalialinux/isos/trabajo-moderna`, en la partición p6 que está siempre montada (40 GB libres) |
| 1d | Faltan herramientas de construcción en este sistema nuevo: **`xorriso`** e **`isolinux`** (`isolinux.bin`/`isohdpfx.bin`). Sin ellas los `build-*.sh` fallan en los pasos 3 y 7. (`mkfs.vfat` sí está: vive en `/usr/sbin`) | ✅ Instaladas 2026-07-25 por `probar-grub-uefi.sh`. Verificado: `xorriso`, `isolinux`, `mksquashfs`, `grub-mkstandalone`, `qemu-system-x86_64` presentes |
| 1f | El menú UEFI reconstruido salía en modo texto y sin fondo: `grub-mkstandalone` no embebía los módulos gráficos y el ISO no llevaba fuente | ✅ Arreglado 2026-07-25 en ambos `build-*.sh`: se añadieron `gfxterm gfxterm_background gfxterm_menu font png gzio` a `--modules` y se copia `/usr/share/grub/unicode.pf2` a `boot/grub/fonts/` del ISO |
| 1g | No había forma rápida de probar el arranque UEFI sin construir un ISO completo (media hora de squashfs) | ✅ Nuevo `scripts/probar-grub-uefi.sh`: arma un ISO mínimo (kernel + initrd + el grub.cfg reconstruido, sin squashfs) y lo arranca en QEMU con OVMF sacando fotos a los 6/18/35 s. Deja las capturas en `isos/pruebas-uefi/` |
| 1h | `prueba-visual.sh` no sirve para probar el arranque UEFI: solo monta el menú **isolinux (BIOS)**. Además apunta a `cursalialinux-ligera-def.iso`, que **se perdió con p6 y no está en el respaldo**, y guarda las capturas en un `scratchpad` de una sesión vieja que ya no existe | ❌ Sin arreglar. Para el UEFI usar `probar-grub-uefi.sh`; si se quiere recuperar `prueba-visual.sh`, sacar el kernel/initrd de `isos/cursalialinux-ligera-1.0.iso` en vez del `-def.iso` |
| 1e | `recetas/scripts/` contiene una copia **más vieja** de los scripts (usa `es_ES.UTF-8` en vez de `es_MX.UTF-8`, `centro-cursalialinux` de 196 líneas frente a 248). Riesgo de editar o construir con la copia equivocada | ⚠️ Avisado 2026-07-25 con `recetas/scripts/LEEME.txt`. La versión buena es siempre `cursalialinux/scripts/` |
| 2 | La raíz **Moderna** (`cocina/moderna-kde/raiz`) **no tiene `ufw` instalado**. Instalada hoy en otra máquina, sale sin cortafuegos | ❌ Sin arreglar |
| 3 | `LEEME.md` dice que la raíz Ligera está en `cocina/ligera-xfce/raiz`, pero esa carpeta **está vacía**: la raíz Ligera es `cocina/raiz` | ✅ Corregido en `LEEME.md` (tabla de `cocina/`: la Ligera es `cocina/raiz` y `ligera-xfce/` queda como taller de construcción) |

### Dónde está cada raíz de verdad

| Ruta | Edición | Tamaño | ¿ufw? |
|---|---|---|---|
| `cocina/moderna-kde/raiz` | Moderna | 8,5 GB | **NO** |
| `cocina/raiz` | Ligera | 6,2 GB | Sí |
| `cocina/ligera-xfce/` | — | vacía | — |

### Plan para la próxima sesión

1. Aplicar seguridad **dentro de las dos raíces de `cocina/`**
   (`ufw` + `rsyslog` + `unattended-upgrades` + los dos ficheros de
   `apt.conf.d` + `plasma-firewall`/`gufw` según edición).
   Se hace con `sudo chroot`. Es lo que hace que llegue al ISO.
2. Arreglar las rutas de `build-real.sh` y que sirva para las dos ediciones.
3. Corregir `LEEME.md` con la ubicación real de la raíz Ligera.
4. Reconstruir los dos ISOs y comprobar.

---

## Resumen: qué toca cada archivo

| Archivo | Qué hace |
|---|---|
| `recetas/*/hooks/normal/0400-cortafuegos.hook.chroot` | ufw activo + Docker blindado |
| `recetas/*/hooks/normal/0410-actualizaciones-seguridad.hook.chroot` | Parches automáticos, con el filtro corregido |
| `recetas/*/package-lists/cursalialinux.list.chroot` | `ufw`, interfaz gráfica, `rsyslog`, `unattended-upgrades` |
