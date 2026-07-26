"""API de gestion des backups de la base de données"""
from flask import Blueprint, jsonify, request, send_file
from services.backup_service import (
    run_backup, run_backup_async, list_backups,
    delete_backup, cleanup_old_backups, restore_backup, BACKUP_DIR
)
from utils.auth_decorators import admin_required
import os

backup_blueprint = Blueprint('backup', __name__)


@backup_blueprint.route('/run', methods=['POST'])
@admin_required
def api_run_backup():
    """Lance un backup manuellement"""
    data = request.get_json() or {}
    schemas = data.get('schemas')
    compress = data.get('compress', True)
    background = data.get('background', False)

    if background:
        result = run_backup_async(schemas, compress)
    else:
        result = run_backup(schemas, compress)
    
    status = 200 if result.get('success') else 500
    return jsonify(result), status


@backup_blueprint.route('/list', methods=['GET'])
@admin_required
def api_list_backups():
    """Liste les backups disponibles"""
    backups = list_backups()
    total_size = sum(b['size_bytes'] for b in backups)
    return jsonify({
        'success': True,
        'data': backups,
        'total': len(backups),
        'total_size_mb': round(total_size / 1024 / 1024, 2),
    }), 200


@backup_blueprint.route('/download/<filename>', methods=['GET'])
@admin_required
def api_download_backup(filename):
    """Télécharge un fichier de backup"""
    filepath = os.path.join(BACKUP_DIR, os.path.basename(filename))
    if not os.path.exists(filepath):
        return jsonify({'success': False, 'error': 'Fichier non trouvé'}), 404
    return send_file(filepath, as_attachment=True, download_name=filename)


@backup_blueprint.route('/delete/<filename>', methods=['DELETE'])
@admin_required
def api_delete_backup(filename):
    """Supprime un backup"""
    result = delete_backup(filename)
    status = 200 if result.get('success') else 404
    return jsonify(result), status


@backup_blueprint.route('/cleanup', methods=['POST'])
@admin_required
def api_cleanup():
    """Supprime les anciens backups selon la rétention"""
    data = request.get_json() or {}
    days = data.get('retention_days')
    result = cleanup_old_backups(days)
    return jsonify(result), 200


@backup_blueprint.route('/restore', methods=['POST'])
@admin_required
def api_restore():
    """Restaure un backup (opération destructive)"""
    data = request.get_json() or {}
    filename = data.get('filename')
    schemas = data.get('schemas')

    if not filename:
        return jsonify({'success': False, 'error': 'filename requis'}), 400

    result = restore_backup(filename, schemas)
    status = 200 if result.get('success') else 500
    return jsonify(result), status
