# -*- coding: utf-8 -*-
"""
Génère le projet QField générique "Topo" :
  project/LahocyTopo/LahocyTopo.gpkg  (modèle de données : carnet de terrain + primitives)
  LahocyTopo/LahocyTopo.qgs   (projet QGIS/QField, symbologie de terrain minimale)

À lancer avec le Python de QGIS (OSGeo4W) :
  C:\\OSGeo4W\\bin\\python-qgis-ltr.bat tools/build_project.py [EPSG] [dossier_sortie]

Le style "client" (calques DWG, blocs, hachures...) est fait au bureau :
ici on ne pose que le strict nécessaire pour lire l'écran sur le terrain.
"""
import os
import sys

from qgis.core import (
    QgsFillSymbol,
    Qgis,
    QgsApplication,
    QgsCategorizedSymbolRenderer,
    QgsCoordinateReferenceSystem,
    QgsEditFormConfig,
    QgsField,
    QgsFields,
    QgsLineSymbol,
    QgsMarkerSymbol,
    QgsPalLayerSettings,
    QgsProject,
    QgsRendererCategory,
    QgsSnappingConfig,
    QgsTextFormat,
    QgsTolerance,
    QgsVectorFileWriter,
    QgsVectorLayer,
    QgsVectorLayerSimpleLabeling,
    QgsWkbTypes,
)
from qgis.PyQt.QtCore import QMetaType, QVariant
from qgis.PyQt.QtGui import QColor, QFont

EPSG = int(sys.argv[1]) if len(sys.argv) > 1 else 2154
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "project", "LahocyTopo")
OUT_DIR = os.path.abspath(OUT_DIR)
GPKG = os.path.join(OUT_DIR, "LahocyTopo.gpkg")
QGS = os.path.join(OUT_DIR, "LahocyTopo.qgs")

T, I, R, D = QVariant.String, QVariant.Int, QVariant.Double, QVariant.DateTime

# Champs communs à toutes les primitives dessinées (facilite la mise en forme bureau)
COMMUN = [
    ("code_objet", T), ("nom_objet", T), ("famille", T), ("calque", T),
    ("matricules", T),  # liste des matricules de points topo utilisés (séparés par ;)
    ("statut", T),      # en_cours | attente | termine
    ("indice", I),      # "Bordure 1", "Bordure 2"...
    ("params_json", T), # paramètres de placement (méthode, arcs, largeurs, ...)
    ("horodatage", D), ("operateur", T),
    ("couleur", T),     # couleur du catalogue (#rrggbb) au moment du levé
]

