# Documentation files

For the latest one-trusted-browser administrator sign-in, use **Defense/Trusted Administrator Device Guide.md**. It supersedes the earlier MFA-only/session-approval rollout instructions and includes the pending migration, new Edge Function, recovery behavior and supporting-schema additions.

New public member registrations also require deployment of `supabase/functions/member-registration` with JWT verification disabled as declared in `supabase/config.toml`. The function creates the Auth user and then inserts the pending application; if the application insert fails, it attempts to remove the new Auth user, which cascades its profile. If cleanup itself fails, staff must remove the incomplete account. Deploy the function before the matching Vercel registration page; the Supabase redirect allowlist must include `https://irongrind-github-io.vercel.app/register.html?completeApplication=1`.

- **Defense/** — detailed study/defense notes, source code map, separate presentation text and editable PowerPoint with speaker notes, and the administrator MFA deployment/recovery guide. Start with `Defense/Admin MFA Setup and Deployment Guide.md` for setup steps.

- **Chapter 1.docx**, **Chapter 2.docx**, **Chapter 3.docx** — the manuscript chapters.
- **Chapter 3 Diagrams/** — figure sources; `05-gym-erd-editable.drawio` and `05-gym-erd-editable.svg` are retained as project ERD reference assets, but the simplified public-schema overview is omitted from the current paper.
- **Prototype Screenshots/** — 27 complete interface captures, selected enlarged form details, and the figure index for Chapter 3's prototype section.
- **Review Notes/** — paper reviews and system investigation notes, including `System Error Review.md` and `Chapter 3 Review Notes.md`.
- **Tools/** — document formatting, diagram generation, and verification scripts. Historical update scripts are retained for reference; running them may restore older figure styles.
- **Review Evidence/** — verification reports and supporting results.
- **Review Previews/** — document preview files.
- **Review Backups/** — earlier document copies retained for recovery.

Previous ERD versions are in `Chapter 3 Diagrams/_Archive/Previous ERD Versions/`. Generator data is in `Chapter 3 Diagrams/_Sources/`.

Chapter 3 uses the earlier multi-panel figure layout. Figures 3a-e continue the nine-process Gane-Sarson Level 1 DFD; Figure 3f isolates the administrator login-security stores. Figures 5a-c show the physical relationships for the existing 15 application tables; Figure 5d supplements them with the three administrator-security tables and their six Auth references. The simplified public-schema overview ERD is omitted. The complete dictionary still covers all 18 current application-owned tables, 201 fields and 27 declared foreign keys. The complete Level 1 DFD is also supplied separately as `Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. `Chapter 3 Diagrams/gane-sarson.ps1 -RenderOnly` regenerates the five DFD continuation panels without rewriting the Word file. The `03a-login-security-stores` and `05a-administrator-security-schema` sources have matching editable `.drawio` and `.svg` files. No application or database deployment resulted from the document update; desktop Word pagination review remains pending.

From the project root, verify the chapters with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'Documentations/Tools/verify-chapters.ps1'
```

The latest schema revision adds the three private member browser-security tables from migration 20261110000006 to Chapter 3 as Figure 5e and Tables 24–26. Current totals are 21 application-owned tables (12 public, 9 private), 224 fields and 33 declared foreign keys. The new editable figure is `Chapter 3 Diagrams/05b-member-security-schema.drawio`, with matching SVG/PNG. Chapters 1 and 2 retain their existing structure and add the corresponding scope/synthesis passages. These totals supersede the eighteen-table totals in the earlier revision description. Validation covers package structure and dictionary consistency; desktop Word pagination and controlled member browser acceptance remain pending. This documentation update does not deploy application changes.
