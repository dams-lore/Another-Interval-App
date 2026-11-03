import { generateId } from '../id';

describe('generateId', () => {
  it('renvoie une chaîne alphanumérique non vide', () => {
    expect(generateId()).toMatch(/^[a-z0-9]+$/);
  });

  it('ne produit pas de doublon sur 1 000 appels', () => {
    const ids = new Set(Array.from({ length: 1000 }, generateId));
    expect(ids.size).toBe(1000);
  });
});
