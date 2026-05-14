---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: tubeflow-app
created: "2026-04-25"
updated: "2026-04-26"
status: ready
source_skill: sf-docs
scope: feature
owner: Diane
confidence: high
risk_level: medium
security_impact: yes
docs_impact: yes
user_story: "As a ReplayGlowz user or evaluator, I can submit text or audio feedback, and authorized admins can review it from the app."
linked_systems: ["Flutter Web", "Convex", "Clerk", "Vercel"]
depends_on: []
supersedes: []
evidence:
  - "tubeflow_app/lib/screens/feedback/feedback_screen.dart"
  - "tubeflow_app/lib/screens/feedback/feedback_admin_screen.dart"
  - "tubeflow_app/lib/providers/mutations.dart"
  - "tubeflow_app/lib/providers/providers.dart"
  - "tubeflow_app/vercel.json"
next_step: "Keep aligned with the Convex backend feedback contract before implementation changes."
---
# Spec Technique — Feedback App + Admin v1 pour TubeFlow

Date: 2026-04-19
Branche front: `main`
Frontend repo: `tubeflow_app`
Backend Convex repo: `/home/claude/tubeflow/packages/backend/convex`

## Titre

Feedback App + Admin v1

## Problème

TubeFlow n’a aujourd’hui aucun vrai flux de feedback exploitable. Le frontend Flutter ne contient ni écran dédié, ni envoi texte/audio vers le backend, ni vue admin pour consulter les retours des utilisateurs. En plus, l’app web actuelle bloque l’accès micro via `Permissions-Policy: microphone=()`, et le router rend toutes les routes métier privées, ce qui empêche un vrai feedback anonyme.

## Solution

Ajouter un flux de feedback unifié dans l’app Flutter existante, utilisable sur web et Android, avec stockage serveur dans Convex, support texte + audio, et un écran admin discret dans l’app réservé à une allowlist d’emails contrôlée côté serveur.

## Scope In

- Envoi de feedback texte depuis l’app Flutter.
- Envoi de feedback audio depuis l’app Flutter sur web et Android.
- Support anonyme quand aucun utilisateur n’est connecté.
- Enrichissement des feedbacks avec plateforme, langue, contexte de build et identité utilisateur si disponible.
- Stockage des feedbacks et des fichiers audio dans Convex.
- Vue admin dans l’app Flutter pour lister, filtrer, écouter et marquer les feedbacks comme lus.
- Affichage du lien admin uniquement pour les admins, avec contrôle serveur effectif.
- Point d’entrée public pour permettre le feedback même hors session.

## Scope Out

- Backoffice web séparé.
- Notifications email, Slack ou push aux admins.
- Rétro-upload automatique d’éventuels brouillons locaux.
- Modération avancée, assignation, tags, réponse aux feedbacks.
- Analytics avancée ou scoring automatique du feedback.
- i18n complète de toute l’interface TubeFlow.

## Constat d’architecture

- Le frontend est une app Flutter unique ciblant au moins le web et potentiellement Android.
- Le backend Convex vit dans un autre repo: `/home/claude/tubeflow/packages/backend/convex`.
- Les writes Convex front passent par `lib/providers/mutations.dart`.
- Les reads typed sont centralisés dans `lib/providers/providers.dart`.
- Le router actuel force l’auth sur toutes les routes sauf `/sign-in`; un feedback anonyme exige donc une nouvelle route publique autorisée.
- Il n’existe aujourd’hui aucun module feedback ni aucune table feedback côté Convex.
- Le web déployé via Vercel bloque explicitement le micro dans [vercel.json](tubeflow_app/vercel.json:1); l’audio web ne peut pas fonctionner sans changement de headers.
- Les préférences utilisateur existent déjà et exposent une langue stockée côté Convex, mais l’app n’applique pas encore une locale globale dans `MaterialApp.router`.
- La navigation secondaire naturelle pour une zone admin discrète est l’écran [preferences_screen.dart](tubeflow_app/lib/screens/preferences/preferences_screen.dart:1).
- Le pattern d’écran admin/listing le plus proche est [hidden_screen.dart](tubeflow_app/lib/screens/hidden/hidden_screen.dart:1).
- Il n’existe pas de système legacy de feedback local à migrer dans TubeFlow. La section migration du plan source doit donc être simplifiée.

