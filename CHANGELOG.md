# Changelog

Toutes les versions notables du plugin sont documentees ici.
Format inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

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
