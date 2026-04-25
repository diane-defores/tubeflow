---
artifact: business_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: tubeflow-site
created: "2026-04-25"
updated: "2026-04-25"
status: draft
source_skill: sf-docs
scope: business
owner: unknown
confidence: low
risk_level: medium
security_impact: unknown
docs_impact: yes
target_audience: unknown
value_proposition: unknown
business_model: unknown
market: unknown
depends_on: []
supersedes: []
evidence: []
next_review: "unknown"
next_step: /sf-docs audit BUSINESS.md
---
# Business - TubeFlow

## Mission

Transformer la consommation passive de videos en apprentissage actif.

## Proposition de valeur

Prendre des notes horodatees pendant le visionnage de videos, les retrouver instantanement, les organiser par playlist. Un clic sur un timestamp ramene directement au passage de la video : le contexte n'est jamais perdu.

## Business Model : Freemium

### Gratuit

- Notes illimitees
- 3 playlists maximum
- Lecture video basique (YouTube et plateformes supportees par react-player)
- Recherche dans ses notes

### Premium

- Playlists illimitees
- Resumes automatiques par IA
- Export des notes (Markdown, PDF)
- Collaboration (notes partagees sur une video)
- Synchronisation cross-device complete
- Mode hors-ligne (notes en cache)

## Persona principal

### "L'Apprenant Actif"

Etudiants, chercheurs, autodidactes qui regardent des cours, conferences et tutoriels en ligne. Ils veulent retenir ce qu'ils regardent, pas juste consommer passivement.

**Caracteristiques :**

- Regarde 3 a 10 videos educatives par semaine
- Prend deja des notes (papier, Notion, fichier texte) mais perd le lien avec la video
- Revise regulierement ses notes
- Frustre par l'impossibilite de retrouver "ce passage a la minute 23"

**Segments secondaires :**

- Createurs de contenu qui analysent des videos concurrentes
- Professionnels en formation continue
- Journalistes et veilleurs qui annotent des sources video

## Marche

- **Secteur** : EdTech, video-based learning
- **Opportunite** : YouTube = 2B+ utilisateurs, les cours en ligne explosent (Coursera, Udemy, YouTube Education)
- **Probleme** : Aucune solution native pour lier notes et timestamps de maniere fluide
- **Tendance** : Apprentissage en ligne en croissance continue, demande de productivite accrue

## Avantage concurrentiel

| Avantage | Detail |
|----------|--------|
| Notes liees au timestamp | Retrouver le contexte en 1 clic |
| Temps reel | Synchronisation instantanee via Convex |
| Multi-plateforme | Web (Next.js) + mobile (Expo, a venir) |
| UX focus | Interface split video/notes, pas de distraction |
| Ecosysteme Flowz | Auth partagee (Clerk), integration future avec NoteFlowz |

## Go-to-Market

1. **Phase 1 (actuel - MVP)** : App web, fonctionnalites de base (notes + timestamps + playlists)
2. **Phase 2** : Extension navigateur pour annoter directement sur YouTube
3. **Phase 3** : App mobile (React Native/Expo)
4. **Phase 4** : Fonctionnalites IA (resumes, extraction de concepts)

## Metriques cles

| Metrique | Description |
|----------|-------------|
| Notes creees | Volume d'engagement |
| Videos annotees | Adoption de la fonctionnalite coeur |
| Temps gagne en revision | Valeur percue (enquete utilisateur) |
| Retention J7 / J30 | Fidelisation |
| Conversion free-to-premium | Monetisation |
| Playlists creees | Profondeur d'usage |