## Décisions produit adaptées à TubeFlow

- Le formulaire de feedback public sera exposé sur `Routes.feedback = '/feedback'`.
- Cette route sera accessible authentifié ou non pour permettre le feedback anonyme.
- L’écran admin sera exposé sur `Routes.feedbackAdmin = '/feedback/admin'`.
- Le lien admin sera affiché dans `Preferences` seulement si `feedback:isAdmin` renvoie `true`.
- Un lien discret vers le formulaire public sera aussi ajouté sur l’écran de sign-in pour couvrir le cas non connecté.
- Le feedback texte restera le fallback universel si le micro est indisponible ou refusé.
- Le brouillon local persistant sera limité au texte; l’audio enregistré restera un brouillon éphémère de session pour éviter une persistance locale fragile multi-plateforme.
- Les feedbacks audio accepteront un message texte optionnel pour ajouter du contexte.
- Les métadonnées de build seront jointes à chaque feedback: `buildCommitSha`, `buildEnvironment`, `buildTimestamp`.

## Modèle serveur proposé

Nouvelle table `feedbackEntries` dans `/home/claude/tubeflow/packages/backend/convex/schema.ts`.

Champs:

- `type`: `"text"` | `"audio"`
- `status`: `"new"` | `"reviewed"`
- `message`: `string?`
- `audioStorageId`: `Id<"_storage">?`
- `audioDurationMs`: `number?`
- `platform`: `"web"` | `"android"` | `"other"`
- `locale`: `string`
- `buildCommitSha`: `string?`
- `buildEnvironment`: `string?`
- `buildTimestamp`: `string?`
- `userId`: `string?`
- `userEmail`: `string?`
- `reviewedAt`: `number?`
- `reviewedByEmail`: `string?`
- `createdAt`: `number`

Indexes minimum:

- `by_created_at` sur `createdAt`
- `by_status_and_created_at` sur `status, createdAt`
- `by_type_and_created_at` sur `type, createdAt`

Notes:

- `userId` reste le Clerk user id string, cohérent avec le reste du schéma.
- `message` reste optionnel pour supporter un feedback audio sans texte.
- `reviewedAt` et `reviewedByEmail` sont ajoutés par rapport au plan source pour donner une traçabilité minimale côté admin.

## Opérations Convex proposées

Nouveau module: `/home/claude/tubeflow/packages/backend/convex/feedback.ts`

Fonctions publiques:

- `feedback:isAdmin`
  - Query.
  - Retourne `true` si l’utilisateur courant appartient à l’allowlist email, sinon `false`.
  - Retourne toujours `false` si non connecté.

- `feedback:getUploadUrl`
  - Mutation.
  - Retourne `ctx.storage.generateUploadUrl()`.
  - Publique pour permettre l’audio anonyme.

- `feedback:createText`
  - Mutation.
  - Accepte `message`, `platform`, `locale`, `buildCommitSha?`, `buildEnvironment?`, `buildTimestamp?`.
  - Résout l’identité courante si présente, mais n’exige pas l’auth.
  - Valide `message.trim().isNotEmpty`.
  - Applique une borne de longueur côté serveur, par exemple 2000 caractères max.

