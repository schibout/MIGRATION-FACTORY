"""
API pour la hiérarchie de maintenance (postes techniques et équipements)
"""
from flask import Blueprint, jsonify, request, current_app
import psycopg2.extras
from config.database import get_db_connection

maintenance_hierarchy_blueprint = Blueprint('maintenance_hierarchy', __name__)


@maintenance_hierarchy_blueprint.route('/functional-locations', methods=['GET'])
def get_functional_locations():
    """Récupère la hiérarchie des postes techniques avec leurs équipements"""
    try:
        root = request.args.get('root', '', type=str)
        include_equipment = request.args.get('include_equipment', 'true', type=str).lower() == 'true'
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Récupérer les postes techniques
            if root:
                # Filtrer par poste technique racine
                fl_query = """
                    SELECT DISTINCT 
                        i.tplnr as id,
                        i.tplma as parent_id,
                        COALESCE(x.pltxt, i.tplnr) as description,
                        i.fltyp as type,
                        'functional_location' as node_type,
                        i.iwerk as maintenance_plant,
                        i.ingrp as planner_group
                    FROM raw_data.iflot i
                    LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                    WHERE i.tplnr LIKE %s OR i.tplnr = %s
                    ORDER BY i.tplnr
                """
                cursor.execute(fl_query, [f'{root}%', root])
            else:
                # Récupérer tous les postes techniques de niveau supérieur
                fl_query = """
                    SELECT DISTINCT 
                        i.tplnr as id,
                        i.tplma as parent_id,
                        COALESCE(x.pltxt, i.tplnr) as description,
                        i.fltyp as type,
                        'functional_location' as node_type,
                        i.iwerk as maintenance_plant,
                        i.ingrp as planner_group
                    FROM raw_data.iflot i
                    LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                    WHERE LENGTH(i.tplnr) <= 4
                    ORDER BY i.tplnr
                    LIMIT 100
                """
                cursor.execute(fl_query)
            
            locations = cursor.fetchall()
            
            # Récupérer les équipements si demandé
            equipment = []
            if include_equipment and root:
                eq_query = """
                    SELECT DISTINCT
                        e.equnr as id,
                        l.tplnr as parent_id,
                        COALESCE(k.eqktx, 'Équipement ' || e.equnr) as description,
                        e.eqart as type,
                        'equipment' as node_type,
                        e.herst as manufacturer,
                        e.typbz as model,
                        e.sernr as serial_number,
                        e.inbdt as start_date
                    FROM raw_data.equi e
                    LEFT JOIN raw_data.eqkt k ON e.equnr = k.equnr AND e.mandt = k.mandt
                    LEFT JOIN raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                    LEFT JOIN raw_data.iloa l ON z.iloan = l.iloan AND z.mandt = l.mandt
                    WHERE l.tplnr LIKE %s
                    ORDER BY l.tplnr, e.equnr
                """
                cursor.execute(eq_query, [f'{root}%'])
                equipment = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': {
                    'functional_locations': locations,
                    'equipment': equipment
                },
                'total_locations': len(locations),
                'total_equipment': len(equipment)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération hiérarchie maintenance: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/functional-locations/<path:tplnr>/children', methods=['GET'])
