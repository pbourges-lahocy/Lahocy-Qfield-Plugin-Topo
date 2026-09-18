# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [0.6.0] - 2026-09-18

### Modifié

- **Nouvelle interface** en trois zones, propre au plugin : barre du haut (source de mesure GNSS / station avec qualité et verrouillage, hauteur de canne ou de prisme, accès station / carnet / implantation / détecteur / paramètres / mode bureau), barre du bas (consigne, confirmation des clics, annuler, continuer, attente, supprimer, relance du plan, où suis-je, zoom, dernier point mesuré), panneau latéral réduit au levé (palette, dessin, mesure, objets actifs) et repliable.
- Palette sur 4 colonnes avec icônes de famille redessinées ; la sous-palette remplace la palette dans le panneau (retour par flèche) avec le nom de chaque objet ; **recherche d'un objet par son nom** dans tout le catalogue.
- Jeu d'icônes monochromes de l'interface (`plugin/theme/ui`, généré par `tools/make_ui_icons.py`, variantes sombre et blanche) à la place des pictogrammes emoji.
- Bouton Mesurer unique coloré par la qualité, STOP, point unique et dernier point ; objets actifs en liste.

## [0.5.3] - 2026-09-18

### Corrigé

- Verrouillage prisme : le mode « lock » de l'ATR (`AUS_SetUserLockState`) est activé à la connexion et avant `AUT_LockIn` ; sans lui, la station trouvait le prisme (recherche spirale) mais refusait le verrouillage et le plugin repassait « prisme perdu » après une seconde. L'état verrouillé accepte aussi le mode prédiction et n'est déclaré perdu qu'après 1,5 s de lectures consécutives.
- La mesure sur prisme reste possible sans verrouillage (visée ATR) : le bouton passe orange au lieu de gris.

## [0.5.2] - 2026-09-18

### Corrigé

- GeoCOM : les codes retour TMC 1280 à 1284 (mesure sans correction complète, précision non garantie, angles seuls) sont des avertissements et non des erreurs : les angles sont acceptés et l'avertissement est remonté (`warn`) dans l'application compagnon, le pont Python et le plugin. Première liaison réelle validée avec une TS15 (code 1283 : instrument non calé).
- Libellés lisibles pour les codes GeoCOM courants (licence, pas de signal, aucune cible, moteur…).

## [0.5.1] - 2026-09-18

### Ajouté

- Application compagnon Android **Lahocy Topo Link** (`companion/`, Kotlin) : liaison Bluetooth avec la station totale (GeoCOM sur SPP), le DISTO (BLE) et le détecteur (SPP), même contrat HTTP local que le pont Python ; écran de test de liaison ; service de premier plan. Publiée dans la release (`lahocy-topolink.apk`, signée par les secrets `TOPOLINK_*`) et compilée à chaque modification (`companion-ci.yml`).

### Modifié