- `feedback:createAudio`
  - Mutation.
  - Accepte `audioStorageId`, `audioDurationMs`, `platform`, `locale`, `message?`, `buildCommitSha?`, `buildEnvironment?`, `buildTimestamp?`.
  - Résout l’identité courante si présente, mais n’exige pas l’auth.
  - Vérifie que `audioStorageId` existe dans `_storage`.
  - Vérifie que le `contentType` commence par `audio/` quand présent.
  - Vérifie `audioDurationMs > 0` et `audioDurationMs <= 120000`.
  - Vérifie une taille max de fichier côté serveur via `_storage`, par exemple 10 MB.
  - Supprime le blob si la validation serveur échoue après upload.

- `feedback:listAdmin`
  - Query protégée.
  - Args: `status?`, `type?`.
  - Refuse l’accès si l’utilisateur courant n’est pas allowlisté.
  - Retourne la liste triée du plus récent au plus ancien.
  - Pour chaque entrée audio, retourne aussi `audioUrl = await ctx.storage.getUrl(audioStorageId)`.

- `feedback:markReviewed`
  - Mutation protégée.
  - Accepte `feedbackId`.
  - Patch `status = "reviewed"`, `reviewedAt = Date.now()`, `reviewedByEmail = adminEmail`.

Helpers backend:

- Ajouter dans `feedback.ts` un helper local `getFeedbackAdminEmail(ctx)` qui:
  - lit l’identité courante;
  - tente de récupérer l’email depuis la table `users` par `clerkId`;
  - retombe sur l’email du token si présent;
  - compare en lowercase avec `process.env.FEEDBACK_ADMIN_EMAILS`.

- Ne pas dépendre uniquement de `users:ensureUser`, car un utilisateur connecté peut techniquement envoyer un feedback avant qu’un document `users` n’existe.

Variable d’environnement Convex:

- `FEEDBACK_ADMIN_EMAILS`
  - Liste CSV d’emails allowlistés.
  - Comparaison en lowercase et trim.
  - Valeur vide = aucun admin.

## Architecture client proposée

### Entrées utilisateur

- Route publique `Routes.feedback` ajoutée dans [router.dart](tubeflow_app/lib/app/router.dart:1).
- Point d’entrée authentifié depuis `Preferences`.
- Point d’entrée non authentifié depuis [auth_gate.dart](tubeflow_app/lib/auth/auth_gate.dart:1).

### Flux texte

1. L’utilisateur ouvre l’écran feedback.
2. Il saisit un message.
3. Le client construit les métadonnées: plateforme, locale effective, build info, identité si disponible.
4. Le client appelle `feedback:createText`.
5. L’écran affiche l’état succès/erreur et vide le brouillon texte local.

### Flux audio

1. L’utilisateur choisit le mode audio.
2. Le client enregistre localement un audio temporaire.
3. Le client appelle `feedback:getUploadUrl`.
4. Le client POST le fichier audio à l’upload URL Convex.
5. Le client récupère `storageId`.
6. Le client appelle `feedback:createAudio`.
7. L’écran affiche l’état succès/erreur et purge le brouillon audio en mémoire.

### Locale envoyée

TubeFlow n’a pas encore de locale globale appliquée à `MaterialApp.router`. Pour v1, la valeur envoyée sera:

- `settings.language` si l’utilisateur authentifié a une préférence connue;
- sinon `Localizations.localeOf(context).languageCode`;
- sinon `"en"` en fallback final.

### Plateforme envoyée

- `web` si `kIsWeb`
- `android` si `defaultTargetPlatform == TargetPlatform.android`
- `other` sinon

## Implémentation détaillée

- [ ] Tâche 1: Ajouter le schéma feedback côté Convex
  - Fichier: `/home/claude/tubeflow/packages/backend/convex/schema.ts`
  - Action: créer la table `feedbackEntries` avec ses validateurs et indexes.

- [ ] Tâche 2: Créer le module backend feedback
  - Fichier: `/home/claude/tubeflow/packages/backend/convex/feedback.ts`
  - Action: implémenter `isAdmin`, `getUploadUrl`, `createText`, `createAudio`, `listAdmin`, `markReviewed`.
  - Notes: toutes les protections admin doivent être faites côté serveur, pas seulement dans l’UI.

