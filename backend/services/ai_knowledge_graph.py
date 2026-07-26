# -*- coding: utf-8 -*-
"""
ai_knowledge_graph — Sous-graphe des jointures pertinentes pour l'Assistant IA.

Source : la vue `public.ai_table_relationships` (FK du DDIC = sap_table_fields.
check_table, cf. migration 017). Pour une question donnée et les tables retrouvées
par le RAG (ai_schema_retriever), on extrait les ARÊTES entre ces tables — c.-à-d.
les colonnes qui les relient — et on les injecte dans le prompt sous forme dense.

Filtrage « both-in-set » : on ne garde que les jointures dont les DEUX extrémités
sont parmi les tables retrouvées. Cela élimine le bruit des innombrables FK vers
des tables de personnalisation (T006, T163...) non extraites/non pertinentes.

Tolérant aux pannes : si la vue n'existe pas encore (migration non jouée) ou en cas
d'erreur, renvoie '' — le pipeline continue sans sous-graphe.
"""

import logging

from config.database import get_db_connection
from services.ai_rag_budget import get_budget

logger = logging.getLogger(__name__)

# Nombre max d'arêtes injectées (budget tokens) — défaut profil compact.
# La valeur effective vient de get_budget() (compact/large selon le fournisseur).
MAX_EDGES = 8


def _bare(table_qualifie: str) -> str:
    """raw_data.ekpo -> ekpo (nom sans schéma, minuscule)."""
    return table_qualifie.split(".")[-1].strip().lower()


def get_relevant_subgraph(question: str, tables, conn=None) -> str:
    """
    Renvoie un bloc compact des jointures (FK DDIC) entre les `tables` retrouvées.
    `tables` : noms schéma-qualifiés (sortie de retrieve_tables). '' si rien.
    """
    noms = sorted({_bare(t) for t in (tables or []) if t})
    if len(noms) < 2:
        return ""  # pas de jointure possible avec moins de 2 tables
    max_edges = get_budget()["max_edges"]

    if conn is None:
        try:
            with get_db_connection() as c:
                return get_relevant_subgraph(question, tables, c)
        except Exception as e:
            logger.warning(f"⚠️ Sous-graphe indisponible (connexion) : {e}")
            return ""

    sql = """
        SELECT r.src_table, r.src_field, r.dst_table,
               COALESCE(bool_or(f.key_flag), false) AS src_is_key
        FROM public.ai_table_relationships r
        LEFT JOIN public.sap_table_fields f
          ON upper(trim(f.table_name)) = upper(r.src_table)
         AND lower(trim(f.field_name)) = r.src_field
        WHERE r.src_table = ANY(%s) AND r.dst_table = ANY(%s)
        GROUP BY r.src_table, r.src_field, r.dst_table
        ORDER BY r.src_table, r.dst_table, src_is_key DESC, r.src_field
    """
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (noms, noms))
            rows = cur.fetchall()
    except Exception as e:
        logger.warning(f"⚠️ Sous-graphe indisponible (requête) : {e}")
        return ""

    # Une arête par couple (src, dst) : la première = champ-clé préféré (ORDER BY).
    vues, aretes = set(), []
    for src_table, src_field, dst_table, _is_key in rows:
        couple = frozenset((src_table, dst_table))
        if couple in vues:
            continue
        vues.add(couple)
        aretes.append(f"{src_table}.{src_field} -> {dst_table}")
        if len(aretes) >= max_edges:
            break

    # Complément : co-occurrences d'usage (tables souvent jointes ensemble dans les
    # requêtes réussies) NON déjà reliées par une FK DDIC. Best-effort (table 018).
    if len(aretes) < max_edges:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT src_table, dst_table, poids
                    FROM public.ai_table_cooccurrence
                    WHERE src_table = ANY(%s) AND dst_table = ANY(%s)
                    ORDER BY poids DESC
                    """,
                    (noms, noms),
                )
                for src_table, dst_table, poids in cur.fetchall():
                    couple = frozenset((src_table, dst_table))
                    if couple in vues:
                        continue
                    vues.add(couple)
                    aretes.append(f"{src_table} ~ {dst_table} (co-occurrence x{poids})")
                    if len(aretes) >= max_edges:
                        break
        except Exception as e:
            logger.warning(f"⚠️ Co-occurrences indisponibles : {e}")

    if not aretes:
        return ""
    return " ; ".join(aretes)


if __name__ == "__main__":
    # Test autonome (serveur) :
    #   python -m services.ai_knowledge_graph
    logging.basicConfig(level=logging.INFO)
    demo = ["raw_data.ekko", "raw_data.ekpo", "raw_data.mara", "raw_data.mard", "raw_data.marc"]
    print(get_relevant_subgraph("commandes et stock", demo))
