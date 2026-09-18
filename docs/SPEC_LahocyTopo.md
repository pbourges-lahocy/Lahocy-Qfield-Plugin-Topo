# Lahocy Topo — spécification fonctionnelle

Plugin de levé topographique **Lahocy Topo** pour **QField** (plugin d'application QML).
Référence : manuel de formation du logiciel de levé utilisé jusqu'ici (V20230823) et son
thème « Sbaa » (base MDB).

Principe directeur : **garder le même principe d'interface que le logiciel de levé utilisé jusqu'ici** (palette / sous‑palettes,
boîte « mesure et dessin », objets actifs, carnet de terrain, excentrements, implantation)
en supprimant tout ce qui est lié à AutoCAD/DWG, au module SIG et aux thèmes clients.

---

## 1. Périmètre

### 1.1 Ce qui est repris du logiciel de référence

| Chapitre du manuel de référence | Fonction | QField Topo |
|---|---|---|
| 1.7 / 18.9 | Palette principale 2 colonnes, sous‑palettes, appui court = sous‑palette, appui long = objet direct | **Oui** (identique, `theme.json`) |
| 1.8 / 3.2 | Activation, plusieurs linéaires actifs simultanés (max 10), STOP, mise en attente, relance dernier objet, relance depuis le plan | **Oui** |
| 1.11 | Zones : ruban / dessin / palette / mesure‑dessin / objets actifs, droitier‑gaucher, mode bureau vs terrain (confirmation des clics) | **Oui** (panneau latéral ancré gauche ou droite) |
| 1.12 | Zoom, pan, zoom total, « Où suis‑je », recentrage auto à la mesure | **Oui** (QField natif + bouton) |
| 1.13 | Outils de mesure distance / surface / coordonnées | **Oui** (outil de mesure QField natif) |
| 3.4 | Linéaire ligne‑arc : ligne brisée, arc 3 pts, arc 2 pts, courbe lissée, tangent/fixe, fermeture, hachure, annuler dernier sommet, ajustement début/fin | **Oui** (arcs et courbes segmentés, définition conservée dans `params_json`) |
| 3.5 | Polyligne 3D / courbe 3D | **Oui** (tous les linéaires sont en Z) |
| 3.6 / 3.7 | Multiligne double / triple (largeur, ligne directrice, fermetures) | **Oui** (ligne directrice levée ; parallèles générées) |
| 3.8 | Rectangle (2/3 pts), cercle (centre+rayon, 3 pts) | **Oui** |
| 3.9 | Symboles 1 / 2 / 3 points, verrous largeur/longueur, poignées d'accrochage, symétrie / décalage, mise en attente | **Oui** (rotation + échelles stockées, le bloc est dessiné au bureau) |
| 3.10 | Habillage de talus (haut+bas, haut seul, bas seul, paramètres barbules) | **Partiel** : haut/bas levés et liés, barbules générées au bureau |
| 3.11 / 18.6 | Textes 1 pt / 2 pts / parallèle, listes de textes | **Oui** |
| 3.12 | Escalier 3 / 4 points, nb marches ou profondeur, flèche | **Oui** (contour + paramètres ; marches générées au bureau) |
| 3.13 | Entrée 2 points, délimiteurs, seuil, sens, texte | **Oui** (paramètres stockés ; habillage bureau) |
| 3.14 | Bâtiment façade + fuyantes + hachure | **Partiel** : façade levée, type/longueur de fuyante en paramètres |
| 4 | Suppression avec levée d'ambiguïté, continuer un linéaire | **Oui** |
| 5.1 | Points topo (matricule, altitude, visibilité, couleur GPS/excentré) | **Oui** |
| 5.3 | Qualité GPS : seuils, boutons vert / orange / rouge, blocage acquisition | **Oui** (HRMS, VRMS, HDOP, PDOP, nb sat, type de fix RTK) |
| 5.4 | Point unique / Mesure point avec liaison / Dernier point | **Oui** |
| 5.5 → 5.14 | Excentrements GPS : par rapport à point, perpendiculaire point précédent, perpendiculaire point suivant, vertical, milieu, deux distances ; paramétrage des favoris | **Oui** |
| 5.16 / 5.17 | Carnet de terrain : filtres, recherche, zoom, hauteur de canne, Z significatif, suppression, export MXYZ / CSV GPS | **Oui** |
| 5.18 | Import d'un fichier de points | **Oui** (CSV M X Y Z → points « importés » ou liste d'implantation) |
| 11 | Détection de réseaux : saisie manuelle de profondeur → point TN + point excentré vertical ZGS | **Oui** (simulateur / marquage au sol, détecteur Bluetooth via le pont local) |
| 12 | Implantation de points : liste, navigation (cible, tolérance, écarts), rapport CSV | **Oui** ; polylignes / MNT / chaises : non (v2) |
| 5.5 → 5.8 | Excentrements TPS : par rapport à la station, distance/recouvrement (dist puis angle), vertical par angle V | **Oui** (chapitre 14) |
| 8 | Station totale : connexion, hauteur de prisme, pilotage (PowerSearch, spirale, joystick, relockage dans le plan), mise en station (coordonnées, point connu, clic libre, visée avant, changement, reprise), visées de référence (angle+distance, angle Hz, approchée), station libre | **Oui** (chapitre 14, via le pont local) |
| 8.1 / 19 | Disto Bluetooth : mesure de distance pour excentrements, télécommande (touches) | **Oui** (pont local) |
| 8.3.2 | Bicapteur GNSS + prisme (hauteurs liées, station libre sur points GNSS) | **Oui** |
| 5.16 / 5.17 | Polygonale, export polaire (GSI, JSI, GEO), points doubles / double retournement | **Oui** (carnet polaire) |
| 17 | TopoMathrix : compensation en bloc | **Partiel** : outil bureau Python `tools/compensation.py` (moindres carrés) + régénération du plan ; pas de calcul embarqué en v1 |

