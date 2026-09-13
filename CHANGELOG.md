# Changelog

Toutes les versions notables du plugin sont documentees ici.
Format inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [0.1.0] - 2026-09-13

### Ajoute

- Structure initiale du plugin QField "Lahocy Topo".
- Ecran d'accueil avec menu : GNSS, Station totale, Leve, Implantation, Polygonale, Appareils, Diagnostic (les entrees non developpees affichent "a venir").
- Ecran de diagnostic QField/GNSS affichant les proprietes reellement exposees par `iface.positioning()` et sa `positionInformation`.
- Calcul topo polaire (station connue + gisement en gon + distance horizontale -> coordonnees du point), avec creation du point dans la couche ponctuelle active de QField.
- Workflow GitHub Actions publiant automatiquement une release installable a chaque tag `vX.Y.Z`.
