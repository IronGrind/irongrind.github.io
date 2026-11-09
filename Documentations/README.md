# Documentation files

- **Chapter 1.docx**, **Chapter 2.docx**, **Chapter 3.docx** — the manuscript chapters.
- **Chapter 3 Diagrams/** — figures; use `05-gym-erd-editable.drawio` to edit the current ERD and `05-gym-erd-editable.svg` for its vector figure.
- **Review Notes/** — paper reviews and system investigation notes, including `System Error Review.md` and `Chapter 3 Review Notes.md`.
- **Tools/** — document formatting, diagram generation, and verification scripts. Historical update scripts are retained for reference; running them may restore older figure styles.
- **Review Evidence/** — verification reports and supporting results.
- **Review Previews/** — document preview files.
- **Review Backups/** — earlier document copies retained for recovery.

Previous ERD versions are in `Chapter 3 Diagrams/_Archive/Previous ERD Versions/`. Generator data is in `Chapter 3 Diagrams/_Sources/`.

Chapter 3 still contains its previously embedded ERD. Organizing these files does not replace that figure.

From the project root, verify the chapters with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'Documentations/Tools/verify-chapters.ps1'
```