LAYERS = {
    "pt_topo": (QgsWkbTypes.PointZ, [
        ("matricule", T), ("type", T),  # GPS | EXCENTRE | CONSTRUIT | IMPORTE | IMPLANTE | CLIC
        ("x", R), ("y", R), ("z", R), ("z_signif", I), ("hv", R),
        ("qualite", T), ("fix_quality", I), ("nb_sat", I),
        ("hrms", R), ("vrms", R), ("pdop", R), ("hdop", R), ("vdop", R),
        ("lat", R), ("lon", R), ("alt_ellips", R),
        ("horodatage", D), ("code_objet", T),
        ("pt_appui", T), ("pt_ref", T), ("methode_excent", T), ("dist_excent", R),
        ("profondeur", R), ("commentaire", T), ("visible", I), ("operateur", T),
        # observations brutes station totale (type = TPS)
        ("station", T), ("hz", R), ("v", R), ("sd", R), ("hi", R), ("hr", R), ("face", I), ("mode_mesure", T),
    ]),
    "station": (QgsWkbTypes.PointZ, [
        ("matricule", T), ("type", T),   # CONNUE | LIBRE | VISEE_AVANT | IMPORTEE | CLIC
        ("statut", T),                   # active | stationnee | non_utilisee
        ("x", R), ("y", R), ("z", R), ("hi", R), ("v0", R),
        ("nb_ref", I), ("emq_plani", R), ("emq_alti", R),
        ("params_json", T), ("horodatage", D), ("operateur", T),
    ]),
    "visee": (QgsWkbTypes.NoGeometry, [
        ("station", T), ("cible", T), ("type", T),  # REF_ANGLE_DIST | REF_ANGLE | REF_APPROCHEE | VISEE_AVANT | POINT
        ("hz", R), ("v", R), ("sd", R), ("hi", R), ("hr", R), ("face", I),
        ("ecart_plani", R), ("ecart_alti", R), ("exclue", I), ("horodatage", D),
    ]),
    "lineaire": (QgsWkbTypes.LineStringZ, COMMUN + [
        ("type_lineaire", T),  # ligne_arc | multiligne_double | multiligne_triple | polyligne3d | courbe3d | batiment
        ("largeur", R), ("ferme", I), ("hachure", I),
    ]),
    "surface": (QgsWkbTypes.PolygonZ, COMMUN + [
        ("type_surface", T),  # rectangle | cercle | ferme | escalier | batiment
        ("hachure", I), ("rayon", R),
        ("nb_marches", I), ("prof_marche", R), ("fleche", I), ("sens", T),
    ]),
    "symbole": (QgsWkbTypes.PointZ, COMMUN + [
        ("famille_bloc", T), ("bloc", T),
        ("rotation", R),   # degrés, sens horaire depuis le nord (convention QGIS)
        ("echelle_x", R), ("echelle_y", R), ("dist_12", R), ("dist_23", R),
        ("nb_points", I), ("symetrie", I),
        ("taille", R),     # taille du SVG du bloc (m) à l'échelle 1 (2 x demi-vue)
    ]),
    "texte": (QgsWkbTypes.PointZ, COMMUN + [
        ("texte", T), ("rotation", R), ("taille", R), ("ancrage", I),
    ]),
    "entree": (QgsWkbTypes.LineStringZ, COMMUN + [
        ("delimiteur_g", T), ("delimiteur_d", T), ("taille_pilier_g", R), ("taille_pilier_d", R),
        ("seuil", I), ("decalage_seuil", R), ("sens", T), ("texte", T), ("decalage_texte", R),
    ]),
    "talus": (QgsWkbTypes.LineStringZ, COMMUN + [
        ("fid_haut", I), ("fid_bas", I), ("mode", I),
        ("espace", R), ("nb_lignes", I), ("pct_court", R), ("pct_long", R), ("pct_inter", R),
    ]),
    "implantation": (QgsWkbTypes.PointZ, [
        ("matricule", T), ("ordre", I), ("x", R), ("y", R), ("z", R),
        ("implante", I), ("dx", R), ("dy", R), ("dz", R), ("dist", R),
        ("matricule_leve", T), ("horodatage", D), ("commentaire", T),
    ]),
    "topo_param": (QgsWkbTypes.NoGeometry, [
        ("cle", T), ("valeur", T),
    ]),
}


def make_fields(defs):
    fields = QgsFields()
    for name, typ in defs:
        fields.append(QgsField(name, typ))
    return fields


def write_layer(name, wkb, defs, crs, first):
    opts = QgsVectorFileWriter.SaveVectorOptions()
    opts.driverName = "GPKG"
    opts.layerName = name
    opts.fileEncoding = "UTF-8"
    opts.actionOnExistingFile = (
        QgsVectorFileWriter.CreateOrOverwriteFile if first else QgsVectorFileWriter.CreateOrOverwriteLayer
    )
    writer = QgsVectorFileWriter.create(GPKG, make_fields(defs), wkb, crs, QgsProject.instance().transformContext(), opts)
    if writer.hasError() != QgsVectorFileWriter.NoError:
        raise RuntimeError(f"{name}: {writer.errorMessage()}")
    del writer


def label(layer, expr, size=8, color="#202020", buffer=True):
    s = QgsPalLayerSettings()
    s.fieldName = expr
    s.isExpression = True
    fmt = QgsTextFormat()
    fmt.setFont(QFont("Arial"))
    fmt.setSize(size)
    fmt.setColor(QColor(color))
    if buffer:
        fmt.buffer().setEnabled(True)
        fmt.buffer().setSize(0.8)
    s.setFormat(fmt)
    s.placement = Qgis.LabelPlacement.OverPoint if layer.geometryType() == Qgis.GeometryType.Point else Qgis.LabelPlacement.Line
    if layer.geometryType() == Qgis.GeometryType.Point:
        s.xOffset = 2.0
        s.yOffset = -2.0
    layer.setLabelsEnabled(True)
    layer.setLabeling(QgsVectorLayerSimpleLabeling(s))