### 1.2 Ce qui est abandonné (sans équivalent)

- Tout AutoCAD : DWG/DWT, Xref, calage Helmert, import cadastre DWG, gabarits, styles de
  traits, finalisation de plan (cartouche, carroyage), export DGN, PGOC / Carto200.
- Onglet **Topo SIG**, onglet **Topo OFFICE**.
- Thèmes « système » / « client » : un **seul catalogue générique** (`theme.json`).
  La mise en forme (symbologie, calques DWG) se fait au bureau dans QGIS selon le client.
- Reconnaissance et synthèse vocales (non disponibles dans le moteur QML de QField).

> **Important — appareils topographiques.** La station totale, le disto et le détecteur
> font partie du périmètre (c'est ce qui distingue Lahocy Topo d'un QField nu). Un plugin
> QField est du QML/JavaScript : il ne peut pas ouvrir lui‑même un port série ou une liaison
> Bluetooth. Le pilotage passe donc par un **pont local** (« Lahocy Bridge », chapitre 14) qui
> tourne sur la tablette et expose les appareils au plugin par HTTP local. Tous les calculs
> topographiques (mise en station, V0, station libre, excentrements TPS, polygonale) sont
> faits dans le plugin.

---

## 2. Architecture

```
plugin/                          ← plugin d'application QField (release : lahocy-topo.zip)
  main.qml, metadata.txt, icon.svg
  topo/                           ← composants QML du plugin (un fichier par zone)
  theme/theme.json               ← catalogue d'objets et palettes (équiv. du MDB de thème)
  theme/icons/*.png              ← icônes des boutons
project/LahocyTopo/              ← projet QField générique (release : LahocyTopo-projet.zip)
  LahocyTopo.qgs                 ← projet QGIS générique (EPSG:2154 par défaut)
  LahocyTopo.gpkg                ← données (carnet + primitives), voir §3
bridge/                          ← pont local (station totale, disto, détecteur), voir §14
tools/theme_to_json.py       ← convertit un thème du logiciel de référence (MDB) en theme.json
tools/build_project.py           ← régénère le GeoPackage + le projet (PyQGIS)
```

- **Plugin d'application** : installé une fois dans QField (« Install plugin from URL »,
  asset `lahocy-topo.zip` au nom fixe pour les mises à jour en place). Il s'active dès
  qu'un projet contenant les couches du modèle est ouvert ; le catalogue et les icônes sont
  embarqués dans le plugin, les données dans le projet.