def get_children(tplnr):
    """Récupère les enfants directs d'un poste technique"""
    try:
        include_equipment = request.args.get('include_equipment', 'true', type=str).lower() == 'true'
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Récupérer les enfants directs (postes techniques)
            # Optimisé avec LEFT JOIN au lieu de sous-requête corrélée
            fl_query = """
                WITH children_counts AS (
                    SELECT tplma, COUNT(*) as cnt
                    FROM raw_data.iflot
                    WHERE tplma IS NOT NULL
                    GROUP BY tplma
                ),
                equipment_counts AS (
                    SELECT l.tplnr, COUNT(*) as cnt
                    FROM raw_data.equz z
                    JOIN raw_data.iloa l ON z.iloan = l.iloan AND z.mandt = l.mandt
                    WHERE l.tplnr IS NOT NULL
                    GROUP BY l.tplnr
                )
                SELECT DISTINCT
                    i.tplnr as id,
                    i.tplma as parent_id,
                    COALESCE(x.pltxt, i.tplnr) as description,
                    i.fltyp as type,
                    'functional_location' as node_type,
                    i.iwerk as maintenance_plant,
                    i.ingrp as planner_group,
                    COALESCE(c.cnt, 0) as children_count,
                    COALESCE(eq.cnt, 0) as equipment_count
                FROM raw_data.iflot i
                LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                LEFT JOIN children_counts c ON c.tplma = i.tplnr
                LEFT JOIN equipment_counts eq ON eq.tplnr = i.tplnr
                WHERE i.tplma = %s
                ORDER BY i.tplnr
            """
            cursor.execute(fl_query, [tplnr])
            locations = cursor.fetchall()
            
            # Récupérer les équipements directs
            equipment = []
            if include_equipment:
                eq_query = """
                    SELECT DISTINCT
                        e.equnr as id,
                        l.tplnr as parent_id,
                        COALESCE(k.eqktx, 'Équipement ' || e.equnr) as description,
                        e.eqart as type,
                        'equipment' as node_type,
                        e.herst as manufacturer,
                        e.typbz as model,
                        e.sernr as serial_number,
                        e.inbdt as start_date
                    FROM raw_data.equi e
                    LEFT JOIN raw_data.eqkt k ON e.equnr = k.equnr AND e.mandt = k.mandt
                    LEFT JOIN raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                    LEFT JOIN raw_data.iloa l ON z.iloan = l.iloan AND z.mandt = l.mandt
                    WHERE l.tplnr = %s
                    ORDER BY e.equnr
                """
                cursor.execute(eq_query, [tplnr])
                equipment = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': {
                    'functional_locations': locations,
                    'equipment': equipment
                }
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération enfants: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/functional-locations/<path:tplnr>/details', methods=['GET'])
def get_location_details(tplnr):
    """Récupère les détails complets d'un poste technique"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            query = """
                WITH children_counts AS (
                    SELECT tplma, COUNT(*) as cnt
                    FROM raw_data.iflot
                    WHERE tplma IS NOT NULL
                    GROUP BY tplma
                ),
                equipment_counts AS (
                    SELECT l2.tplnr, COUNT(*) as cnt
                    FROM raw_data.equz z2
                    JOIN raw_data.iloa l2 ON z2.iloan = l2.iloan AND z2.mandt = l2.mandt
                    WHERE l2.tplnr IS NOT NULL
                    GROUP BY l2.tplnr
                )
                SELECT DISTINCT
                    i.tplnr as id,
                    i.tplma as parent_id,
                    COALESCE(x.pltxt, i.tplnr) as description,
                    i.fltyp as type,
                    'functional_location' as node_type,
                    i.iwerk as maintenance_plant,
                    i.ingrp as planner_group,
                    i.erdat as created_date,
                    i.ernam as created_by,
                    i.aedat as modified_date,
                    i.aenam as modified_by,
                    i.datab as valid_from,
                    i.begru as authorization_group,
                    i.eqart as object_type,
                    i.invnr as inventory_number,
                    i.groes as size,
                    i.brgew as weight,
                    i.gewei as weight_unit,
                    i.answt as acquisition_value,
                    i.waers as currency,
                    i.ansdt as acquisition_date,
                    i.herst as manufacturer,
                    i.herld as manufacturer_country,
                    i.baujj as construction_year,
                    i.baumm as construction_month,
                    i.typbz as model,
                    i.lvorm as deletion_flag,
                    i.inbdt as start_date,
                    i.swerk as fl_plant,
                    i.stort as fl_location,
                    i.msgrp as message_group,
                    i.klasse as classe,
                    i.ustatus as user_status,
                    l.kostl as cost_center,
                    l.bukrs as company_code,
                    l.gsber as business_area,
                    l.swerk as plant,
                    l.stort as location,
                    l.beber as plant_section,
                    l.arbpl as work_center,
                    COALESCE(c.cnt, 0) as children_count,
                    COALESCE(eq.cnt, 0) as equipment_count
                FROM raw_data.iflot i
                LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                LEFT JOIN raw_data.iloa l ON i.iloan = l.iloan AND i.mandt = l.mandt
                LEFT JOIN children_counts c ON c.tplma = i.tplnr
                LEFT JOIN equipment_counts eq ON eq.tplnr = i.tplnr
                WHERE i.tplnr = %s
                LIMIT 1
            """
            cursor.execute(query, [tplnr])
            location = cursor.fetchone()
            
            if not location:
                return jsonify({
                    'success': False,
                    'error': 'Poste technique non trouvé'
                }), 404
            
            return jsonify({
                'success': True,
                'data': location
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération détails poste technique: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/equipment/<equnr>/details', methods=['GET'])
def get_equipment_details(equnr):
    """Récupère les détails complets d'un équipement"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            query = """
                SELECT DISTINCT
                    e.equnr as id,
                    l.tplnr as parent_id,
                    COALESCE(k.eqktx, 'Equipement ' || e.equnr) as description,
                    e.eqart as type,
                    'equipment' as node_type,
                    e.eqtyp as category,
                    e.herst as manufacturer,
                    e.herld as manufacturer_country,
                    e.typbz as model,
                    e.sernr as serial_number,
                    e.invnr as inventory_number,
                    e.groes as size,
                    e.brgew as weight,
                    e.gewei as weight_unit,
                    e.answt as acquisition_value,
                    e.waers as currency,
                    e.ansdt as acquisition_date,
                    e.baujj as construction_year,
                    e.baumm as construction_month,
                    e.inbdt as start_date,
                    e.erdat as created_date,
                    e.ernam as created_by,
                    e.aedat as modified_date,
                    e.aenam as modified_by,
                    e.lvorm as deletion_flag,
                    e.gwlen as warranty_period,
                    e.gwldt as warranty_end_date,
                    e.elief as supplier,
                    e.matnr as material_number,
                    e.begru as authorization_group,
                    l.kostl as cost_center,
                    l.bukrs as company_code,
                    l.gsber as business_area,
                    l.swerk as plant,
                    l.stort as location,
                    l.beber as plant_section,
                    z.iwerk as maintenance_plant,
                    z.ingrp as planner_group
                FROM raw_data.equi e
                LEFT JOIN raw_data.eqkt k ON e.equnr = k.equnr AND e.mandt = k.mandt
                LEFT JOIN raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                LEFT JOIN raw_data.iloa l ON z.iloan = l.iloan AND z.mandt = l.mandt
                WHERE e.equnr = %s
                LIMIT 1
            """
            cursor.execute(query, [equnr])
            equipment = cursor.fetchone()
            
            if not equipment:
                return jsonify({
                    'success': False,
                    'error': 'Équipement non trouvé'
                }), 404
            
            return jsonify({
                'success': True,
                'data': equipment
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération détails équipement: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/functional-locations/<path:tplnr>/rename', methods=['PUT'])
def rename_location(tplnr):
    """Renomme un poste technique (change le tplnr)"""
    try:
        data = request.get_json()
        new_tplnr = data.get('new_id')
        
        if not new_tplnr:
            return jsonify({
                'success': False,
                'error': 'Le nouveau tplnr est requis'
            }), 400
        
        if new_tplnr == tplnr:
            return jsonify({
                'success': False,
                'error': 'Le nouveau tplnr doit être différent de l\'ancien'
            }), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Vérifier que le nouveau tplnr n'existe pas déjà
            cursor.execute("SELECT 1 FROM raw_data.iflot WHERE tplnr = %s", [new_tplnr])
            if cursor.fetchone():
                return jsonify({
                    'success': False,
                    'error': f'Le poste technique {new_tplnr} existe déjà'
                }), 400
            
            # Vérifier que l'ancien tplnr existe
            cursor.execute("SELECT 1 FROM raw_data.iflot WHERE tplnr = %s", [tplnr])
            if not cursor.fetchone():
                return jsonify({
                    'success': False,
                    'error': f'Le poste technique {tplnr} n\'existe pas'
                }), 404
            
            # Mettre à jour les références parent (tplma) dans les enfants
            cursor.execute("""
                UPDATE raw_data.iflot 
                SET tplma = %s
                WHERE tplma = %s
            """, [new_tplnr, tplnr])
            children_updated = cursor.rowcount
            
            # Mettre à jour la table iflotx (description)
            cursor.execute("""
                UPDATE raw_data.iflotx 
                SET tplnr = %s
                WHERE tplnr = %s
            """, [new_tplnr, tplnr])
            
            # Mettre à jour la table iloa (location assignment)
            cursor.execute("""
                UPDATE raw_data.iloa 
                SET tplnr = %s
                WHERE tplnr = %s
            """, [new_tplnr, tplnr])
            
            # Mettre à jour la table principale iflot
            cursor.execute("""
                UPDATE raw_data.iflot 
                SET tplnr = %s, aedat = TO_CHAR(NOW(), 'YYYYMMDD')
                WHERE tplnr = %s
            """, [new_tplnr, tplnr])
            
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': f'Poste technique renommé de {tplnr} à {new_tplnr}',
                'new_id': new_tplnr,
                'children_updated': children_updated
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur renommage poste technique: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors du renommage',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/functional-locations/<path:tplnr>', methods=['PUT'])
def update_location(tplnr):
    """Met à jour un poste technique"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Mise à jour de la description dans iflotx
            if 'description' in data:
                cursor.execute("""
                    UPDATE raw_data.iflotx 
                    SET pltxt = %s
                    WHERE tplnr = %s
                """, [data['description'], tplnr])
            
            # Mise à jour des champs dans iflot
            update_fields = []
            update_values = []
            
            field_mapping = {
                'maintenance_plant': 'iwerk',
                'planner_group': 'ingrp',
                'object_type': 'eqart',
                'inventory_number': 'invnr',
                'manufacturer': 'herst',
                'model': 'typbz',
                'construction_year': 'baujj',
                'construction_month': 'baumm',
                'parent_id': 'tplma',
            }
            
            for api_field, db_field in field_mapping.items():
                if api_field in data:
                    update_fields.append(f"{db_field} = %s")
                    update_values.append(data[api_field])
            
            if update_fields:
                update_fields.append("aedat = TO_CHAR(NOW(), 'YYYYMMDD')")
                update_values.append(tplnr)
                
                query = f"""
                    UPDATE raw_data.iflot 
                    SET {', '.join(update_fields)}
                    WHERE tplnr = %s
                """
                cursor.execute(query, update_values)
            
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': 'Poste technique mis à jour avec succès'
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur mise à jour poste technique: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la mise à jour',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/equipment/<equnr>', methods=['PUT'])
def update_equipment(equnr):
    """Met à jour un équipement"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Mise à jour de la description dans eqkt
            if 'description' in data:
                desc = data['description']
                if isinstance(desc, str) and len(desc) > 40:
                    return jsonify({
                        'success': False,
                        'error': f'La description dépasse la longueur maximale (40 caractères, reçu {len(desc)})'
                    }), 400
                cursor.execute("""
                    UPDATE raw_data.eqkt 
                    SET eqktx = %s
                    WHERE equnr = %s
                """, [desc, equnr])
            
            # Mise à jour des champs dans equi
            update_fields = []
            update_values = []
            
            field_mapping = {
                'manufacturer': ('herst', 30),
                'manufacturer_country': ('herld', 3),
                'model': ('typbz', 20),
                'serial_number': ('sernr', 18),
                'inventory_number': ('invnr', 25),
                'construction_year': ('baujj', 4),
                'construction_month': ('baumm', 2),
                'type': ('eqart', 10),
                'category': ('eqtyp', 1),
                'size': ('groes', 18),
                'weight': ('brgew', None),
                'weight_unit': ('gewei', 3),
                'acquisition_value': ('answt', None),
                'currency': ('waers', 5),
                'acquisition_date': ('ansdt', None),
                'start_date': ('inbdt', None),
                'supplier': ('elief', 10),
                'material_number': ('matnr', 18),
                'warranty_period': ('gwlen', None),
                'warranty_end_date': ('gwldt', None),
            }
            
            for api_field, (db_field, max_len) in field_mapping.items():
                if api_field in data:
                    val = data[api_field]
                    if max_len and isinstance(val, str) and len(val) > max_len:
                        return jsonify({
                            'success': False,
                            'error': f'Le champ "{api_field}" dépasse la longueur maximale ({max_len} caractères)'
                        }), 400
                    update_fields.append(f"{db_field} = %s")
                    update_values.append(val)
            
            if update_fields:
                update_fields.append("aedat = TO_CHAR(NOW(), 'YYYYMMDD')")
                update_values.append(equnr)
                
                query = f"""
                    UPDATE raw_data.equi 
                    SET {', '.join(update_fields)}
                    WHERE equnr = %s
                """
                cursor.execute(query, update_values)
            
            conn.commit()
            
            return jsonify({
                'success': True,
                'message': 'Équipement mis à jour avec succès'
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur mise à jour équipement: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la mise à jour',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/equipment', methods=['POST'])
def create_equipment():
    """Crée un nouvel équipement.
    INSERT réparti sur les tables sources (equi, eqkt, equz).
    Le tplnr (poste technique) est optionnel : si fourni, l'iloan est récupéré
    depuis raw_data.iloa pour lier l'équipement au poste technique.
    """
    try:
        data = request.get_json() or {}
        description = (data.get('description') or '').strip()
        if not description:
            return jsonify({'success': False, 'error': 'Description requise'}), 400
        if len(description) > 40:
            return jsonify({'success': False, 'error': 'Description max 40 caractères'}), 400

        tplnr = (data.get('functional_location') or '').strip() or None

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT mandt FROM raw_data.equi LIMIT 1")
            row = cursor.fetchone()
            mandt = row['mandt'] if row else '700'

            cursor.execute("SELECT MAX(CAST(equnr AS BIGINT)) AS max_eq FROM raw_data.equi")
            result = cursor.fetchone()
            max_eq = result['max_eq'] if result and result['max_eq'] else 0
            new_equnr = str(max_eq + 1).zfill(18)

            iloan = None
            if tplnr:
                cursor.execute(
                    "SELECT iloan FROM raw_data.iloa WHERE tplnr = %s AND mandt = %s LIMIT 1",
                    [tplnr, mandt]
                )
                ir = cursor.fetchone()
                iloan = ir['iloan'] if ir else None

            cursor.execute("""
                INSERT INTO raw_data.equi (
                    mandt, equnr, eqart, eqtyp, herst, herld, typbz, sernr,
                    invnr, matnr, groes, brgew, gewei, answt, waers, ansdt,
                    baujj, baumm, inbdt, elief, erdat, ernam
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, TO_CHAR(NOW(), 'YYYYMMDD'), 'MIGFAC'
                )
            """, [
                mandt, new_equnr,
                data.get('type') or '',
                data.get('category') or '',
                data.get('manufacturer') or '',
                data.get('manufacturer_country') or '',
                data.get('model') or '',
                data.get('serial_number') or '',
                data.get('inventory_number') or '',
                data.get('material_number') or '',
                data.get('size') or '',
                data.get('weight') or '',
                data.get('weight_unit') or '',
                data.get('acquisition_value') or '',
                data.get('currency') or '',
                data.get('acquisition_date') or '',
                data.get('construction_year') or '',
                data.get('construction_month') or '',
                data.get('start_date') or '',
                data.get('supplier') or ''
            ])

            cursor.execute("""
                INSERT INTO raw_data.eqkt (mandt, equnr, spras, eqktx)
                VALUES (%s, %s, 'F', %s)
            """, [mandt, new_equnr, description])

            cursor.execute("""
                INSERT INTO raw_data.equz (
                    mandt, equnr, eqlfn, datbi, datab, iloan, iwerk, ingrp
                ) VALUES (
                    %s, %s, '0001', '99991231', TO_CHAR(NOW(), 'YYYYMMDD'),
                    %s, %s, %s
                )
            """, [
                mandt, new_equnr,
                iloan or '',
                data.get('maintenance_plant') or '9200',
                data.get('planner_group') or ''
            ])

            conn.commit()

            return jsonify({
                'success': True,
                'message': 'Équipement créé',
                'data': {'equnr': new_equnr, 'linked_to_tplnr': bool(iloan)}
            }), 201

    except Exception as e:
        current_app.logger.error(f"Erreur création équipement: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_hierarchy_blueprint.route('/equipment/<equnr>', methods=['DELETE'])
def delete_equipment(equnr):
    """Supprime un équipement et ses sous-équipements (cascade equz → eqkt → equi)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT equnr FROM raw_data.equi WHERE equnr = %s", [equnr])
            if not cursor.fetchone():
                return jsonify({'success': False, 'error': 'Équipement non trouvé'}), 404

            # Suppression récursive des sous-équipements (hequi pointe vers ce equnr)
            def _delete_recursive(eq):
                cursor.execute(
                    "SELECT DISTINCT equnr FROM raw_data.equz WHERE hequi = %s",
                    [eq]
                )
                count = 0
                for row in cursor.fetchall():
                    count += _delete_recursive(row['equnr'])
                cursor.execute("DELETE FROM raw_data.equz WHERE equnr = %s", [eq])
                cursor.execute("DELETE FROM raw_data.eqkt WHERE equnr = %s", [eq])
                cursor.execute("DELETE FROM raw_data.equi WHERE equnr = %s", [eq])
                return count + 1

            deleted = _delete_recursive(equnr)
            conn.commit()

            return jsonify({
                'success': True,
                'message': f'Équipement et {deleted - 1} sous-équipement(s) supprimés',
                'data': {'deleted_count': deleted}
            }), 200

    except Exception as e:
        current_app.logger.error(f"Erreur suppression équipement: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@maintenance_hierarchy_blueprint.route('/root-locations', methods=['GET'])
def get_root_locations():
    """Récupère les postes techniques racines (niveau 1)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Récupérer les postes techniques de niveau 1 (sans tiret)
            # Optimisé avec LEFT JOIN au lieu de sous-requêtes corrélées
            query = """
                WITH children_counts AS (
                    SELECT tplma, COUNT(*) as cnt 
                    FROM raw_data.iflot 
                    WHERE tplma IS NOT NULL
                    GROUP BY tplma
                ),
                equipment_counts AS (
                    SELECT 
                        SUBSTRING(l.tplnr FROM 1 FOR POSITION('-' IN l.tplnr || '-') - 1) as root_tplnr,
                        COUNT(*) as cnt
                    FROM raw_data.equz z
                    JOIN raw_data.iloa l ON z.iloan = l.iloan
                    WHERE l.tplnr IS NOT NULL
                    GROUP BY SUBSTRING(l.tplnr FROM 1 FOR POSITION('-' IN l.tplnr || '-') - 1)
                )
                SELECT DISTINCT
                    i.tplnr as id,
                    i.tplma as parent_id,
                    COALESCE(x.pltxt, i.tplnr) as description,
                    i.fltyp as type,
                    'functional_location' as node_type,
                    COALESCE(c.cnt, 0) as children_count,
                    COALESCE(eq.cnt, 0) as equipment_count
                FROM raw_data.iflot i
                LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                LEFT JOIN children_counts c ON c.tplma = i.tplnr
                LEFT JOIN equipment_counts eq ON eq.root_tplnr = i.tplnr
                WHERE i.tplma IS NULL
                  AND i.tplnr NOT LIKE '%-%'
                ORDER BY i.tplnr
            """
            cursor.execute(query)
            locations = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': locations,
                'total': len(locations)
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur récupération postes racines: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/equipment', methods=['GET'])
def list_equipment():
    """Liste tous les équipements avec pagination et filtres"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 25, type=int)
        search = request.args.get('search', '', type=str).strip()
        eq_type = request.args.get('type', '', type=str).strip()
        plant = request.args.get('plant', '', type=str).strip()
        order_by = request.args.get('order_by', 'id', type=str)
        order = request.args.get('order', 'asc', type=str)
        
        per_page = min(per_page, 100)
        offset = (page - 1) * per_page
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            where_clauses = []
            params = []
            
            if search:
                where_clauses.append("""
                    (e.equnr ILIKE %s
                     OR kf.eqktx ILIKE %s
                     OR kn.eqktx ILIKE %s
                     OR kx.eqktx ILIKE %s
                     OR e.herst ILIKE %s
                     OR e.typbz ILIKE %s)
                """)
                sp = f'%{search}%'
                params.extend([sp, sp, sp, sp, sp, sp])
            
            if eq_type:
                where_clauses.append("e.eqart IS NOT NULL AND TRIM(e.eqart) = %s")
                params.append(eq_type)
            
            if plant:
                where_clauses.append("z.iwerk IS NOT NULL AND TRIM(z.iwerk) = %s")
                params.append(plant)
            
            where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
            
            outer_order_mapping = {
                'id': 'id',
                'description': 'description',
                'type': 'type',
                'manufacturer': 'manufacturer',
            }
            outer_order_column = outer_order_mapping.get(order_by, 'id')
            order_dir = 'DESC' if order.lower() == 'desc' else 'ASC'

            join_z = "JOIN" if plant else "LEFT JOIN"

            # Fallback descriptions FR → NL → tout
            joins_eqkt = """
                LEFT JOIN raw_data.eqkt kf ON e.equnr = kf.equnr AND e.mandt = kf.mandt AND kf.spras = 'F'
                LEFT JOIN raw_data.eqkt kn ON e.equnr = kn.equnr AND e.mandt = kn.mandt AND kn.spras = 'N'
                LEFT JOIN raw_data.eqkt kx ON e.equnr = kx.equnr AND e.mandt = kx.mandt
            """

            count_query = f"""
                SELECT COUNT(DISTINCT e.equnr) as total
                FROM raw_data.equi e
                {joins_eqkt}
                {join_z} raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                {where_sql}
            """
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']

            query = f"""
                SELECT * FROM (
                    SELECT DISTINCT ON (e.equnr)
                        e.equnr as id,
                        COALESCE(TRIM(kf.eqktx), TRIM(kn.eqktx), TRIM(kx.eqktx), 'Équipement ' || TRIM(e.equnr)) as description,
                        TRIM(e.eqart) as type,
                        TRIM(e.eqtyp) as category,
                        TRIM(e.herst) as manufacturer,
                        TRIM(e.typbz) as model,
                        TRIM(e.sernr) as serial_number,
                        TRIM(e.invnr) as inventory_number,
                        TRIM(z.iwerk) as maintenance_plant,
                        TRIM(z.ingrp) as planner_group
                    FROM raw_data.equi e
                    {joins_eqkt}
                    {join_z} raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                    {where_sql}
                    ORDER BY e.equnr
                ) sub
                ORDER BY {outer_order_column} {order_dir} NULLS LAST, id ASC
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, params + [per_page, offset])
            equipment = cursor.fetchall()
            
            # Always load filter options
            cursor.execute("""
                SELECT DISTINCT TRIM(eqart) as eqart FROM raw_data.equi 
                WHERE eqart IS NOT NULL AND TRIM(eqart) != '' 
                ORDER BY 1
            """)
            types = [r['eqart'] for r in cursor.fetchall()]
            
            cursor.execute("""
                SELECT DISTINCT TRIM(iwerk) as iwerk FROM raw_data.equz 
                WHERE iwerk IS NOT NULL AND TRIM(iwerk) != '' 
                ORDER BY 1
            """)
            plants = [r['iwerk'] for r in cursor.fetchall()]
            
            return jsonify({
                'success': True,
                'data': equipment,
                'total': total,
                'page': page,
                'per_page': per_page,
                'filter_options': {
                    'types': types,
                    'plants': plants
                }
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur liste équipements: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la récupération des données',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/functional-locations/search-parents', methods=['GET'])
def search_parent_locations():
    """Recherche des postes techniques pour sélection comme parent"""
    try:
        query = request.args.get('q', '', type=str)
        exclude = request.args.get('exclude', '', type=str)  # ID à exclure (le nœud lui-même)
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            if query and len(query) >= 1:
                search_param = f'%{query}%'
                fl_query = """
                    SELECT DISTINCT 
                        i.tplnr as id,
                        COALESCE(x.pltxt, i.tplnr) as description,
                        i.fltyp as type
                    FROM raw_data.iflot i
                    LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                    WHERE (i.tplnr ILIKE %s OR x.pltxt ILIKE %s)
                      AND i.tplnr != %s
                    ORDER BY i.tplnr
                    LIMIT 50
                """
                cursor.execute(fl_query, [search_param, search_param, exclude])
            else:
                # Sans recherche, retourner les premiers niveaux
                fl_query = """
                    SELECT DISTINCT 
                        i.tplnr as id,
                        COALESCE(x.pltxt, i.tplnr) as description,
                        i.fltyp as type
                    FROM raw_data.iflot i
                    LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                    WHERE i.tplnr != %s
                    ORDER BY i.tplnr
                    LIMIT 50
                """
                cursor.execute(fl_query, [exclude])
            
            locations = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': locations
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur recherche parents: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la recherche',
            'message': str(e)
        }), 500


@maintenance_hierarchy_blueprint.route('/search', methods=['GET'])
def search_hierarchy():
    """Recherche dans la hiérarchie de maintenance"""
    try:
        query = request.args.get('q', '', type=str)
        if not query or len(query) < 2:
            return jsonify({
                'success': False,
                'error': 'Le terme de recherche doit contenir au moins 2 caractères'
            }), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            search_param = f'%{query}%'
            
            # Rechercher dans les postes techniques
            fl_query = """
                SELECT DISTINCT 
                    i.tplnr as id,
                    i.tplma as parent_id,
                    COALESCE(x.pltxt, i.tplnr) as description,
                    'functional_location' as node_type
                FROM raw_data.iflot i
                LEFT JOIN raw_data.iflotx x ON i.tplnr = x.tplnr AND i.mandt = x.mandt AND x.spras = 'F'
                WHERE i.tplnr ILIKE %s OR x.pltxt ILIKE %s
                ORDER BY i.tplnr
                LIMIT 50
            """
            cursor.execute(fl_query, [search_param, search_param])
            locations = cursor.fetchall()
            
            # Rechercher dans les équipements
            eq_query = """
                SELECT DISTINCT
                    e.equnr as id,
                    l.tplnr as parent_id,
                    COALESCE(k.eqktx, 'Équipement ' || e.equnr) as description,
                    'equipment' as node_type
                FROM raw_data.equi e
                LEFT JOIN raw_data.eqkt k ON e.equnr = k.equnr AND e.mandt = k.mandt
                LEFT JOIN raw_data.equz z ON e.equnr = z.equnr AND e.mandt = z.mandt
                LEFT JOIN raw_data.iloa l ON z.iloan = l.iloan AND z.mandt = l.mandt
                WHERE e.equnr ILIKE %s OR k.eqktx ILIKE %s
                ORDER BY e.equnr
                LIMIT 50
            """
            cursor.execute(eq_query, [search_param, search_param])
            equipment = cursor.fetchall()
            
            return jsonify({
                'success': True,
                'data': {
                    'functional_locations': locations,
                    'equipment': equipment
                }
            }), 200
            
    except Exception as e:
        current_app.logger.error(f"Erreur recherche hiérarchie: {e}")
        return jsonify({
            'success': False,
            'error': 'Erreur lors de la recherche',
            'message': str(e)
        }), 500
