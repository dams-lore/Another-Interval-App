# intrvl — App Garmin (Vivoactive 5)

App Connect IQ (Monkey C) affichée sur la montre pendant un workout piloté depuis l'iPhone :
chrono du bloc, nom du mouvement, Round X/Y, allure cible, vitesse GPS, fréquence cardiaque.
Tap haut = bloc suivant, tap ailleurs = pause.

## Prérequis (Windows ou Mac)
- Connect IQ SDK 9.1.0 (SDK Manager Garmin)
- VS Code + extension "Monkey C"
- JDK 17
- Clé développeur : `openssl genrsa -out developer_key.pem 4096` puis conversion DER (JAMAIS commitée)

## Build / simulateur
1. VS Code : ouvrir ce dossier, `Monkey C: Build Current Project` (device `vivoactive5`)
2. Lancer `simulator.exe` du SDK, puis `monkeydo bin/intrvlwatch.prg vivoactive5`
3. Simulation > Phone App Message pour envoyer un JSON

## Protocole phone -> montre
`{"type":"workout_state","blockName":"...","blockType":"...","elapsed":0,"duration":0,"round":1,"totalRounds":4,"targetPace":"...","gpsSpeed":0,"isPaused":false}`

Montre -> phone : `{"type":"user_action","action":"pause"|"next_block"}`

## Reste à faire côté iOS
Module natif Swift (ConnectIQ iOS SDK) pour parler à la montre via Garmin Connect. Voir le dossier racine du repo.
