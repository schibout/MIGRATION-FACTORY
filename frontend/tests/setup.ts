import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeEach, expect, vi } from 'vitest';

let blockedRequests: string[] = [];

beforeEach(() => {
  localStorage.clear();
  blockedRequests = [];
  // Une API oubliee dans un test doit echouer, jamais joindre un vrai service.
  vi.stubGlobal('fetch', vi.fn(() => {
    blockedRequests.push('fetch');
    return Promise.reject(new Error('Reseau interdit dans les tests frontend'));
  }));
  vi.spyOn(XMLHttpRequest.prototype, 'open').mockImplementation(() => {
    blockedRequests.push('XMLHttpRequest');
    throw new Error('Reseau interdit dans les tests frontend : simuler la frontiere API');
  });
});

afterEach(() => {
  cleanup();
  localStorage.clear();
  vi.unstubAllGlobals();
  // Echouer meme si le code applicatif intercepte une erreur de reseau simulee.
  expect(blockedRequests).toEqual([]);
});