- Menu station : indication du champ port (COM ou nom Bluetooth ; vide = station choisie dans l'application compagnon).
- Documentation : installation Android, deux implémentations du pont.

## [0.5.0] - 2026-09-18

### Modifié

- Renommage complet : plus aucune référence au logiciel de levé précédent dans le code, les fichiers, les couches (`topo_param`), le projet (`LahocyTopo`), le pont (`topo_bridge.py`, asset `lahocy-bridge.zip`) et la documentation. Historique git réinitialisé, anciennes releases supprimées.
- Composants QML renommés `Topo*` (dossier `plugin/topo`).

### Ajouté

- `bridge/geocom_test.py` : test autonome de la liaison GeoCOM avec une station totale (port COM, nom d'instrument, angles, mesure), à passer avant toute utilisation dans QField.
- Note d'architecture sur la connexion directe des appareils dans QField (Android) : options et plan.

## [0.4.2] - 2026-09-17

### Corrigé

- Consigne d'excentrement TPS effacée une fois le point construit.
- Libellés de la levée d'ambiguïté (plus de « Texte Texte … », contenu du texte affiché).

### Ajouté

- `tests/run_tests.cmd` : 30 tests unitaires des calculs (excentrements, arcs, réduction polaire, double retournement, station libre, relèvement, GSI) exécutés avec le runtime Qt d'OSGeo4W.

### Validé sur QField Windows

- Symbole 1 point, texte avec saisie, excentrement par rapport à la station, « Continuer » (reprise par la fin), « Supprimer » avec levée d'ambiguïté, paramètres et seuils GNSS, gestionnaire d'implantation.

## [0.4.1] - 2026-09-17

### Corrigé (premiers tests réels sur QField Windows 4.3.3)

- Conflits avec des propriétés/signaux réservés des Item QML : `data` → `db`, `layer()` → `getLayer()`, `stateChanged` → `uiChanged`, id `palette` → `pal`, `enabled` du client pont → `polling`.
- Le catalogue est maintenant un module JavaScript embarqué (`theme/theme.js`, généré avec `theme.json`) : QField interdit `XMLHttpRequest` sur les fichiers locaux et `readFileContent` hors du dossier projet.
- Itération sans filtre quand l'expression est vide (le carnet listait 0 point).
- Le client du pont ne rejoue plus l'historique des événements au démarrage.
- Titre des sous-palettes sans le préfixe « Cat ».

### Validé sur QField Windows

- Palette / sous-palettes, activation d'un linéaire, 3 mesures GNSS (récepteur fichier NMEA RTK), STOP, zoom, carnet de terrain, mise en station sur point connu (confirmation de clic en mode terrain), bascule TPS, 3 mesures au simulateur de station (calculs polaires vérifiés), deuxième linéaire.

## [0.4.0] - 2026-09-17

### Réécriture complète « Lahocy Topo »

- Nouvelle base : palette / sous-palettes issues du thème Sbaa (`plugin/theme`), boîte mesure et dessin, objets actifs multiples, linéaires ligne / arc 3 pts / arc 2 pts / courbe, multilignes, rectangles / cercles, symboles 1-2-3 points, textes, entrées, escaliers, talus.
- Excentrements GNSS (point, perpendiculaire précédent / suivant, vertical, milieu, deux distances) et TPS (station, distance / recouvrement, vertical par angle V).
- Carnet de terrain (filtres, zoom, hauteur de canne, Z significatif, suppression, export XYZ / CSV) et carnet polaire (export GSI / CSV).
- Implantation de points avec guidage et rapport.
- Menu station : mise en station (coordonnées, point connu, clic libre, visée avant, changement), visées de référence, station libre par moindres carrés, pilotage (PowerSearch, spirale, joystick, relockage dans le plan).
- Détection : saisie manuelle de profondeur → point TN + point excentré vertical.
- Modèle de données GeoPackage (`project/LahocyTopo`) : pt_topo, station, visee, lineaire, surface, symbole, texte, entree, talus, implantation, topo_param.
- Pont local Python (`bridge/`) : simulateur (testé), Leica GeoCOM, disto BLE, détecteur série (à valider sur matériel).
- Panneau latéral en Popup non modal (leçon du POC Android).

### Historique du POC (0.1.0 → 0.3.9)

#### [0.3.9] - 2026-09-15

### Debug temporaire

- Ajout de `MinimalTestScreen.qml` ("Test minimal" dans le menu) : un seul bouton, un seul Label, dans une vraie `Dialog` (meme mecanisme que Diagnostic/Leve qui fonctionnent). Objectif : determiner si le probleme de rafraichissement touche absolument tout le plugin, y compris le cas le plus simple possible, ou seulement la palette.

#### [0.3.8] - 2026-09-15

### Debug temporaire

- Le point clignote (rendu actif confirme) mais l'ecran ne change toujours pas : la theorie "boucle de rendu endormie" est donc fausse. Remise du label de debug texte (`DEBUG cat=... code=...`), en permanence visible en haut du panneau, pendant que l'animation tourne : si meme ce texte ne se met pas a jour malgre un rendu actif prouve, le probleme n'est pas le repaint mais la reevaluation du binding lui-meme.

#### [0.3.7] - 2026-09-15

### Debug temporaire

- `iface.logMessage()` (silencieux) ne force pas non plus le redessin, contrairement au toast - ce qui n'est donc pas "n'importe quel appel natif" mais quelque chose lie a l'affichage visuel du toast lui-meme. Test suivant : un petit point clignotant (animation d'opacite en boucle infinie) en haut du panneau, actif tant que celui-ci est ouvert - si une animation active en continu maintient la boucle de rendu "eveillee", nos changements d'etat pourraient enfin s'afficher pendant qu'elle tourne.

#### [0.3.6] - 2026-09-14

### Debug temporaire

- Le test "dossier neuf" (cachetest) n'a rien change : le probleme n'est pas un cache. Hypothese actuelle : QField utilise une boucle de rendu specifique pour le canvas carte (economie de batterie) qui semble egalement regir le reste de la fenetre, et nos changements d'etat internes ne declenchent pas ce cycle - seul un evenement natif QField (toast) le fait. Test : `iface.logMessage(...)` (ecriture silencieuse dans le journal, sans popup visible) a la place du toast, pour voir si un evenement natif SANS affichage visible suffit aussi a forcer le redessin.

#### [0.3.5] - 2026-09-14

### Corrige

- Les panneaux haut/bas/droite passaient sous la barre d'etat Android et les boutons de navigation systeme (visible sur capture). Utilisation de `mainWindow.sceneTopMargin` / `sceneBottomMargin` / `sceneRightMargin` (proprietes QField refletant la zone sure du systeme) pour positionner les 3 panneaux correctement, quel que soit l'appareil.

#### [0.3.4] - 2026-09-14

### Corrige

- Diagnostic complet obtenu : la propriete `selectedCategoryIndex` se met bien a jour au clic (confirme via toast affichant 0/1/2/3), mais AUCUN element visuel du panneau ne se repeint jamais tout seul - ni le texte de debug, ni les ecrans en opacite/visible. Le micro-animation de la 0.3.3 n'aurait pas suffi non plus (le probleme touche aussi un simple binding de texte, pas seulement opacity/visible).
- Nos autres ecrans qui fonctionnent de facon fiable (Diagnostic, Leve, menu d'accueil) sont tous des `Dialog`, geres par le systeme d'Overlay natif de QtQuick Controls. La palette etait un simple `Item` reparente a la main, en dehors de ce systeme. Reecriture complete en `Popup` non modal (`modal: false`, `closePolicy: Popup.NoAutoClose`, ancre a droite via x/y/height) : meme mecanisme de rendu fiable que les Dialog, sans bloquer la carte ni se fermer tout seul.

#### [0.3.3] - 2026-09-14

### Corrige

- Le debug confirme un scenario precis : le 1er tap fonctionne (l'etat interne change et l'ecran categories devient bien `enabled: false`), mais le repaint visuel ne se fait pas - l'ecran categories reste affiche a l'identique, donc les taps suivants atterrissent sur des boutons desormais desactives, d'ou "plus rien ne se passe" apres le premier tap. Ajout d'un `Behavior on opacity` (micro-animation 80ms) sur les 3 ecrans : une animation force toujours un vrai repaint frame par frame, contrairement a un changement de propriete instantane qui semble etre saute par le moteur de rendu sur cet appareil.

#### [0.3.2] - 2026-09-14

### Corrige

- Preuve obtenue via le label de debug (v0.3.1) : `selectedCategoryIndex` se met bien a jour au clic, mais l'ecran ne changeait jamais visuellement malgre `visible: <expression>` correcte - sur cet appareil, un item qui passe invisible/visible en superposition exacte avec un autre ne semble pas provoquer de reel repaint. Remplace `visible` par `opacity: 0/1` + `enabled` sur les 3 ecrans, qui force un repaint reel (contrairement a `visible`, `opacity` modifie le noeud de rendu directement).

#### [0.3.1] - 2026-09-14

### Debug temporaire

- La grille de categories s'affiche desormais (confirme par l'utilisateur), mais taper sur une categorie ne fait toujours rien. Ajout d'un label de debug permanent (visible en permanence, pas un toast) affichant `selectedCategoryIndex` et `selectedCode` en temps reel, pour voir directement si le clic met a jour l'etat ou non, sans avoir a capter un message qui disparait.

#### [0.3.0] - 2026-09-14

### Corrige

- La grille de categories restait toujours vide malgre le correctif de largeur (v0.2.9). Reecriture complete de la navigation de la palette : abandon de `ScrollView` + `StackLayout`/`Loader` au profit de 3 blocs `anchors.fill: parent` bascules par `visible`, directement enfants d'une zone de contenu elle-meme ancree. Chaque ecran a desormais une geometrie explicite des sa creation, sans dependre d'un calcul de taille en chaine (Layout dans ScrollView dans Loader). C'est la structure la plus simple et la plus directe testee jusqu'ici pour ce panneau.

#### [0.2.9] - 2026-09-14

### Corrige

- Apres le passage au `Loader` (v0.2.8), le titre "Categories" s'affichait mais la grille de boutons restait invisible : le `ColumnLayout` charge par le `Loader` n'avait pas de largeur explicite, donc ses enfants en `Layout.fillWidth` se retrouvaient a largeur nulle. Ajout de `width: parent.width` sur le `ColumnLayout` racine des 3 ecrans.

#### [0.2.8] - 2026-09-14

### Corrige

- La v0.2.7 (sans debug) restait bloquee sur l'ecran des categories sur tablette, alors que la v0.2.6 (avec toasts de debug) fonctionnait avec un code par ailleurs identique. Hypothese : le `StackLayout` changeait bien d'etat en interne, mais l'ecran ne se repeignait pas sur cet appareil sans l'effet de bord visuel des toasts. Remplace par un `Loader` qui charge un `Component` different par ecran (Categories/Codes/Pose) : detruire et recreer l'ecran a chaque changement force un vrai repaint, plus fiable que de simplement basculer l'ecran courant d'un `StackLayout`.

#### [0.2.7] - 2026-09-14

### Corrige

- Navigation de la palette confirmee fonctionnelle sur tablette avec le build de debug v0.2.6 (memes changements que la v0.2.5, plus instrumentation). La panne rapportee sur la v0.2.5 etait donc probablement un souci d'installation/cache et non un bug du `StackLayout`. Retrait des toasts et du titre de debug.

#### [0.2.6] - 2026-09-14

### Debug temporaire

- Le correctif StackLayout de la v0.2.5 ne resout pas le probleme sur tablette (confirme par l'utilisateur, version bien a jour, app redemarree). Remise de toasts de debug plus detailles (valeur de `selectedCategoryIndex` avant/apres clic, valeur de `currentIndex` du StackLayout, index affiche directement dans le titre "Categories") pour localiser precisement ou ca casse sur cet appareil.

#### [0.2.5] - 2026-09-13

### Corrige

- La palette ne changeait pas d'ecran en tapant sur une categorie : le clic etait bien recu (confirme par debug), mais alterner `visible` sur 3 `ColumnLayout` freres a l'interieur d'un `ScrollView` ne redeclenchait pas correctement l'affichage. Remplace par un `StackLayout` (l'outil concu pour "un seul ecran visible a la fois"), plus robuste. Retrait des toasts de debug.

#### [0.2.4] - 2026-09-13

### Debug temporaire

- Ajout de toasts "DEBUG: ..." sur les boutons de categorie et de fermeture de la palette, pour diagnostiquer un rapport terrain ou tapoter sur "Reseaux"/"Voirie" ne provoquait aucun changement visible. A retirer une fois la cause identifiee.

#### [0.2.3] - 2026-09-13

### Ajoute

- Excentrement fonctionnel dans la palette (mode 1 pt) : gisement + distance depuis la position actuelle, calcule via `TopoEngine.polarPoint` (le meme moteur que le leve polaire).

### Corrige

- Le bouton "X" du panneau palette ferme maintenant aussi les panneaux haut/bas de test (auparavant seul le panneau de droite se fermait).

#### [0.2.2] - 2026-09-13

### Ajoute

- `TopBarPanel.qml` et `BottomBarPanel.qml` : panneaux de test ancres en haut et en bas de l'ecran, affiches en meme temps que la palette (droite) via l'entree de menu "Palette (test)", pour juger si 3 panneaux ancres simultanement restent utilisables.

### Note technique

- `mapCanvas` expose des proprietes `rightMargin`/`bottomMargin` reglables pour reserver de l'espace (pas de survol), mais aucune `topMargin`. Les modifier depuis un plugin ecraserait le binding interne de QField pour ses propres tiroirs - non fait pour l'instant, les 3 panneaux restent en survol.

#### [0.2.1] - 2026-09-13

### Modifie

- `PaletteScreen.qml` retravaille en panneau ancre a droite de l'ecran (non modal) au lieu d'une Dialog. Le panneau reste ouvert en permanence pendant qu'on continue a naviguer sur la carte, comme la palette du logiciel de référence - plus besoin de rouvrir une popup a chaque point leve. Le menu "Palette (test)" bascule maintenant sa visibilite au lieu de l'ouvrir/fermer.

#### [0.2.0] - 2026-09-13

### Ajoute

- `PaletteScreen.qml` : prototype d'interaction "palette a 2 niveaux" (categories -> sous-palette de codes -> pose du point), inspire du fonctionnement reel du logiciel de référence. Catalogue d'exemple (pas le catalogue Lahocy definitif). Accessible temporairement via l'entree de menu "Palette (test)".
- Mode "1 pt" fonctionnel : leve le point a la position GNSS actuelle et l'ajoute a la couche ponctuelle active (formulaire QField standard pour validation), avec tentative de renseignement d'un champ "code" si la couche en possede un.
- Modes "2 pts"/"3 pts" et excentrement : presents dans l'interface mais non cables (a developper).

#### [0.1.1] - 2026-09-13

### Corrige

- `PolarSurveyScreen.qml` : la propriete `result` etait un nom reserve (FINAL) sur `Dialog` dans QField, provoquant l'erreur "Type ... unavailable / Cannot override FINAL property" a l'ouverture de l'ecran Leve. Renommee en `computedPoint`.
- `DiagnosticScreen.qml` : utilisait `Theme.gray` sans faire `import Theme`, ce qui aurait fait echouer l'ecran Diagnostic a l'ouverture.

#### [0.1.0] - 2026-09-13

### Ajoute

- Structure initiale du plugin QField "Lahocy Topo".
- Ecran d'accueil avec menu : GNSS, Station totale, Leve, Implantation, Polygonale, Appareils, Diagnostic (les entrees non developpees affichent "a venir").
- Ecran de diagnostic QField/GNSS affichant les proprietes reellement exposees par `iface.positioning()` et sa `positionInformation`.
- Calcul topo polaire (station connue + gisement en gon + distance horizontale -> coordonnees du point), avec creation du point dans la couche ponctuelle active de QField.
- Workflow GitHub Actions publiant automatiquement une release installable a chaque tag `vX.Y.Z`.
