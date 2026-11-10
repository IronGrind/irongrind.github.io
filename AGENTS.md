# Project maintenance

For every material application, schema, security, workflow, or deployment change, update both:
- `Documentations/Defense/Capstone Study and Defense Notes.md`
- `Documentations/Defense/Capstone Presentation.md` (slide content and speaker notes)

Record what changed, why, affected modules, validation and deployment status. Explain verified history from repository evidence; do not invent dates, evaluations or production outcomes. Keep pending work distinct from deployed behavior. Update the implementation guide when setup steps change. The user explicitly requested this ongoing maintenance.

For Supabase schema changes, make the SQL a timestamped file under `supabase/migrations` and apply it through the VS Code terminal. First run `npx.cmd supabase db push --linked --dry-run`, confirm the linked project and pending migrations, then run `npx.cmd supabase db push --linked` and confirm the prompt. Do not use the SQL Editor as a substitute for applying a repository migration.