- **Positionnement** : le récepteur GNSS est géré par QField (interne, Bluetooth NMEA,
  NTRIP). Le plugin lit `positionSource.positionInformation` (lat/lon, altitude déjà
  corrigée de la **hauteur d'antenne** et du géoïde selon les réglages QField, HRMS/VRMS,
  DOP, nombre de satellites, type de fix).
- **Écriture des données** : le plugin crée/modifie directement les entités des couches
  du GeoPackage (`QfLayerUtils.addFeature`, `QfFeatureModel.changeGeometry`), sans
  formulaire.

---

## 3. Modèle de données (GeoPackage)

Toutes les couches sont en **Z** et portent les champs communs `code_objet`, `nom_objet`,
`famille`, `calque` (nom du calque du logiciel de référence, pour la correspondance bureau), `matricules`
(points topo utilisés), `statut` (`en_cours` / `attente` / `termine`), `indice`,
`params_json`, `horodatage`, `operateur`.

| Couche | Géométrie | Rôle | Champs spécifiques |
|---|---|---|---|
| `pt_topo` | PointZ | **Carnet de terrain** : tout point mesuré, excentré, construit, importé, implanté | `matricule`, `type` (GPS/EXCENTRE/CONSTRUIT/IMPORTE/IMPLANTE/CLIC), `x y z`, `z_signif`, `hv`, `qualite`, `fix_quality`, `nb_sat`, `hrms vrms pdop hdop vdop`, `lat lon alt_ellips`, `pt_appui`, `pt_ref`, `methode_excent`, `dist_excent`, `profondeur`, `visible` |
| `lineaire` | LineStringZ | ligne‑arc, polyligne 3D, multilignes (ligne directrice), façades bâtiment | `type_lineaire`, `largeur`, `ferme`, `hachure` |
| `surface` | PolygonZ | rectangles, cercles, linéaires fermés hachurés, escaliers | `type_surface`, `hachure`, `rayon`, `nb_marches`, `prof_marche`, `fleche`, `sens` |
| `symbole` | PointZ | blocs | `famille_bloc`, `bloc`, `rotation` (° horaire depuis le nord), `echelle_x`, `echelle_y`, `dist_12`, `dist_23`, `nb_points`, `symetrie` |
| `texte` | PointZ | textes | `texte`, `rotation`, `taille`, `ancrage` |
| `entree` | LineStringZ (2 pts) | entrées | `delimiteur_g/d`, `taille_pilier_g/d`, `seuil`, `decalage_seuil`, `sens`, `texte`, `decalage_texte` |
| `talus` | LineStringZ | habillage de talus (lien haut/bas) | `fid_haut`, `fid_bas`, `mode`, `espace`, `nb_lignes`, `pct_court/long/inter` |
| `implantation` | PointZ | liste des points à implanter | `matricule`, `ordre`, `x y z`, `implante`, `dx dy dz dist`, `matricule_leve` |
| `station` | PointZ | stations (connues, libres, créées par visée avant) et mises en station | `matricule`, `x y z`, `hi` (hauteur tourillons), `v0` (grades), `type` (CONNUE / LIBRE / VISEE_AVANT / IMPORTEE), `statut` (active, stationnee, non_utilisee), `nb_ref`, `emq_plani`, `emq_alti`, `params_json` |
| `visee` | table | carnet polaire : références et observations brutes | `station`, `cible`, `type` (REF_ANGLE_DIST / REF_ANGLE / REF_APPROCHEE / VISEE_AVANT / POINT), `hz`, `v`, `sd`, `hi`, `hr`, `face`, `ecart_plani`, `ecart_alti`, `exclue`, `horodatage` |

Les points levés au TPS (`pt_topo.type = TPS`) conservent aussi leurs observations brutes
(`station`, `hz`, `v`, `sd`, `hi`, `hr`, `face`) pour permettre un recalcul après
compensation ou changement de V0.
| `topo_param` | table | paramètres persistants du plugin | `cle`, `valeur` (matricule suivant, hauteur de canne, seuils GNSS, droitier, mode bureau…) |

