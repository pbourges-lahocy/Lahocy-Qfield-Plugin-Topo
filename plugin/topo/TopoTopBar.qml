import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoTopBar - barre d'état en haut de la carte : source de mesure (GNSS /
 * station) avec sa qualité, hauteur de canne ou de prisme, accès aux modules
 * (station, carnet, implantation, détecteur, paramètres, mode bureau).
 * Popup non modal (voir TopoPanel pour la raison).
 */
Popup {
  id: bar

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow
  property real reserve: 0          // largeur occupée par le panneau latéral

  signal openCarnet()
  signal openImplantation()
  signal openStationMenu()
  signal openSettings()
  signal openDetection()

  readonly property bool droitier: engine.droitier
  readonly property bool tps: engine.mesureSource === "tps"
  readonly property real safeTop: mainWindow.sceneTopMargin !== undefined ? mainWindow.sceneTopMargin : 0
  readonly property real safeRight: mainWindow.sceneRightMargin !== undefined ? mainWindow.sceneRightMargin : 0
  readonly property real safeLeft: mainWindow.sceneLeftMargin !== undefined ? mainWindow.sceneLeftMargin : 0
  readonly property real menuGap: 60   // bouton de menu QField en haut à gauche

  readonly property string gnssState: engine.qualityState
  readonly property string tpsState: !devices.tpsConnected ? "none" : (devices.tpsLocked || station.driver === "simulateur") ? "ok" : "warn"

  parent: mainWindow.contentItem
  x: droitier ? safeLeft + menuGap : safeLeft + reserve + 8
  y: safeTop + 6
  width: parent.width - safeLeft - safeRight - menuGap - reserve - 16
  height: 48
  padding: 4
  modal: false
  dim: false
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: QfTheme.darkTheme ? "#1f1f1f" : "#ffffff"
    border.color: QfTheme.darkTheme ? "#505050" : "#d4d4d4"
    border.width: 1
    radius: 8
    opacity: 0.96
  }

  function stateColor(s) {
    return s === "ok" ? "#d9f2d9" : s === "warn" ? "#ffe2b8" : s === "bad" ? "#ffd0d0" : (QfTheme.darkTheme ? "#3a3a3a" : "#ececec");
  }

  component Pill: Rectangle {
    property string ui: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    signal clicked()
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 38
    radius: 8
    color: QfTheme.darkTheme ? "#3a3a3a" : "#ececec"
    border.width: active ? 2 : 1
    border.color: active ? QfTheme.mainColor : (QfTheme.darkTheme ? "#505050" : "#d4d4d4")
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 6
      Image {
        source: Qt.resolvedUrl("../theme/ui/") + parent.parent.ui + (QfTheme.darkTheme ? "_w" : "") + ".svg"
        width: 20; height: 20; sourceSize.width: 40; sourceSize.height: 40
        anchors.verticalCenter: parent.verticalCenter
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: parent.parent.parent.label; font.pixelSize: 11; font.bold: parent.parent.parent.active; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020" }
        Text { visible: text !== ""; text: parent.parent.parent.detail; font.pixelSize: 9; color: QfTheme.darkTheme ? "#c8c8c8" : "#505050" }
      }
    }
    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
  }

  contentItem: RowLayout {
    spacing: 6

    Pill {
      ui: "gnss"
      active: !bar.tps
      color: bar.stateColor(bar.gnssState)
      label: bar.gnssState === "none" ? engine.qualityText : engine.qualityDetail.split(/[,\n]/)[0].replace(/^Qualité = /, "")
      detail: bar.gnssState === "none" ? "" : engine.qualityText
      onClicked: engine.setMesureSource("gnss")
    }
    Pill {
      ui: "station"
      active: bar.tps
      color: bar.stateColor(bar.tpsState)
      label: devices.tpsConnected ? (devices.tpsModel.split(" ")[0] || "Station") : "Station"
      detail: !devices.reachable ? "pont injoignable" : !devices.tpsConnected ? "non connectée" : ((devices.tpsLocked || station.driver === "simulateur") ? "verrouillé" : "ATR") + (devices.tpsBattery !== null ? "  " + devices.tpsBattery + " %" : "")
      onClicked: { if (bar.tps) bar.openStationMenu(); else engine.setMesureSource("tps"); }
    }
    Pill {
      ui: "hauteur"
      label: bar.tps ? ("prisme " + station.hr.toFixed(3)) : ("canne " + engine.hauteurCanne.toFixed(3))
      onClicked: engine.requestDialog("hauteur", { "tps": bar.tps })
    }

    Item { Layout.fillWidth: true }

    TopoBtn { width: 44; height: 40; ui: "station"; text: "station"; fontSize: 8; baseColor: devices.tpsConnected ? "#d9f2d9" : (QfTheme.darkTheme ? "#3a3a3a" : "#f2f2f2"); onClicked: bar.openStationMenu() }
    TopoBtn { width: 44; height: 40; ui: "carnet"; text: "carnet"; fontSize: 8; onClicked: bar.openCarnet() }
    TopoBtn { width: 44; height: 40; ui: "implantation"; text: "implant."; fontSize: 8; checked: engine.implantation.actif; onClicked: bar.openImplantation() }
    TopoBtn { width: 44; height: 40; ui: "detecteur"; text: "détect."; fontSize: 8; baseColor: engine.detection ? "#ffe2b8" : (QfTheme.darkTheme ? "#3a3a3a" : "#f2f2f2"); onClicked: bar.openDetection() }
    TopoBtn { width: 44; height: 40; ui: "parametres"; text: "param."; fontSize: 8; onClicked: bar.openSettings() }
    TopoBtn { width: 44; height: 40; ui: engine.modeBureau ? "bureau" : "terrain"; text: engine.modeBureau ? "bureau" : "terrain"; fontSize: 8; onClicked: { engine.modeBureau = !engine.modeBureau; engine.saveSettings(); } }
  }
}
