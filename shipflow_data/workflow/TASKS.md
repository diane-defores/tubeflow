# Tasks — replayglowz

## Audit: Deps

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Remove beta auth packages `clerk_flutter` / `clerk_auth` and replace the disabled path with stable Firebase Auth | ✅ done |
| ✅ | Remove unused Flutter codegen packages: `riverpod_annotation`, `build_runner`, and `riverpod_generator` | ✅ done |
| ✅ | Upgrade direct non-beta dependencies to latest resolvable versions, including `go_router`, `sentry_flutter`, and `flutter_lints` | ✅ done |
| 🟠 | Validate Firebase Auth, Convex token acceptance, and YouTube OAuth on the deployed Vercel/Convex environment | ⏳ pending `/sf-prod` |

## Documentation Governance

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Align root and subproject ShipFlow docs under canonical `shipflow_data/` paths | ✅ done |