`params_json` d'un linéaire conserve la **définition exacte** des sommets et segments
(matricule, x y z, type de segment `L` ligne / `A3` arc 3 pts / `A2` arc 2 pts / `C`
courbe, tangence), ce qui permet de régénérer les arcs vrais au bureau (équivalent de la
base MDB « mémoire du lever » du logiciel de référence).

---

## 4. Catalogue d'objets (`theme.json`)

Équivalent des tables `PA_Objet`, `PA_Palette`, `PA_PaletteItem`, `PA_Met*` du thème
le logiciel de référence, sans aucune information de rendu :

```json
{
  "nom": "Sbaa", "colonnes": 2,
  "palette": [
    { "pos": 0, "code": "Voirie", "nom": "CatVoirie", "icone": "CatVoirie.png",
      "objet": "", "sous_palette": [ { "pos": 0, "objet": "Trottoir", "icone": "1.png" }, ... ] }
  ],
  "objets": {
    "Trottoir": { "famille": "lineaire", "nom": "Trottoir", "libelle_audio": "Trottoir",
                  "calque": "Voie_bord",
                  "methode": { "type": "ligne_arc", "mode": "ligne", "tangent": false,
                               "ajust_debut": false, "ajust_fin": false, "remplissage": false } },
    "Avaloir":  { "famille": "symbole", "calque": "Assa_sym_ep_A",
                  "symbole": { "famille_bloc": "Assnt", "bloc": "Assa_Avaloir" },
                  "methode": { "points": 3, "ancrages": [6, 8, 2],
                               "verrou_largeur": false, "verrou_longueur": false } },
    "Mur plein": { "famille": "lineaire", "methode": { "type": "multiligne_double",
                  "largeur": 0.2, "ligne_directrice": 4, "fermeture_debut": true, "fermeture_fin": true } }
  },
  "listes_textes": { "Type de sol": ["Enrobé", "Béton", ...] }
}
```

Familles : `lineaire`, `symbole`, `texte`, `talus`, `escalier`, `entree`, `batiment`,
`categorie` (bouton « chapeau » de palette principale).
Le catalogue livré est la conversion du thème **Sbaa** (18 boutons principaux, 241
boutons de sous‑palettes, 316 objets). Tout autre thème se convertit avec
`tools/theme_to_json.py`. Le fichier est éditable à la main au bureau.

---

## 5. Interface (principe du logiciel de référence conservé)

Panneau latéral ancré à **droite** (droitier) ou à **gauche** (gaucher), masquable par un
bouton « Lahocy Topo » de la barre d'outils QField.

```
┌────────────┬──────────────────────────────┬──────┐
│ ZONE 3     │ ZONE 4 – Mesure et dessin    │ Z.5  │
│ Palette    │ ┌ excentrements favoris ───┐ │ Obj. │
│ 2 colonnes │ │ [pt][⊥prec][⊥suiv][Z][…] │ │ actifs│
│ (scroll)   │ ├──────────────────────────┤ │ [↺]  │
│            │ │ [canne 2.000] [Z?] [STOP]│ │ [⏸]  │
│  ┌──┐┌──┐  │ │ Point   │ CQ3D = 0.021 m │ │ ──── │
│  │  ││  │  │ │ unique  │ RTK fixe       │ │ [B1] │
│  └──┘└──┘  │ │ Dernier │ 12 satellites  │ │ [T1] │
│  ┌──┐┌──┐  │ │ point   │                │ │ [B2] │
│  │  ││  │  │ └──────────────────────────┘ │      │
│  └──┘└──┘  │  Objet en cours : Trottoir    │      │
│   ...      │  [ligne][arc3][arc2][courbe]  │      │
│            │  [fermer][hachure][↶ annuler] │      │
│            │  [ajust déb][ajust fin]       │      │
│            ├──────────────────────────────┤      │
│            │ [GNSS ●] [Carnet] [Impla] [⚙]│      │
└────────────┴──────────────────────────────┴──────┘
```

- **Zone 3 – Palette** : boutons carrés avec icône ; appui **court** → sous‑palette
  flottante (grille paginée) ; appui **long** → exécution de l'objet du bouton (marqueur
  « main » en bas à droite comme dans Topo). Emplacements vides conservés.
