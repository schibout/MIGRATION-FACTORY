import React from 'react';
import { act, fireEvent, render, renderHook, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import StepUpload from '../src/pages/ImportGeneric/steps/StepUpload';
import { useFileUpload } from '../src/hooks/useFileUpload';
import { importService } from '../src/services/importService';
import api from '../src/services/api';
import useGenericImport from '../src/pages/ImportGeneric/hooks/useGenericImport';

vi.mock('../src/services/api', () => ({ default: { post: vi.fn(), get: vi.fn() } }));
vi.mock('../src/services/importService', () => ({ importService: { validateFile: vi.fn(), uploadFile: vi.fn() } }));

describe('Selection et validation du fichier import', () => {
  it('transmet le fichier choisi et desactive la selection pendant analyse', () => {
    const selected = vi.fn().mockResolvedValue(undefined);
    const { container, rerender } = render(<StepUpload loading={false} onFileSelect={selected} />);
    const input = container.querySelector('input[type="file"]') as HTMLInputElement;
    const file = new File(['code;nom\n1;Client'], 'clients.csv', { type: 'text/csv' });
    fireEvent.change(input, { target: { files: [file] } });
    expect(selected).toHaveBeenCalledWith(file);
    rerender(<StepUpload loading onFileSelect={selected} />);
    expect(input).toBeDisabled();
    expect(screen.getByText('Analyse du fichier en cours...')).toBeInTheDocument();
  });

  it.each([
    ['fichier vide', new File([], 'clients.csv'), /vide/],
    ['format non supporte', new File(['test'], 'clients.exe'), /Format non support/],
    ['fichier trop gros', new File(['0123456789'], 'clients.csv'), /volumineux/],
  ])('refuse %s sans appel serveur', async (_reason, file, errorPattern) => {
    const { result } = renderHook(() => useFileUpload({ validationOptions: { maxSize: 5, allowedTypes: ['csv'] } }));
    await act(async () => { await result.current.selectFile(file); });
    expect(result.current.canUpload).toBe(false);
    expect(result.current.state.validationErrors.join(' ')).toMatch(errorPattern);
    await act(async () => { await result.current.uploadFile('clients'); });
    expect(importService.validateFile).not.toHaveBeenCalled();
    expect(importService.uploadFile).not.toHaveBeenCalled();
  });

  it('conserve le fichier et affiche un refus de validation sans lancer l import', async () => {
    vi.mocked(importService.validateFile).mockResolvedValue({ success: false, message: 'Colonne client absente', errors: ['code_client obligatoire'] });
    const { result } = renderHook(() => useFileUpload());
    const file = new File(['nom\nClient'], 'clients.csv');
    await act(async () => { await result.current.selectFile(file); });
    await act(async () => { await result.current.uploadFile('clients'); });
    expect(importService.uploadFile).not.toHaveBeenCalled();
    expect(result.current.state.file).toBe(file);
    expect(result.current.state.error).toBe('Colonne client absente');
    expect(result.current.state.uploading).toBe(false);
  });

  it('rend un echec de traitement sans annoncer un succes', async () => {
    vi.mocked(importService.validateFile).mockResolvedValue({ success: true, preview: [] });
    vi.mocked(importService.uploadFile).mockResolvedValue({ success: false, message: 'Import indisponible', errors: [] });
    const onError = vi.fn();
    const onSuccess = vi.fn();
    const { result } = renderHook(() => useFileUpload({ onError, onSuccess }));
    const file = new File(['code\n1'], 'clients.csv');
    await act(async () => { await result.current.selectFile(file); });
    await act(async () => { await result.current.uploadFile('clients'); });
    expect(importService.uploadFile).toHaveBeenCalledWith(file, 'clients');
    expect(result.current.state.error).toBe('Import indisponible');
    expect(result.current.state.success).toBe(false);
    expect(result.current.state.uploading).toBe(false);
    expect(onSuccess).not.toHaveBeenCalled();
    expect(onError).toHaveBeenCalledWith('Import indisponible');
  });

  it('termine un upload valide et permet de repartir de zero', async () => {
    vi.mocked(importService.validateFile).mockResolvedValue({ success: true });
    vi.mocked(importService.uploadFile).mockResolvedValue({ success: true, message: 'Import accepte' });
    const onSuccess = vi.fn();
    const { result } = renderHook(() => useFileUpload({ onSuccess }));
    await act(async () => { await result.current.selectFile(new File(['code\n1'], 'clients.csv')); });
    await act(async () => { await result.current.uploadFile('clients'); });
    expect(result.current.state.success).toBe(true);
    expect(result.current.uploadPercentage).toBe('100%');
    expect(onSuccess).toHaveBeenCalledOnce();
    act(() => result.current.resetUpload());
    expect(result.current.state.file).toBeNull();
    expect(result.current.canUpload).toBe(false);
  });
});

describe('Assistant import generique', () => {
  it('transmet le vrai fichier a analyser et conserve l erreur serveur', async () => {
    vi.mocked(api.post).mockRejectedValue({ response: { status: 422, data: { error: 'Classeur invalide' } } });
    const { result } = renderHook(() => useGenericImport());
    const file = new File(['invalid'], 'clients.xlsx');
    await act(async () => {
      await expect(result.current.analyzeFile(file)).rejects.toMatchObject({ response: { status: 422 } });
    });
    const [, body] = vi.mocked(api.post).mock.calls[0];
    expect((body as FormData).get('file')).toBe(file);
    expect(result.current.state.step).toBe(0);
    expect(result.current.error).toBe('Classeur invalide');
    expect(result.current.loading).toBe(false);
  });
});
