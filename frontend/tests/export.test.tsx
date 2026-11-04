import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import ExportButton from '../src/components/export/ExportButton';
import { exportClientsData } from '../src/services/exportService';
import api from '../src/services/api';

vi.mock('../src/services/api', () => ({ default: { post: vi.fn(), get: vi.fn() } }));

describe('Export ZIP', () => {
  beforeEach(() => {
    vi.spyOn(console, 'log').mockImplementation(() => undefined);
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    vi.stubGlobal('URL', class extends URL {
      static createObjectURL = vi.fn(() => 'blob:export-test');
      static revokeObjectURL = vi.fn();
    });
  });

  it('bloque le bouton sans selection et pendant un export', async () => {
    const onExport = vi.fn();
    const { rerender } = render(<ExportButton exporting={false} selectedTables={[]} onExport={onExport} />);
    expect(screen.getByRole('button')).toBeDisabled();
    rerender(<ExportButton exporting selectedTables={['clients']} onExport={onExport} />);
    expect(screen.getByRole('button', { name: 'Export en cours...' })).toBeDisabled();
    fireEvent.click(screen.getByRole('button'));
    expect(onExport).not.toHaveBeenCalled();
  });

  it('lance l export de la selection a la demande', async () => {
    const onExport = vi.fn();
    render(<ExportButton exporting={false} selectedTables={['client', 'adresse']} onExport={onExport} />);
    await userEvent.click(screen.getByRole('button', { name: 'Exporter 2 table(s) en ZIP' }));
    expect(onExport).toHaveBeenCalledOnce();
  });

  it('telecharge le ZIP nomme par le serveur puis libere son URL', async () => {
    const clicks: { download: string; href: string }[] = [];
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function () {
      clicks.push({ download: this.download, href: this.href });
    });
    vi.mocked(api.post).mockResolvedValue({ data: new Blob(['zip']), headers: {
      'content-disposition': 'attachment; filename="clients-test.zip"',
      'x-export-summary': '{"clients":2}',
      'x-export-tables-count': '1',
    } });
    const result = await exportClientsData({ selectedTables: ['clients'], includeHeaders: true, includeInactive: false });
    expect(api.post).toHaveBeenCalledWith('/export/clients', {
      selectedTables: ['clients'], format: 'zip', includeHeaders: true, includeInactive: false, csvSeparator: ';',
    }, { responseType: 'blob' });
    expect(clicks).toEqual([{ download: 'clients-test.zip', href: 'blob:export-test' }]);
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:export-test');
    expect(result).toMatchObject({ success: true, filename: 'clients-test.zip', summary: { clients: 2 } });
    expect(document.querySelector('a[download]')).toBeNull();
  });

  it('ne telecharge rien en cas de refus du serveur', async () => {
    const error = { response: { status: 500, data: { error: 'Export impossible' } } };
    vi.mocked(api.post).mockRejectedValue(error);
    await expect(exportClientsData({ selectedTables: ['clients'], includeHeaders: false, includeInactive: false })).rejects.toBe(error);
    expect(URL.createObjectURL).not.toHaveBeenCalled();
    expect(document.querySelector('a[download]')).toBeNull();
  });
});
