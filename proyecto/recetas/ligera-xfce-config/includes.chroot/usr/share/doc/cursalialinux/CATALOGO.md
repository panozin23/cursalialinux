# 🧊 Catálogo de herramientas — cursalialinux

Guía para ampliar tu sistema **según tu necesidad**, poco a poco.


## Cómo está organizado

El **Centro cursalialinux** agrupa todo en cinco Estudios. Este catálogo sigue
el mismo orden, así que lo que ves en pantalla es lo que encuentras aquí.

| Estudio | Para qué |
|---|---|
| 🪟 **Windows Studio** | Ejecutar programas de Windows dentro de cursalialinux |
| 💻 **Desarrollo Web** | Crear sitios: Laravel, WordPress, editores, bases de datos, SEO |
| 🎬 **Video Studio** | Editar, grabar pantalla, subtítulos y karaoke |
| 🖼️ **Imágenes y Diseño** | Gráficos, fotos, logos e imágenes libres |
| 🧰 **Utilitarios** | Audio, oficina, internet, seguridad y mantenimiento |

> ✅ = ya viene incluido &nbsp;·&nbsp; 📥 = opcional, se instala con un clic

## ¿Cómo instalar cualquiera de estas?

**Opción A (fácil):** abre la **Terminal** y escribe:

```
sudo apt install NOMBRE
```

(te pedirá tu contraseña; luego se descarga e instala solo).

**Opción B (aún más fácil):** desde el **Centro cursalialinux**, en cada Studio las herramientas pesadas tienen un botón **“📥 Instalar”** — un clic y listo.

> ✅ = ya viene incluido en cursalialinux &nbsp;·&nbsp; 📥 = opcional, instálalo si lo necesitas
> Requiere conexión a internet solo al momento de instalar.

---

## 🪟 Windows Studio — usar programas de Windows aquí

¿Tu trabajo te obliga a usar un programa que solo existe para Windows? No hace
falta reiniciar ni renunciar a cursalialinux: puedes ejecutarlo **en una ventana**,
como cualquier otro programa.

Sirve para sistemas institucionales de escritorio, programas de contabilidad,
lectores de PDF con firma digital, Laragon y cualquier cosa que no tenga
equivalente libre.

**Todo está en el Centro cursalialinux → 🪟 Windows Studio**, en tres pasos:

| Paso | Qué hace |
|---|---|
| 1️⃣ ¿Puede mi equipo? | Comprueba tu procesador, memoria y disco. **No instala nada** |
| 2️⃣ Instalar herramientas | Baja lo necesario (~400 MB, solo si lo pides) |
| 3️⃣ Crear la máquina | Elige la versión de Windows y el resto lo hace solo |

Después aparecen dos programas nuevos en tu menú:

| Herramienta | Para qué sirve |
|---|---|
| **Windows** ✅ | Abre tu Windows en una ventana. Al cerrar guarda el estado, así la próxima vez abre en segundos |
| **Panel de Windows** ✅ | Cortar o dar internet, pasarle archivos con un CD virtual, y tomar instantáneas para volver atrás si algo sale mal |

**Funciona con Windows 7, 8.1, 10 y 11.** Cada versión necesita ajustes distintos
y el asistente los aplica solo — incluido el detalle de que Windows 7 no reconoce
el USB 3.0 y se queda sin teclado si no se configura bien.

> ⚖️ **Importante:** cursalialinux prepara la computadora virtual, pero **Windows
> es de Microsoft y requiere licencia**. Conseguirla es responsabilidad de cada
> quien. Lee *Licencias y responsabilidad* dentro del Windows Studio: explica los
> tipos de licencia y las opciones legales gratuitas que existen.

> 🛡️ Si vas a usar **Windows 7, 8.1 o 10**, que ya no reciben parches de
> seguridad, lee también *Proteger un Windows sin soporte*. El resumen: córtale
> internet cuando no lo uses y toma instantáneas. Ambas cosas están a un botón en
> el Panel.