def _prop(name):
    """Identifiant de propriété définie par les données, compatible QGIS 3.2x (PropertyX) et 3.3x+ (Property.X)."""
    from qgis.core import QgsSymbolLayer
    try:
        return getattr(QgsSymbolLayer.Property, name)
    except AttributeError:
        return getattr(QgsSymbolLayer, "Property" + name)


def load_theme():
    """Catalogue du plugin (theme.json) : styles par objet pour la symbologie."""
    import json
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plugin", "theme", "theme.json")
    if not os.path.exists(p):
        return {"objets": {}}
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _map_units(layer_obj, setter_name):
    from qgis.core import QgsUnitTypes
    getattr(layer_obj, setter_name)(QgsUnitTypes.RenderMapUnits)


def line_symbol_for(o):
    """Symbole de ligne QGIS d'un linéaire du standard : couleur et épaisseur du calque,
    tirets du type de ligne (unités carte) et textes intégrés (« aep ») en ligne de marqueurs."""
    from qgis.core import QgsMarkerLineSymbolLayer, QgsFontMarkerSymbolLayer, QgsUnitTypes, Qgis
    st = o.get("style") or {}
    color = st.get("couleur", "#202020")
    width = max(float(st.get("epaisseur_mm", 0.25)), 0.2)
    sym = QgsLineSymbol.createSimple({"color": color, "width": str(width)})
    lt = st.get("ltype")
    if not lt or not lt.get("elements"):
        return sym
    line = sym.symbolLayer(0)
    vec = []           # tirets / espaces alternés (m)
    texts = []         # (position le long du motif, texte, hauteur)
    pos = 0.0
    for e in lt["elements"]:
        length = float(e.get("len", 0))
        if e.get("type") == "text":
            texts.append((pos + abs(length) / 2.0, e.get("text", ""), float(e.get("echelle", 0.254)) or 0.254))
            kind, l = "gap", abs(length)
        elif length > 0:
            kind, l = "dash", length
        elif length < 0:
            kind, l = "gap", -length
        else:
            kind, l = "dash", 0.02   # point
        want_dash = (len(vec) % 2 == 0)
        if (kind == "dash") == want_dash:
            vec.append(l)
        elif vec:
            vec[-1] += l
        else:
            vec.extend([0.0, l])
        pos += abs(length)
    if len(vec) % 2 == 1:
        vec.append(0.0)
    if any(v > 0 for v in vec[1::2]):
        line.setUseCustomDashPattern(True)
        line.setCustomDashVector(vec)
        line.setCustomDashPatternUnit(QgsUnitTypes.RenderMapUnits)
    total = float(lt.get("longueur") or sum(vec)) or sum(vec)
    for offset, text, h in texts:
        if not text.strip():
            continue
        fm = QgsFontMarkerSymbolLayer("Arial", text, h)
        fm.setSizeUnit(QgsUnitTypes.RenderMapUnits)
        fm.setColor(QColor(color))
        marker = QgsMarkerSymbol()
        marker.changeSymbolLayer(0, fm)
        ml = QgsMarkerLineSymbolLayer()
        try:
            ml.setPlacements(Qgis.MarkerLinePlacements(Qgis.MarkerLinePlacement.Interval))
        except Exception:
            ml.setPlacement(QgsMarkerLineSymbolLayer.Interval)
        ml.setInterval(total)
        ml.setIntervalUnit(QgsUnitTypes.RenderMapUnits)
        ml.setOffsetAlongLine(offset)
        ml.setOffsetAlongLineUnit(QgsUnitTypes.RenderMapUnits)
        ml.setRotateMarker(True)
        ml.setSubSymbol(marker)
        sym.appendSymbolLayer(ml)
    return sym