- **Zone 4 – Mesure et dessin**
  - Haut : ligne des excentrements favoris (configurable, §7), hauteur de canne,
    bascule « Z significatif », **STOP**.
  - Gros boutons **Point unique**, **Mesure point avec liaison** (bouton qualité), **Dernier
    point**. La zone qualité est **verte** (mesure possible), **orange** (hors tolérance
    proche : confirmation demandée), **rouge** (mesure interdite), **grise** (pas de GNSS).
  - Milieu : primitives et réglages de l'objet en cours (varie selon la famille).
  - Bas : état GNSS (ouvre le menu positionnement QField), Carnet, Implantation,
    Paramètres (droitier/gaucher, mode bureau/terrain, seuils GNSS, matricule).
- **Zone 5 – Objets actifs** : pile des linéaires actifs non achevés (« Bordure 1 »,
  « Talus 1 »…), clic = bascule ; boutons supérieurs « relance dernier objet » et « objets
  en attente » (appui long = liste des objets en attente à reprendre).
- **Ruban** (ligne d'icônes en tête de panneau) : Continuer, Supprimer, Relance depuis le
  plan, Mesurer, Où suis‑je, Zoom total.

---

## 6. Cycle de placement

1. Activation (palette, relance, continuer, attente) → l'objet apparaît dans la zone 5
   (linéaires) et ses paramètres dans la zone 4 ; message d'aide en tête (« Trottoir –
   ligne brisée »).
2. Chaque **Mesure point avec liaison** (ou **Dernier point**, ou clic dans le plan en
   mode bureau / clic confirmé en mode terrain) crée un point topo et l'utilise
   immédiatement comme sommet / point de symbole / point de texte.
3. **STOP** finalise (`statut = termine`) ; appui court sur « attente » met en attente
   (`statut = attente`, repris plus tard). Les objets en cours sont **persistés en base** :
   après un plantage ou une fermeture, « Continuer » les réactive.
4. Symboles / textes / entrées / escaliers ne vont pas dans la zone 5 : ils se lèvent en
   points consécutifs (2, 3 ou 4) puis proposent leurs ajustements (symétrie, inversion,
   projection sur linéaire).

Numérotation : matricule incrémenté automatiquement (`topo_param.matricule_prochain`),
modifiable dans les paramètres.

---

## 7. Excentrements GNSS

| Méthode | Entrées | Résultat |
|---|---|---|
| Par rapport à point | point d'appui (mesure ou dernier point), point de référence (par défaut le précédent, ou choisi sur le plan), direction G/D/Avant/Arrière, distance | point excentré, Z = Z appui |
| Perpendiculaire point précédent | dernier sommet de l'objet en cours (pt 1), position GNSS (pt 2), côté, distance | pt 3 sur la perpendiculaire, ajouté à l'objet |
| Perpendiculaire point suivant | mesure pt 1 + distance mémorisée, puis mesure pt 2 (+ distance) | pts 3 et 4 construits, objet amorcé (icône sur fond orange tant que l'excentrement est incomplet) |
| Vertical | point d'appui, Δz (négatif vers le bas) | point excentré même XY, Z décalé |
| Milieu | deux mesures de part et d'autre | point milieu, Z moyen |
| Deux distances | deux points + deux distances + côté | point intersection des deux cercles, Z moyen |

Les points d'appui restent dans le carnet (couleur marron pour les points excentrés,
masquables par « visibilité des points d'appui »).

---

## 8. Carnet de terrain

Boîte plein écran : filtres par type (GPS, excentrés, construits, importés, implantés),
recherche par matricule, liste (matricule, type, hv, X, Y, Z, Z significatif), boutons
**Zoomer**, **Retrouver depuis le plan**, **Changer la hauteur de canne** (recalcule Z),
**Changer Z significatif**, **Supprimer** (avec gestion des points excentrés dépendants :
suppression double ou transformation en point construit), **Exporter** (MXYZ `.xyz`,
CSV données GPS avec précisions / satellites / heure), **Importer** un fichier de points.

---

## 9. Implantation de points

Liste depuis la couche `implantation` (préparée au bureau ou importée) ou depuis le carnet.
Vue de guidage : cible bleue (point), position GNSS orange, écarts dx/dy/dz et distance,
flèches gauche/droite/avant/arrière relatives au cap, cercle vert de tolérance (5 cm par
défaut) ; bouton de mesure vert dans la tolérance. « Implanter » crée un point topo
`IMPLANTE`, renseigne les écarts et passe au point suivant. Rapport CSV.

---

## 10. Détection (mode simulateur)

Onglet Détecteur : saisie manuelle de la profondeur (+ index, intensité, fréquence
optionnels) mise en attente ; la mesure GNSS suivante crée le point TN et le point excentré
vertical (ZGS = ZTN − profondeur) accroché à l'objet en cours (canalisation en polyligne
3D). Mode « dès réception » ou « délai » comme dans Topo.

