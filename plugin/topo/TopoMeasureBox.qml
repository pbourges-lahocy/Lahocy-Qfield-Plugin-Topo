import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoMeasureBox - partie haute de la zone 4 : excentrements favoris,
 * hauteur canne / prisme, STOP, boutons d'acquisition et voyant de qualité.
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

  /* ---------------- excentrements favoris ---------------- */
  Flow {
    Layout.fillWidth: true
    spacing: 3
    Repeater {
      model: box.tps ? ["station", "dist_rec", "vertical_tps"].concat(engine.excentFavoris.filter(m => m !== "milieu")) : engine.excentFavoris
      delegate: TopoBtn {
        required property var modelData
        width: 44; height: 40
        fontSize: 8
        emoji: ({ "point": "◎", "perp_prec": "⊥₁", "perp_suiv": "⊥₂", "vertical": "↕Z", "milieu": "◐", "deux_dist": "◔", "station": "△", "dist_rec": "↔∠", "vertical_tps": "∠Z" })[modelData] || "?"
        text: ({ "point": "Point", "perp_prec": "Perp.préc", "perp_suiv": "Perp.suiv", "vertical": "Vertical", "milieu": "Milieu", "deux_dist": "2 dist.", "station": "Station", "dist_rec": "Dist/Rec", "vertical_tps": "Vert. V" })[modelData] || modelData
        checked: (["station", "dist_rec", "vertical_tps"].indexOf(modelData) >= 0) ? station.excentTps === modelData : engine.excentMode === modelData
        onClicked: {
          if (["station", "dist_rec", "vertical_tps"].indexOf(modelData) >= 0) station.setExcentTps(modelData);
          else engine.setExcentMode(modelData);
        }
      }
    }
    TopoBtn { width: 44; height: 40; emoji: "⋯"; fontSize: 8; text: "Plus"; onClicked: engine.requestDialog("excent_config", {}) }
  }

  /* ---------------- hauteur, source, STOP ---------------- */
  RowLayout {
    Layout.fillWidth: true
    spacing: 4
    TopoBtn {
      Layout.preferredWidth: 78; Layout.preferredHeight: 48
      emoji: box.tps ? "🎯" : "📡"
      text: box.tps ? ("Prisme " + station.hr.toFixed(3)) : ("Canne " + engine.hauteurCanne.toFixed(3))
      fontSize: 9
      onClicked: engine.requestDialog("hauteur", { "tps": box.tps })
    }
    TopoBtn {
      Layout.preferredWidth: 48; Layout.preferredHeight: 48
      emoji: box.tps ? "△" : "🛰"
      text: box.tps ? "TPS" : "GNSS"
      fontSize: 8
      checked: true
      checkedColor: box.tps ? "#6c5ce7" : "#2d98da"
      onClicked: engine.setMesureSource(box.tps ? "gnss" : "tps")
    }
    TopoBtn {
      Layout.fillWidth: true; Layout.preferredHeight: 48
      emoji: "⛔"
      text: "STOP"
      fontSize: 10
      baseColor: "#ffd6d6"
      onClicked: engine.stop()
    }
  }

  /* ---------------- acquisition ---------------- */
  RowLayout {
    Layout.fillWidth: true
    spacing: 4
    ColumnLayout {
      spacing: 4
      TopoBtn {
        Layout.preferredWidth: 78; Layout.preferredHeight: 52
        text: "Point\nunique"
        fontSize: 10
        baseColor: box.qualityColor
        enabled: box.quality !== "none" && box.quality !== "bad"
        onClicked: engine.measure(false, false)
      }
      TopoBtn {
        Layout.preferredWidth: 78; Layout.preferredHeight: 52
        text: "Dernier\npoint"
        fontSize: 10
        onClicked: engine.useLastPoint()
      }
    }
    TopoBtn {
      id: linkBtn
      Layout.fillWidth: true; Layout.preferredHeight: 108
      baseColor: box.qualityColor
      enabled: box.quality !== "none" && box.quality !== "bad"
      onClicked: engine.measure(true, false)
      onPressAndHold: {
        if (box.tps) engine.requestDialog("station_menu", {});
        else { const m = iface.findItemByObjectName("gnssMenu"); if (m) m.popup(linkBtn.width / 2, 0); }
      }
      Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 2
        Text { text: "Mesure point avec liaison  🔗"; font.bold: true; font.pixelSize: 11; color: "#202020"; width: parent.width; wrapMode: Text.WordWrap }
        Text {
          visible: !box.tps
          text: engine.qualityText
          font.pixelSize: 13; font.bold: true; color: "#202020"
        }
        Text {
          visible: !box.tps
          text: engine.qualityDetail
          font.pixelSize: 10; color: "#303030"
          width: parent.width; wrapMode: Text.WordWrap
        }
        // contexte station totale : LEDs de latence + verrouillage prisme
        Row {
          visible: box.tps
          spacing: 3
          Repeater {
            model: 5
            Rectangle { width: 12; height: 12; radius: 6; border.color: "#404040"; color: index < devices.leds ? "#1e9e3a" : "#e0e0e0" }
          }
          Text { text: devices.tpsLatency !== null ? (devices.tpsLatency + " ms") : "—"; font.pixelSize: 10; color: "#202020"; anchors.verticalCenter: parent.verticalCenter }
        }
        Text {
          visible: box.tps
          text: !devices.reachable ? "Pont injoignable" : !devices.tpsConnected ? "Station non connectée" : (devices.tpsLocked || station.driver === "simulateur" ? "Prisme verrouillé" : "Prisme non verrouillé (visée ATR)")
          font.pixelSize: 12; font.bold: true; color: "#202020"
        }
        Text {
          visible: box.tps
          text: station.active ? ("Station " + station.current.matricule + (station.oriente ? " – V0 " + Number(station.current.v0).toFixed(4) : " – NON ORIENTÉE")) : "Aucune station"
          font.pixelSize: 10; color: "#303030"; width: parent.width; wrapMode: Text.WordWrap
        }
        Text {
          visible: box.tps && devices.tpsConnected
          text: "Hz " + (isNaN(devices.tpsHz) ? "—" : devices.tpsHz.toFixed(4)) + "  V " + (isNaN(devices.tpsV) ? "—" : devices.tpsV.toFixed(4)) + (devices.tpsBattery !== null ? "  🔋" + devices.tpsBattery + "%" : "")
          font.pixelSize: 10; color: "#303030"
        }
      }
    }
  }

  // barre d'état de la mesure (simulateur / double retournement / excentrement)
  Text {
    Layout.fillWidth: true
    visible: box.tps && station.message !== ""
    text: station.message
    font.pixelSize: 10
    color: QfTheme.mainTextColor
    wrapMode: Text.WordWrap
  }
}