def fill_symbol_for(o):
    """Symbole de surface : contour de la couleur de l'objet et hachure du standard (.pat)."""
    from qgis.core import QgsLinePatternFillSymbolLayer, QgsUnitTypes
    st = o.get("style") or {}
    color = st.get("couleur", "#202020")
    width = max(float(st.get("epaisseur_mm", 0.25)), 0.2)
    sym = QgsFillSymbol.createSimple({"color": "0,0,0,0", "outline_color": color, "outline_width": str(width)})
    h = st.get("hachure")
    if not h:
        return sym
    sc = float(h.get("echelle") or 1.0)
    for ln in h.get("lignes", []):
        angle, x0, y0, dx, dy = ln[:5]
        dashes = ln[5:]
        lp = QgsLinePatternFillSymbolLayer()
        lp.setLineAngle(float(angle) + float(h.get("angle", 0)))
        lp.setDistance(max(abs(float(dy)) * sc, 0.005))
        lp.setDistanceUnit(QgsUnitTypes.RenderMapUnits)
        lp.setOffset(float(y0) * sc)
        lp.setOffsetUnit(QgsUnitTypes.RenderMapUnits)
        lp.setLineWidth(width)
        lp.setColor(QColor(color))
        sub = QgsLineSymbol.createSimple({"color": color, "width": str(width)})
        if dashes:
            sl = sub.symbolLayer(0)
            vec = [abs(float(v)) * sc for v in dashes]
            if len(vec) % 2 == 1:
                vec.append(0.0)
            sl.setUseCustomDashPattern(True)
            sl.setCustomDashVector(vec)
            sl.setCustomDashPatternUnit(QgsUnitTypes.RenderMapUnits)
        lp.setSubSymbol(sub)
        sym.appendSymbolLayer(lp)
    return sym


def symbole_marker():
    """Marqueur SVG du bloc GéoBretagne : fichier <projet>/blocs/<bloc>[_m].svg, taille en mètres,
    largeur = taille x échelle Y, hauteur = taille x échelle X (l'axe X du bloc est vers le haut du SVG),
    rotation = gisement du 1er vers le 2e point. Sans bloc (thème sans SVG) : flèche rouge."""
    from qgis.core import QgsSvgMarkerSymbolLayer, QgsProperty, QgsUnitTypes
    svg = QgsSvgMarkerSymbolLayer("", 1.0)
    svg.setSizeUnit(QgsUnitTypes.RenderMapUnits)
    svg.setFixedAspectRatio(0)
    svg.setStrokeColor(QColor("#b00020"))
    svg.setStrokeWidth(0.25)
    svg.setStrokeWidthUnit(QgsUnitTypes.RenderMillimeters)
    svg.setFillColor(QColor(176, 0, 32, 70))
    props = svg.dataDefinedProperties()
    props.setProperty(_prop("Name"), QgsProperty.fromExpression(
        "@project_folder || '/blocs/' || \"bloc\" || CASE WHEN \"symetrie\" = 1 THEN '_m' ELSE '' END || '.svg'"))
    props.setProperty(_prop("Width"), QgsProperty.fromExpression("coalesce(\"taille\", 0.5) * coalesce(\"echelle_y\", 1)"))
    props.setProperty(_prop("Height"), QgsProperty.fromExpression("coalesce(\"taille\", 0.5) * coalesce(\"echelle_x\", 1)"))
    props.setProperty(_prop("Angle"), QgsProperty.fromExpression("coalesce(\"rotation\", 0)"))
    # couleur du catalogue enregistrée sur l'objet au levé (trait ; le remplissage du SVG garde sa transparence)
    props.setProperty(_prop("StrokeColor"), QgsProperty.fromExpression("coalesce(\"couleur\", '#b00020')"))
    props.setProperty(_prop("FillColor"), QgsProperty.fromExpression("coalesce(\"couleur\", '#b00020')"))
    marker = QgsMarkerSymbol()
    marker.changeSymbolLayer(0, svg)
    return marker


