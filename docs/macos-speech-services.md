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
2. Pour Soniox, choisis dans **Soniox project region** la région affichée pour le projet qui a émis ta clé. Une clé européenne doit utiliser **Union européenne**. Une région incorrecte peut provoquer un refus d’authentification `401`. Les réunions et le push-to-talk utilisent la même région. Ensuite, conserve `stt-rt-v6` ou saisis un modèle de reconnaissance temps réel de ton compte. Choisis **Soniox** pour la traduction directe, ou **Text model** pour utiliser le service texte configuré plus haut. Les notes de réunion gardent leur propre configuration. Avec une langue cible fixe, Soniox traduit vers cette langue. Avec **Follow system**, il utilise la paire de langues affichée par Cicada.
3. Pour ElevenLabs, choisis par exemple `eleven_flash_v2_5` ou `eleven_v4_turbo`. Clique sur **Load voices** pour choisir une voix de ton compte, ou colle directement son **Voice ID**. La clé doit avoir accès à la synthèse et, pour charger la liste, à la lecture des voix.
4. Clique sur **Save** au bas du formulaire pour mémoriser les modèles, la voix et les services actifs. Le mode qui limite tout au serveur personnalisé désactive ces deux services externes.

### Parler dans une application

Sur Mac, Cicada s’ouvre en pause. Choisis **Notes › Start Recording** (⌘R) pour commencer une réunion. Le raccourci de parole reste utilisable en dehors d’une réunion si **Interpreting** est activé.

Active **Interpreting** et sélectionne **BlackHole 2ch** comme microphone dans l’application destinataire, ou laisse-la suivre le micro système si Cicada le gère. Le bouton d’installation de Cicada permet d’ajouter le pilote. Le raccourci de parole fonctionne aussi lorsque l’application destinataire a le focus.

Dans le menu de la barre macOS, **Subtitles** règle la langue du texte affiché. Sous **Interpreting**, choisis **They hear › Same as subtitles** pour que la voix suive ce choix. Par exemple, sélectionne **Deutsch** avant d’appuyer sur ⌥ et ta prochaine phrase sera traduite en allemand. Tu peux aussi choisir une langue fixe dans **They hear**, par exemple pour lire des sous-titres français et répondre en allemand. Le même réglage figure dans **Settings › Language** et **Settings › Interpreting** et reste enregistré après la fermeture.

Si tu parles toujours français, choisis **I speak › Français**, **Language they speak › Auto**, les sous-titres en **Français** et **They hear › Follow them**. Cicada répond dans la dernière langue étrangère reconnue dans la réunion, que la voix vienne du Mac ou du micro de salle. Avant la première phrase étrangère, il utilise l’anglais. Si tu fixes volontairement la sortie sur ta propre langue, ⌥ conserve ta phrase dans le chat et la réunion sans envoyer de voix traduite. Une traduction en échec conserve aussi la transcription disponible.

Maintiens la touche de parole (⌥ droite par défaut), parle, puis relâche. Soniox peut transcrire pendant l’appui. La sortie vers BlackHole commence après le relâchement, une fois la traduction prête. Une traduction directe incomplète au relâchement ou un échec de reconnaissance empêche la lecture. Une première activation des services externes remet le mode de parole sur le raccourci. L’audio de la réunion va à Soniox si tu l’actives, le texte à lire va à ElevenLabs si tu l’actives. La capture, les sous-titres et le micro virtuel sont gérés par le Mac.

Les services s’appliquent à l’écoute en direct et à l’interprétation au micro. Les imports de fichiers suivent les réglages habituels.

### Afficher le chat pendant un partage

Sélectionne **Dev › Display › Live chat** pour épingler le chat au centre, juste sous la barre des menus de l’écran choisi. Si ce mode est déjà sélectionné, Cicada ouvre la pastille au démarrage. L’historique des réunions reste accessible depuis le menu. Choisir le chat, démarrer la réunion ou prononcer la première phrase ouvre la fenêtre de 560 × 250 points. En mode chat, les phrases en cours apparaissent dans les bulles sous l’encoche. Elle garde sa taille pendant les pauses et après la réunion. Trois secondes après les derniers mots, l’opacité du fond passe de 82 % à 50 %. Elle remonte à 82 % dès que quelqu’un reparle ou que tu survoles le chat.

Fais défiler le chat vers le haut pour relire la conversation depuis le début de la réunion. Les nouvelles phrases arrivent en dessous pendant que tu lis. Redescends jusqu’en bas ou clique sur la flèche ↓ pour reprendre le direct. La conversation reste consultable à la fin de la réunion. Une nouvelle réunion ouvre un historique vide. Hors réunion, les prises de parole avec ⌥ apparaissent uniquement en mémoire dans le chat. Tes prises de parole avec ⌥ apparaissent à droite en bleu. À gauche, une phrase en cours reste neutre. Dès que Cicada attribue la phrase à une voix, la bulle prend sa couleur. Un nom déjà associé à la voix apparaît quand il est disponible. Les réglages **Original**, **Translation** et **Both** s’appliquent aussi au chat.

Pour garder les bulles sur ton Mac pendant une diffusion, choisis la fenêtre à présenter ou un onglet de navigateur dans le sélecteur de partage. Avec deux écrans, sélectionne **Dev › Display › Live chat** depuis la barre de menus de l’écran privé, puis partage l’autre écran. Cicada mémorise ce choix. Si cet écran est débranché, sélectionne à nouveau la tuile sur l’écran voulu. Une capture du même écran peut inclure les bulles. [Limites du partage de fenêtres sur macOS](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none).

### Compiler la copie locale

À la racine du fork, `scripts/build.sh` crée l’application de développement dans `build/Cicada.app`. Les Command Line Tools suffisent sur le Mac équipé du SDK 26.5. Avec les Command Line Tools 27 et le SDK 26 installé, le script choisit le SDK 26 pour SwiftUI. Le bundle de développement a ses propres préférences et ses propres fichiers de clés.

[API Soniox](https://docs.soniox.com/api-reference/stt/websocket-api) · [Modèles ElevenLabs](https://elevenlabs.io/docs/overview/models) · [Voix du compte](https://elevenlabs.io/docs/api-reference/voices/search)