## 💻 Desarrollo Web — Laravel, WordPress, editores, SEO

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **VSCodium** ✅ | Editor de código | *(incluido)* | vscodium.com |
| **Git** ✅ | Control de versiones | *(incluido)* | git-scm.com |
| **Node.js + npm** ✅ | JavaScript del lado servidor | *(incluido)* | nodejs.org |
| **PHP + Composer** ✅ | Desarrollo web PHP | *(incluido)* | php.net |
| **Python 3** ✅ | Lenguaje Python | *(incluido)* | python.org |
| **Docker** ✅ | Contenedores | *(incluido)* | docker.com |
| **SQLite Browser** ✅ | Ver bases de datos | *(incluido)* | sqlitebrowser.org |
| **Meld** ✅ | Comparar archivos/código | *(incluido)* | meldmerge.org |
| **FileZilla** 📥 | Subir archivos por FTP/SFTP | `sudo apt install filezilla` | filezilla-project.org |
| **Bluefish** 📥 | Editor web (HTML/PHP/CSS) | `sudo apt install bluefish` | bluefish.openoffice.nl |
| **Git-cola** 📥 | Git con ventanas (visual) | `sudo apt install git-cola` | git-cola.github.io |
| **Chromium** 📥 | Navegador para probar tus webs | `sudo apt install chromium` | chromium.org |

## 🎬 Video Studio — edición, grabación y karaoke

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **Shotcut** ✅ | Editor de video sencillo y potente | *(incluido)* | shotcut.org |
| **HandBrake** ✅ | Convertir/comprimir videos | *(incluido)* | handbrake.fr |
| **SimpleScreenRecorder** ✅ | Grabar la pantalla | *(incluido)* | maartenbaert.be/simplescreenrecorder |
| **VLC** 📥 | Reproductor que abre casi todo | `sudo apt install vlc` | videolan.org |
| **Kdenlive** 📥 | Editor de video profesional (multipista) | `sudo apt install kdenlive` | kdenlive.org |
| **OpenShot** 📥 | Editor de video fácil para empezar | `sudo apt install openshot-qt` | openshot.org |
| **OBS Studio** 📥 | Grabar y transmitir en vivo (streaming) | `sudo apt install obs-studio` | obsproject.com |
| **Cheese** 📥 | Cámara web (fotos y video) | `sudo apt install cheese` | wiki.gnome.org/Apps/Cheese |
| 🎤 **Aegisub** 📥 | Subtítulos y **karaoke** (letras con colores/tiempos) | `sudo apt install aegisub` | aegisub.org |
| 🎤 **Subtitle Editor** 📥 | Crear y editar subtítulos | `sudo apt install subtitleeditor` | packages.debian.org/trixie/subtitleeditor |
| 🎤 **Performous** 📥 | Cantar karaoke con puntaje (juego) | `sudo apt install performous` | performous.org |

## 🖼️ Imágenes y Diseño — gráficos, fotos, logos

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **GIMP** ✅ | Editar imágenes (estilo Photoshop) | *(incluido)* | gimp.org |
| **Inkscape** ✅ | Vectores y logos (estilo Illustrator) | *(incluido)* | inkscape.org |
| **Krita** ✅ | Dibujo e ilustración digital | *(incluido)* | krita.org |
| **Darktable** 📥 | Revelado de fotos RAW (estilo Lightroom) | `sudo apt install darktable` | darktable.org |
| **RawTherapee** 📥 | Otro revelador de fotos RAW | `sudo apt install rawtherapee` | rawtherapee.com |
| **Scribus** 📥 | Maquetación (revistas, folletos, PDF) | `sudo apt install scribus` | scribus.net |
| **digiKam** 📥 | Organizar y catalogar fotos | `sudo apt install digikam` | digikam.org |
| **Blender** 📥 | 3D, modelado y animación | `sudo apt install blender` | blender.org |

### 🗜️ Optimizar y comprimir imágenes — ¡clave para web!

