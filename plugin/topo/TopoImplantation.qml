import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui
import "TopoCore.js" as Core

/*
 * TopoImplantation - gestionnaire des points à implanter.
 */
Dialog {
  id: impl

  required property var engine
  required property var mainWindow

  title: "Implantation de points"
  modal: false
  parent: mainWindow.contentItem
  width: Math.min(560, mainWindow.width - 20)
  height: Math.min(520, mainWindow.height - 20)
  x: 10
  y: 10
  standardButtons: Dialog.Close

  property var liste: []
  function refresh() { liste = engine.implantationList(); }
  onOpened: refresh()

  contentItem: ColumnLayout {
    spacing: 4
    Text { text: liste.length + " point(s), " + liste.filter(p => p.implante).length + " implanté(s)"; color: QfTheme.mainTextColor }
    Rectangle {
      Layout.fillWidth: true; height: 24; color: QfTheme.darkTheme ? "#444" : "#e0e0e0"
      Row {
        anchors.fill: parent; anchors.leftMargin: 4
        Text { width: 40; text: "N°"; font.bold: true; color: QfTheme.mainTextColor }
        Text { width: 100; text: "Matricule"; font.bold: true; color: QfTheme.mainTextColor }
        Text { width: 110; text: "X"; font.bold: true; color: QfTheme.mainTextColor }
        Text { width: 110; text: "Y"; font.bold: true; color: QfTheme.mainTextColor }
        Text { width: 80; text: "Z"; font.bold: true; color: QfTheme.mainTextColor }
        Text { width: 70; text: "Implanté"; font.bold: true; color: QfTheme.mainTextColor }
      }
    }
    ListView {
      id: list
      Layout.fillWidth: true; Layout.fillHeight: true
      clip: true
      model: impl.liste
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: list.width; height: 28
        color: list.currentIndex === index ? QfTheme.mainColor : (index % 2 ? "#00000010" : "transparent")
        Row {
          anchors.fill: parent; anchors.leftMargin: 4
          property color c: list.currentIndex === index ? "white" : QfTheme.mainTextColor
          Text { width: 40; text: modelData.ordre; color: parent.c; font.pixelSize: 12 }
          Text { width: 100; text: modelData.matricule; color: parent.c; font.pixelSize: 12 }
          Text { width: 110; text: Core.fmt(modelData.x, 3); color: parent.c; font.pixelSize: 12 }
          Text { width: 110; text: Core.fmt(modelData.y, 3); color: parent.c; font.pixelSize: 12 }
          Text { width: 80; text: Core.fmt(modelData.z, 3); color: parent.c; font.pixelSize: 12 }
          Text { width: 70; text: modelData.implante ? "✔" : ""; color: parent.c; font.pixelSize: 12 }
        }
        MouseArea { anchors.fill: parent; onClicked: list.currentIndex = index; onDoubleClicked: { impl.close(); engine.implantationStart(index); } }
      }
    }
    Flow {
      Layout.fillWidth: true
      spacing: 4
      TopoBtn { width: 110; height: 46; emoji: "▶"; text: "Démarrer\nl'implantation"; fontSize: 8; baseColor: "#8fe08f"; enabled: impl.liste.length > 0; onClicked: { impl.close(); engine.implantationStart(list.currentIndex >= 0 ? list.currentIndex : undefined); } }
      TopoBtn { width: 110; height: 46; emoji: "◎"; text: "Ajouter depuis\nle plan"; fontSize: 8; onClicked: { impl.close(); engine.pickPoint(function (pt) { engine.implantationAddPoint(pt); impl.open(); }, "Cliquer sur le point à implanter"); } }
      TopoBtn { width: 110; height: 46; emoji: "📥"; text: "Importer\nune liste"; fontSize: 8; onClicked: engine.requestDialog("import", {}) }
      TopoBtn { width: 110; height: 46; emoji: "🔍"; text: "Zoomer"; fontSize: 8; enabled: list.currentIndex >= 0; onClicked: engine.zoomToPoints([impl.liste[list.currentIndex]]) }
      TopoBtn { width: 110; height: 46; emoji: "🗑"; text: "Retirer"; fontSize: 8; baseColor: "#ffd6d6"; enabled: list.currentIndex >= 0; onClicked: { engine.db.deleteFeature("implantation", impl.liste[list.currentIndex].fid); impl.refresh(); } }
      TopoBtn { width: 110; height: 46; emoji: "📄"; text: "Rapport\nCSV"; fontSize: 8; onClicked: engine.exportImplantation() }
    }
  }
}
