# 🪟 Windows dentro de cursalialinux

Hoja de trabajo para ejecutar los programas del **Ministerio de Salud de Bolivia**
(SALMI, SOAPS, SNIS) desde cursalialinux, sin arrancar en Windows.

Creada el 2026-07-25 · Equipo: AMD Ryzen 5 5500U · cursalialinux Moderna (Debian 13)

---

## Por qué máquina virtual y no Wine

Las fichas técnicas oficiales de <https://snis.minsalud.gob.bo/software> dicen esto:

| Programa | Sistema que pide | De qué depende |
|---|---|---|
| **SOAPS** 6.0.1 | Windows XP / 7 o superior | .NET Framework + **Microsoft Excel** |
| **SNIS** | Windows XP / 7 o superior | **Microsoft Access + Excel** |
| **SIAHV** 2.0 | Windows XP / 7 o superior | .NET Framework + **Microsoft Excel** |
| **SICE** 6.0.2 | Windows XP / 7 / Server 2003 | **SQL Server 2005** + Excel 2007 |

*(De SALMI no se pudo confirmar la ficha; se asume la misma familia.)*

Piden **Microsoft Excel y Access de verdad**, no LibreOffice: los programas
llaman a Excel por su nombre para generar reportes. Esa combinación
(.NET + Office real) es justo donde Wine se vuelve frágil.

**Conclusión: Windows real dentro de una máquina virtual.** Es la opción
aburrida y por eso la correcta para una herramienta de trabajo.

---

## Antes de empezar — la lista de la compra

1. **ISO de Windows 11** — <https://www.microsoft.com/software-download/windows11>
2. **Drivers VirtIO** — el archivo `virtio-win.iso`, versión **estable**
   <https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/>
   > Sin esto Windows no verá el disco duro durante la instalación.
3. **Licencia de Microsoft Office** — ✅ confirmada
4. **Licencia de Windows** — ver la nota al final

---

## Paso 1 — Preparar cursalialinux

Dos scripts, en este orden. El primero **solo mira**, no cambia nada:

```bash
cd ~/PROYECTOS-CURSALIA/cursalialinux/scripts
bash virt-inspeccionar.sh
```

Lee el veredicto del final. Si sale ✅, entonces:

```bash
sudo bash virt-instalar.sh
```

Te pedirá escribir `INSTALAR` para confirmar.

> ⚠️ **Al terminar, cierra la sesión y vuelve a entrar.** Los grupos nuevos
> (`kvm`, `libvirt`) no se aplican hasta ese momento. Si no lo haces,
> virt-manager dará errores de permisos y parecerá que algo falló.

---

## Paso 2 — Crear la máquina virtual

Abre **Gestor de máquinas virtuales** (`virt-manager`) → *Archivo* → *Nueva máquina virtual*.

En la última pantalla marca **«Personalizar configuración antes de instalar»**.
Sin eso no podrás tocar lo importante.

### Configuración exacta

| Apartado | Valor | Por qué |
|---|---|---|
| **Chipset** | `Q35` | El moderno, con PCIe. El otro (i440FX) es de los 90 |
| **Firmware** | `UEFI` con **Secure Boot** (`OVMF ... secboot`) | Windows 11 lo exige |
| **Memoria** | 6144 MB (6 GB) | De tus 14 GB. Puedes subir a 8 GB si va justo |
| **Procesadores** | 4 vCPU | De tus 12 hilos |
| **Modelo de CPU** | `host-passthrough` | Le pasa tu Ryzen tal cual: velocidad casi nativa |
| **Disco** | 80 GB, formato **qcow2**, bus **VirtIO** | 64 GB es el mínimo de Windows; Office pide más |
| Caché del disco | `writeback` | Lo que recomienda la guía de referencia |
| Descarte (*discard*) | `unmap` | Permite que el archivo encoja al borrar dentro de Windows |
| **Red** | Modelo **VirtIO**, red `default` | La rápida |
| **TPM** | Añadir hardware → TPM → Emulado, versión **2.0**, modelo **CRB** | El corazón del asunto |
| Vídeo | `QXL` o `virtio` | Ambos van bien con SPICE |

> ⚠️ **Firmware y chipset se eligen AL CREAR la máquina.** Después no se
> pueden cambiar sin rehacerla desde cero. Revísalos dos veces.

### ⚠️ El ajuste obligatorio para AMD

Tu procesador es un **Ryzen**. Si activas las mejoras Hyper-V (recomendadas
para rendimiento), el XML incluye una línea que **los AMD no soportan**:

```xml
<evmcs state="on"/>
```

**Hay que borrarla.** Si se queda, la máquina virtual sencillamente no arranca
y el mensaje de error no dice por qué.

Para editarlo: en virt-manager, *Editar → Preferencias → marcar «Habilitar
edición XML»*. Luego, en la máquina, pestaña **XML**, buscar `evmcs` y borrar
esa línea. Guarda una copia del XML antes de tocarlo.

---

## Paso 3 — Instalar Windows

Aquí hay dos momentos donde tropieza todo el mundo:

### 🔸 «Press any key to boot from CD or DVD»

Aparece unos segundos en el primer arranque. **Si lo dejas pasar, no arranca
el instalador.** No está roto: apaga la máquina virtual, enciéndela otra vez
y esta vez pulsa una tecla a tiempo.

### 🔸 La pantalla de discos aparece VACÍA

Cuando Windows pregunte dónde instalarse, **no verá ningún disco**. Es normal:
Windows no conoce los discos VirtIO de fábrica.

