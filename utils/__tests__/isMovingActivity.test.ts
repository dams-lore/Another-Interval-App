import { isMovingActivity } from '../isMovingActivity';

describe('isMovingActivity', () => {
  it.each(['Run', 'running 400m', 'Course à pied', 'Footing', 'Jog', 'Sprint', 'Vélo', 'Bike', 'cycling'])(
    'détecte « %s » comme une activité en déplacement',
    (movement) => {
      expect(isMovingActivity(movement)).toBe(true);
    },
  );

  it.each(['Assault Bike', 'Echo bike', 'Air-bike', 'Airbike', 'Bike Erg', 'Vélo stationnaire'])(
    'exclut l’équipement fixe « %s »',
    (movement) => {
      expect(isMovingActivity(movement)).toBe(false);
    },
  );

  it.each(['Burpees', 'Wall balls', 'Rowing', 'Ski Erg', 'Sled push', ''])(
    'ne détecte pas « %s »',
    (movement) => {
      expect(isMovingActivity(movement)).toBe(false);
    },
  );

  it('ne matche pas un mot partiel (« runner » n’est pas « run »)', () => {
    expect(isMovingActivity('Runner lunges')).toBe(false);
  });
});
