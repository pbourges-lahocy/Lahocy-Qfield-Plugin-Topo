import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui
import "TopoCore.js" as Core
import "TopoCalc.js" as Topo

/*
 * TopoCarnet - carnet de terrain (points) et carnet polaire (stations / visées).
 */
Dialog {
  id: carnet

  required property var engine
  required property var station
  required property var mainWindow

  title: "Carnet de terrain"
  modal: false
  parent: mainWindow.contentItem
  width: Math.min(760, mainWindow.width - 20)
  height: Math.min(600, mainWindow.height - 20)
  x: 10
  y: 10
  standardButtons: Dialog.Close

  property var types: ["GPS", "TPS", "EXCENTRE", "CONSTRUIT", "IMPORTE", "IMPLANTE", "STATION", "CLIC"]
  property var filtres: ({ "GPS": true, "TPS": true, "EXCENTRE": true, "CONSTRUIT": true, "IMPORTE": true, "IMPLANTE": true, "STATION": true, "CLIC": false })
  property var points: []
  property var polaire: []
  property var selection: ({})
  readonly property int nbSel: Object.keys(selection).length

  function refresh() {
    let t = [];
    for (const k of types) if (filtres[k]) t.push(k);
    points = engine.carnetList(t, search.text);
    selection = {};
    if (tabs.currentIndex === 1) polaire = station.carnetPolaire();
  }
  function selected() { return points.filter(p => selection[p.fid]); }
  function toggle(fid) { let s = Object.assign({}, selection); if (s[fid]) delete s[fid]; else s[fid] = true; selection = s; }
  onOpened: refresh()

  contentItem: ColumnLayout {
    spacing: 4
    TabBar {
      id: tabs
      Layout.fillWidth: true
      TabButton { text: "Points" }
      TabButton { text: "Carnet polaire (stations)" }
      onCurrentIndexChanged: carnet.refresh()
    }

    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: tabs.currentIndex

      /* ---------------- points ---------------- */
      ColumnLayout {
        spacing: 4
        Flow {
          Layout.fillWidth: true
          spacing: 2
          Repeater {
            model: carnet.types
            CheckBox { required property var modelData; text: ({ "GPS": "Points GPS", "TPS": "Points rayonnés", "EXCENTRE": "Excentrés", "CONSTRUIT": "Construits", "IMPORTE": "Importés", "IMPLANTE": "Implantés", "STATION": "Stations", "CLIC": "Cliqués" })[modelData]; checked: carnet.filtres[modelData]; font.pixelSize: 11
              onToggled: { let f = Object.assign({}, carnet.filtres); f[modelData] = checked; carnet.filtres = f; carnet.refresh(); } }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          TextField { id: search; Layout.fillWidth: true; placeholderText: "Chercher le matricule…"; onTextChanged: carnet.refresh() }
          Text { text: carnet.points.length + " pts, " + carnet.nbSel + " sél."; color: QfTheme.mainTextColor }
          TopoBtn { width: 80; height: 34; text: "Tout sél."; fontSize: 9; onClicked: { let s = {}; for (const p of carnet.points) s[p.fid] = true; carnet.selection = s; } }
        }
        Rectangle {
          Layout.fillWidth: true; height: 24; color: QfTheme.darkTheme ? "#444" : "#e0e0e0"
          Row {
            anchors.fill: parent; anchors.leftMargin: 4
            Text { width: 90; text: "Matricule"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 80; text: "Type"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 55; text: "Hv"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 110; text: "X"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 110; text: "Y"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 80; text: "Z"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 60; text: "Z sign."; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 90; text: "Appui/Réf"; font.bold: true; color: QfTheme.mainTextColor }
          }
        }
        ListView {
          id: list
          Layout.fillWidth: true; Layout.fillHeight: true
          clip: true
          model: carnet.points
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width; height: 28
            color: carnet.selection[modelData.fid] ? QfTheme.mainColor : (index % 2 ? "#00000010" : "transparent")
            Row {
              anchors.fill: parent; anchors.leftMargin: 4
              property color c: carnet.selection[modelData.fid] ? "white" : (modelData.type === "GPS" ? "#1e9e3a" : modelData.type === "TPS" ? "#1f5fbf" : modelData.type === "EXCENTRE" || modelData.type === "CONSTRUIT" ? "#8b5a2b" : modelData.type === "IMPLANTE" ? "#d81b9a" : QfTheme.mainTextColor)
              Text { width: 90; text: modelData.matricule; color: parent.c; font.pixelSize: 12 }
              Text { width: 80; text: modelData.type; color: parent.c; font.pixelSize: 12 }
              Text { width: 55; text: Core.fmt(modelData.hv, 3); color: parent.c; font.pixelSize: 12 }
              Text { width: 110; text: Core.fmt(modelData.x, 3); color: parent.c; font.pixelSize: 12 }
              Text { width: 110; text: Core.fmt(modelData.y, 3); color: parent.c; font.pixelSize: 12 }
              Text { width: 80; text: Core.fmt(modelData.z, 3); color: parent.c; font.pixelSize: 12 }
              Text { width: 60; text: modelData.z_signif ? "Oui" : "Non"; color: parent.c; font.pixelSize: 12 }
              Text { width: 90; text: modelData.pt_appui + (modelData.pt_ref ? "/" + modelData.pt_ref : ""); color: parent.c; font.pixelSize: 11; elide: Text.ElideRight }
            }
            MouseArea { anchors.fill: parent; onClicked: carnet.toggle(modelData.fid); onDoubleClicked: engine.zoomToPoints([modelData]) }
          }
        }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          TopoBtn { width: 104; height: 46; emoji: "🔍"; text: "Zoomer sur\nle(s) point(s)"; fontSize: 8; enabled: carnet.nbSel > 0; onClicked: engine.zoomToPoints(carnet.selected()) }
          TopoBtn { width: 104; height: 46; emoji: "🗺"; text: "Retrouver depuis\nle plan"; fontSize: 8; onClicked: { carnet.close(); engine.pickPoint(function (pt) { carnet.open(); search.text = pt.matricule; }, "Cliquer sur un point topo dans le plan"); } }
          TopoBtn { width: 104; height: 46; emoji: "📏"; text: "Changer la\nhauteur de canne"; fontSize: 8; enabled: carnet.nbSel > 0; onClicked: hvDialog.open() }
          TopoBtn { width: 104; height: 46; emoji: "Z"; text: "Changer\nZ significatif"; fontSize: 8; enabled: carnet.nbSel > 0; onClicked: zDialog.open() }
          TopoBtn { width: 104; height: 46; emoji: "🗑"; text: "Supprimer\nle(s) point(s)"; fontSize: 8; baseColor: "#ffd6d6"; enabled: carnet.nbSel > 0; onClicked: delDialog.open() }
          TopoBtn { width: 104; height: 46; emoji: "📤"; text: "Exporter\nMXYZ"; fontSize: 8; onClicked: engine.exportXyz(carnet.nbSel > 0 ? carnet.selected() : carnet.points) }
          TopoBtn { width: 104; height: 46; emoji: "📤"; text: "Exporter\nCSV GPS"; fontSize: 8; onClicked: engine.exportCsvGps() }
          TopoBtn { width: 104; height: 46; emoji: "📥"; text: "Importer\ndes points"; fontSize: 8; onClicked: engine.requestDialog("import", {}) }
        }
      }

      /* ---------------- carnet polaire ---------------- */
      ColumnLayout {
        spacing: 4
        Rectangle {
          Layout.fillWidth: true; height: 24; color: QfTheme.darkTheme ? "#444" : "#e0e0e0"
          Row {
            anchors.fill: parent; anchors.leftMargin: 4
            Text { width: 110; text: "Données"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 120; text: "Type"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 60; text: "Hi / Hv"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 110; text: "V0 / Hz / X"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 110; text: "V / Y"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 90; text: "Di / Z"; font.bold: true; color: QfTheme.mainTextColor }
            Text { width: 100; text: "Écarts"; font.bold: true; color: QfTheme.mainTextColor }
          }
        }
        ListView {
          id: polList
          Layout.fillWidth: true; Layout.fillHeight: true
          clip: true
          model: carnet.polaire
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: polList.width; height: 26
            color: modelData.kind === "station" ? (QfTheme.darkTheme ? "#3a3030" : "#fff0f0") : (index % 2 ? "#00000010" : "transparent")
            Row {
              anchors.fill: parent; anchors.leftMargin: modelData.kind === "station" ? 4 : 20
              property color c: modelData.kind === "station" ? "#c0392b" : modelData.kind === "visee" ? "#8e44ad" : "#1f5fbf"
              Text { width: modelData.kind === "station" ? 110 : 94; text: modelData.kind === "station" ? modelData.matricule : (modelData.cible || modelData.matricule); color: parent.c; font.pixelSize: 12; font.bold: modelData.kind === "station" }
              Text { width: 120; text: modelData.kind === "station" ? ("Station " + modelData.type + " (" + modelData.statut + ")") : modelData.kind === "visee" ? ({ "REF_ANGLE_DIST": "Référence", "REF_ANGLE": "Référence (Hz)", "REF_APPROCHEE": "Réf. approchée", "VISEE_AVANT": "Visée avant" })[modelData.type] || modelData.type : "Point rayonné"; color: parent.c; font.pixelSize: 11 }
              Text { width: 60; text: modelData.kind === "station" ? Core.fmt(modelData.hi, 3) : Core.fmt(modelData.hr, 3); color: parent.c; font.pixelSize: 11 }
              Text { width: 110; text: modelData.kind === "station" ? ("V0 " + Topo.fmtGr(modelData.v0)) : Topo.fmtGr(modelData.hz); color: parent.c; font.pixelSize: 11 }
              Text { width: 110; text: modelData.kind === "station" ? Core.fmt(modelData.x, 3) + " / " + Core.fmt(modelData.y, 3) : Topo.fmtGr(modelData.v); color: parent.c; font.pixelSize: 11 }
              Text { width: 90; text: modelData.kind === "station" ? Core.fmt(modelData.z, 3) : Core.fmt(modelData.sd, 3); color: parent.c; font.pixelSize: 11 }
              Text { width: 100; text: modelData.kind === "visee" && Core.isNum(modelData.ecart_plani) ? (Core.fmt(modelData.ecart_plani, 3) + " / " + Core.fmt(modelData.ecart_alti, 3)) : ""; color: parent.c; font.pixelSize: 11 }
            }
          }
        }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          TopoBtn { width: 120; height: 46; emoji: "📤"; text: "Exporter GSI\n(Leica)"; fontSize: 8; onClicked: station.exportGsi() }
          TopoBtn { width: 120; height: 46; emoji: "📤"; text: "Exporter CSV\npolaire"; fontSize: 8; onClicked: station.exportCsvPolaire() }
          TopoBtn { width: 120; height: 46; emoji: "△"; text: "Voir la\npolygonale"; fontSize: 8; onClicked: { const s = station.stationList(); if (s.length) engine.zoomToPoints(s); } }
          TopoBtn { width: 120; height: 46; emoji: "🔄"; text: "Recalculer les points\nde la station active"; fontSize: 8; enabled: station.active; onClicked: station.recomputePoints() }
        }
      }
    }
  }

  Dialog {
    id: hvDialog
    parent: mainWindow.contentItem; modal: true; title: "Nouvelle hauteur de canne / prisme (m)"; width: 300
    standardButtons: Dialog.Ok | Dialog.Cancel
    x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
    contentItem: TextField { id: hvField; text: engine.hauteurCanne.toFixed(3); inputMethodHints: Qt.ImhFormattedNumbersOnly }
    onAccepted: { engine.changeHv(carnet.selected(), parseFloat(hvField.text) || 0); carnet.refresh(); }
  }
  Dialog {
    id: zDialog
    parent: mainWindow.contentItem; modal: true; title: "Z significatif"; width: 300
    standardButtons: Dialog.Yes | Dialog.No
    x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
    contentItem: Text { text: "OUI : Z significatif\nNON : Z non significatif"; color: QfTheme.mainTextColor }
    onAccepted: { engine.setZSignif(carnet.selected(), true); carnet.refresh(); }
    onRejected: { engine.setZSignif(carnet.selected(), false); carnet.refresh(); }
  }
  Dialog {
    id: delDialog
    parent: mainWindow.contentItem; modal: true; title: "Supprimer " + carnet.nbSel + " point(s) ?"; width: 320
    standardButtons: Dialog.Yes | Dialog.No
    x: (mainWindow.width - width) / 2; y: (mainWindow.height - height) / 2
    contentItem: Text { text: "La suppression de points topographiques est irréversible."; color: QfTheme.mainTextColor; wrapMode: Text.WordWrap }
    onAccepted: { for (const p of carnet.selected()) engine.deleteElement("pt_topo", p.fid); carnet.refresh(); }
  }
}
