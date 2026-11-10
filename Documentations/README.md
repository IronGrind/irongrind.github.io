# Documentation files

For the latest one-trusted-browser administrator sign-in, use **Defense/Trusted Administrator Device Guide.md**. It supersedes the earlier MFA-only/session-approval rollout instructions and includes the pending migration, new Edge Function, recovery behavior and supporting-schema additions.

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

Chapter 3's DFD section uses Figure 3 for the complete nine-process operational DFD and Figure 3a for the administrator login-security stores. The simplified DFD overview source `03-dfd-overview.png` remains available for internal reference but is intentionally omitted from the paper; `Tools/build-dfd-overview.ps1` can regenerate that source. `Tools/apply-summary-dfd.ps1` is a historical insertion workflow and should not be used to prepare the current paper. Per the paper revision, the public-schema overview ERD is also omitted; the full data dictionary and written relationship descriptions remain. Figure 5 is the administrator-security schema supplement. The complete dictionary covers eighteen application-owned tables and 201 fields. `03a-login-security-stores` and `05a-administrator-security-schema` have matching editable `.drawio` and `.svg` files. They supplement the nine-function DFD and schema documentation; they are not duplicate versions.

From the project root, verify the chapters with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'Documentations/Tools/verify-chapters.ps1'
```
