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
    └── PolarSurveyScreen.qml # leve polaire (POC)
```

Cette structure reste volontairement plate : on ajoute un fichier quand une
fonctionnalite existe reellement, pas avant. Pas de dossiers vides.

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
