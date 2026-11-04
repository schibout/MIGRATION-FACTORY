import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import ReloadSapDialog from '../src/components/maintenance/ReloadSapDialog';
import MaintenanceActions from '../src/components/maintenance/MaintenanceActions';
import SnapshotManagerPanel from '../src/components/maintenance/SnapshotManagerPanel';
import api from '../src/services/api';

vi.mock('../src/services/api', () => ({ default: { post: vi.fn(), get: vi.fn(), delete: vi.fn() } }));

const job = { id: 12, job_type: 'RELOAD', status: 'PENDING', snapshot_id: 5 };

describe('Maintenance : protection des saisies', () => {
  it('propose la fusion par defaut et transmet les options sans reset implicite', async () => {
    vi.mocked(api.post).mockResolvedValue({ data: { data: job } });
    const onStarted = vi.fn();
    const onClose = vi.fn();
    render(<ReloadSapDialog open onClose={onClose} onStarted={onStarted} />);
    expect(screen.getByRole('radio', { name: /Fusionner/ })).toHaveAttribute('aria-checked', 'true');
    expect(screen.getByText(/sauvegard.*automatiquement/i)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('checkbox'));
    await userEvent.click(screen.getByRole('button', { name: 'Fusionner' }));
    await waitFor(() => expect(onStarted).toHaveBeenCalledWith(job));
    expect(api.post).toHaveBeenCalledWith('/maintenance/reload', { mode: 'merge', with_extraction: false });
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('garde le dialogue ouvert sur un conflit 409 sans annoncer de job', async () => {
    vi.mocked(api.post).mockRejectedValue({ response: { status: 409, data: { message: 'Une operation maintenance est deja en cours' } } });
    const onStarted = vi.fn();
    const onClose = vi.fn();
    render(<ReloadSapDialog open onClose={onClose} onStarted={onStarted} />);
    await userEvent.click(screen.getByRole('button', { name: 'Fusionner' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Une operation maintenance est deja en cours');
    expect(onStarted).not.toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Fusionner' })).toBeEnabled();
  });

  it('neutralise rechargement et rafraichissement pendant un job actif', async () => {
    const onRefresh = vi.fn();
    render(<MaintenanceActions jobActive hideSnapshots onRefresh={onRefresh} onJobStarted={vi.fn()} />);
    expect(screen.getByRole('button', { name: 'Recharger depuis SAP' })).toBeDisabled();
    const refresh = screen.getAllByRole('button').find((button) => !button.textContent);
    expect(refresh).toBeDisabled();
    expect(api.post).not.toHaveBeenCalled();
    expect(onRefresh).not.toHaveBeenCalled();
  });

  it('cree un etat nomme puis recharge la liste des sauvegardes', async () => {
    vi.mocked(api.get).mockResolvedValue({ data: { data: [] } });
    vi.mocked(api.post).mockResolvedValue({ data: { data: { id: 5 } } });
    render(<SnapshotManagerPanel onRestoreStarted={vi.fn()} />);
    await waitFor(() => expect(api.get).toHaveBeenCalledWith('/maintenance/snapshots'));
    await userEvent.type(screen.getByLabelText(/Nom de l/), 'Avant correction');
    await userEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));
    await waitFor(() => expect(api.post).toHaveBeenCalledWith('/maintenance/snapshots', { name: 'Avant correction', description: undefined }));
    await waitFor(() => expect(api.get).toHaveBeenCalledTimes(2));
    expect(screen.getByLabelText(/Nom de l/)).toHaveValue('');
  });

  it('ne restaure un snapshot qu apres confirmation explicite', async () => {
    vi.mocked(api.get).mockResolvedValue({ data: { data: [{
      id: 5, name: 'Avant fusion', description: null, kind: 'MANUAL', status: 'READY',
      tables: { 'clean_data.maintenance_object': 12 }, total_rows: 12,
      size_bytes: 1024, created_by: 'test', created_at: '2026-11-04T10:00:00Z', error_message: null,
    }] } });
    vi.mocked(api.post).mockResolvedValue({ data: { data: { ...job, job_type: 'RESTORE' } } });
    const onRestoreStarted = vi.fn();
    render(<SnapshotManagerPanel onRestoreStarted={onRestoreStarted} />);
    await userEvent.click(await screen.findByRole('button', { name: 'Restaurer Avant fusion' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(api.post).not.toHaveBeenCalled();
    await userEvent.click(screen.getByRole('button', { name: 'Restaurer' }));
    await waitFor(() => expect(onRestoreStarted).toHaveBeenCalledWith({ ...job, job_type: 'RESTORE' }));
    expect(api.post).toHaveBeenCalledWith('/maintenance/snapshots/5/restore');
  });
});
