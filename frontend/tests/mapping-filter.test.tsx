import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import MappingFilter from '../src/components/fieldmapping/MappingFilter';

const tables = [{ name: 'kna1', description: 'Clients SAP' }];

describe('Filtres de mapping', () => {
  it('applique le nouveau statut avec la recherche courante sans attendre un second clic', async () => {
    const onFilter = vi.fn();
    render(<MappingFilter loading={false} sourceTables={tables} targetTables={tables} onFilter={onFilter} />);
    await userEvent.type(screen.getByLabelText('Recherche'), 'client');
    fireEvent.mouseDown(screen.getByLabelText('Statut'));
    await userEvent.click(screen.getByRole('option', { name: 'Actifs' }));
    expect(onFilter).toHaveBeenCalledTimes(1);
    expect(onFilter).toHaveBeenCalledWith({ sourceTable: '', targetTable: '', status: 'active', search: 'client' });
  });

  it('ne soumet pas a nouveau les filtres quand le parent change de callback', async () => {
    const first = vi.fn();
    const latest = vi.fn();
    const { rerender } = render(<MappingFilter loading={false} sourceTables={tables} targetTables={tables} onFilter={first} />);
    fireEvent.mouseDown(screen.getByLabelText('Statut'));
    await userEvent.click(screen.getByRole('option', { name: 'Inactifs' }));
    expect(first).toHaveBeenCalledTimes(1);
    rerender(<MappingFilter loading={false} sourceTables={[...tables]} targetTables={[...tables]} onFilter={latest} />);
    expect(latest).not.toHaveBeenCalled();
    expect(screen.getByLabelText('Statut')).toHaveTextContent('Inactifs');
  });
});