- [ ] Tâche 3: Rendre l’allowlist admin configurable
  - Fichier: `/home/claude/tubeflow/packages/backend/convex/feedback.ts`
  - Action: parser `process.env.FEEDBACK_ADMIN_EMAILS` en helper réutilisable.
  - Notes: comparaison lowercase + trim, valeurs vides ignorées.

- [ ] Tâche 4: Ajouter le modèle Dart de feedback admin
  - Fichier: `lib/models/feedback_entry.dart`
  - Action: créer `FeedbackEntry` avec mapping JSON pour `type`, `status`, `message`, `audioUrl`, `audioDurationMs`, `platform`, `locale`, `userEmail`, `reviewedAt`, `createdAt`, build metadata.

- [ ] Tâche 5: Exporter le modèle
  - Fichier: `lib/models/models.dart`
  - Action: exporter `feedback_entry.dart`.

- [ ] Tâche 6: Ajouter les reads typed Riverpod
  - Fichier: `lib/providers/providers.dart`
  - Action: ajouter `feedbackIsAdminProvider` et `feedbackAdminEntriesProvider`.
  - Notes: préférer des `FutureProvider` one-shot plutôt qu’une subscription realtime pour cette v1 admin.

- [ ] Tâche 7: Ajouter les helpers de mutation feedback
  - Fichier: `lib/providers/mutations.dart`
  - Action: ajouter `createFeedbackText`, `getFeedbackUploadUrl`, `createFeedbackAudio`, `markFeedbackReviewed`.
  - Notes: respecter la règle du repo selon laquelle tous les writes passent par `mutations.dart`.

- [ ] Tâche 8: Ajouter un service de soumission feedback côté Flutter
  - Fichier: `lib/screens/feedback/feedback_service.dart`
  - Action: centraliser l’orchestration texte/audio, l’upload HTTP vers Convex, la récupération de locale et des build infos, la normalisation plateforme, et les erreurs.
  - Notes: le service doit être utilisable connecté ou non.

- [ ] Tâche 9: Ajouter l’écran public de feedback
  - Fichier: `lib/screens/feedback/feedback_screen.dart`
  - Action: créer le formulaire texte/audio avec états `idle`, `recording`, `uploading`, `submitting`, `success`, `error`.
  - Notes: le texte est obligatoire en mode texte; il reste optionnel en mode audio.

- [ ] Tâche 10: Ajouter l’écran admin feedback
  - Fichier: `lib/screens/feedback/feedback_admin_screen.dart`
  - Action: créer la vue admin avec filtres `All / Unread / Text / Audio`, tri décroissant, lecteur audio, CTA `Mark as read`, et affichage des métadonnées.
  - Notes: si `feedbackIsAdminProvider` vaut `false`, afficher un état `Access denied`.

- [ ] Tâche 11: Brancher les nouvelles routes
  - Fichier: `lib/app/router.dart`
  - Action: ajouter `Routes.feedback` et `Routes.feedbackAdmin`, autoriser `Routes.feedback` dans le `redirect`, déclarer les pages correspondantes.
  - Notes: `Routes.feedbackAdmin` reste une route authentifiée.

- [ ] Tâche 12: Ajouter les points d’entrée UI
  - Fichier: `lib/screens/preferences/preferences_screen.dart`
  - Action: ajouter une carte ou `ListTile` “Send feedback” visible à tous et un lien “Feedback admin” visible uniquement si admin.

- [ ] Tâche 13: Ajouter un point d’entrée public hors session
  - Fichier: `lib/auth/auth_gate.dart`
  - Action: ajouter un lien discret vers `Routes.feedback` depuis l’écran de sign-in.

- [ ] Tâche 14: Ajouter les dépendances audio Flutter
  - Fichier: `pubspec.yaml`
  - Action: ajouter `record` pour l’enregistrement et `just_audio` pour la lecture.
  - Notes: réutiliser `http` déjà présent pour l’upload du blob à l’upload URL Convex.

