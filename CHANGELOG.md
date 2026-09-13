# Changelog

Toutes les versions notables du plugin sont documentees ici.
Format inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [0.2.3] - 2026-09-13

### Ajoute

- Excentrement fonctionnel dans la palette (mode 1 pt) : gisement + distance depuis la position actuelle, calcule via `TopoEngine.polarPoint` (le meme moteur que le leve polaire).

### Corrige

- Le bouton "X" du panneau palette ferme maintenant aussi les panneaux haut/bas de test (auparavant seul le panneau de droite se fermait).

## [0.2.2] - 2026-09-13

### Ajoute

- `TopBarPanel.qml` et `BottomBarPanel.qml` : panneaux de test ancres en haut et en bas de l'ecran, affiches en meme temps que la palette (droite) via l'entree de menu "Palette (test)", pour juger si 3 panneaux ancres simultanement restent utilisables.

### Note technique

- `mapCanvas` expose des proprietes `rightMargin`/`bottomMargin` reglables pour reserver de l'espace (pas de survol), mais aucune `topMargin`. Les modifier depuis un plugin ecraserait le binding interne de QField pour ses propres tiroirs - non fait pour l'instant, les 3 panneaux restent en survol.

## [0.2.1] - 2026-09-13

### Modifie

- `PaletteScreen.qml` retravaille en panneau ancre a droite de l'ecran (non modal) au lieu d'une Dialog. Le panneau reste ouvert en permanence pendant qu'on continue a naviguer sur la carte, comme la palette de Land2Map - plus besoin de rouvrir une popup a chaque point leve. Le menu "Palette (test)" bascule maintenant sa visibilite au lieu de l'ouvrir/fermer.

## [0.2.0] - 2026-09-13

### Ajoute

- `PaletteScreen.qml` : prototype d'interaction "palette a 2 niveaux" (categories -> sous-palette de codes -> pose du point), inspire du fonctionnement reel de Land2Map. Catalogue d'exemple (pas le catalogue Lahocy definitif). Accessible temporairement via l'entree de menu "Palette (test)".
- Mode "1 pt" fonctionnel : leve le point a la position GNSS actuelle et l'ajoute a la couche ponctuelle active (formulaire QField standard pour validation), avec tentative de renseignement d'un champ "code" si la couche en possede un.
- Modes "2 pts"/"3 pts" et excentrement : presents dans l'interface mais non cables (a developper).

## [0.1.1] - 2026-09-13

### Corrige

- `PolarSurveyScreen.qml` : la propriete `result` etait un nom reserve (FINAL) sur `Dialog` dans QField, provoquant l'erreur "Type ... unavailable / Cannot override FINAL property" a l'ouverture de l'ecran Leve. Renommee en `computedPoint`.
- `DiagnosticScreen.qml` : utilisait `Theme.gray` sans faire `import Theme`, ce qui aurait fait echouer l'ecran Diagnostic a l'ouverture.

## [0.1.0] - 2026-09-13

### Ajoute

- Structure initiale du plugin QField "Lahocy Topo".
- Ecran d'accueil avec menu : GNSS, Station totale, Leve, Implantation, Polygonale, Appareils, Diagnostic (les entrees non developpees affichent "a venir").
- Ecran de diagnostic QField/GNSS affichant les proprietes reellement exposees par `iface.positioning()` et sa `positionInformation`.
- Calcul topo polaire (station connue + gisement en gon + distance horizontale -> coordonnees du point), avec creation du point dans la couche ponctuelle active de QField.
- Workflow GitHub Actions publiant automatiquement une release installable a chaque tag `vX.Y.Z`.
