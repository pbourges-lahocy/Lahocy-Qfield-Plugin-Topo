import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoDrawOptions - partie centrale de la zone 4 : primitives de dessin et
 * réglages de l'objet en cours (varient selon la famille), confirmation des
 * clics en mode terrain, guidage d'implantation.
 */
ColumnLayout {
  id: opts

  required property var engine
  required property var station
  spacing: 4

  readonly property string fam: engine.currentFamily

  /* ---------------- consigne ---------------- */
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: msg.implicitHeight + 8
    color: QfTheme.darkTheme ? "#333" : "#fff8d6"
    border.color: "#d8c890"
    radius: 4
    Text {
      id: msg
      anchors.fill: parent
      anchors.margins: 4
      text: engine.message
      font.pixelSize: 11
      color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
      wrapMode: Text.WordWrap
    }
  }

  /* ---------------- confirmation de clic (mode terrain) ---------------- */
  RowLayout {
    Layout.fillWidth: true
    visible: engine.clickCandidate !== null
    spacing: 4
    Text { Layout.fillWidth: true; text: engine.clickCandidate ? engine.clickCandidate.descr : ""; font.bold: true; color: QfTheme.mainTextColor; wrapMode: Text.WordWrap }
    TopoBtn { Layout.preferredWidth: 60; Layout.preferredHeight: 40; emoji: "✔"; baseColor: "#8fe08f"; onClicked: engine.validateCandidate() }
    TopoBtn { Layout.preferredWidth: 60; Layout.preferredHeight: 40; emoji: "✘"; baseColor: "#ff7b7b"; onClicked: engine.cancelCandidate() }
  }

  /* ---------------- linéaire ---------------- */
  ColumnLayout {
    Layout.fillWidth: true
    visible: opts.fam === "lineaire"
    spacing: 4
    Text { text: (engine.currentObj ? engine.currentObj.nom : "") + "  –  " + engine.currentVertexCount + " sommet(s), " + engine.currentLength.toFixed(2) + " m"; font.pixelSize: 10; color: QfTheme.mainTextColor }
    Flow {
      Layout.fillWidth: true
      spacing: 3
      TopoBtn { width: 48; height: 44; emoji: "⟋"; text: "Ligne"; fontSize: 8; checked: engine.currentMode === "ligne"; onClicked: engine.setMode("ligne") }
      TopoBtn { width: 48; height: 44; emoji: "◠₃"; text: "Arc 3"; fontSize: 8; checked: engine.currentMode === "arc3"; onClicked: engine.setMode("arc3") }
      TopoBtn { width: 48; height: 44; emoji: "◠₂"; text: "Arc 2"; fontSize: 8; checked: engine.currentMode === "arc2"; enabled: engine.currentTangent; onClicked: engine.setMode("arc2") }
      TopoBtn { width: 48; height: 44; emoji: "∿"; text: "Courbe"; fontSize: 8; checked: engine.currentMode === "courbe"; onClicked: engine.setMode("courbe") }
      TopoBtn { width: 48; height: 44; emoji: "T"; text: engine.currentTangent ? "Tangent" : "Fixe"; fontSize: 8; checked: engine.currentTangent; onClicked: engine.toggleTangent() }
    }
    Flow {
      Layout.fillWidth: true
      spacing: 3
      TopoBtn { width: 48; height: 44; emoji: "⟲"; text: "Fermer"; fontSize: 8; enabled: engine.currentVertexCount >= 3; onClicked: engine.closeCurrent() }
      TopoBtn { width: 48; height: 44; emoji: "▨"; text: "Hachure"; fontSize: 8; checked: engine.currentHachure; onClicked: engine.toggleHachure() }
      TopoBtn { width: 48; height: 44; emoji: "↶"; text: "Annuler"; fontSize: 8; enabled: engine.currentVertexCount > 0; onClicked: engine.undoVertex() }
      TopoBtn { width: 48; height: 44; emoji: "⇤"; text: "Ajust.déb"; fontSize: 8; checked: engine.currentAjustDeb; onClicked: engine.toggleAjustDeb() }
      TopoBtn { width: 48; height: 44; emoji: "⇥"; text: "Ajust.fin"; fontSize: 8; checked: engine.currentAjustFin; onClicked: engine.toggleAjustFin() }
    }
  }

  /* ---------------- symbole / texte / entrée / escalier ---------------- */
  ColumnLayout {
    Layout.fillWidth: true
    visible: ["symbole", "texte", "entree", "escalier"].indexOf(opts.fam) >= 0
    spacing: 4
    Text { text: (engine.currentObj ? engine.currentObj.nom : "") + "  –  point " + (engine.pendingCount + 1) + " / " + engine.pendingNeeded; font.pixelSize: 10; color: QfTheme.mainTextColor }
    Text { visible: opts.fam === "texte"; text: "Texte : « " + engine.pendingText + " »"; font.pixelSize: 11; font.bold: true; color: QfTheme.mainTextColor; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    Flow {
      Layout.fillWidth: true
      spacing: 3
      TopoBtn { visible: opts.fam === "texte"; width: 56; height: 44; emoji: "✎"; text: "Modifier"; fontSize: 8; onClicked: engine.requestDialog("texte", { "obj": engine.currentObj, "liste": [], "defaut": engine.pendingText }) }
      TopoBtn { width: 48; height: 44; emoji: "↶"; text: "Annuler pt"; fontSize: 8; enabled: engine.pendingCount > 0; onClicked: engine.undoVertex() }
      TopoBtn { visible: opts.fam === "symbole"; width: 48; height: 44; emoji: "⇋"; text: "Symétrie"; fontSize: 8; enabled: engine.lastPlaced !== null; onClicked: engine.adjustSymetrie() }
      TopoBtn { visible: opts.fam !== "texte"; width: 48; height: 44; emoji: "⟲"; text: "Inverser"; fontSize: 8; enabled: engine.lastPlaced !== null; onClicked: engine.adjustInverser() }
      TopoBtn { visible: opts.fam === "symbole"; width: 48; height: 44; emoji: "⇢"; text: "Décaler"; fontSize: 8; enabled: engine.lastPlaced !== null; onClicked: engine.requestDialog("decalage", {}) }
      TopoBtn { visible: opts.fam === "symbole"; width: 48; height: 44; emoji: "⏸"; text: "Attente"; fontSize: 8; enabled: engine.lastPlaced !== null; onClicked: engine.wait() }
    }
  }

  /* ---------------- rectangle / cercle ---------------- */
  ColumnLayout {
    Layout.fillWidth: true
    visible: opts.fam === "rectangle" || opts.fam === "cercle"
    spacing: 4
    Text { text: (engine.currentObj ? engine.currentObj.nom : "") + " (" + opts.fam + ")  –  point " + (engine.pendingCount + 1) + " / " + engine.pendingNeeded; font.pixelSize: 10; color: QfTheme.mainTextColor }
    Flow {
      Layout.fillWidth: true
      spacing: 3
      TopoBtn { visible: opts.fam === "rectangle"; width: 56; height: 44; emoji: "▭"; text: "2 points"; fontSize: 8; checked: engine.rectanglePoints === 2; onClicked: engine.setRectanglePoints(2) }
      TopoBtn { visible: opts.fam === "rectangle"; width: 56; height: 44; emoji: "▭"; text: "3 points"; fontSize: 8; checked: engine.rectanglePoints === 3; onClicked: engine.setRectanglePoints(3) }
      TopoBtn { visible: opts.fam === "cercle"; width: 56; height: 44; emoji: "◯"; text: "Centre+R"; fontSize: 8; checked: engine.pendingNeeded < 3; onClicked: engine.setCercle3Points(false) }
      TopoBtn { visible: opts.fam === "cercle"; width: 56; height: 44; emoji: "◯₃"; text: "3 points"; fontSize: 8; checked: engine.pendingNeeded === 3; onClicked: engine.setCercle3Points(true) }
      TopoBtn { visible: opts.fam === "cercle"; width: 70; height: 44; emoji: engine.rayonVerrouille ? "🔒" : "🔓"; text: "R = " + engine.rayonCercle.toFixed(2); fontSize: 8; checked: engine.rayonVerrouille; onClicked: engine.requestDialog("rayon", {}) }
      TopoBtn { width: 48; height: 44; emoji: "↶"; text: "Annuler pt"; fontSize: 8; enabled: engine.pendingCount > 0; onClicked: engine.undoVertex() }
    }
  }

  /* ---------------- détection ---------------- */
  RowLayout {
    Layout.fillWidth: true
    visible: engine.detection !== null
    Text { Layout.fillWidth: true; text: "Détection en attente : profondeur " + (engine.detection ? Number(engine.detection.profondeur).toFixed(2) : "") + " m"; color: "#b35c00"; font.bold: true; wrapMode: Text.WordWrap }
    TopoBtn { Layout.preferredWidth: 48; Layout.preferredHeight: 36; emoji: "✘"; onClicked: engine.detection = null }
  }

  /* ---------------- guidage d'implantation ---------------- */
  TopoGuidage {
    Layout.fillWidth: true
    visible: engine.implantation.actif
    engine: opts.engine
    station: opts.station
  }
}
