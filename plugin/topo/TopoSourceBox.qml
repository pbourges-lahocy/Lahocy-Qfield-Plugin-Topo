import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoSourceBox - haut du panneau de mesure : choix de la source (GNSS / station
 * totale) avec son voyant de qualité, hauteur de canne ou de prisme, état des
 * appareils (station connectée, prisme, batterie, latence, station active).
 */
ColumnLayout {
  id: box

  required property var engine
  required property var station
  required property var devices
  spacing: 4

  signal openStationMenu()

  readonly property bool tps: engine.mesureSource === "tps"
  readonly property string gnssState: engine.qualityState
  readonly property string tpsState: !devices.tpsConnected ? "none" : (devices.tpsLocked || station.driver === "simulateur") ? "ok" : "warn"

  function stateColor(s) {
    return s === "ok" ? "#d9f2d9" : s === "warn" ? "#ffe2b8" : s === "bad" ? "#ffd0d0" : (QfTheme.darkTheme ? "#3a3a3a" : "#ececec");
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 4
    TopoBtn {
      Layout.fillWidth: true; Layout.preferredHeight: 46
      ui: "gnss"; text: "GNSS"; fontSize: 9
      baseColor: box.stateColor(box.gnssState)
      lightIcon: QfTheme.darkTheme
      border.width: box.tps ? 1 : 2
      border.color: box.tps ? (QfTheme.darkTheme ? "#505050" : "#d4d4d4") : QfTheme.mainColor
      textColor: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
      onClicked: engine.setMesureSource("gnss")
    }
    TopoBtn {
      Layout.fillWidth: true; Layout.preferredHeight: 46
      ui: "station"; text: "Station"; fontSize: 9
      baseColor: box.stateColor(box.tpsState)
      lightIcon: QfTheme.darkTheme
      border.width: box.tps ? 2 : 1
      border.color: box.tps ? QfTheme.mainColor : (QfTheme.darkTheme ? "#505050" : "#d4d4d4")
      textColor: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
      onClicked: engine.setMesureSource("tps")
      onPressAndHold: box.openStationMenu()
    }
    TopoBtn {
      Layout.preferredWidth: 76; Layout.preferredHeight: 46
      ui: "hauteur"; fontSize: 9
      text: box.tps ? ("prisme " + station.hr.toFixed(3)) : ("canne " + engine.hauteurCanne.toFixed(3))
      onClicked: engine.requestDialog("hauteur", { "tps": box.tps })
    }
  }

  // état détaillé de la source active
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: detail.implicitHeight + 10
    radius: 6
    color: box.stateColor(box.tps ? box.tpsState : box.gnssState)
    Text {
      id: detail
      anchors.fill: parent
      anchors.margins: 5
      font.pixelSize: 10
      color: "#202020"
      wrapMode: Text.WordWrap
      text: box.tps
        ? (!devices.reachable ? "Pont injoignable : lancer Lahocy Topo Link (Android) ou le pont Windows"
           : !devices.tpsConnected ? "Station non connectée (appui long sur Station)"
           : (devices.tpsModel || "Station") + " · " + ((devices.tpsLocked || station.driver === "simulateur") ? "prisme verrouillé" : "prisme non verrouillé (visée ATR)")
             + (devices.tpsBattery !== null ? " · " + devices.tpsBattery + " %" : "") + (devices.tpsLatency !== null ? " · " + devices.tpsLatency + " ms" : "")
             + "\n" + (station.active ? ("Station " + station.current.matricule + (station.oriente ? " · V0 " + Number(station.current.v0).toFixed(4) + " gon" : " · NON ORIENTÉE")) : "Aucune mise en station")
             + (station.message ? "\n" + station.message : ""))
        : (engine.qualityText + (engine.qualityDetail ? "\n" + engine.qualityDetail.split("\n").join(" · ") : ""))
    }
  }

  TopoBtn {
    visible: box.tps && !devices.tpsConnected
    Layout.fillWidth: true; Layout.preferredHeight: 36
    ui: "liaison"; text: "Connecter la station"; fontSize: 9
    baseColor: "#d9f2d9"; lightIcon: false
    onClicked: box.openStationMenu()
  }
}
