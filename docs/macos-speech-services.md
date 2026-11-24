# Traduction vocale sur Mac

Dans **Settings › AI Service**, la partie **Live speech services** permet de configurer séparément la transcription et la synthèse. Les deux services sont désactivés à la première ouverture. Arrête l’écoute et termine ta prise de parole avant de modifier ces réglages.

| Configuration | Audio entrant et micro pendant l’appui | Traduction des phrases | Voix dans l’application de réunion |
|---|---|---|---|
| De base sur Apple silicon, sans clé | Reconnaissance du Mac | Chaîne de traduction habituelle de Cicada | Voix du Mac |
| Soniox uniquement | Soniox | Soniox en mode direct, ou modèle texte sélectionné | Voix habituelle |
| ElevenLabs uniquement | Reconnaissance habituelle | Traduction habituelle | Modèle et voix ElevenLabs |
| Les deux | Soniox | Soniox en mode direct, ou modèle texte sélectionné | Modèle et voix ElevenLabs |

### Configurer les clés

1. Active la ligne du service souhaité. Saisis sa clé dans le champ masqué, puis clique sur **Save** à côté de la clé. Les clés sont stockées dans des fichiers séparés accessibles au seul compte macOS (0600), exclus des sauvegardes. **Remove key** supprime la clé de ce service.
2. Pour Soniox, conserve `stt-rt-v6` ou saisis un modèle de reconnaissance temps réel de ton compte. Choisis **Soniox** pour la traduction directe, ou **Text model** pour utiliser le service texte configuré plus haut. Les notes de réunion gardent leur propre configuration. Avec une langue cible fixe, Soniox traduit vers cette langue. Avec **Follow system**, il utilise la paire de langues affichée par Cicada.
3. Pour ElevenLabs, choisis par exemple `eleven_flash_v2_5` ou `eleven_v4_turbo`. Clique sur **Load voices** pour choisir une voix de ton compte, ou colle directement son **Voice ID**. La clé doit avoir accès à la synthèse et, pour charger la liste, à la lecture des voix.
4. Clique sur **Save** au bas du formulaire pour mémoriser les modèles, la voix et les services actifs. Le mode qui limite tout au serveur personnalisé désactive ces deux services externes.

### Parler dans une application

Active **Interpreting** et sélectionne **BlackHole 2ch** comme microphone dans l’application destinataire, ou laisse-la suivre le micro système si Cicada le gère. Le bouton d’installation de Cicada permet d’ajouter le pilote. Le raccourci de parole fonctionne aussi lorsque l’application destinataire a le focus.

Maintiens la touche de parole (⌥ droite par défaut), parle, puis relâche. Soniox peut transcrire pendant l’appui. La sortie vers BlackHole commence après le relâchement, une fois la traduction prête. Une traduction directe incomplète au relâchement ou un échec de reconnaissance empêche la lecture. Une première activation des services externes remet le mode de parole sur le raccourci. L’audio de la réunion va à Soniox si tu l’actives, le texte à lire va à ElevenLabs si tu l’actives. La capture, les sous-titres et le micro virtuel sont gérés par le Mac.

Les services s’appliquent à l’écoute en direct et à l’interprétation au micro. Les imports de fichiers suivent les réglages habituels.

### Compiler la copie locale

À la racine du fork, `scripts/build.sh` crée l’application de développement dans `build/Cicada.app`. Les Command Line Tools suffisent sur le Mac équipé du SDK 26.5. Avec les Command Line Tools 27 et le SDK 26 installé, le script choisit le SDK 26 pour SwiftUI. Le bundle de développement a ses propres préférences et ses propres fichiers de clés.

[API Soniox](https://docs.soniox.com/api-reference/stt/websocket-api) · [Modèles ElevenLabs](https://elevenlabs.io/docs/overview/models) · [Voix du compte](https://elevenlabs.io/docs/api-reference/voices/search)
