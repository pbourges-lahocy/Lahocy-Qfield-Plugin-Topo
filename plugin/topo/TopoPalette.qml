import QtQuick
import QtQuick.Controls
import org.qfield.gui

/*
 * TopoPalette - palette d'objets sur 4 colonnes : familles (icônes de
 * l'interface), sous-palette affichée à la place des familles (retour par le
 * bouton du panneau), recherche d'un objet par son nom dans tout le catalogue.
 * Appui court sur une famille = sous-palette ; appui long = objet par défaut.
 */
Item {
  id: pal

  required property var engine
  property real cell: 52
  property real spacing: 4
  property int columns: 4

  property var sub: null                 // bouton de famille ouvert (sous-palette)
  property string subGroup: ""           // filtre Surface / Sous-sol / Information (catalogue GéoBretagne)
  property bool searching: false
  property string query: ""
  readonly property bool inSub: sub !== null
  readonly property string title: searching ? "Recherche" : (sub ? famLabel(sub) : "Palette")
  function groupesOf(b) {
    let g = [];
    if (b) for (const it of (b.sous_palette || [])) if (it && it.groupe && g.indexOf(it.groupe) < 0) g.push(it.groupe);
    return g;
  }
  readonly property var groupes: groupesOf(sub)
  readonly property var groupLabels: ({ "Surface": "Surface", "Sous-sol": "Sous-sol", "Information": "Info" })
  onSubChanged: { const g = groupesOf(sub); subGroup = g.length > 0 ? g[0] : ""; }

  readonly property var famIcons: ({
    "Voirie": "fam_voirie", "CatBati": "fam_bati", "CatMobilier": "fam_mobilier", "CatDivers": "fam_divers",
    "CatFleches": "fam_fleches", "CatPanneaux": "fam_panneaux", "CatPannInterdit": "fam_interdit", "CatTopo": "fam_topo",
    "CatVegetation": "fam_vegetation", "CatTexte": "fam_texte", "CatEau": "fam_eau", "CatEclairage": "fam_eclairage",
    "CatElec": "fam_elec", "CatGaz": "fam_gaz", "CatPTT": "fam_ptt", "CatSNCF": "fam_sncf", "CatTV": "fam_tv", "CatReseaux": "fam_reseaux"
  })
  readonly property var famLabels: ({
    "CatPannInterdit": "Interdit", "CatEclairage": "Éclairage", "CatPTT": "Télécom", "CatVegetation": "Végétation", "CatFleches": "Flèches", "CatBati": "Bâti"
  })

  function famLabel(b) {
    if (!b) return "";
    if (famLabels[b.code]) return famLabels[b.code];
    return String(b.nom || b.code).replace(/^Cat/, "");
  }
  function objLabel(code) {
    const o = engine.objet(code);
    return o && o.nom ? o.nom : code;
  }
  function back() { sub = null; searching = false; query = ""; }
  function toggleSearch() { searching = !searching; if (searching) { sub = null; searchField.forceActiveFocus(); } else query = ""; }

  // familles (les emplacements vides du thème ne sont pas conservés)
  readonly property var familles: (engine.theme.palette || []).filter(b => b !== null).sort((a, b) => a.pos - b.pos)
  // objets de la sous-palette ouverte
  readonly property var subItems: sub ? (sub.sous_palette || []).filter(b => b !== null && (!subGroup || !b.groupe || b.groupe === subGroup)).sort((a, b) => a.pos - b.pos) : []
  // résultats de recherche
  readonly property var results: {
    if (!searching || query.trim().length < 2) return [];
    const q = query.trim().toLowerCase();
    const objs = engine.theme.objets || {};
    let out = [];
    for (const code in objs) {
      const o = objs[code];
      if (!o || o.famille === "categorie") continue;
      const n = String(o.nom || code);
      if (n.toLowerCase().indexOf(q) >= 0 || code.toLowerCase().indexOf(q) >= 0) out.push({ "code": code, "nom": n, "icone": o.icone || "" });
      if (out.length >= 60) break;
    }
    return out;
  }

  Rectangle {
    anchors.fill: parent
    color: QfTheme.darkTheme ? "#262626" : "#f7f7f7"
    border.color: QfTheme.darkTheme ? "#444" : "#e0e0e0"
    radius: 6
  }

  /* ---------------- recherche ---------------- */
  TextField {
    id: searchField
    visible: pal.searching
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 4
    height: 32
    placeholderText: "Nom de l'objet…"
    font.pixelSize: 12
    onTextChanged: pal.query = text
  }

  /* ---------------- groupes de la sous-palette ---------------- */
  Flow {
    id: groupRow
    visible: pal.inSub && !pal.searching && pal.groupes.length > 1
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 4
    spacing: 4
    Repeater {
      model: pal.groupes
      delegate: TopoBtn {
        required property var modelData
        width: 52; height: 26
        text: pal.groupLabels[modelData] || modelData
        fontSize: 9
        small: true
        checked: pal.subGroup === modelData
        onClicked: pal.subGroup = modelData
      }
    }
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 4
    anchors.topMargin: pal.searching ? 40 : (groupRow.visible ? groupRow.height + 10 : 4)
    contentHeight: pal.searching ? resultCol.height + 4 : grid.height + 4
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    /* ---------------- familles / sous-palette ---------------- */
    Grid {
      id: grid
      visible: !pal.searching
      columns: pal.columns
      spacing: pal.spacing

      Repeater {
        model: pal.inSub ? pal.subItems : pal.familles
        delegate: TopoBtn {
          required property var modelData
          width: pal.cell
          height: pal.inSub ? pal.cell + 10 : pal.cell
          ui: pal.inSub ? "" : (modelData.ui || pal.famIcons[modelData.code] || "fam_objet")
          icon: pal.inSub ? engine.iconUrl(modelData.icone) : ""
          text: pal.inSub ? pal.objLabel(modelData.objet) : pal.famLabel(modelData)
          fontSize: 8
          iconSize: pal.inSub ? 26 : 22
          marker: !pal.inSub && !!(modelData.objet && modelData.sous_palette && modelData.sous_palette.length > 0)
          checked: engine.currentObj !== null && engine.currentObj !== undefined && modelData.objet === engine.currentObj.code
          onClicked: {
            if (pal.inSub) { if (modelData.objet) engine.activate(modelData.objet); return; }
            if (modelData.sous_palette && modelData.sous_palette.length > 0) pal.sub = modelData;
            else if (modelData.objet) engine.activate(modelData.objet);
          }
          onPressAndHold: {
            if (pal.inSub) return;
            if (modelData.objet) engine.activate(modelData.objet);
            else if (modelData.sous_palette && modelData.sous_palette.length > 0) pal.sub = modelData;
          }
        }
      }
    }

    /* ---------------- résultats ---------------- */
    Column {
      id: resultCol
      visible: pal.searching
      width: flick.width
      spacing: 2
      Text {
        visible: pal.results.length === 0
        text: pal.query.trim().length < 2 ? "Taper au moins 2 lettres" : "Aucun objet"
        font.pixelSize: 11; color: QfTheme.darkTheme ? "#c8c8c8" : "#606060"
        padding: 6
      }
      Repeater {
        model: pal.results
        delegate: Rectangle {
          required property var modelData
          width: resultCol.width
          height: 34
          radius: 6
          color: rowArea.pressed ? (QfTheme.darkTheme ? "#505050" : "#dcdcdc") : "transparent"
          Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6
            Image { source: engine.iconUrl(modelData.icone); width: 26; height: 26; fillMode: Image.PreserveAspectFit; asynchronous: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: modelData.nom; font.pixelSize: 11; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"; width: parent.width - 36; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: rowArea; anchors.fill: parent; onClicked: { engine.activate(modelData.code); pal.back(); } }
        }
      }
    }
  }
}
