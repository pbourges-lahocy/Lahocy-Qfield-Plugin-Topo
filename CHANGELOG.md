# Changelog

Toutes les versions notables du plugin sont documentees ici.
Format inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [0.3.5] - 2026-09-14

### Corrige

- Les panneaux haut/bas/droite passaient sous la barre d'etat Android et les boutons de navigation systeme (visible sur capture). Utilisation de `mainWindow.sceneTopMargin` / `sceneBottomMargin` / `sceneRightMargin` (proprietes QField refletant la zone sure du systeme) pour positionner les 3 panneaux correctement, quel que soit l'appareil.

## [0.3.4] - 2026-09-14

### Corrige

- Diagnostic complet obtenu : la propriete `selectedCategoryIndex` se met bien a jour au clic (confirme via toast affichant 0/1/2/3), mais AUCUN element visuel du panneau ne se repeint jamais tout seul - ni le texte de debug, ni les ecrans en opacite/visible. Le micro-animation de la 0.3.3 n'aurait pas suffi non plus (le probleme touche aussi un simple binding de texte, pas seulement opacity/visible).
- Nos autres ecrans qui fonctionnent de facon fiable (Diagnostic, Leve, menu d'accueil) sont tous des `Dialog`, geres par le systeme d'Overlay natif de QtQuick Controls. La palette etait un simple `Item` reparente a la main, en dehors de ce systeme. Reecriture complete en `Popup` non modal (`modal: false`, `closePolicy: Popup.NoAutoClose`, ancre a droite via x/y/height) : meme mecanisme de rendu fiable que les Dialog, sans bloquer la carte ni se fermer tout seul.

## [0.3.3] - 2026-09-14

### Corrige

- Le debug confirme un scenario precis : le 1er tap fonctionne (l'etat interne change et l'ecran categories devient bien `enabled: false`), mais le repaint visuel ne se fait pas - l'ecran categories reste affiche a l'identique, donc les taps suivants atterrissent sur des boutons desormais desactives, d'ou "plus rien ne se passe" apres le premier tap. Ajout d'un `Behavior on opacity` (micro-animation 80ms) sur les 3 ecrans : une animation force toujours un vrai repaint frame par frame, contrairement a un changement de propriete instantane qui semble etre saute par le moteur de rendu sur cet appareil.

## [0.3.2] - 2026-09-14

### Corrige

- Preuve obtenue via le label de debug (v0.3.1) : `selectedCategoryIndex` se met bien a jour au clic, mais l'ecran ne changeait jamais visuellement malgre `visible: <expression>` correcte - sur cet appareil, un item qui passe invisible/visible en superposition exacte avec un autre ne semble pas provoquer de reel repaint. Remplace `visible` par `opacity: 0/1` + `enabled` sur les 3 ecrans, qui force un repaint reel (contrairement a `visible`, `opacity` modifie le noeud de rendu directement).

## [0.3.1] - 2026-09-14

### Debug temporaire

- La grille de categories s'affiche desormais (confirme par l'utilisateur), mais taper sur une categorie ne fait toujours rien. Ajout d'un label de debug permanent (visible en permanence, pas un toast) affichant `selectedCategoryIndex` et `selectedCode` en temps reel, pour voir directement si le clic met a jour l'etat ou non, sans avoir a capter un message qui disparait.

## [0.3.0] - 2026-09-14

### Corrige

- La grille de categories restait toujours vide malgre le correctif de largeur (v0.2.9). Reecriture complete de la navigation de la palette : abandon de `ScrollView` + `StackLayout`/`Loader` au profit de 3 blocs `anchors.fill: parent` bascules par `visible`, directement enfants d'une zone de contenu elle-meme ancree. Chaque ecran a desormais une geometrie explicite des sa creation, sans dependre d'un calcul de taille en chaine (Layout dans ScrollView dans Loader). C'est la structure la plus simple et la plus directe testee jusqu'ici pour ce panneau.

## [0.2.9] - 2026-09-14

### Corrige

- Apres le passage au `Loader` (v0.2.8), le titre "Categories" s'affichait mais la grille de boutons restait invisible : le `ColumnLayout` charge par le `Loader` n'avait pas de largeur explicite, donc ses enfants en `Layout.fillWidth` se retrouvaient a largeur nulle. Ajout de `width: parent.width` sur le `ColumnLayout` racine des 3 ecrans.

## [0.2.8] - 2026-09-14

### Corrige

- La v0.2.7 (sans debug) restait bloquee sur l'ecran des categories sur tablette, alors que la v0.2.6 (avec toasts de debug) fonctionnait avec un code par ailleurs identique. Hypothese : le `StackLayout` changeait bien d'etat en interne, mais l'ecran ne se repeignait pas sur cet appareil sans l'effet de bord visuel des toasts. Remplace par un `Loader` qui charge un `Component` different par ecran (Categories/Codes/Pose) : detruire et recreer l'ecran a chaque changement force un vrai repaint, plus fiable que de simplement basculer l'ecran courant d'un `StackLayout`.

## [0.2.7] - 2026-09-14

### Corrige

- Navigation de la palette confirmee fonctionnelle sur tablette avec le build de debug v0.2.6 (memes changements que la v0.2.5, plus instrumentation). La panne rapportee sur la v0.2.5 etait donc probablement un souci d'installation/cache et non un bug du `StackLayout`. Retrait des toasts et du titre de debug.

## [0.2.6] - 2026-09-14

### Debug temporaire

- Le correctif StackLayout de la v0.2.5 ne resout pas le probleme sur tablette (confirme par l'utilisateur, version bien a jour, app redemarree). Remise de toasts de debug plus detailles (valeur de `selectedCategoryIndex` avant/apres clic, valeur de `currentIndex` du StackLayout, index affiche directement dans le titre "Categories") pour localiser precisement ou ca casse sur cet appareil.

## [0.2.5] - 2026-09-13

### Corrige

- La palette ne changeait pas d'ecran en tapant sur une categorie : le clic etait bien recu (confirme par debug), mais alterner `visible` sur 3 `ColumnLayout` freres a l'interieur d'un `ScrollView` ne redeclenchait pas correctement l'affichage. Remplace par un `StackLayout` (l'outil concu pour "un seul ecran visible a la fois"), plus robuste. Retrait des toasts de debug.

## [0.2.4] - 2026-09-13

### Debug temporaire

- Ajout de toasts "DEBUG: ..." sur les boutons de categorie et de fermeture de la palette, pour diagnostiquer un rapport terrain ou tapoter sur "Reseaux"/"Voirie" ne provoquait aucun changement visible. A retirer une fois la cause identifiee.

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
