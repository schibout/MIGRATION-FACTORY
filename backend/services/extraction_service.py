import os
import json
import time
import requests
from datetime import datetime
from typing import Dict, List, Optional, Any
import threading
from sqlalchemy import create_engine, text
from flask import current_app

SAP_API_URL = os.environ.get("SAP_EXTRACTION_API_URL", "http://10.190.100.58:8000")
SAP_API_TIMEOUT = int(os.environ.get("SAP_API_TIMEOUT", "10"))

extraction_jobs = {}
extraction_history = []


class ExtractionService:
    """Service d'extraction — proxy vers l'API SAP (Docker sap-extraction)."""

    def __init__(self):
        self.engine = None

    def _ensure_engine(self):
        """Crée le moteur SQLAlchemy si besoin (init blueprint peut avoir échoué)."""
        if self.engine is not None:
            return
        uri = current_app.config.get("SQLALCHEMY_DATABASE_URI")
        if not uri:
            raise RuntimeError("SQLALCHEMY_DATABASE_URI manquant dans la configuration Flask")
        # pool_pre_ping : vérifie la connexion avant usage (évite les
        # "SSL SYSCALL error: EOF detected" sur connexion coupée côté serveur).
        # pool_recycle : recycle les connexions au bout de 30 min.
        self.engine = create_engine(uri, pool_pre_ping=True, pool_recycle=1800)
        self._ensure_tables()

    def initialize(self):
        self._ensure_engine()

    @staticmethod
    def _parse_tables_field(raw) -> List[str]:
        """Colonne extraction_history.tables : JSON ou déjà liste."""
        if raw is None:
            return []
        if isinstance(raw, list):
            return [str(x) for x in raw]
        if not isinstance(raw, str):
            return []
        raw = raw.strip()
        if not raw:
            return []
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [str(x) for x in data]
            return [str(data)] if data is not None else []
        except (json.JSONDecodeError, TypeError):
            return []

    # ── Tables PostgreSQL pour l'historique ──────────────────────────────

    def _ensure_tables(self):
        """Cree les tables d'historique si elles n'existent pas."""
        ddl = text("""
            CREATE TABLE IF NOT EXISTS public.extraction_history (
                job_id          TEXT PRIMARY KEY,
                user_id         TEXT,
                started_at      TIMESTAMP,
                completed_at    TIMESTAMP,
                status          TEXT DEFAULT 'pending',
                tables          TEXT,
                rows_extracted  INTEGER DEFAULT 0,
                extraction_mode TEXT DEFAULT 'standard',
                batch_size      INTEGER DEFAULT 500,
                error_message   TEXT,
                duration_seconds INTEGER
            );
            CREATE TABLE IF NOT EXISTS public.extraction_details (
                id              SERIAL PRIMARY KEY,
                job_id          TEXT REFERENCES public.extraction_history(job_id),
                table_name      TEXT,
                rows_extracted  INTEGER DEFAULT 0,
                start_time      TIMESTAMP,
                end_time        TIMESTAMP,
                status          TEXT DEFAULT 'pending',
                error_message   TEXT
            );
        """)
        try:
            with self.engine.begin() as conn:
                conn.execute(ddl)
        except Exception:
            pass

    # ── Liste des tables (depuis sap_table_properties) ──────────────────

    def get_available_tables(self) -> List[Dict[str, Any]]:
        """Recupere les tables depuis public.sap_table_properties."""
        self._ensure_engine()
        try:
            query = text("""
                SELECT
                    table_name,
                    description,
                    table_class,
                    client_dependent,
                    availableformapping
                FROM public.sap_table_properties
                ORDER BY table_name
            """)
            with self.engine.connect() as conn:
                rows = conn.execute(query).fetchall()
            return [
                {
                    "name": row.table_name,
                    "description": row.description or "",
                    "tableClass": row.table_class or "",
                    "clientDependent": row.client_dependent or False,
                    "availableForMapping": row.availableformapping or False,
                    "disabled": False,
                }
                for row in rows
            ]
        except Exception as e:
            current_app.logger.error(
                f"Erreur lecture sap_table_properties: {e}"
            )
            return []

    # ── Découverte / création de tables (proxy service SAP) ───────────────

    def available_tables(
        self,
        search: Optional[str] = None,
        domaine: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Dict[str, Any]:
        """Recherche les tables SAP transparentes non encore cataloguées.

        Proxy vers GET {SAP_API}/tables/available avec recherche serveur,
        filtre par domaine applicatif et pagination.
        """
        params: Dict[str, Any] = {"limit": limit, "offset": offset}
        if search:
            params["search"] = search
        if domaine:
            params["domaine"] = domaine
        try:
            resp = requests.get(
                f"{SAP_API_URL}/tables/available",
                params=params,
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            current_app.logger.error(f"SAP API /tables/available echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    def extract_metadata(
        self,
        tables: List[str],
        add_to_config: bool = True,
        batch_size: int = 50,
        force: bool = False,
        find_relations: bool = True,
    ) -> Dict[str, Any]:
        """Lance l'extraction des métadonnées SAP des tables choisies.

        Proxy vers POST {SAP_API}/metadata/extract. Extrait la structure via
        DDIF_FIELDINFO_GET (sap_table_fields / sap_table_properties), recherche
        les relations et — si add_to_config — ajoute la table à table_config.py
        ET la crée dans raw_data. S'exécute en job de fond : renvoie un
        metadata_job_id à suivre via metadata_status().
        """
        try:
            resp = requests.post(
                f"{SAP_API_URL}/metadata/extract",
                json={
                    "tables": [t.upper() for t in tables],
                    "add_to_config": add_to_config,
                    "batch_size": batch_size,
                    "force": force,
                    "find_relations": find_relations,
                },
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            current_app.logger.error(f"SAP API /metadata/extract echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    def metadata_status(self, job_id: str) -> Dict[str, Any]:
        """Statut d'un job d'extraction de métadonnées.

        Proxy vers GET {SAP_API}/metadata/status/{job_id}.
        """
        try:
            resp = requests.get(
                f"{SAP_API_URL}/metadata/status/{job_id}",
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            current_app.logger.error(f"SAP API /metadata/status echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    def metadata_jobs(self, limit: int = 30) -> Any:
        """Liste des jobs de métadonnées. Proxy vers GET {SAP_API}/metadata/jobs."""
        try:
            resp = requests.get(
                f"{SAP_API_URL}/metadata/jobs",
                params={"limit": limit},
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            current_app.logger.error(f"SAP API /metadata/jobs echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    def metadata_logs(self, job_id: str, limit: int = 200) -> List[Dict[str, str]]:
        """Logs d'un job de métadonnées. Proxy vers GET {SAP_API}/metadata/jobs/{id}/logs."""
        try:
            resp = requests.get(
                f"{SAP_API_URL}/metadata/jobs/{job_id}/logs",
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            lines = resp.json().get("logs", []) or []
            parsed = [self._parse_log_line(l) for l in lines]
            return parsed[-limit:] if limit else parsed
        except Exception as e:
            current_app.logger.error(f"SAP API /metadata logs echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    def cancel_metadata_job(self, job_id: str) -> Dict[str, Any]:
        """Annule un job de métadonnées. Proxy vers POST {SAP_API}/metadata/jobs/{id}/cancel."""
        try:
            resp = requests.post(
                f"{SAP_API_URL}/metadata/jobs/{job_id}/cancel",
                timeout=max(SAP_API_TIMEOUT, 30),
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            current_app.logger.error(f"SAP API /metadata cancel echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

    # ── Lancement de l'extraction ────────────────────────────────────────

    def start_extraction(
        self,
        tables: List[str],
        options: Dict[str, Any],
        user_id: str,
    ) -> Dict[str, Any]:
        self._ensure_engine()
        now = datetime.now()
        mode = options.get("mode", "standard")
        # L'API :8000 valide mode par regex : standard|debug|complet (pas "complete")
        if mode == "complete":
            mode = "complet"
        batch_size = options.get("batch_size", options.get("batchSize", 500))

        # Contrat API :8000 v2.1.0 : champs PLATS (pas d'objet "options" imbriqué).
        # mode="complet" OU truncate_before=true => extraction complète (TRUNCATE + reload).
        sap_payload = {
            "tables": [t.upper() for t in tables],
            "batch_size": batch_size,
            "row_page_size": options.get("pageSize", options.get("page_size", 5000)),
            "workers": options.get("workers", 4),
            "truncate_before": bool(options.get("clean", False)),
            "mode": mode,
            "user_id": user_id,
        }

        try:
            resp = requests.post(
                f"{SAP_API_URL}/extract",
                json=sap_payload,
                timeout=SAP_API_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            sap_job_id = data["extraction_id"]
            persisted_by_sap = bool(data.get("persisted_db", False))
        except Exception as e:
            current_app.logger.error(f"SAP API /extract echoue: {e}")
            raise RuntimeError(
                f"Impossible de contacter le conteneur SAP ({SAP_API_URL}): {e}"
            ) from e

        if not persisted_by_sap:
            with self.engine.begin() as conn:
                conn.execute(
                    text("""
                INSERT INTO public.extraction_history
                (job_id, user_id, started_at, status, tables,
                 extraction_mode, batch_size)
                VALUES (:job_id, :user_id, :started_at, :status,
                        :tables, :mode, :batch_size)
                """),
                    {
                        "job_id": sap_job_id,
                        "user_id": user_id,
                        "started_at": now,
                        "status": "running",
                        "tables": json.dumps(tables),
                        "mode": mode,
                        "batch_size": batch_size,
                    },
                )
                for table in tables:
                    conn.execute(
                        text("""
                    INSERT INTO public.extraction_details
                    (job_id, table_name, start_time, status)
                    VALUES (:job_id, :table_name, :start_time, :status)
                    """),
                        {
                            "job_id": sap_job_id,
                            "table_name": table,
                            "start_time": now,
                            "status": "pending",
                        },
                    )

            thread = threading.Thread(
                target=self._poll_sap_status,
                args=(sap_job_id,),
                daemon=True,
            )
            thread.start()

        return {"extraction_id": sap_job_id}

    # ── Polling du statut SAP ────────────────────────────────────────────

    def _poll_sap_status(self, job_id: str):
        """Interroge periodiquement l'API SAP et synchronise PostgreSQL."""
        while True:
            time.sleep(5)
            try:
                resp = requests.get(
                    f"{SAP_API_URL}/status/{job_id}",
                    timeout=SAP_API_TIMEOUT,
                )
                if not resp.ok:
                    continue
                data = resp.json()
            except Exception:
                continue

            status = data.get("status", "running")

            try:
                with self.engine.begin() as conn:
                    for td in data.get("tablesDetails", []):
                        conn.execute(
                            text("""
                            UPDATE public.extraction_details
                            SET status = :status,
                                rows_extracted = :rows,
                                end_time = CASE
                                    WHEN :end_time IS NOT NULL
                                         THEN :end_time::timestamp
                                    ELSE end_time END,
                                error_message = :error
                            WHERE job_id = :job_id AND table_name = :table_name
                            """),
                            {
                                "job_id": job_id,
                                "table_name": td["name"],
                                "status": td["status"],
                                "rows": td.get("rows", 0),
                                "end_time": td.get("endTime"),
                                "error": td.get("error"),
                            },
                        )

                    if status in ("completed", "failed", "cancelled"):
                        conn.execute(
                            text("""
                            UPDATE public.extraction_history
                            SET status = :status,
                                completed_at = :completed_at,
                                rows_extracted = :rows,
                                duration_seconds = :duration,
                                error_message = :error
                            WHERE job_id = :job_id
                            """),
                            {
                                "job_id": job_id,
                                "status": status,
                                "completed_at": data.get("completedAt"),
                                "rows": data.get("rowsExtracted", 0),
                                "duration": data.get("duration"),
                                "error": data.get("error"),
                            },
                        )
                    else:
                        conn.execute(
                            text("""
                            UPDATE public.extraction_history
                            SET rows_extracted = :rows
                            WHERE job_id = :job_id
                            """),
                            {
                                "job_id": job_id,
                                "rows": data.get("rowsExtracted", 0),
                            },
                        )
            except Exception as exc:
                current_app.logger.error(
                    f"Erreur synchro status {job_id}: {exc}"
                )

            if status in ("completed", "failed", "cancelled"):
                break

    # ── Lecture du statut ─────────────────────────────────────────────────

    def get_extraction_status(self, job_id: str) -> Dict[str, Any]:
        self._ensure_engine()
        sap_data = None
        try:
            resp = requests.get(
                f"{SAP_API_URL}/status/{job_id}",
                timeout=SAP_API_TIMEOUT,
            )
            if resp.ok:
                sap_data = resp.json()
        except Exception:
            pass

        if sap_data:
            return sap_data

        main_query = text("""
            SELECT
                eh.job_id,
                eh.user_id,
                eh.started_at,
                eh.completed_at,
                eh.status,
                eh.tables,
                eh.rows_extracted,
                eh.extraction_mode,
                eh.batch_size,
                eh.error_message,
                eh.duration_seconds,
                u.username AS user_name,
                u.email    AS user_email,
                u.role     AS user_role
            FROM public.extraction_history eh
            LEFT JOIN public.users u ON u.id::text = eh.user_id
            WHERE eh.job_id = :job_id
        """)
        details_query = text("""
            SELECT table_name, rows_extracted, start_time, end_time,
                   status, error_message
            FROM public.extraction_details
            WHERE job_id = :job_id ORDER BY start_time
        """)

        with self.engine.connect() as conn:
            main = conn.execute(main_query, {"job_id": job_id}).fetchone()
            if not main:
                return {"error": "Extraction not found"}

            details = conn.execute(details_query, {"job_id": job_id})
            tables_details = []
            for d in details:
                tables_details.append({
                    "name": d.table_name,
                    "rows": d.rows_extracted,
                    "startTime": d.start_time.isoformat() if d.start_time else None,
                    "endTime": d.end_time.isoformat() if d.end_time else None,
                    "status": d.status,
                    "error": d.error_message,
                })

            tables_list = self._parse_tables_field(main.tables)
            completed_count = sum(
                1 for td in tables_details if td["status"] == "completed"
            )
            total = len(tables_list) if tables_list else 1
            progress = 100 if main.status == "completed" else int(
                completed_count / total * 100
            )

            display_name = main.user_name or main.user_id or "inconnu"
            return {
                "id": main.job_id,
                "user": display_name,
                "userId": main.user_id,
                "userName": main.user_name,
                "userEmail": main.user_email,
                "userRole": main.user_role,
                "startedAt": main.started_at.isoformat() if main.started_at else None,
                "completedAt": main.completed_at.isoformat() if main.completed_at else None,
                "status": main.status,
                "progress": progress,
                "tables": tables_list,
                "tablesDetails": tables_details,
                "rowsExtracted": main.rows_extracted,
                "mode": main.extraction_mode,
                "batchSize": main.batch_size,
                "error": main.error_message,
                "duration": main.duration_seconds,
            }

    # ── Historique ────────────────────────────────────────────────────────

    def get_extraction_history(
        self, limit: int = 20, offset: int = 0
    ) -> List[Dict[str, Any]]:
        self._ensure_engine()
        query = text("""
            SELECT
                eh.job_id,
                eh.user_id,
                eh.started_at,
                eh.completed_at,
                eh.status,
                eh.tables,
                eh.rows_extracted,
                eh.extraction_mode,
                eh.duration_seconds,
                u.username AS user_name,
                u.email    AS user_email,
                u.role     AS user_role
            FROM public.extraction_history eh
            LEFT JOIN public.users u ON u.id::text = eh.user_id
            ORDER BY eh.started_at DESC
            LIMIT :limit OFFSET :offset
        """)
        with self.engine.connect() as conn:
            result = conn.execute(query, {"limit": limit, "offset": offset})
            history = []
            for row in result:
                display_name = row.user_name or row.user_id or "inconnu"
                history.append({
                    "id": row.job_id,
                    "user": display_name,
                    "userId": row.user_id,
                    "userName": row.user_name,
                    "userEmail": row.user_email,
                    "userRole": row.user_role,
                    "startedAt": row.started_at.isoformat() if row.started_at else None,
                    "completedAt": row.completed_at.isoformat() if row.completed_at else None,
                    "status": row.status,
                    "tables": self._parse_tables_field(row.tables),
                    "rowsExtracted": row.rows_extracted,
                    "mode": row.extraction_mode,
                    "duration": row.duration_seconds,
                })
            return history

    # ── Arret ─────────────────────────────────────────────────────────────

    def stop_extraction(self, job_id: str, reason: str = "Arret manuel") -> bool:
        self._ensure_engine()
        try:
            resp = requests.post(
                f"{SAP_API_URL}/stop/{job_id}",
                timeout=SAP_API_TIMEOUT,
            )
            sap_ok = resp.ok
        except Exception:
            sap_ok = False

        try:
            with self.engine.begin() as conn:
                conn.execute(
                    text("""
                    UPDATE public.extraction_history
                    SET status = 'cancelled',
                        completed_at = :now,
                        error_message = :reason
                    WHERE job_id = :job_id
                      AND status IN ('pending', 'running')
                    """),
                    {
                        "job_id": job_id,
                        "now": datetime.now(),
                        "reason": f"Annule: {reason}",
                    },
                )
                conn.execute(
                    text("""
                    UPDATE public.extraction_details
                    SET status = 'cancelled', end_time = :now
                    WHERE job_id = :job_id
                      AND status IN ('pending', 'running')
                    """),
                    {"job_id": job_id, "now": datetime.now()},
                )
            return True
        except Exception as e:
            current_app.logger.error(f"Erreur arret {job_id}: {e}")
            return sap_ok

    # ── Hiérarchie IFLO ──────────────────────────────────────────────────

    def get_iflo_hierarchy(self) -> List[Dict[str, Any]]:
        """Retourne la hiérarchie des postes techniques (raw_data.iflo) sous forme d'arbre."""
        self._ensure_engine()
        query = text("""
            SELECT tplnr, tplma, pltxt
            FROM raw_data.iflo
            WHERE tplnr NOT LIKE '?%'
            ORDER BY tplnr
        """)
        try:
            with self.engine.connect() as conn:
                rows = conn.execute(query).fetchall()
        except Exception as e:
            current_app.logger.error(f"Erreur lecture IFLO: {e}")
            return []

        nodes: Dict[str, Dict] = {}
        for row in rows:
            nodes[row.tplnr] = {
                "id": row.tplnr,
                "label": row.tplnr,
                "description": row.pltxt or "",
                "parent": row.tplma if row.tplma and row.tplma != row.tplnr else None,
                "children": [],
            }

        roots: List[Dict] = []
        for node in nodes.values():
            parent_id = node["parent"]
            if parent_id and parent_id in nodes:
                nodes[parent_id]["children"].append(node)
            else:
                roots.append(node)

        return roots

    # ── Logs (placeholder) ───────────────────────────────────────────────

    @staticmethod
    def _parse_log_line(line: str) -> Dict[str, str]:
        """Parse une ligne de log '<iso> [LEVEL] message' en {timestamp, level, message}."""
        ts, level, msg = "", "INFO", line or ""
        if line and "[" in line and "]" in line:
            try:
                ts = line.split(" ", 1)[0]
                rest = line[len(ts):].strip()
                if rest.startswith("["):
                    close = rest.index("]")
                    level = rest[1:close] or "INFO"
                    msg = rest[close + 1:].strip()
            except Exception:
                pass
        return {"timestamp": ts, "level": level, "message": msg}

    def get_extraction_logs(
        self, extraction_id: str, limit: int = 100
    ) -> List[Dict[str, str]]:
        """Logs live d'un job — proxy vers :8000 /jobs/{id}/logs.

        L'API renvoie { "logs": ["<iso> [LEVEL] message", ...] }. Repli sur une
        synthèse depuis le statut (tablesDetails) si l'API ne répond pas.
        """
        try:
            resp = requests.get(
                f"{SAP_API_URL}/jobs/{extraction_id}/logs",
                timeout=SAP_API_TIMEOUT,
            )
            if resp.ok:
                lines = resp.json().get("logs", []) or []
                parsed = [self._parse_log_line(l) for l in lines]
                return parsed[-limit:] if limit else parsed
        except Exception as e:
            current_app.logger.warning(
                f"SAP API /jobs/{extraction_id}/logs indisponible, repli synthèse: {e}"
            )

        # Repli : synthèse depuis le statut détaillé
        status = self.get_extraction_status(extraction_id)
        logs = []
        for td in status.get("tablesDetails", []):
            logs.append({
                "timestamp": td.get("startTime", ""),
                "level": "ERROR" if td["status"] == "failed" else "INFO",
                "message": (
                    f"{td['name']}: {td['status']} "
                    f"({td.get('rows', 0)} lignes)"
                    + (f" — {td['error']}" if td.get("error") else "")
                ),
            })
        return logs[:limit]


extraction_service = ExtractionService()