- [ ] Tâche 15: Autoriser le micro sur le web déployé
  - Fichier: `vercel.json`
  - Action: passer `Permissions-Policy` de `microphone=()` à une valeur autorisant l’origine de l’app, par exemple `microphone=(self)`.

- [ ] Tâche 16: Autoriser le micro côté Android
  - Fichier: `android/app/src/main/AndroidManifest.xml`
  - Action: déclarer `android.permission.RECORD_AUDIO`.
  - Notes: ce fichier n’est pas actuellement versionné dans ce repo; appliquer cette étape dans le host Android réellement utilisé au build si nécessaire.

- [ ] Tâche 17: Ajouter l’UI et la gestion d’erreurs audio web/Android
  - Fichier: `lib/screens/feedback/feedback_screen.dart`
  - Action: gérer permission refusée, indisponibilité du micro, re-record, annulation, durée max et fallback texte.

- [ ] Tâche 18: Ajouter le formatage et les helpers d’affichage
  - Fichier: `lib/utils/date_utils.dart`
  - Action: compléter si nécessaire avec un format date+heure plus utile pour la vue admin.

- [ ] Tâche 19: Documenter la nouvelle variable d’environnement
  - Fichier: `README.md`
  - Action: documenter `FEEDBACK_ADMIN_EMAILS` et la présence du flux feedback.

- [ ] Tâche 20: Régénérer les artefacts si nécessaire
  - Fichier: `/home/claude/tubeflow/packages/backend/convex/_generated/*`
  - Action: régénérer les bindings Convex après ajout du module backend.
  - Notes: seulement si le workflow de l’équipe versionne ces fichiers générés.

## UI v1 attendue

### Écran feedback public

- Un header simple: “Send feedback”.
- Un switch ou segmented control: `Text` / `Audio`.
- En mode texte:
  - champ multiligne;
  - bouton `Send`.
- En mode audio:
  - bouton `Record`;
  - compteur de durée;
  - boutons `Stop`, `Record again`, `Send`;
  - champ texte optionnel “Add context”.
- Un texte d’aide indiquant que le feedback peut être envoyé anonymement si l’utilisateur n’est pas connecté.
- Snackbars d’erreur via `showErrorSnackBar`.

### Écran admin

- AppBar `Feedback Admin`.
- Filtres simples `All / Unread / Text / Audio`.
- Liste en cards ou `ListTile` comme `hidden_screen.dart`.
- Métadonnées visibles:
  - date + heure;
  - plateforme;
  - locale;
  - email utilisateur si dispo, sinon `Anonymous`;
  - build commit court si dispo.
- Pour l’audio:
  - bouton play/pause;
  - durée affichée.
- CTA `Mark as read` seulement si `status == new`.

## Critères d’acceptation

- [ ] CA 1: Given un utilisateur connecté sur web ou Android, when il envoie un feedback texte, then une entrée `feedbackEntries` est créée avec `type = "text"`, `status = "new"`, son `userId` si disponible et son email si résolu.

- [ ] CA 2: Given un utilisateur non connecté, when il ouvre `/feedback` et envoie un feedback texte, then l’entrée est créée sans auth et apparaît dans l’admin comme anonyme.

- [ ] CA 3: Given un utilisateur connecté ou non, when il enregistre puis envoie un feedback audio, then le client obtient une upload URL, upload le blob, récupère un `storageId`, crée l’entrée backend et l’admin peut lire l’audio via `audioUrl`.

- [ ] CA 4: Given le déploiement web Vercel mis à jour, when un utilisateur autorise le micro dans le navigateur, then l’enregistrement audio fonctionne depuis l’app web.

- [ ] CA 5: Given le header Vercel n’est pas mis à jour ou que l’utilisateur refuse le micro, when il tente un audio feedback sur web, then l’UI affiche une erreur claire et propose le fallback texte.

