# terriflux.github.io

Vitrine en ligne des versions OpenSankey.

Chaque démo est un **build statique** de l'exemple React correspondant
(`examples/<version>/<viewer|editor>/`), précompilé par GitHub Actions et
servi sur GitHub Pages. Le visiteur voit instantanément la démo tourner ;
s'il veut modifier le code, un lien "éditer ↗" ouvre l'exemple dans
CodeSandbox.

## Architecture

```
GitLab su-model/opensankey ──(push mirror)──> GitHub TerriFlux/opensankey
                                                       │
                                                       ▼ checkout par GH Actions
                                              npm install + npm run build
                                                       │
                                                       ▼ artefact
                                            terriflux.github.io/<v>/<kind>/
                                                       │
                                                       ▼
                                       Vitrine racine = iframes locaux
```

## Structure du repo

- [`index.html`](./index.html) — vitrine racine, listée par version. Référence les builds dans `./<v>/<kind>/`.
- [`.github/workflows/build.yml`](./.github/workflows/build.yml) — build et déploiement Pages :
  1. checkout TerriFlux/opensankey
  2. pour chaque exemple, `npm install && npm run build`
  3. assemblage dans `public/`
  4. déploiement sur GitHub Pages

Rien d'autre n'est commité — les builds sont régénérés à chaque exécution du workflow.

## Ajouter une nouvelle version (ex. 1.1.3)

1. Vérifier que `open-sankey@1.1.3` est publié sur npm.
2. Ajouter `1.1.3/viewer` et `1.1.3/editor` à `EXAMPLE_MATRIX` dans [`build.yml`](./.github/workflows/build.yml).
3. Dupliquer une `<section class="version">` dans [`index.html`](./index.html), remplacer les numéros.
4. Push → le workflow rebuilde et redéploie.

## Setup initial (à faire une fois)

1. Créer le repo `TerriFlux/terriflux.github.io` (public, vide).
2. Pousser ce contenu sur `main`.
3. Settings → Pages → Source = **GitHub Actions**.
4. Le premier run du workflow déploie ; URL finale : `https://terriflux.github.io`.

## Déclenchement du workflow

- À chaque push sur `main` de ce repo.
- Manuellement via Actions → "Build & deploy demos" → "Run workflow".
- Tous les jours à 6h UTC (au cas où le mirror GitLab→GitHub a apporté du nouveau code sans qu'on push ce repo). Ce cron peut être retiré si tu préfères pousser à la main.

## Test local

Pour tester `index.html` (sans les builds, donc les iframes seront 404) :

```powershell
cd d:\tmp\terriflux-pages
D:\miniconda3\python.exe -m http.server 8000
start http://localhost:8000/
```

Pour tester un build complet en local, c'est plus simple de laisser CI le faire et regarder le déploiement Pages.