def style_layers(layers):
    # Points topo : couleur selon le type (GPS vert, excentré marron, implanté magenta, importé bleu)
    pt = layers["pt_topo"]
    cats = []
    for value, color, lbl in [
        ("GPS", "#1e9e3a", "Point GPS"),
        ("EXCENTRE", "#8b5a2b", "Point excentré"),
        ("CONSTRUIT", "#8b5a2b", "Point construit"),
        ("IMPORTE", "#1f5fbf", "Point importé"),
        ("IMPLANTE", "#d81b9a", "Point implanté"),
        ("CLIC", "#777777", "Point cliqué"),
    ]:
        sym = QgsMarkerSymbol.createSimple({"name": "cross2", "color": color, "outline_color": color, "size": "2.2"})
        cats.append(QgsRendererCategory(value, sym, lbl))
    pt.setRenderer(QgsCategorizedSymbolRenderer("type", cats))
    label(pt, "concat(\"matricule\", if(\"z_signif\"=1 and \"z\" is not null, '\\n' || format_number(\"z\", 2), ''))", 7, "#00808a")

    theme = load_theme()
    objets = theme.get("objets", {})

    # linéaires : une catégorie par objet du catalogue (couleur, épaisseur, type de ligne, textes intégrés)
    lin = layers["lineaire"]
    cats = []
    for code, o in sorted(objets.items()):
        if o.get("famille") == "lineaire" and o.get("style"):
            cats.append(QgsRendererCategory(code, line_symbol_for(o), o.get("nom", code)))
    cats.append(QgsRendererCategory("", QgsLineSymbol.createSimple({"color": "#202020", "width": "0.4"}), "Autre linéaire"))
    lin.setRenderer(QgsCategorizedSymbolRenderer("code_objet", cats))
    label(lin, "\"nom_objet\"", 7, "#404040")

    # surfaces : hachures du standard par objet, sinon remplissage neutre
    surf = layers["surface"]
    cats = []
    for code, o in sorted(objets.items()):
        st = o.get("style") or {}
        if o.get("famille") == "lineaire" and st.get("hachure"):
            cats.append(QgsRendererCategory(code, fill_symbol_for(o), o.get("nom", code)))
    cats.append(QgsRendererCategory("", QgsFillSymbol.createSimple({"color": "60,60,60,40", "outline_color": "#202020", "outline_width": "0.3"}), "Autre surface"))
    surf.setRenderer(QgsCategorizedSymbolRenderer("code_objet", cats))
    label(surf, "\"nom_objet\"", 7, "#404040")

    sym = layers["symbole"]
    sym.renderer().setSymbol(symbole_marker())
    label(sym, "\"nom_objet\"", 7, "#b00020")

    tx = layers["texte"]
    tx.renderer().symbol().setSize(1.0)
    label(tx, "\"texte\"", 9, "#000000")
    lab = tx.labeling().settings()
    lab.dataDefinedProperties().setProperty(QgsPalLayerSettings.Property.LabelRotation, "-\"rotation\"")
    lab.dataDefinedProperties().setProperty(QgsPalLayerSettings.Property.Color, "coalesce(\"couleur\", '#000000')")
    tx.setLabeling(QgsVectorLayerSimpleLabeling(lab))

    ent = layers["entree"]
    ent.renderer().symbol().setColor(QColor("#6a1b9a"))
    ent.renderer().symbol().setWidth(0.8)
    label(ent, "\"texte\"", 7, "#6a1b9a")

    tal = layers["talus"]
    tal.renderer().symbol().setColor(QColor("#2e7d32"))

    sta = layers["station"]
    cats = [
        QgsRendererCategory("active", QgsMarkerSymbol.createSimple({"name": "triangle", "color": "#ff0000", "outline_color": "#ff0000", "size": "4.5"}), "Station active"),
        QgsRendererCategory("stationnee", QgsMarkerSymbol.createSimple({"name": "triangle", "color": "#ffffff", "outline_color": "#ff0000", "outline_width": "0.6", "size": "4.0"}), "Station stationnée"),
        QgsRendererCategory("non_utilisee", QgsMarkerSymbol.createSimple({"name": "triangle", "color": "#ffffff", "outline_color": "#1f5fbf", "outline_width": "0.6", "size": "4.0"}), "Station non utilisée"),
    ]
    sta.setRenderer(QgsCategorizedSymbolRenderer("statut", cats))
    label(sta, "\"matricule\"", 8, "#ff0000")

    imp = layers["implantation"]
    cats = [
        QgsRendererCategory(0, QgsMarkerSymbol.createSimple({"name": "circle", "color": "#00000000", "outline_color": "#1f5fbf", "outline_width": "0.6", "size": "3.5"}), "À implanter"),
        QgsRendererCategory(1, QgsMarkerSymbol.createSimple({"name": "circle", "color": "#1e9e3a", "outline_color": "#1e9e3a", "size": "3.0"}), "Implanté"),
    ]
    imp.setRenderer(QgsCategorizedSymbolRenderer("implante", cats))
    label(imp, "\"matricule\"", 7, "#1f5fbf")


