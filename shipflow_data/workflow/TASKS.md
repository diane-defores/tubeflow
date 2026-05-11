# Tasks — tubeflow-flutter

## Audit: Deps

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Patch `tubeflow_site` Astro/PostCSS XSS advisories by updating `astro` to >= 6.1.6 and `postcss` to >= 8.5.10, then run `npm run build` | 📋 todo |
| 🟠 | Patch `tubeflow_lab` `requests` to >= 2.33.0 and smoke-test OpenAI/Deepgram transcript calls; CVE-2026-25645 is limited-use but affects a direct HTTP package in the worker | 📋 todo |
| 🟡 | Add dependency update automation covering npm, pub, pip, GitHub Actions, and Docker base images with review for major upgrades | 📋 todo |
| 🟡 | Pin package/tool versions more completely: add npm `packageManager`, stabilize Flutter SDK selection in Vercel/GitHub Actions, and add a Python lock or hash strategy for worker images | 📋 todo |
| 🟡 | Review likely unused Flutter deps before removal: `flutter_slidable`, `google_fonts`, `riverpod_annotation`, `build_runner`, and `riverpod_generator` | 📋 todo |
