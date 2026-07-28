# Licencias y responsabilidad

Aviso sobre el uso de Windows y otro software propietario dentro de cursalialinux.
Escrito el 2026-07-26.

---

## Lo esencial en tres frases

1. **cursalialinux te da la herramienta, no el software.** Los scripts y guías de
   este proyecto preparan una computadora virtual. Vacía.
2. **Windows y Office son de Microsoft y requieren licencia.** Conseguirla es
   responsabilidad de quien los instala.
3. **Todo esto se publica con fines educativos.** Lo que cada persona haga con
   ello es decisión y responsabilidad suya.

---

## Qué hace y qué no hace este proyecto

**Lo que hacemos:** documentar cómo configurar KVM, QEMU y virt-manager —todos
programas libres— para crear una máquina virtual capaz de ejecutar Windows.

**Lo que NO hacemos:** distribuir Windows, distribuir Office, proporcionar claves
de activación, ni explicar cómo saltarse la activación.

La analogía es sencilla: enseñamos a construir el estante, no regalamos los libros.

---

## Sobre las licencias de Windows

Microsoft **permite descargar** las imágenes de Windows libremente desde su sitio
oficial. Eso a veces confunde: descargar es gratis, **usar no lo es**. El sistema
requiere una licencia según los términos de Microsoft.

### Tipos de licencia y qué implican

| Tipo | Cómo se reconoce | ¿Sirve para una máquina virtual? |
|---|---|---|
| **OEM** | Vino con el equipo de fábrica | Normalmente **no**: está atada al equipo físico donde se activó |
| **Retail** (caja o descarga) | La compraste aparte | Generalmente **sí**, y suele poder trasladarse de equipo |
| **Volumen / corporativa** | La da tu institución | Depende del contrato: **pregunta a tu área de sistemas** |

Si tu equipo trae Windows de fábrica, esa licencia está grabada en el firmware y
atada a esa máquina física. **Una máquina virtual no la hereda.**

### Windows funciona sin activar

Es un hecho técnico, no un permiso: Windows 10 y 11 se instalan y funcionan sin
activación, con marca de agua y la personalización bloqueada. Los términos de
licencia de Microsoft siguen requiriendo una licencia para su uso.

Dicho claramente: que técnicamente arranque no significa que estés en regla.

### Opciones legales y gratuitas para probar

Si solo quieres aprender o evaluar, Microsoft ofrece caminos legítimos:

- **Microsoft Evaluation Center** — Windows Enterprise por 90 días, sin costo
- **Windows dev environment** — máquinas virtuales de desarrollo que Microsoft
  publica ya preparadas
- **Windows Insider** — versiones de prueba para quien se registra

Para aprender virtualización, cualquiera de estas sirve perfectamente y te evita
el problema por completo.

---

## Sobre Microsoft Office

Lo mismo: **Office requiere licencia**. Si tu institución te la proporciona,
pregunta si cubre la instalación en una máquina virtual — normalmente sí, pero
confirmarlo cuesta un correo.

Y si el programa que necesitas no exige Excel específicamente,
**LibreOffice es libre, gratuito y viene incluido en cursalialinux.** Vale la pena
comprobarlo antes de gastar en una licencia.

---

## Versiones antiguas: el otro riesgo

Este es un tema distinto al legal, pero igual de serio.

| Sistema | Último parche de seguridad |
|---|---|
| Windows 7 | enero de 2020 |
| Windows 8.1 | enero de 2023 |
| Windows 10 | octubre de 2025 |
| Windows 11 | con soporte actual |

Un Windows sin parches conectado a internet es un riesgo real: las
vulnerabilidades descubiertas después de esas fechas **no se arreglan nunca**.

### Recomendación práctica

Si necesitas una versión antigua para un programa concreto:

- Úsala **solo para ese programa**, no para navegar ni leer correo
- **Déjala sin internet.** Lo más fácil es desde el Gestor de máquinas virtuales:
  doble clic en la máquina → botón de información → **NIC** → desmarcar
  **«Enlace activo»**. Se puede hacer en caliente, sin apagar.

  Desde la terminal, usando la **dirección MAC** (nunca `vnet0`, que cambia al
  arrancar y no existe con la máquina apagada):
  ```bash
  sudo virsh domiflist NOMBRE                              # ver la MAC
  sudo virsh domif-setlink NOMBRE 52:54:00:xx:xx:xx down   # cortar la red
  sudo virsh domif-setlink NOMBRE 52:54:00:xx:xx:xx up     # devolvérsela
  ```
- **Para pasarle archivos sin red**, crea un CD desde una carpeta de Linux:
  ```bash
  genisoimage -J -r -V DATOS -o /var/lib/libvirt/images/datos.iso ~/mi-carpeta/
  ```
  y añádelo como CDROM desde el Gestor. Funciona en todas las versiones de
  Windows, sin drivers ni configuración. Las opciones `-J -r` permiten nombres
  largos y con acentos.
- Haz **instantáneas** antes de cualquier cambio, para poder volver atrás:
  ```bash
  sudo virsh snapshot-create-as NOMBRE antes-de-actualizar "Estado bueno"
  sudo virsh snapshot-revert     NOMBRE antes-de-actualizar
  ```
- Si necesitas internet un momento (actualizar el propio programa, registrar una
  licencia): **instantánea → encender la red → hacer solo eso → volver a
  cortarla**. Minutos de exposición en vez de meses.

La ventaja de virtualizar es justamente esta: el sistema viejo queda encerrado en
su caja. Si algo le pasa, tu cursalialinux ni se entera.

---

## Aviso de responsabilidad

Este proyecto se publica **con fines educativos y de documentación técnica**.

- El material describe cómo usar software libre (KVM, QEMU, libvirt, virt-manager)
  para virtualizar sistemas operativos.
- **No se distribuye software propietario** ni medios para eludir sus protecciones.
- Quien siga estas guías es **responsable de contar con las licencias** que
  correspondan a lo que instale.
- Los autores **no se hacen responsables** del uso que se dé a esta información,
  ni de pérdidas de datos, fallos de configuración o incumplimientos de términos
  de terceros.
- Esto **no es asesoramiento legal**. Las normas de licenciamiento varían según el
  país y el contrato. Ante la duda, consulta con el titular de la licencia o con
  el área de sistemas de tu institución.

---

## Para instituciones públicas

Si trabajas en salud, educación o cualquier entidad pública, hay un camino que
mucha gente no considera: **preguntar formalmente a tu área de sistemas** si el
contrato de licenciamiento de la institución cubre máquinas virtuales.

En muchos casos sí lo hace, y basta con solicitarlo. Es la vía más limpia y
además deja constancia de que hiciste las cosas bien.

---

## Software libre: siempre la primera opción

Antes de montar una máquina virtual, vale la pena comprobar si lo que necesitas
ya existe libre y sin costo:

| En vez de | Prueba |
|---|---|
| Microsoft Office | LibreOffice, OnlyOffice |
| Adobe Acrobat | Okular, Xournal++, LibreOffice Draw |
| Photoshop | GIMP, Krita |
| AutoCAD | LibreCAD, FreeCAD |
| Outlook | Thunderbird |

La máquina virtual tiene sentido cuando **no hay alternativa**: un programa
institucional obligatorio, un formato propietario que nadie más abre, un trámite
que exige un certificado concreto.

Para todo lo demás, cursalialinux ya trae con qué.