---

## 11. Réglages (équivalent onglet Topo PARAM)

- Droitier / gaucher ; mode bureau (clics directs) / terrain (confirmation).
- Seuils de précision GNSS (boîte identique à Lahocy Topo : critère coché + limite) : HDOP, VDOP,
  PDOP, HRMS, VRMS, nb satellites mini, fix RTK requis, marge orange.
- Hauteur de canne (liste de valeurs favorites), matricule du prochain point.
- Excentrements favoris affichés en première ligne.
- Tolérance d'implantation, zoom automatique.

Tous ces réglages sont stockés dans `topo_param` (donc synchronisés avec le projet).

---

## 12. Livrables bureau (hors plugin)

- Projet QGIS de mise en forme client : symbologie par `code_objet` / `calque`, génération
  des barbules de talus, marches d'escalier, habillage d'entrées, parallèles de multilignes
  (déjà générées sur le terrain) et export DXF/DWG (QGIS ou FME).
- `tools/theme_to_json.py` : conversion d'un thème du logiciel de référence existant.
- `tools/build_project.py` : (re)création du GeoPackage et du projet générique dans un
  autre système de projection (`python-qgis-ltr.bat tools/build_project.py 3948`).

---

## 14. Station totale, disto, détecteur : le pont local « Lahocy Bridge »

### 14.1 Principe

```
 ┌──────────────────────────┐   HTTP JSON (localhost:8765)   ┌──────────────────────────┐
 │ QField + plugin      │ ─────────────────────────────► │ Lahocy Bridge (Python)      │
 │  - interface, calculs    │ ◄───────────────────────────── │  - pilotes appareils     │
 │  - carnet, plan          │   statut / mesures / événements│  - COM / Bluetooth / BLE │
 └──────────────────────────┘                                └──────────────────────────┘
                                                                   │        │       │
                                                              GeoCOM     Disto   Détecteur
                                                            (TS13/TS16) (D810)  (RD, vLoc)
```

