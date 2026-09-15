"""
Parsing des fichiers CSV PE Tools ("PeTool - 7.<CODE>.csv") vers les colonnes
de raw_data.pe_tools.

Module pur : ni Flask ni base, pour etre testable seul. La logique (encodage
cp850, cle de rapprochement sans accents, reparation des guillemets, surplus de
champs ignore) est reprise du script externe fusion_csv.py qui a servi au
chargement initial de la table.
"""
import csv
import io
import re
import unicodedata
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# (colonne SQL, intitule dans les CSV), dans l'ordre de raw_data.pe_tools.
PE_TOOLS_COLUMNS: List[Tuple[str, str]] = [
    ('localisation_classement',      'Localisation / Classement'),
    ('gamme_en_dms',                 'Gamme en DMS'),
    ('poste_technique',              'Poste technique'),
    ('niveau_sap',                   'Niveau SAP'),
    ('plan_entretien',               'Plan Entretien'),
    ('poste_entretien',              'Poste entretien'),
    ('groupe_de_gamme',              'Groupe de Gamme'),
    ('compteur_de_gamme',            'Compteur de Gamme'),
    ('frequence',                    'Frequence'),
    ('designation',                  'Désignation'),
    ('type',                         'Type'),
    ('criticite',                    'Criticité'),
    ('parite_semaine',               'Parité semaine'),
    ('jour',                         'Jour'),
    ('decalage',                     'Décal.'),
    ('date_validation',              'Date de validation'),
    ('lien_fichier_gamme_source',    'Lien Fichier de gamme Source'),
    ('lien_fichier_dms_sap_pdf',     'Lien Fichier DMS SAP en PDF'),
    ('dms_sap',                      'DMS_SAP'),
    ('charge',                       'Charge'),
    ('nb_intervenants',              'Nombre intervenants'),
    ('date_rev',                     'Date rév.'),
    ('nb_jours_depuis_derniere_rev', 'Nb jours depuis la dernière rév.'),
]

# Sans ces deux colonnes (noms SQL) le fichier n'est pas un export PE Tools.
COLONNES_OBLIGATOIRES = ('poste_technique', 'plan_entretien')

SEPARATEUR = ';'
BOM_UTF8 = b'\xef\xbb\xbf'


@dataclass
class ParsedFile:
    rows: List[Dict[str, Optional[str]]] = field(default_factory=list)
    missing_columns: List[str] = field(default_factory=list)
    unknown_columns: List[str] = field(default_factory=list)
    repaired_lines: int = 0


def cle(nom: str) -> str:
    """Cle de rapprochement d'un intitule : sans accents, sans casse, espaces
    normalises, ponctuation finale retiree ('Date rév.' == 'DATE  REV')."""
    nom = unicodedata.normalize('NFKD', nom or '')
    nom = ''.join(c for c in nom if not unicodedata.combining(c))
    nom = re.sub(r'\s+', ' ', nom.replace('\n', ' ').replace('\r', ' ')).strip()
    return nom.lower().rstrip(' .:')


def _decoder(content: bytes) -> str:
    # L'export CSV de l'ecran est en UTF-8 (BOM ou non). Un accent cp850
    # (ex. 'e' = 0x82) ne peut jamais demarrer une sequence UTF-8 valide : le
    # decodage UTF-8 echoue donc de maniere fiable sur les vrais exports
    # Excel PE Tools, qui sont en cp850.
    try:
        return content.decode('utf-8-sig')
    except UnicodeDecodeError:
        return content.decode('cp850')


def _lire_lignes(texte: str) -> Tuple[List[List[str]], int]:
    """Parse ligne physique par ligne physique : chaque ligne physique est un
    enregistrement (hypothese reprise du script externe fusion_csv.py qui a
    servi au chargement initial de la table) ; un champ contenant un vrai
    saut de ligne entre guillemets n'est pas supporte.

    Un nombre impair de guillemets sur la ligne (guillemet isole, frequent
    dans les exports Excel PE Tools pour noter des pouces, ex. 12") ferait
    que le lecteur CSV standard avale le reste de la ligne dans un seul
    champ : on reparse alors cette ligne avec QUOTE_NONE, qui traite le
    guillemet comme un caractere litteral et preserve les 23 colonnes."""
    lignes: List[List[str]] = []
    reparees = 0
    for ligne in texte.splitlines():
        if not ligne.strip():
            continue
        if ligne.count('"') % 2:
            lignes.append(next(csv.reader(io.StringIO(ligne), delimiter=SEPARATEUR, quoting=csv.QUOTE_NONE)))
            reparees += 1
        else:
            lignes.append(next(csv.reader(io.StringIO(ligne), delimiter=SEPARATEUR)))
    return lignes, reparees


def parse_pe_tools_csv(content: bytes) -> ParsedFile:
    """Transforme le contenu binaire d'un CSV PE Tools en lignes pretes a
    inserer (cles = colonnes SQL, '' -> None).

    Leve ValueError (message en francais) si le contenu est vide ou si
    l'en-tete ne ressemble pas a un export PE Tools.
    """
    if not content or not content.strip():
        raise ValueError('Fichier vide')

    lignes, reparees = _lire_lignes(_decoder(content))
    if not lignes:
        raise ValueError('Fichier vide')

    entete = [cle(nom) for nom in lignes[0]]
    attendues = {cle(intitule): col_sql for col_sql, intitule in PE_TOOLS_COLUMNS}
    # Accepte aussi en entete les noms de colonnes SQL eux-memes : c'est ce
    # que produit l'export CSV de l'ecran (re-import de son propre export).
    attendues.update({col_sql: col_sql for col_sql, _ in PE_TOOLS_COLUMNS})

    # position dans la ligne -> colonne SQL (les colonnes inconnues et le
    # surplus de champs au-dela de l'en-tete sont ignores)
    position = {i: attendues[k] for i, k in enumerate(entete) if k in attendues}

    colonnes_resolues = set(position.values())
    for col_sql in COLONNES_OBLIGATOIRES:
        if col_sql not in colonnes_resolues:
            intitule = next(lib for c, lib in PE_TOOLS_COLUMNS if c == col_sql)
            raise ValueError(
                f"En-tete non reconnue : colonne « {intitule} » absente "
                f"(le fichier n'est pas un export PE Tools ?)"
            )

    result = ParsedFile(repaired_lines=reparees)
    result.missing_columns = [intitule for col_sql, intitule in PE_TOOLS_COLUMNS if col_sql not in colonnes_resolues]
    result.unknown_columns = [
        nom.strip() for nom in lignes[0] if cle(nom) not in attendues and nom.strip()
    ]

    for champs in lignes[1:]:
        if not any(c.strip() for c in champs):
            continue
        ligne: Dict[str, Optional[str]] = {col_sql: None for col_sql, _ in PE_TOOLS_COLUMNS}
        for i, valeur in enumerate(champs):
            col_sql = position.get(i)
            if col_sql is None:
                continue
            valeur = valeur.strip()
            ligne[col_sql] = valeur if valeur else None
        result.rows.append(ligne)

    return result