1. Pulsa **«Cargar controlador»**
2. Busca en la unidad de CD del `virtio-win.iso` → carpeta `Viostor\w11\amd64`
3. Aparecerá el disco de 80 GB
4. Repite para la red: carpeta `NetKVM\w11\amd64`

Mucha gente abandona justo en este punto creyendo que algo falló.

---

## Paso 4 — Después de instalar

1. Dentro de Windows, abre el CD de VirtIO y ejecuta **`virtio-win-guest-tools.exe`**
   → instala el agente invitado de QEMU y los drivers de vídeo.
   Sin esto la pantalla va lenta, la resolución no se ajusta sola y no se puede
   apagar limpiamente desde Linux.
2. Instalar **Microsoft Office** (Excel y Access — obligatorios).
3. Instalar **.NET Framework** si algún programa lo pide.
4. Recién entonces: **SALMI, SOAPS, SNIS**.

### ⚠️ El canal del agente invitado

Instalar `virtio-win-guest-tools.exe` dentro de Windows **no basta**: la máquina
virtual necesita además un **canal** por donde el agente hable con Linux. Si falta,
`virsh` responde *«Agente de huésped QEMU no está configurado»* aunque el agente
esté correctamente instalado en Windows.

Comprobar:

```bash
virsh -c qemu:///system dumpxml Windows11-Salud | grep guest_agent
```

Si no devuelve nada, añadirlo (la máquina puede estar encendida; se aplica al
siguiente arranque):

```bash
cat > /tmp/canal-agente.xml <<'XML'
<channel type='unix'>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
XML
virsh -c qemu:///system attach-device Windows11-Salud /tmp/canal-agente.xml --config
```

Después, **apagar y encender** la máquina (reiniciar desde dentro de Windows no
sirve: el hardware virtual se construye al arrancar el proceso).

*(El script `virt-crear-windows.sh` ya lo incluye desde el 2026-07-26.)*

### Ajustes opcionales de rendimiento

- Desactivar el servicio **SysMain** (SuperFetch)
- Desactivar sugerencias de búsqueda web
- `bcdedit /deletevalue useplatformclock`
- Reducir los efectos visuales
- Quitar programas del arranque automático

---

## Paso 5 — La prueba de verdad

**Usar los tres programas una semana normal de trabajo.** Esto es lo que decide
si la función entra o no en cursalialinux. Anotar:

- [ ] ¿SALMI instala y abre?
- [ ] ¿SOAPS instala y abre?
- [ ] ¿SNIS instala y abre?
- [ ] ¿Los reportes a Excel salen bien?
- [ ] ¿Va con fluidez o se arrastra?
- [ ] ¿Se conectan a la red del ministerio sin problemas?
- [ ] ¿Cuánta RAM y disco consume de verdad?

---

## ☠️ Cómo borrar la máquina virtual SIN perder los ISOs

Para rehacer la máquina desde cero, **dos pasos**:

```bash
sudo virsh undefine Windows11-Salud --nvram
sudo rm -f /var/lib/libvirt/images/windows11-salud.qcow2
```

### ⚠️ NUNCA uses `--remove-all-storage`

```bash
# ☠️ ESTO BORRA TAMBIÉN LOS ISOs DE WINDOWS Y VIRTIO
sudo virsh undefine Windows11-Salud --nvram --remove-all-storage
```

Para libvirt, los CDs conectados **son discos**. `--remove-all-storage` los
elimina junto con el disco duro virtual, sin preguntar y sin pasar por la
papelera. Son 8,5 GB de descarga perdidos.

*(Comprobado a la mala el 2026-07-25.)*

### Guarda una copia maestra

Para no volver a descargar 7,7 GB nunca más, copia los ISOs al disco externo
**SANSUNG2** en cuanto los tengas:

```bash
cp /var/lib/libvirt/images/Win11_25H2_Spanish_Mexico_x64_v2.iso  /ruta/al/SANSUNG2/
cp /var/lib/libvirt/images/virtio-win-0.1.285.iso                /ruta/al/SANSUNG2/
```

---

## Nota sobre la licencia de Windows

El Windows instalado en `p3` de este equipo probablemente traiga licencia OEM
grabada en el firmware, atada a la máquina física. **Una máquina virtual no la
hereda.**

Windows 11 se instala y funciona **sin activar**: marca de agua en la esquina y
personalización bloqueada, pero los programas corren igual. Para trabajar sirve.
Conviene saberlo de antemano y no como sorpresa.

---

## Si esto funciona: llevarlo a la distro

El plan es **no meter los paquetes en la ISO** (añadirían ~500 MB a los 3,2 GB
de Moderna, para algo que la mayoría no usará). En su lugar, seguir el patrón
que el proyecto ya tiene:

- Un módulo **🪟 Windows Studio** en el [Centro cursalialinux](../scripts/centro-cursalialinux),
  con botón **📥 Instalar** que llama a `virt-instalar.sh`
- Una sección nueva en el [CATÁLOGO](CATALOGO-cursalialinux.md)

**Coste para la ISO: prácticamente cero.** Y resuelve un problema real de mucha
gente en salud pública en Bolivia, atada a Windows exactamente por estos programas.

---

## Fuentes

- Guía de referencia (2025): <https://sysguides.com/install-windows-11-on-kvm>
- Guía original citada en el video: <https://sysguides.com/install-a-windows-11-virtual-machine-on-kvm>
- Video en español (LinuxD0, dic 2024): <https://www.youtube.com/watch?v=mYa0d5x9-tA>
- Fichas técnicas de los programas: <https://snis.minsalud.gob.bo/software>
