.pragma library

// Moteur de calcul topo. Aucune dependance QML/UI ici : ce fichier ne
// contient que des fonctions pures, testables independamment de QField.

/**
 * Calcul polaire (rayonnement) : coordonnees d'un point vise depuis une
 * station connue, a partir d'un gisement (en gon, 0-400) et d'une distance
 * horizontale.
 *
 * Convention francaise : gisement compte depuis le Nord (axe Y), dans le
 * sens horaire. X = Est, Y = Nord.
 *
 * @param {number} xStation
 * @param {number} yStation
 * @param {number} gisementGon
 * @param {number} distanceHz
 * @returns {{x: number, y: number}}
 */
function polarPoint(xStation, yStation, gisementGon, distanceHz) {
    var gisementRad = gisementGon * (Math.PI / 200);
    return {
        x: xStation + distanceHz * Math.sin(gisementRad),
        y: yStation + distanceHz * Math.cos(gisementRad)
    };
}

/**
 * Valide qu'une chaine represente un nombre fini (utilise pour la
 * validation des champs de saisie avant calcul).
 */
function isValidNumber(text) {
    if (text === undefined || text === null || text === "") {
        return false;
    }
    var value = Number(text);
    return !isNaN(value) && isFinite(value);
}
