---
artifact: brand_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: tubeflow-site
created: "2026-04-25"
updated: "2026-04-25"
status: draft
source_skill: sf-docs
scope: brand
owner: unknown
confidence: low
risk_level: medium
security_impact: unknown
docs_impact: yes
brand_voice: unknown
trust_posture: unknown
depends_on: []
supersedes: []
evidence: []
next_review: "unknown"
next_step: /sf-docs audit BRANDING.md
---
# Branding - TubeFlow

## Nom

**TubeFlow** : Tube + Flow

- **Tube** : reference directe a la video (YouTube, le "tube" numerique)
- **Flow** : flux d'apprentissage continu, etat de flow pendant l'etude

## Tagline

> Apprends activement, note intelligemment

## Identite visuelle

### Interface split

Le pattern fondamental de TubeFlow est l'interface divisee :

- **Gauche** : lecteur video (zone de visionnage)
- **Droite** : panneau de notes (zone de travail)
- **Mobile** : bascule entre les deux vues

### Couleurs

- **Tons neutres** : fond sombre ou clair, pas de distraction pendant le visionnage
- **Accent principal** : couleur vive pour les timestamps et les highlights
- **Accent secondaire** : couleur complementaire pour les actions (sauvegarder, exporter)
- **Dark mode** supporte nativement

### Palette indicative

| Role | Usage |
|------|-------|
| Background | Fond principal, neutre |
| Surface | Panneaux, cards |
| Text | Contenu principal |
| Timestamp | Marqueurs temporels, cliquables (accent) |
| Highlight | Notes mises en avant, selections |
| Muted | Texte secondaire, bordures |

## Typographie

- **System fonts** : performance maximale, pas de chargement de polices
- **Monospace pour les timestamps** : distinction visuelle claire (`font-mono`)
- **Hierarchie** : titres des videos en `font-semibold`, notes en `font-normal`
- Echelle Tailwind standard

## Iconographie

- **Librairie** : Lucide
- **Style** : Outline, coherent avec l'ecosysteme Flowz
- **Icons cles** :
  - Play/Pause : controle video
  - Clock : timestamps
  - Pen : edition de notes
  - Bookmark : favoris / playlists
  - Download : export

## Valeurs de marque

| Valeur | Manifestation |
|--------|---------------|
| Apprentissage actif | Chaque interaction encourage la prise de notes |
| Organisation | Notes structurees, playlists, recherche |
| Efficacite | Retrouver n'importe quel passage en 1 clic |
| Simplicite | Interface minimale, focus sur le contenu |

## Experience utilisateur

### Modes d'utilisation

- **Mode standard** : video a gauche, notes a droite (desktop)
- **Focus mode** : video plein ecran avec overlay de notes semi-transparent
- **Mode revision** : liste des notes sans video, avec timestamps cliquables pour revoir les passages

### Export

- Notes exportables en Markdown
- Timestamps preserves dans l'export
- Format compatible avec Obsidian, Notion, et autres outils PKM

### Interactions cles

- **Clic sur timestamp** : seek instantane dans la video
- **Raccourci clavier** : creer une note au timestamp courant (pendant le visionnage)
- **Auto-pause optionnelle** : pause la video pendant la saisie
- **Drag & drop** : reorganiser les notes dans une playlist