- Le pont est un exécutable Windows (tablette durcie, comme aujourd'hui avec le logiciel de référence) ou
  un service Android (v2). Il n'a **aucune logique topographique** : il expose des
  primitives « mesurer », « tourner », « chercher le prisme », « lire une distance ».
- Le plugin interroge `GET /status` (0,5 s) et `GET /events?since=n` (long‑poll) : perte /
  reprise du prisme, latence radio (LEDs), touche disto (télécommande), mesure détecteur.
- Pilotes : **Simulateur** (entrée clavier d'angles/distances, comme « Entrée clavier » de
  Topo), **Leica GeoCOM** (TS13/TS16/TS60, poignée RH17 ou Bluetooth), Trimble / Topcon /
  Sokkia (interfaces prévues, à implémenter avec le matériel), Disto Leica (BLE), détecteurs
  Radiodetection / Vivax (trames série Bluetooth).

### 14.2 API du pont (extrait)

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/status` | état de chaque famille (tps, gps, disto, detector) : connecté, modèle, verrouillé sur prisme, latence ms, batterie, hauteur prisme, angles courants |
| POST | `/tps/connect` `{driver, port, baud}` / `/tps/disconnect` | connexion |
| POST | `/tps/measure` `{mode: "prisme" \| "sans_prisme", face: 1 \| 2}` | mesure Hz, V (grades), Di (m) |
| POST | `/tps/angles` | lecture des angles seuls |
| POST | `/tps/search` `{type: "powersearch" \| "powersearch_etendu" \| "spirale", hz, v}` / `/tps/stop` | recherche de prisme |
| POST | `/tps/joystick` `{dir: "gauche" \| "droite" \| "haut" \| "bas", speed: "lent" \| "rapide"}` | rotation manuelle |
| POST | `/tps/turn` `{hz, v}` | orientation vers une direction (relockage dans le plan) |
| POST | `/tps/lock` `{on}` | verrouillage / suivi du prisme |
| POST | `/tps/laser` `{on}` | plomb laser / pointeur |
| POST | `/disto/measure` | distance disto (m) |
| GET | `/detector/pending` / POST `/detector/simulate` `{profondeur, ...}` | mesures de détection |
| GET | `/events?since=` | événements asynchrones |

### 14.3 Fonctions topographiques du plugin (menu Station)

Le **menu Station** reprend celui de Topo (zone 4, partie basse) : Mise en station,
Visées de référence, Pilotage, Hauteur prisme, Paramétrage, Implantation.

- **Mise en station** : saisie de coordonnées, clic sur point connu (point topo/station
  transformé), clic libre dans le plan (Z du contexte), création par **visée avant** (crée
  une station future), **changement** de station (hauteur tourillons + visées de référence
  obligatoires avant mesure), **reprise** de station, **station libre** (résection par
  moindres carrés sur n visées, écarts par point, exclusion, options XY / Z / Hv, mode
  bicapteur : point GNSS créé à la volée comme référence).
- **Visées de référence** : angle + distance sur point connu (écarts plani/alti), angle Hz
  seul, visée **approchée** (V0 provisoire puis recalcul et redessin des points levés).
- **Calcul d'un point** : `Hz_g = V0 + Hz`, `Dh = Di·sin V`, `Z = Zs + hi + Di·cos V − hr`
  (option courbure/réfraction), double retournement (moyenne des faces).
- **Pilotage** : PowerSearch (fenêtre restreinte / étendue), recherche spirale (angles
  paramétrés), joystick lent/rapide, relockage dans le plan (clic sur point topo → rotation
  + recherche ; clic hors point → rotation seule), affichage de l'axe de visée.
- **Suivi du prisme** : LEDs de latence radio, bip perte/relockage, blocage des boutons de
  mesure si prisme perdu, bascule automatique vers l'écran de pilotage après 3 s.
- **Excentrements TPS** : par rapport à la station (G/D/Avant/Arrière + distance saisie ou
  disto, visée horizontale / au sol avec hauteur du disto), distance/recouvrement (une
  mesure pour la distance, une pour l'angle), vertical par visée d'angle V.
- **Bicapteur** : hauteurs prisme / antenne liées par le décalage `parambicapteur`, mesure
  bicapteur dans les références (point GNSS puis visée TPS instantanée).
- **Carnet polaire** : stations, mises en station, références, points rayonnés ; export
  GSI / JSI / GEO ; vue de la polygonale ; renommage de matricules.

### 14.4 Compensation (TopoMathrix)

En v1, la compensation en bloc est réalisée au bureau (`tools/compensation.py`, moindres
carrés sur le carnet polaire exporté) et les points recalculés sont réinjectés par
« régénération » (mise à jour des `pt_topo` puis reconstruction des primitives à partir de
leurs `matricules`). L'embarquement du calcul dans le plugin (JavaScript) est prévu en v2.

## 15. Limites connues / choix techniques

- Le pont local est indispensable pour les appareils ; sans pont, le plugin fonctionne en
  GNSS seul (QField natif).

- Arcs et courbes : géométrie **segmentée** dans le GeoPackage (compatibilité maximale
  QField / QGIS / export), définition exacte conservée dans `params_json`.
- Rotation des symboles : convention QGIS (degrés horaires depuis le nord), à utiliser
  dans la symbologie bureau (`rotation` piloté par donnée).
- Pas de synthèse vocale ni de télécommande disto.
- Le plugin s'appuie sur l'API QField 4.3 (`org.qfield.core`, `org.qfield.gui`) ; tester
  sur QField Windows/Android avec le plugin **PluginReloader** pendant le développement.
