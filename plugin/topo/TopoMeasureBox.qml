import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoMeasureBox - mesure : excentrements favoris, bouton Mesurer (point avec
 * liaison) coloré par la qualité, STOP, point unique et dernier point.
 * La source (GNSS / station) et la hauteur se règlent dans la barre du haut.
 */
ColumnLayout {
  id: box

  required property var engine
  required property var station
  required property var devices
  spacing: 4

  readonly property bool tps: engine.mesureSource === "tps"
  readonly property string quality: tps ? (!devices.tpsConnected ? "none" : (!devices.tpsLocked && station.modeMesure === "prisme" && station.driver !== "simulateur") ? "warn" : (station.active && station.oriente ? "ok" : "warn")) : engine.qualityState
  readonly property color qualityColor: quality === "ok" ? "#8fe08f" : quality === "warn" ? "#ffb347" : quality === "bad" ? "#ff7b7b" : "#cfcfcf"
  readonly property var excentLabels: ({ "point": "point", "perp_prec": "perp. 1", "perp_suiv": "perp. 2", "vertical": "vertical", "milieu": "milieu", "deux_dist": "2 dist.", "station": "station", "dist_rec": "dist/rec", "vertical_tps": "vert. V" })

  /* ---------------- excentrements favoris ---------------- */
  Flow {
    Layout.fillWidth: true
    spacing: 3
    Repeater {
      model: box.tps ? ["station", "dist_rec", "vertical_tps"].concat(engine.excentFavoris.filter(m => m !== "milieu")) : engine.excentFavoris
      delegate: TopoBtn {
        required property var modelData
        width: 40; height: 38
        fontSize: 7
        ui: "exc_" + modelData
        text: box.excentLabels[modelData] || modelData
        checked: (["station", "dist_rec", "vertical_tps"].indexOf(modelData) >= 0) ? station.excentTps === modelData : engine.excentMode === modelData
        onClicked: {
          if (["station", "dist_rec", "vertical_tps"].indexOf(modelData) >= 0) station.setExcentTps(modelData);
          else engine.setExcentMode(modelData);
        }
      }
    }
    TopoBtn { width: 40; height: 38; ui: "exc_plus"; fontSize: 7; text: "plus"; onClicked: engine.requestDialog("excent_config", {}) }
  }

  /* ---------------- Mesurer + STOP ---------------- */
  RowLayout {
    Layout.fillWidth: true
    spacing: 4
    TopoBtn {
      id: measureBtn
      Layout.fillWidth: true; Layout.preferredHeight: 58
      baseColor: box.qualityColor
      lightIcon: false
      textColor: "#202020"
      enabled: box.quality !== "none" && box.quality !== "bad"
      onClicked: engine.measure(true, false)
      onPressAndHold: {
        if (box.tps) engine.requestDialog("station_menu", {});
        else { const m = iface.findItemByObjectName("gnssMenu"); if (m) m.popup(measureBtn.width / 2, 0); }
      }
      Row {
        anchors.centerIn: parent
        spacing: 8
        Image { source: Qt.resolvedUrl("../theme/ui/mesurer.svg"); width: 26; height: 26; sourceSize.width: 52; sourceSize.height: 52; anchors.verticalCenter: parent.verticalCenter }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: "Mesurer"; font.pixelSize: 14; font.bold: true; color: "#202020" }
          Text {
            text: box.tps
              ? (!devices.reachable ? "pont injoignable" : !devices.tpsConnected ? "station non connectée" : !station.active ? "aucune station" : !station.oriente ? "station non orientée" : ((devices.tpsLocked || station.driver === "simulateur") ? "prisme verrouillé" : "visée ATR") + (devices.tpsLatency !== null ? " · " + devices.tpsLatency + " ms" : ""))
              : engine.qualityDetail.split(/[,\n]/)[0]
            font.pixelSize: 9; color: "#303030"
          }
        }
      }
    }
    TopoBtn { Layout.preferredWidth: 52; Layout.preferredHeight: 58; ui: "stop"; text: "STOP"; fontSize: 8; baseColor: "#ffd0d0"; lightIcon: false; onClicked: engine.stop() }
  }

  /* ---------------- point unique / dernier point ---------------- */
  RowLayout {
    Layout.fillWidth: true
    spacing: 4
    TopoBtn { Layout.fillWidth: true; Layout.preferredHeight: 40; ui: "point_unique"; text: "point unique"; fontSize: 8; enabled: box.quality !== "none" && box.quality !== "bad"; onClicked: engine.measure(false, false) }
    TopoBtn { Layout.fillWidth: true; Layout.preferredHeight: 40; ui: "dernier_point"; text: "dernier point"; fontSize: 8; onClicked: engine.useLastPoint() }
  }
}
