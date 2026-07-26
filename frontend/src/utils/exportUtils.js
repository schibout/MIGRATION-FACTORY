import * as XLSX from 'xlsx';

/**
 * Exporte les données vers un fichier Excel
 * @param {Array} data - Les données à exporter
 * @param {String} filename - Le nom du fichier sans extension
 * @param {Array} columns - Les colonnes à inclure (optionnel)
 */
export const exportToExcel = (data, filename, columns = null) => {
  if (!data || data.length === 0) {
    console.error('Aucune donnée à exporter');
    return;
  }

  try {
    // Si des colonnes sont spécifiées, filtrer les données
    let exportData = data;
    if (columns) {
      // Créer une liste des champs à inclure
      const fields = columns.map(col => col.field);
      // Mapper les données pour n'inclure que ces champs avec les noms d'en-tête
      exportData = data.map(item => {
        const row = {};
        columns.forEach(col => {
          // Si un formateur est défini, l'utiliser
          if (col.valueFormatter && item[col.field] !== undefined) {
            row[col.headerName || col.field] = col.valueFormatter({ 
              value: item[col.field], 
              row: item 
            });
          } else {
            row[col.headerName || col.field] = item[col.field];
          }
        });
        return row;
      });
    }

    // Créer une nouvelle feuille de calcul
    const worksheet = XLSX.utils.json_to_sheet(exportData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Données');

    // Générer le fichier Excel
    XLSX.writeFile(workbook, `${filename}.xlsx`);
  } catch (error) {
    console.error('Erreur lors de l\'export Excel:', error);
  }
}; 