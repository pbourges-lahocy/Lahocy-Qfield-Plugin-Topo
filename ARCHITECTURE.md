# Architecture

## Principe

Ce plugin s'appuie entierement sur QField pour tout ce qui est moteur
cartographique, gestion des couches, snapping, symbologie, offline et
synchronisation QFieldCloud. Le plugin n'apporte que la couche **metier
topographique** : calculs, carnet d'observations, pilotage d'instruments,
codification.

Tout le code QML/JS est charge dynamiquement par QField depuis le dossier
`plugin/` (voir [README.md](README.md) pour le mecanisme d'installation).

## Structure actuelle

```
plugin/
├── metadata.txt              # nom, version, description (lu par QField)
├── icon.svg                  # icone du bouton dans la barre d'outils
├── main.qml                  # point d'entree : bouton + routage des ecrans
└── qml/
    ├── TopoEngine.js         # calculs topo purs (aucune dependance QML)
    ├── HomeMenu.qml          # menu d'accueil
    ├── PlaceholderScreen.qml # ecran generique "a venir"
    ├── DiagnosticScreen.qml  # diagnostic QField/GNSS
    ├── PolarSurveyScreen.qml # leve polaire (POC)
    ├── PaletteScreen.qml     # panneau ancre a droite : palette de codes (prototype)
    ├── TopBarPanel.qml       # panneau de test ancre en haut
    └── BottomBarPanel.qml    # panneau de test ancre en bas
```

Cette structure reste volontairement plate : on ajoute un fichier quand une
fonctionnalite existe reellement, pas avant. Pas de dossiers vides.

## Portee : Land2Map vs Lahocy Topo

Land2Map fait ~285 pages de documentation, ce qui peut donner l'impression
qu'il faut reconstruire un logiciel enorme. En realite, une grosse partie
de ce volume est du dessin CAO generaliste que QGIS/QField fournit deja
nativement - ce n'est pas notre perimetre. Le tableau ci-dessous separe ce
qui est deja couvert, ce qu'il reste vraiment a construire, et ce qui est
volontairement laisse de cote.

### Deja fourni par QField/QGIS (a ne pas reconstruire)

- Moteur cartographique, gestion des couches, symbologie QGIS
- Snapping, edition geometrique (points/lignes/polygones)
- Formulaires de saisie (feature form)
- Fonctionnement offline + synchronisation QFieldCloud
- Fond de plan / cadastre / couches raster et vecteur
- Positionnement GNSS de base (`iface.positioning()`)
- Navigation carte (zoom, pan, mesures)

### A construire nous-memes (le vrai perimetre du plugin)

| Fonction | Statut |
|---|---|
| Calcul polaire (rayonnement) | Fait (POC) |
| Diagnostic QField/GNSS | Fait |
| Palette de codes (categories -> sous-palette -> pose) | Prototype en cours |
| Panneaux ancres (droite/haut/bas) | Prototype en cours |
| Station sur point connu, orientation, station libre (resection) | A faire |
| Intersection, polygonale, compensation | A faire |
| Carnet d'observations brutes (station/cible/angles/distance/face/instrument, separe de la coordonnee calculee, recalcul en cascade) | A faire - c'est le principe central du projet |
| Points deportes / excentrements (Land2Map en propose 8 methodes) | A faire |
| Connexion GNSS Bluetooth (NMEA generique, Emlid, Leica, Spectra, Trimble) | A faire |
| Connexion station totale (Leica en premier) | A faire |
| Connexion detecteur electromagnetique | A faire |
| Client NTRIP integre (caster/port/mountpoint/GGA/RTCM) | A faire |
| Mise en station (coordonnees, clic point connu, clic libre, visee avant, changement/reprise station) | A faire |
| Implantation (navigation vers point/polyligne, rapport d'ecarts) | A faire |
| Catalogue Lahocy canonique + mapping par profil client | A concevoir (probablement cote QGIS/PostGIS, pas dans le plugin lui-meme) |
| Export DWG comme format de sortie (pas source de verite) | Long terme, probablement un traitement serveur plutot que le plugin terrain |

### Volontairement laisse de cote (couvert ailleurs, ou non prioritaire)

- Dessin CAO generaliste (talus, escalier, entree, batiment, multilignes) - couvert par l'edition QGIS/QField
- Gestion de xrefs/calques a la AutoCAD - la notion de couches QGIS suffit
- Reconnaissance vocale / synthese vocale - eventuellement tres tard, pas une priorite
- Modes "bureau" vs "tactile" distincts - QField est deja concu tactile nativement
- Livrables specifiques a un standard (type PGOC/C200) - a voir au cas par cas selon les contrats clients
- Affichage superpose type Google Maps - QField a deja ses propres fonds de carte en ligne

## Ou vont les prochaines fonctionnalites

Cette section documente les **intentions**, pas des fichiers a creer
immediatement.

- **Moteur topo** (`TopoEngine.js`, puis eventuellement plusieurs modules
  `.js` si le fichier grossit) : station sur point connu, orientation,
  station libre, intersection, polygonale, compensation, transformations.
  Toujours des fonctions pures (entree -> sortie), testables sans QField.

- **Observations brutes** : le principe central est de conserver la mesure
  brute (angles, distance inclinee, hauteurs, face, instrument) separement
  de la coordonnee calculee, pour pouvoir recalculer si une station bouge
  apres compensation. Quand ce sujet sera developpe, il aura probablement
  besoin d'un stockage structure (couches QGIS dediees aux observations et
  aux stations, plutot que des fichiers JS) - a concevoir avec PostGIS/QGIS
  en tete plutot qu'en JQML pur.

- **Instruments** (GNSS Bluetooth, stations totales, NTRIP) : chaque
  famille d'appareil deviendra son propre module de connexion quand elle
  sera abordee. Rien n'est cree tant qu'aucun driver n'est implemente.

- **Codification Lahocy / profils clients** : catalogue metier independant
  de la representation AutoCAD. A modeliser plus tard, probablement cote
  QGIS/PostGIS (table de correspondance) plutot que dans le plugin QField
  lui-meme, qui n'a pas besoin de connaitre les profils clients pour
  fonctionner sur le terrain.

## Distribution

Voir [README.md](README.md#mise-a-jour-sur-la-tablette) pour le mecanisme
de release et de mise a jour sur QField Android.
