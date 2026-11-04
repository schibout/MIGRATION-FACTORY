import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import SapDataTable from '../src/components/sap/SapDataTable';

const data = {
  columns: [{ name: 'designation', type: 'text', label: 'Designation' }],
  rows: [{ designation: 'Moteur principal' }, { designation: 'Pompe' }],
  total: 2, page: 1, pageSize: 10, totalPages: 1,
};

const baseProps = {
  data,
  currentPage: 0,
  currentRowsPerPage: 10,
  currentSortField: 'designation',
  currentSortDirection: 'asc' as const,
  loading: false,
  onPageChange: vi.fn(),
  onRowsPerPageChange: vi.fn(),
  onSortChange: vi.fn(),
};

afterEach(() => { vi.useRealTimers(); });

describe('Table SAP : recherche et changements du parent', () => {
  it('applique un filtre local aux nouvelles lignes sans perdre la recherche', () => {
    const { rerender } = render(<SapDataTable {...baseProps} />);
    fireEvent.change(screen.getByPlaceholderText(/Rechercher/), { target: { value: 'moteur' } });
    expect(screen.getByText('Moteur principal')).toBeInTheDocument();
    expect(screen.queryByText('Pompe')).not.toBeInTheDocument();
    rerender(<SapDataTable {...baseProps} data={{ ...data, rows: [{ designation: 'Moteur secondaire' }, { designation: 'Valve' }] }} />);
    expect(screen.getByPlaceholderText(/Rechercher/)).toHaveValue('moteur');
    expect(screen.getByText('Moteur secondaire')).toBeInTheDocument();
    expect(screen.queryByText('Valve')).not.toBeInTheDocument();
  });

  it('ne relance ni ne retarde la recherche quand les callbacks du parent changent', () => {
    vi.useFakeTimers();
    const firstSearch = vi.fn();
    const latestSearch = vi.fn();
    const firstFilters = vi.fn();
    const latestFilters = vi.fn();
    const { rerender } = render(<SapDataTable {...baseProps} toolbarResetKey="articles" debounceSearchMs={250} onSearchChange={firstSearch} onFilterChange={firstFilters} />);
    act(() => { vi.advanceTimersByTime(250); });
    firstSearch.mockClear();
    firstFilters.mockClear();
    fireEvent.change(screen.getByPlaceholderText(/Rechercher/), { target: { value: 'moteur' } });
    act(() => { vi.advanceTimersByTime(249); });
    expect(firstSearch).not.toHaveBeenCalled();
    rerender(<SapDataTable {...baseProps} toolbarResetKey="articles" debounceSearchMs={250} onSearchChange={latestSearch} onFilterChange={latestFilters} />);
    expect(screen.getByPlaceholderText(/Rechercher/)).toHaveValue('moteur');
    expect(latestFilters).not.toHaveBeenCalled();
    act(() => { vi.advanceTimersByTime(1); });
    expect(latestSearch).toHaveBeenCalledTimes(1);
    expect(latestSearch).toHaveBeenCalledWith('moteur');
    expect(firstSearch).not.toHaveBeenCalled();
    act(() => { vi.advanceTimersByTime(1000); });
    expect(latestSearch).toHaveBeenCalledTimes(1);
  });

  it('reinitialise la recherche uniquement lors du changement de vue', () => {
    const onSearch = vi.fn();
    const onFilters = vi.fn();
    const { rerender } = render(<SapDataTable {...baseProps} toolbarResetKey="articles" onSearchChange={onSearch} onFilterChange={onFilters} />);
    fireEvent.change(screen.getByPlaceholderText(/Rechercher/), { target: { value: 'moteur' } });
    onSearch.mockClear();
    onFilters.mockClear();
    rerender(<SapDataTable {...baseProps} toolbarResetKey="fournisseurs" onSearchChange={onSearch} onFilterChange={onFilters} />);
    expect(screen.getByPlaceholderText(/Rechercher/)).toHaveValue('');
    expect(onSearch).toHaveBeenCalledWith('');
    expect(onFilters).toHaveBeenCalledWith({});
  });
});
