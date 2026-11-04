import React from 'react';
import { configureStore } from '@reduxjs/toolkit';
import { Provider } from 'react-redux';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import api from '../src/services/api';
import authReducer from '../src/store/slices/authSlice';
import Login from '../src/pages/Login';

vi.mock('../src/services/api', () => ({ default: { post: vi.fn(), get: vi.fn() } }));

function renderLogin() {
  const store = configureStore({ reducer: { auth: authReducer } });
  render(
    <Provider store={store}>
      <MemoryRouter initialEntries={[{ pathname: '/login', state: { from: '/exports' } }]}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/exports" element={<h1>Exports autorises</h1>} />
        </Routes>
      </MemoryRouter>
    </Provider>,
  );
  return store;
}

describe('Connexion', () => {
  it('ne soumet pas un formulaire incomplet', async () => {
    renderLogin();
    await userEvent.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(api.post).not.toHaveBeenCalled();
    expect(screen.getByRole('heading', { name: 'Connexion' })).toBeInTheDocument();
  });

  it('affiche le refus du serveur et permet une nouvelle tentative', async () => {
    vi.mocked(api.post).mockRejectedValue({ response: { status: 401, data: { error: 'Identifiants incorrects' } } });
    const store = renderLogin();
    await userEvent.type(screen.getByLabelText(/Nom d'utilisateur/), 'operateur');
    await userEvent.type(screen.getByLabelText(/Mot de passe/), 'mot-de-passe-test');
    await userEvent.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(await screen.findByText('Identifiants incorrects')).toBeInTheDocument();
    expect(store.getState().auth.isAuthenticated).toBe(false);
    expect(localStorage.getItem('token')).toBeNull();
    expect(screen.getByRole('button', { name: 'Se connecter' })).toBeEnabled();
  });

  it('enregistre les jetons et revient a la page demandee apres connexion', async () => {
    vi.mocked(api.post).mockResolvedValue({ data: {
      access_token: 'access-test', refresh_token: 'refresh-test',
      user: { id: '1', username: 'operateur', role: 'operator' },
    } });
    const store = renderLogin();
    await userEvent.type(screen.getByLabelText(/Nom d'utilisateur/), 'operateur');
    await userEvent.type(screen.getByLabelText(/Mot de passe/), 'mot-de-passe-test');
    await userEvent.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(await screen.findByRole('heading', { name: 'Exports autorises' })).toBeInTheDocument();
    expect(api.post).toHaveBeenCalledWith('/auth/login', { username: 'operateur', password: 'mot-de-passe-test' });
    expect(localStorage.getItem('token')).toBe('access-test');
    expect(localStorage.getItem('refresh_token')).toBe('refresh-test');
    expect(store.getState().auth.isAuthenticated).toBe(true);
  });

  it('bloque une seconde soumission pendant la connexion', async () => {
    let resolve!: (response: { data: unknown }) => void;
    vi.mocked(api.post).mockReturnValue(new Promise((done) => { resolve = done; }));
    renderLogin();
    await userEvent.type(screen.getByLabelText(/Nom d'utilisateur/), 'operateur');
    await userEvent.type(screen.getByLabelText(/Mot de passe/), 'mot-de-passe-test');
    await userEvent.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(screen.getByLabelText(/Nom d'utilisateur/)).toBeDisabled();
    expect(screen.getByLabelText(/Mot de passe/)).toBeDisabled();
    expect(api.post).toHaveBeenCalledTimes(1);
    resolve({ data: { access_token: 'test', refresh_token: 'refresh', user: { username: 'operateur' } } });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'Exports autorises' })).toBeInTheDocument());
  });
});
