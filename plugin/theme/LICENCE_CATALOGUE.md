# Catalogue d'objets : standard topographique régional GéoBretagne

Le catalogue (`theme.json`, `theme.js`) et les icônes (`icons/`) sont dérivés du
**standard topographique régional** publié par GéoBretagne et ses partenaires
(pôle métier Référentiel topographique, service topographie de Lorient Agglomération) :

- dépôt : https://github.com/geobretagne/standard-topographique
- version utilisée : 2.0.6 (archive `geobretagne_standard_topographique_2_0_6`)
- licence : GNU General Public License v3.0

Les icônes sont des recadrages des vignettes JPG de la nomenclature ; les règles de levé
proviennent du carnet des objets (DOCX) ; les attributs proviennent des blocs du DXF de
nomenclature. La conversion est faite par `tools/geobretagne_to_theme.py`.

Ces fichiers sont redistribués sous la même licence (GPL-3.0). Toute modification du
catalogue doit se faire dans le standard amont ou dans `tools/geobretagne_rules.json`,
puis régénération.
