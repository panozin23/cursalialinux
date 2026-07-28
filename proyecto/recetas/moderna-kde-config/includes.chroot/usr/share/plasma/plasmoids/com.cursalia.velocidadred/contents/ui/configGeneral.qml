import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: raiz

    property alias cfg_umbralKB: umbral.value
    property alias cfg_activoKB: activo.value
    property alias cfg_modo: modo.currentIndex
    property alias cfg_pingHost: host.text
    property alias cfg_pingMaxMs: pingMax.value
    property alias cfg_mostrarSubida: subida.checked
    property alias cfg_intervaloMs: intervalo.value
    property alias cfg_suavizadoSeg: suavizado.value

    // ---------- cuando avisar ----------
    QQC2.ComboBox {
        id: modo
        Kirigami.FormData.label: "Ponerse rojo:"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        model: [
            "Solo si estoy descargando y va lento",
            "Siempre que baje del limite",
            "Vigilar la conexion con ping"
        ]
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.75
        text: modo.currentIndex === 0
            ? "Recomendado. En reposo se queda gris. Solo avisa cuando de verdad hay una descarga en marcha y no alcanza el limite."
            : modo.currentIndex === 1
            ? "Literal: rojo siempre que la bajada este por debajo del limite, aunque no estes haciendo nada. Estara rojo casi todo el dia."
            : "Ademas de la velocidad, comprueba la conexion con un ping. Se pone rojo si internet se cae o responde muy lento, aunque no descargues nada."
    }

    Item { Kirigami.FormData.isSection: false; implicitHeight: Kirigami.Units.largeSpacing }

    // ---------- umbrales ----------
    QQC2.SpinBox {
        id: umbral
        Kirigami.FormData.label: "Limite de velocidad:"
        from: 10
        to: 100000
        stepSize: 50
        editable: true
        textFromValue: function(v) { return v + " KB/s" }
        valueFromText: function(t) { return parseInt(t.replace(/[^0-9]/g, "")) || 0 }
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.75
        text: "Por debajo de esto se considera lento. Referencia: " + umbral.value +
              " KB/s son unos " + (umbral.value * 8 / 1000).toFixed(1) + " Mbps."
    }

    QQC2.SpinBox {
        id: activo
        Kirigami.FormData.label: "Hay descarga a partir de:"
        from: 1
        to: 5000
        stepSize: 5
        editable: true
        enabled: modo.currentIndex !== 1
        textFromValue: function(v) { return v + " KB/s" }
        valueFromText: function(t) { return parseInt(t.replace(/[^0-9]/g, "")) || 0 }
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.75
        enabled: modo.currentIndex !== 1
        text: "Por debajo de este trafico se entiende que estas en reposo y no se avisa."
    }

    Item { Kirigami.FormData.isSection: false; implicitHeight: Kirigami.Units.largeSpacing }

    // ---------- ping ----------
    QQC2.TextField {
        id: host
        Kirigami.FormData.label: "Comprobar contra:"
        enabled: modo.currentIndex === 2
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
    }

    QQC2.SpinBox {
        id: pingMax
        Kirigami.FormData.label: "Latencia maxima:"
        from: 50
        to: 5000
        stepSize: 50
        editable: true
        enabled: modo.currentIndex === 2
        textFromValue: function(v) { return v + " ms" }
        valueFromText: function(t) { return parseInt(t.replace(/[^0-9]/g, "")) || 0 }
    }

    Item { Kirigami.FormData.isSection: false; implicitHeight: Kirigami.Units.largeSpacing }

    // ---------- aspecto ----------
    QQC2.SpinBox {
        id: suavizado
        Kirigami.FormData.label: "Promediar sobre:"
        from: 1
        to: 60
        stepSize: 1
        editable: true
        textFromValue: function(v) { return v + " s" }
        valueFromText: function(t) { return parseInt(t.replace(/[^0-9]/g, "")) || 6 }
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.75
        text: {
            var n = Math.max(1, Math.round(suavizado.value * 1000 / intervalo.value))
            return "Muestra la media de los ultimos " + suavizado.value + " segundos (" + n +
                   " lecturas), no el valor de golpe. Cuanto mas alto, mas quieto el numero, " +
                   "pero mas tarda en reflejar un cambio."
        }
    }

    QQC2.CheckBox {
        id: subida
        Kirigami.FormData.label: "Mostrar tambien:"
        text: "la velocidad de subida"
    }

    QQC2.SpinBox {
        id: intervalo
        Kirigami.FormData.label: "Refrescar cada:"
        from: 500
        to: 10000
        stepSize: 500
        editable: true
        textFromValue: function(v) { return (v / 1000).toFixed(1) + " s" }
        valueFromText: function(t) { return Math.round(parseFloat(t.replace(",", ".")) * 1000) || 1500 }
    }
}