def copy_blocs():
    """Copie les SVG des blocs du catalogue (plugin/theme/blocs) dans le projet : le rendu
    des symboles utilise @project_folder/blocs/<bloc>.svg."""
    import shutil
    src = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plugin", "theme", "blocs")
    dst = os.path.join(OUT_DIR, "blocs")
    if not os.path.isdir(src):
        print("pas de blocs SVG dans", src)
        return
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print(len(os.listdir(dst)), "blocs SVG copiés dans", dst)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    copy_blocs()
    crs = QgsCoordinateReferenceSystem(f"EPSG:{EPSG}")
    project = QgsProject.instance()
    project.clear()
    project.setCrs(crs)
    project.setTitle("Lahocy Topo - projet générique")

    first = True
    for name, (wkb, defs) in LAYERS.items():
        write_layer(name, wkb, defs, crs if wkb != QgsWkbTypes.NoGeometry else QgsCoordinateReferenceSystem(), first)
        first = False

    layers = {}
    order = ["implantation", "texte", "symbole", "entree", "talus", "lineaire", "surface", "pt_topo", "station", "visee", "topo_param"]
    for name in order:
        vl = QgsVectorLayer(f"{GPKG}|layername={name}", name, "ogr")
        if not vl.isValid():
            raise RuntimeError("Couche invalide : " + name)
        # Les objets sont créés par le plugin : jamais de formulaire QField
        cfg = vl.editFormConfig()
        cfg.setSuppress(QgsEditFormConfig.FeatureFormSuppress.SuppressOn)
        vl.setEditFormConfig(cfg)
        # Variables lues par le plugin (rôle des couches)
        vl.setCustomProperty("lahocy/role", name)
        layers[name] = vl

    style_layers(layers)

    # Ordre d'affichage : premier ajouté = au-dessus
    for name in ["station", "pt_topo", "symbole", "texte", "entree", "implantation", "lineaire", "surface", "talus", "visee", "topo_param"]:
        project.addMapLayer(layers[name])

    # Valeurs initiales des paramètres du plugin
    param = layers["topo_param"]
    param.startEditing()
    from qgis.core import QgsFeature
    for k, v in [
        ("matricule_prochain", "1000"),
        ("hauteur_canne", "2.000"),
        ("gnss_seuils", '{"hrms":{"actif":true,"limite":0.05},"vrms":{"actif":false,"limite":0.10},"hdop":{"actif":false,"limite":2.0},"pdop":{"actif":false,"limite":3.0},"nb_sat_min":6,"fix_requis":4,"tolerance_orange":2.0}'),
        ("droitier", "1"),
        ("mode_bureau", "0"),
        ("tol_implantation", "0.05"),
        ("excentrements_favoris", "point;perp_prec;perp_suiv;vertical;milieu;deux_dist"),
        ("hauteur_prisme", "1.500"),
        ("hauteur_tourillons", "1.500"),
        ("hauteur_disto", "1.20"),
        ("decalage_bicapteur", "0.000"),
        ("bridge_url", "http://127.0.0.1:8765"),
        ("tps_driver", "simulateur"),
        ("tps_port", "COM3"),
        ("tps_baud", "115200"),
        ("station_matricule_prochain", "S.1"),
        ("tps_double_retournement", "0"),
        ("tps_correction_courbure", "1"),
        ("tps_tolerance_ecart_moyenne", "0.04"),
        ("tps_spirale_hz", "10"),
        ("tps_spirale_v", "10"),
    ]:
        f = QgsFeature(param.fields())
        f.setAttribute("cle", k)
        f.setAttribute("valeur", v)
        param.addFeature(f)
    param.commitChanges()

    # Accrochage sur les points topo (utile pour le mode bureau)
    snap = QgsSnappingConfig(project)
    snap.setEnabled(True)
    snap.setMode(Qgis.SnappingMode.AllLayers)
    snap.setTypeFlag(Qgis.SnappingType.Vertex)
    snap.setTolerance(12)
    snap.setUnits(QgsTolerance.Pixels)
    project.setSnappingConfig(snap)

    # Variables de projet lues par le plugin
    from qgis.core import QgsExpressionContextUtils
    QgsExpressionContextUtils.setProjectVariable(project, "topo_theme", "theme/theme.json")
    QgsExpressionContextUtils.setProjectVariable(project, "topo_version", "0.1")

    project.writeEntryBool("Paths", "/Absolute", False)
    if not project.write(QGS):
        raise RuntimeError("Écriture du projet impossible : " + QGS)
    print("OK :", QGS)
    print("OK :", GPKG, "couches =", ", ".join(LAYERS))


if __name__ == "__main__":
    app = QgsApplication([], False)
    app.initQgis()
    try:
        main()
    finally:
        app.exitQgis()
