# Current ERD files

- **05-gym-erd-editable.drawio** — editable diagrams.net source for the 12-table public-schema ERD.
- **05-gym-erd-editable.svg** — matching vector output.
- **_Sources/05-gym-erd-public-preview.html** — browser preview of the public-only ERD.
- **_Archive/Previous ERD Versions/05-gym-erd-complete-with-private.drawio / .svg** — preserved all-21-table draft.

The main ERD focuses on the 12 public tables and their 18 declared foreign-key relationships. This preserves the simpler public business layout. The nine private application tables remain defined in the Chapter 3 dictionary and separate administrator/member security references. Together, the Chapter 3 schema materials cover 21 application-owned tables, 224 fields, and 33 declared foreign keys.

The public diagram uses selected columns for readability; use `_Sources/schema-visualizer.json` and the Chapter 3 data dictionary for the full field list. Supabase-managed Auth tables appear only as relationship references. Other Supabase-managed schemas are outside the application-owned ERD scope.

The model is based on the user-supplied Supabase public-schema context and full pgAdmin export, reconciled with checked-in migrations through `20261110000006`. This is repository/documentation evidence, not direct live database introspection. Use `Documentations/Tools/build-public-schema-erd.mjs` to restore the editable and SVG files from the archived public-only source.

The current Chapter 3 manuscript uses this public overview as Figure 5, with selected attributes, a scope explanation and a notation legend. It is not a complete private-schema ERD; the full dictionary and separate security references supply the supporting definitions. The November 11 revision darkens managed-Auth connectors without changing the 18 foreign-key routes or endpoint symbols.