> Una web con imágenes pesadas carga lenta. Estas herramientas **reducen el peso sin perder calidad visible** — imprescindible si manejas muchas imágenes.

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **Trimage** 📥 | Comprime PNG/JPG sin perder calidad (arrastrar y soltar) | `sudo apt install trimage` | trimage.org |
| **pngquant** 📥 | Comprime PNG con enorme ahorro (ideal para web) | `sudo apt install pngquant` | pngquant.org |
| **OptiPNG** 📥 | Optimiza PNG sin pérdida de calidad | `sudo apt install optipng` | optipng.sourceforge.net |
| **jpegoptim** 📥 | Optimiza y comprime archivos JPG | `sudo apt install jpegoptim` | github.com/tjko/jpegoptim |
| **WebP** 📥 | Convierte a WebP, el formato **más liviano** para web | `sudo apt install webp` | developers.google.com/speed/webp |
| **Converseen** 📥 | Convertir y redimensionar imágenes **por lotes** (500 de una vez) | `sudo apt install converseen` | converseen.fasterland.net |
| **gThumb** 📥 | Ver, redimensionar y convertir por lotes | `sudo apt install gthumb` | wiki.gnome.org/Apps/gthumb |
| **ImageMagick** 📥 | Todo terreno por comandos (redimensionar, convertir, comprimir) | `sudo apt install imagemagick` | imagemagick.org |
| **scour** 📥 | Optimizar y limpiar archivos SVG (logos) | `sudo apt install scour` | github.com/scour-project/scour |
| **Gifsicle** 📥 | Optimizar y crear GIF animados | `sudo apt install gifsicle` | lcdf.org/gifsicle |

**Truco para optimizar cientos de imágenes de golpe** (en la Terminal, dentro de la carpeta):

```
pngquant --quality=65-80 *.png      # comprime todos los PNG (mucho ahorro)
jpegoptim --max=82 *.jpg            # optimiza todos los JPG
cwebp -q 80 foto.jpg -o foto.webp   # convierte a WebP (lo más liviano)
```

### 🖼️ Bancos de imágenes libres (uso comercial)

> El Studio Imágenes trae un **Buscador de imágenes libres** integrado (Openverse) que solo muestra imágenes de **uso comercial** con su licencia visible. Estas son las fuentes:

| Fuente | Qué ofrece | Web |
|---|---|---|
| **Openverse** | Millones de imágenes CC / dominio público, con licencia clara. Sin registro. | openverse.org |
| **Pixabay** | Fotos, vectores e ilustraciones gratis, uso comercial. | pixabay.com |
| **Pexels** | Fotos y videos gratis de alta calidad, uso comercial. | pexels.com |
| **Unsplash** | Fotos profesionales gratis. | unsplash.com |

**⚠️ 3 reglas para no cometer errores legales:**
1. **CC0 / Dominio público** = libre total. **CC-BY** = puedes usarla pero **debes dar crédito**.
2. Personas reconocibles, **marcas, logos o productos** en la foto pueden tener derechos aparte.
3. Ante la duda, **lee la licencia** (el buscador te la muestra).


## 🧰 Utilitarios

Todo lo demás que trae el sistema. No son el objetivo principal de
cursalialinux, pero están completos y a un clic cuando los necesites.

### 🎙️ Audio Studio — música, podcast y grabación

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **Audacity** ✅ | Grabar y editar audio / podcast | *(incluido)* | audacityteam.org |
| **LMMS** 📥 | Producción de música (estilo FL Studio) | `sudo apt install lmms` | lmms.io |
| **Hydrogen** 📥 | Caja de ritmos / batería | `sudo apt install hydrogen` | hydrogenmusic.org |
| **MuseScore** 📥 | Escribir partituras musicales | `sudo apt install musescore3` | musescore.org |
| **Mixxx** 📥 | Mezclar como DJ | `sudo apt install mixxx` | mixxx.org |
| **Rosegarden** 📥 | Secuenciador y edición MIDI | `sudo apt install rosegarden` | rosegardenmusic.com |
| **Kid3** 📥 | Editar etiquetas de MP3 (título, artista) | `sudo apt install kid3` | kid3.kde.org |
| **Ardour** 📥 | Estudio de grabación profesional (DAW) | `sudo apt install ardour` | ardour.org |

