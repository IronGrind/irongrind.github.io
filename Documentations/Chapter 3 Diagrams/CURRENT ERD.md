# Current ERD files

- **05-gym-erd-editable.drawio** — editable diagrams.net source for the complete application-owned database ERD.
- **05-gym-erd-editable.svg** — matching vector output.
- **_Sources/05-gym-erd-complete-preview.html** — full-sheet browser preview; zoom the SVG for field-level reading.
- **_Archive/Previous ERD Versions/05-gym-erd-public-only.drawio / .svg** — preserved prior public-only version for comparison.

The complete ERD contains 21 application-owned tables (12 `public`, 9 `private`), 224 fields, and 33 declared foreign keys. It shows `auth.users` and `auth.sessions` only as managed reference nodes; Supabase-owned `auth`, `storage`, `realtime`, and migration tables are not application-owned entities in this ERD.

The model in `_Sources/schema-visualizer.json` uses the user-supplied Supabase public-schema context and full pgAdmin schema export, reconciled with checked-in migrations through `20261110000006`. This is repository/documentation evidence, not fresh live-schema introspection. Use `Documentations/Tools/build-complete-application-erd.mjs` to regenerate the editable and SVG outputs.

Chapter 3's submitted Word manuscript retains its existing physical relationship panels and separate administrator/member security supplements. This complete ERD is an additional consolidated reference; it does not claim that the Word figures were replaced or that application/schema deployment changed.
