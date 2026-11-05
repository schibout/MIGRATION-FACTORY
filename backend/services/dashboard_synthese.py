"""Calculs du tableau de bord, sans base : statuts d'extraction, ecarts et series des controles.

Une mesure est un dictionnaire jour / ecran / code / label / anomalies ; anomalies None = controle non
calculable, jamais assimile a 0.
"""
from datetime import timedelta

A_TRAITER_MAX = 8


def statut_extraction(statut, ancien):
    """Statut lisible ; `ancien` : commence depuis plus de 24 h, donc un job jamais clos et non « en cours »."""
    s = (statut or '').lower()
    if s == 'completed':
        return 'reussie'
    if s == 'completed_with_errors':
        return 'avec_erreurs'
    if s == 'cancelled':
        return 'annulee'
    if s in ('running', 'pending'):
        return 'interrompue' if ancien else 'en_cours'
    return 'echec'


def mois_glissants(aujourdhui, n=6):
    """Les n derniers mois 'AAAA-MM', du plus ancien au mois courant."""
    total = aujourdhui.year * 12 + aujourdhui.month - 1
    return [f'{m // 12:04d}-{m % 12 + 1:02d}' for m in range(total - n + 1, total + 1)]


def _ecart(actuel, reference, cles):
    """Ecart sur les controles mesures aux deux dates : un controle nouveau ou en erreur n'est pas une variation."""
    if reference is None:
        return None
    communs = [k for k in cles if actuel[k] is not None and reference.get(k) is not None]
    return sum(actuel[k] - reference[k] for k in communs) if communs else None


def synthese(lignes):
    """(domaines par ecran, anomalies a traiter, historique par jour et ecran) depuis les mesures."""
    par_jour = {}
    infos = {}
    for m in lignes:
        par_jour.setdefault(m['jour'], {})[m['ecran'], m['code']] = m['anomalies']
        infos[m['ecran'], m['code']] = m['label']
    if not par_jour:
        return {}, [], []

    jours = sorted(par_jour)
    actuel = par_jour[jours[-1]]
    precedent = par_jour[jours[-2]] if len(jours) > 1 else None
    limite_7j = jours[-1] - timedelta(days=7)
    semaine = next((par_jour[j] for j in reversed(jours) if j <= limite_7j), None)

    domaines = {}
    for ecran in {e for e, _ in actuel}:
        cles = [k for k in actuel if k[0] == ecran]
        valeurs = [k for k in cles if actuel[k] is not None]
        ko = [k for k in valeurs if actuel[k] > 0]
        pire = max(ko, key=lambda k: actuel[k], default=None)
        domaines[ecran] = {
            'controles': len(cles),
            'ko': len(ko),
            'en_erreur': len(cles) - len(valeurs),
            'anomalies': sum(actuel[k] for k in valeurs),
            'delta_precedent': _ecart(actuel, precedent, cles),
            'delta_7j': _ecart(actuel, semaine, cles),
            'principale': {'label': infos[pire], 'n': actuel[pire]} if pire else None,
        }

    a_traiter = [{'ecran': k[0], 'code': k[1], 'label': infos[k], 'n': actuel[k],
                  'delta': _ecart(actuel, precedent, [k])}
                 for k in actuel if actuel[k]]
    a_traiter.sort(key=lambda a: (-max(a['delta'] or 0, 0), -a['n'], a['code']))

    historique = []
    for jour in jours:
        for ecran in sorted({e for e, _ in par_jour[jour]}):
            valeurs = [n for k, n in par_jour[jour].items() if k[0] == ecran and n is not None]
            historique.append({'jour': jour.isoformat(), 'ecran': ecran, 'ko': sum(n > 0 for n in valeurs),
                               'anomalies': sum(valeurs)})
    return domaines, a_traiter[:A_TRAITER_MAX], historique


def series_controles(lignes, ecran, limite=6):
    """Courbes d'un ecran : les `limite` controles les plus lourds (derniere valeur), tries par code pour que
    chacun garde sa couleur ; `masques` compte les autres controles ayant eu des anomalies."""
    series = {}
    derniere = {}
    for m in sorted((m for m in lignes if m['ecran'] == ecran), key=lambda m: m['jour']):
        serie = series.setdefault(m['code'], {'code': m['code'], 'label': m['label'], 'points': []})
        serie['label'] = m['label']
        serie['points'].append({'jour': m['jour'].isoformat(), 'n': m['anomalies']})
        derniere[m['code']] = m['anomalies'] or 0
    utiles = [c for c, s in series.items() if any(p['n'] for p in s['points'])]
    utiles.sort(key=lambda c: (-derniere[c], c))
    return {'series': [series[c] for c in sorted(utiles[:limite])], 'masques': max(len(utiles) - limite, 0)}