- [ ] CA 6: Given un utilisateur allowlisté, when il ouvre l’écran admin, then il voit la liste triée du plus récent au plus ancien et peut filtrer `All / Unread / Text / Audio`.

- [ ] CA 7: Given un utilisateur connecté mais non allowlisté, when il force la route `/feedback/admin`, then l’écran n’expose aucune donnée et affiche `Access denied`.

- [ ] CA 8: Given un admin allowlisté, when il marque un feedback comme lu, then `status` passe à `reviewed`, `reviewedAt` est renseigné et l’entrée disparaît du filtre `Unread`.

- [ ] CA 9: Given un utilisateur connecté, when il ouvre `Preferences`, then il voit un point d’entrée vers le formulaire feedback et, s’il est admin, un lien additionnel vers l’admin feedback.

- [ ] CA 10: Given un utilisateur non connecté, when il arrive sur l’écran de sign-in, then il peut ouvrir le formulaire feedback sans se connecter.

- [ ] CA 11: Given un feedback envoyé, when il est consulté en admin, then la plateforme, la locale et les métadonnées de build sont visibles si elles ont été envoyées.

- [ ] CA 12: Given une tentative d’upload audio invalide ou trop grosse, when `feedback:createAudio` est appelé, then la mutation refuse l’entrée et ne laisse pas un feedback invalide consultable dans l’admin.

## Stratégie de test

Automatisé:

- Pas de harness de test déjà en place côté frontend Flutter ni côté backend Convex.
- Pour cette v1, la vérification automatique minimale reste:
  - analyse statique Dart;
  - génération Convex sans erreur;
  - build web sans erreur.

Manuel:

- Tester texte authentifié.
- Tester texte anonyme.
- Tester audio authentifié sur web.
- Tester audio anonyme sur web.
- Tester audio sur Android.
- Tester refus permission micro.
- Tester admin allowlisté.
- Tester admin non allowlisté.
- Tester route forcée admin.
- Tester fallback texte après échec audio.

## Dépendances

- Flutter package `record`
- Flutter package `just_audio`
- `http` déjà présent dans `pubspec.yaml`
- Convex File Storage via `ctx.storage.generateUploadUrl()` et `ctx.storage.getUrl()`

## Risques

- Le plus gros risque fonctionnel côté web est le header `Permissions-Policy` actuel qui bloque le micro.
- Le plus gros risque sécurité/abuse est l’upload audio public anonyme; v1 reste sans rate limiting ni anti-spam.
- Un upload réussi sans mutation finale peut laisser des blobs orphelins dans Convex storage; acceptable en v1 mais à surveiller.
- L’admin dépend d’une allowlist email et donc d’une résolution d’email fiable côté serveur.
- Le module Android natif n’est pas versionné complètement dans ce repo; le changement de permission micro doit être appliqué dans le host Android réellement utilisé.
- L’app n’a pas aujourd’hui de locale globale; la valeur `locale` envoyée sera “best effort” à partir des préférences ou de la locale système.

## Résumé exécutable

Spec: Feedback App + Admin v1
─────────────────────────
Tâches: 20
Critères: 12
Frontend files: `lib/app/router.dart`, `lib/providers/mutations.dart`, `lib/providers/providers.dart`, `lib/screens/preferences/preferences_screen.dart`, `lib/auth/auth_gate.dart`, `lib/screens/feedback/*`, `lib/models/*`, `pubspec.yaml`, `vercel.json`
Backend files: `/home/claude/tubeflow/packages/backend/convex/schema.ts`, `/home/claude/tubeflow/packages/backend/convex/feedback.ts`
─────────────────────────

## Prochaine étape

- Lancer `/sf-start Feedback App + Admin v1` pour implémenter la spec.
- Pendant l’implémentation, traiter d’abord les fondations backend et routing public avant l’UI audio.