### 📄 Oficina — Word, Excel, PowerPoint

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **LibreOffice** ✅ | Writer, Calc, Impress (Word/Excel/PowerPoint) | *(incluido)* | libreoffice.org |
| **Evince** 📥 | Leer PDF (ligero) | `sudo apt install evince` | wiki.gnome.org/Apps/Evince |
| **Xournal++** 📥 | Anotar/firmar PDF y tomar apuntes | `sudo apt install xournalpp` | xournalpp.github.io |
| **Calibre** 📥 | Gestionar y convertir libros electrónicos | `sudo apt install calibre` | calibre-ebook.com |

### 🌐 Internet — navegar, correo, descargas

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **Firefox** ✅ | Navegador | *(incluido)* | mozilla.org/firefox |
| **qBittorrent** 📥 | Descargas por torrent | `sudo apt install qbittorrent` | qbittorrent.org |
| **Thunderbird** 📥 | Correo electrónico | `sudo apt install thunderbird` | thunderbird.net |

### 🛡️ Seguridad — proteger tu equipo y auditar TUS webs

> Los básicos vienen instalados. Las herramientas de auditoría son para **probar la seguridad de tus propios proyectos web** (uso legítimo del desarrollador).

**Protección (ya incluidos):**

| Herramienta | Para qué sirve | Web oficial |
|---|---|---|
| **KeePassXC** ✅ | Gestor de contraseñas seguro | keepassxc.org |
| **Cortafuegos (gufw)** ✅ | Controlar conexiones de red | (incluido) |

**Auditar la seguridad de tus webs (instalar según necesites):**

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **ClamTk** 📥 | Antivirus (escanear archivos) | `sudo apt install clamtk` | clamtk.sourceforge.io |
| **nmap** 📥 | Escanear puertos y red | `sudo apt install nmap` | nmap.org |
| **Wireshark** 📥 | Analizar tráfico de red | `sudo apt install wireshark` | wireshark.org |
| **Nikto** 📥 | Escáner de vulnerabilidades web | `sudo apt install nikto` | cirt.net/Nikto2 |
| **sqlmap** 📥 | Probar inyección SQL en tus webs | `sudo apt install sqlmap` | sqlmap.org |
| **Wapiti** 📥 | Escáner de vulnerabilidades web | `sudo apt install wapiti` | wapiti-scanner.github.io |
| **WhatWeb** 📥 | Detectar tecnologías de una web | `sudo apt install whatweb` | github.com/urbanadventurer/WhatWeb |
| **dirb** 📥 | Descubrir rutas ocultas de una web | `sudo apt install dirb` | (Kali/Debian) |
| **Lynis** 📥 | Auditoría de seguridad del sistema | `sudo apt install lynis` | cisofy.com/lynis |
| **OWASP ZAP** 📥 | Auditar webs (completo, gráfico) | *(descargar de la web)* | zaproxy.org |
| **Burp Suite Community** 📥 | Auditar webs (estándar de la industria) | *(descargar de la web)* | portswigger.net/burp |

### 🛠️ Sistema — mantenimiento y limpieza

| Herramienta | Para qué sirve | Instalar | Web oficial |
|---|---|---|---|
| **BleachBit** 📥 | Limpiar caché, basura y liberar espacio | `sudo apt install bleachbit` | bleachbit.org |
| **GParted** 📥 | Administrar particiones del disco | `sudo apt install gparted` | gparted.org |
| **Timeshift** 📥 | Respaldos/puntos de restauración | `sudo apt install timeshift` | github.com/linuxmint/timeshift |

### 🧹 Limpieza rápida sin instalar nada
Para limpiar caché, basura y paquetes huérfanos, en la Terminal:

```
sudo apt autoremove --purge      # quita paquetes huérfanos
sudo apt clean                   # borra paquetes descargados
rm -rf ~/.cache/thumbnails/*     # borra miniaturas viejas
```

---

*cursalialinux · Azul Hielo · Catálogo de herramientas — instala según tu necesidad.*

