import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: raiz

    // ---------------- estado medido ----------------
    property real bajadaBs: 0        // media movil, bytes por segundo
    property real subidaBs: 0
    property real bajadaInst: 0      // ultima lectura sin suavizar
    property real subidaInst: 0
    property var  muestrasB: []
    property var  muestrasS: []
    property real rxPrev: -1
    property real txPrev: -1
    property real tPrev: 0
    property int  pingMs: -1
    property bool sinRed: false
    property string ifaz: ""

    // ---------------- configuracion ----------------
    readonly property int  umbralKB:  Plasmoid.configuration.umbralKB
    readonly property int  activoKB:  Plasmoid.configuration.activoKB
    readonly property int  modo:      Plasmoid.configuration.modo
    readonly property int  pingMaxMs: Plasmoid.configuration.pingMaxMs

    // ---------------- logica del aviso ----------------
    readonly property real bajadaKB: bajadaBs / 1024
    readonly property real subidaKB: subidaBs / 1024
    readonly property bool hayDescarga: bajadaKB >= activoKB
    readonly property bool lenta: bajadaKB < umbralKB

    readonly property bool alerta: {
        if (modo === 1) return lenta
        if (modo === 2) {
            if (sinRed) return true
            if (pingMs > pingMaxMs) return true
            return hayDescarga && lenta
        }
        return hayDescarga && lenta
    }

    readonly property color colorTexto: alerta ? Kirigami.Theme.negativeTextColor
                                               : Kirigami.Theme.textColor

    // ---------------- comandos ----------------
    readonly property string cmdBytes: "awk '/:/ {gsub(/:/,FS); n=$1; if (n ~ /^(lo|docker|veth|br-|virbr|tun|tap)/) next; rx+=$2; tx+=$10} END {print rx+0, tx+0}' /proc/net/dev"
    readonly property string cmdRuta:  "ip route show default"
    readonly property string cmdPing:  "ping -n -c 1 -W 2 " + Plasmoid.configuration.pingHost

    // ---------------- utilidades ----------------
    function coma(n, dec) {
        return n.toFixed(dec).replace(".", ",")
    }

    // cuantas lecturas entran en la media, segun los segundos configurados
    readonly property int nMuestras: Math.max(1, Math.round(
        Plasmoid.configuration.suavizadoSeg * 1000 / Plasmoid.configuration.intervaloMs))

    function media(a) {
        if (a.length === 0) return 0
        var s = 0
        for (var i = 0; i < a.length; i++) s += a[i]
        return s / a.length
    }

    function fmt(bs) {
        var kb = bs / 1024
        if (kb < 1)     return "0 KB/s"
        if (kb < 10)    return coma(kb, 1) + " KB/s"
        if (kb < 1024)  return Math.round(kb) + " KB/s"
        return coma(kb / 1024, 1) + " MB/s"
    }

    function procesarBytes(salida) {
        var p = salida.trim().split(/\s+/)
        if (p.length < 2) return
        var rx = parseFloat(p[0])
        var tx = parseFloat(p[1])
        if (isNaN(rx) || isNaN(tx)) return
        var ahora = Date.now()
        if (rxPrev >= 0) {
            var dt = (ahora - tPrev) / 1000
            var drx = rx - rxPrev
            var dtx = tx - txPrev
            // si los contadores se reinician (cambio de adaptador) se ignora la muestra
            if (dt > 0 && drx >= 0 && dtx >= 0) {
                bajadaInst = drx / dt
                subidaInst = dtx / dt

                // media movil: el numero deja de saltar de un segundo a otro
                muestrasB.push(bajadaInst)
                muestrasS.push(subidaInst)
                while (muestrasB.length > nMuestras) muestrasB.shift()
                while (muestrasS.length > nMuestras) muestrasS.shift()

                bajadaBs = media(muestrasB)
                subidaBs = media(muestrasS)
            }
        }
        rxPrev = rx
        txPrev = tx
        tPrev = ahora
    }

    function procesarPing(salida) {
        var m = /time=([0-9.]+)/.exec(salida)
        if (m) {
            pingMs = Math.round(parseFloat(m[1]))
            sinRed = false
        } else {
            pingMs = -1
            sinRed = true
        }
    }

    function procesarRuta(salida) {
        var m = /dev\s+(\S+)/.exec(salida)
        ifaz = m ? m[1] : ""
    }

    // ---------------- lector ----------------
    Plasma5Support.DataSource {
        id: ejecutor
        engine: "executable"
        connectedSources: []

        onNewData: function(fuente, datos) {
            disconnectSource(fuente)
            var salida = datos["stdout"] || ""
            if (fuente === raiz.cmdBytes)      raiz.procesarBytes(salida)
            else if (fuente === raiz.cmdRuta)  raiz.procesarRuta(salida)
            else if (fuente === raiz.cmdPing)  raiz.procesarPing(salida)
        }

        function correr(cmd) {
            disconnectSource(cmd)
            connectSource(cmd)
        }
    }

    Timer {
        interval: Plasmoid.configuration.intervaloMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ejecutor.correr(raiz.cmdBytes)
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ejecutor.correr(raiz.cmdRuta)
    }

    Timer {
        interval: 5000
        running: raiz.modo === 2
        repeat: true
        triggeredOnStart: true
        onTriggered: ejecutor.correr(raiz.cmdPing)
    }

    // ---------------- texto emergente ----------------
    toolTipMainText: "Velocidad de red"
    toolTipSubText: {
        var t = "Bajada: " + fmt(bajadaBs) + "\nSubida: " + fmt(subidaBs)
        t += "\n(media de " + Plasmoid.configuration.suavizadoSeg + " s)"
        if (ifaz !== "") t += "\nSaliendo por: " + ifaz
        if (modo === 2) t += sinRed ? "\nConexion: CAIDA"
                                    : "\nRespuesta: " + (pingMs >= 0 ? pingMs + " ms" : "?")
        t += alerta ? "\n\nPor debajo del limite (" + umbralKB + " KB/s)"
                    : "\n\nLimite: " + umbralKB + " KB/s"
        return t
    }

    // ---------------- vista en la barra ----------------
    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compacto
        Layout.minimumWidth:  columna.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.minimumHeight: Kirigami.Units.gridUnit
        acceptedButtons: Qt.LeftButton
        onClicked: raiz.expanded = !raiz.expanded

        ColumnLayout {
            id: columna
            anchors.centerIn: parent
            spacing: 0

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: "↓ " + raiz.fmt(raiz.bajadaBs)
                color: raiz.colorTexto
                font.pixelSize: Plasmoid.configuration.mostrarSubida
                                ? Math.max(9, compacto.height * 0.42)
                                : Math.max(10, compacto.height * 0.55)
                font.bold: raiz.alerta
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                visible: Plasmoid.configuration.mostrarSubida
                text: "↑ " + raiz.fmt(raiz.subidaBs)
                color: Kirigami.Theme.textColor
                opacity: 0.75
                font.pixelSize: Math.max(9, compacto.height * 0.42)
            }
        }

        // parpadeo suave solo si la conexion esta caida
        SequentialAnimation {
            running: raiz.modo === 2 && raiz.sinRed
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { target: columna; property: "opacity"; to: 0.3; duration: 600 }
            NumberAnimation { target: columna; property: "opacity"; to: 1.0; duration: 600 }
            onRunningChanged: if (!running) columna.opacity = 1.0
        }
    }

    // ---------------- vista desplegada ----------------
    fullRepresentation: Item {
        Layout.preferredWidth:  Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 13

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 3
                text: "Velocidad de red"
            }

            Kirigami.Separator { Layout.fillWidth: true }

            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                PlasmaComponents.Label { text: "Bajada"; opacity: 0.7 }
                PlasmaComponents.Label {
                    text: raiz.fmt(raiz.bajadaBs)
                    color: raiz.colorTexto
                    font.bold: true
                }

                PlasmaComponents.Label { text: "Subida"; opacity: 0.7 }
                PlasmaComponents.Label { text: raiz.fmt(raiz.subidaBs) }

                PlasmaComponents.Label { text: "Ahora mismo"; opacity: 0.7 }
                PlasmaComponents.Label {
                    text: "↓ " + raiz.fmt(raiz.bajadaInst) + "   ↑ " + raiz.fmt(raiz.subidaInst)
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }

                PlasmaComponents.Label { text: "Saliendo por"; opacity: 0.7 }
                PlasmaComponents.Label { text: raiz.ifaz !== "" ? raiz.ifaz : "sin ruta" }

                PlasmaComponents.Label {
                    text: "Respuesta"
                    opacity: 0.7
                    visible: raiz.modo === 2
                }
                PlasmaComponents.Label {
                    visible: raiz.modo === 2
                    text: raiz.sinRed ? "sin conexion"
                                      : (raiz.pingMs >= 0 ? raiz.pingMs + " ms" : "...")
                    color: (raiz.sinRed || raiz.pingMs > raiz.pingMaxMs)
                           ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                }

                PlasmaComponents.Label { text: "Limite"; opacity: 0.7 }
                PlasmaComponents.Label { text: raiz.umbralKB + " KB/s" }
            }

            Item { Layout.fillHeight: true }

            Kirigami.Separator { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    width: Kirigami.Units.gridUnit * 0.6
                    height: width
                    radius: width / 2
                    color: raiz.alerta ? Kirigami.Theme.negativeTextColor
                                       : Kirigami.Theme.positiveTextColor
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    text: {
                        if (raiz.modo === 2 && raiz.sinRed) return "Sin conexion a internet"
                        if (raiz.modo === 2 && raiz.pingMs > raiz.pingMaxMs) return "La conexion responde muy lenta"
                        if (raiz.alerta) return "Descargando por debajo del limite"
                        if (raiz.modo !== 1 && !raiz.hayDescarga) return "En reposo, sin descargas"
                        return "Todo correcto"
                    }
                }
            }
        }
    }
}
