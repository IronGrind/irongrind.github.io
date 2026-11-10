# Current ERD files

- **05-gym-erd-editable.drawio** — editable diagrams.net source for the 12-table public-schema ERD.
- **05-gym-erd-editable.svg** — matching vector output.
- **_Sources/05-gym-erd-public-preview.html** — browser preview of the public-only ERD.
- **_Archive/Previous ERD Versions/05-gym-erd-complete-with-private.drawio / .svg** — preserved all-21-table draft.

The main ERD focuses on the 12 public tables and their 18 declared foreign-key relationships. This preserves the simpler public business layout. The nine private application tables remain documented in the Chapter 3 relationship panels and the administrator/member security supplements. Together, the Chapter 3 schema materials cover 21 application-owned tables, 224 fields, and 33 declared foreign keys.

The public diagram uses selected columns for readability; use `_Sources/schema-visualizer.json` and the Chapter 3 data dictionary for the full field list. Supabase-managed Auth tables appear only as relationship references. Other Supabase-managed schemas are outside the application-owned ERD scope.

The model is based on the user-supplied Supabase public-schema context and full pgAdmin export, reconciled with checked-in migrations through `20261110000006`. This is repository/documentation evidence, not direct live database introspection. Use `Documentations/Tools/build-public-schema-erd.mjs` to restore the editable and SVG files from the archived public-only source.

The simplified public overview remains a project reference asset. Chapter 3 retains its separate physical relationship panels and private security supplements; the Word figures were not replaced by this standalone public-only file.
