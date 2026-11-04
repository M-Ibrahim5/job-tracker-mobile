# JobTrail
Monorepo: backend/ (Java 21 + Spring Boot 4 + Maven microservices + MySQL), app/ (Flutter). Docs in docs/ are the source of truth.
- Start with docs/00-README.md; then the session file you were asked to implement (docs/sessions/).
- Contract: docs/API.md, docs/DATABASE.md. UI: docs/DESIGN.md.
- Backend checks: cd backend && mvn verify
- App checks: cd app && dart format . && flutter analyze && flutter test
- No print/System.out in committed code (use a logger). Strings in app via core/constants.
- Enum values are camelCase strings identical across DB, API and Dart.
