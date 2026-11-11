# Documentation files

For the latest one-trusted-browser administrator sign-in, use **Defense/Trusted Administrator Device Guide.md**. It supersedes the earlier MFA-only/session-approval rollout instructions and includes the pending migration, new Edge Function, recovery behavior and supporting-schema additions.

New public member registrations also require deployment of `supabase/functions/member-registration` with JWT verification disabled as declared in `supabase/config.toml`. The function creates the Auth user and then inserts the pending application; if the application insert fails, it attempts to remove the new Auth user, which cascades its profile. If cleanup itself fails, staff must remove the incomplete account. Apply migration `20261110000007_restore_registration_application_access.sql` as well: signup needs service-role INSERT/SELECT on membership_applications and the name-validation trigger must execute its private helper safely. Migration 07 is applied to the linked project; no client or Edge Function redeployment was required for that permission repair. Deploy the function before the matching Vercel registration page; the Supabase redirect allowlist must include `https://irongrind.vercel.app/register.html?completeApplication=1`.

- **Defense/** â€” detailed study/defense notes, source code map, separate presentation text and editable PowerPoint with speaker notes, and the administrator MFA deployment/recovery guide. Start with `Defense/Admin MFA Setup and Deployment Guide.md` for setup steps.

- **Chapter 1.docx**, **Chapter 2.docx**, **Chapter 3.docx** â€” the manuscript chapters.
- **Chapter 3 Diagrams/** â€” figure sources; `05-gym-erd-editable.drawio` and `05-gym-erd-editable.svg` are retained as project ERD reference assets, but the simplified public-schema overview is omitted from the current paper.
- **Prototype Screenshots/** â€” 57 updated FEATURES.zip captures, including supplied interface details, and the figure index for Chapter 3's prototype section.
- **Review Notes/** â€” paper reviews and system investigation notes, including `System Error Review.md` and `Chapter 3 Review Notes.md`.
- **Tools/** â€” document formatting, diagram generation, and verification scripts. Historical update scripts are retained for reference; running them may restore older figure styles.
- **Review Evidence/** â€” verification reports and supporting results.
- **Review Previews/** â€” document preview files.
- **Review Backups/** â€” earlier document copies retained for recovery.

Previous ERD versions are in `Chapter 3 Diagrams/_Archive/Previous ERD Versions/`. Generator data is in `Chapter 3 Diagrams/_Sources/`.

Chapter 3 uses the earlier multi-panel figure layout. Figures 3a-e continue the nine-process Gane-Sarson Level 1 DFD, and the DFD store symbols show public application tables only. Authentication records and private security stores are outside that DFD view; the login flow remains Process 1.0. Figures 5a-c show the physical relationships for the existing 15 application tables; Figure 5d supplements them with the three administrator-security tables and their six Auth references. The simplified public-schema overview ERD is omitted. The complete dictionary covers all 18 current application-owned tables, 201 fields and 27 declared foreign keys. The complete Level 1 DFD is also supplied separately as `Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. `Chapter 3 Diagrams/gane-sarson.ps1 -RenderOnly` regenerates the five DFD continuation panels without rewriting the Word file. The administrator-security schema remains available in the ERD supplement. No application or database deployment resulted from the documentation update; final desktop Word pagination review remains pending.

From the project root, verify the chapters with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'Documentations/Tools/verify-chapters.ps1'
```

The latest schema revision adds the three private member browser-security tables from migration 20261110000006 to Chapter 3 as Figure 5e and Tables 24â€“26. Current totals are 21 application-owned tables (12 public, 9 private), 224 fields and 33 declared foreign keys. The new editable figure is `Chapter 3 Diagrams/05b-member-security-schema.drawio`, with matching SVG/PNG. Chapters 1 and 2 retain their existing structure and add the corresponding scope/synthesis passages. These totals supersede the eighteen-table totals in the earlier revision description. Validation covers package structure and dictionary consistency; desktop Word pagination and controlled member browser acceptance remain pending. This documentation update does not deploy application changes.
