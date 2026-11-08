Paper alignment update — November 8, 2026

Updated deliverables: Chapter 1.docx, Chapter 2.docx, and Chapter 3.docx in this folder. Pre-update copies are in Review Backups/paper-update-20261108-212722.

Chapter 1

- Preserved the introduction text and its paragraph order, including the SDG paragraph immediately after the first Background of the Study paragraph. The pre-update and final introduction text were compared and matched.
- Expanded scope coverage for required/duplicate account validation, separate staff name inputs, active operator accounts, separate dashboard and scanner sessions, phone pairing duration, shared paired/pending capacity, and Incomplete attendance.
- Clarified the distinction between approved online renewal requests and direct counter membership transactions.
- Added concise definitions for incomplete attendance, input validation, pending pairing QR, phone pairing, and user session.
- Stated that concurrent-user capacity remains unmeasured.

Chapter 2

- Preserved the separate Literature, Applications, Studies, and Synthesis sections.
- Added technical literature on database access control, session identity, and controlled production/load testing. Platform concepts are distinguished from IronGrind-specific implementation choices.
- Added three official Supabase references, with matching n.d.-a/b/c citations and retrieval dates. The new references use hanging indents and regular text.
- Kept other systems' reported metrics separate from IronGrind's evidence.

Chapter 3

- Added Verification and Evaluation, based on the saved forty-check regression report and the live database lint result. Simulated browser logic, real SDK checks with mocked Auth responses, and isolated PostgreSQL tests are identified accurately.
- Described performance and physical multi-phone validation that still needs to be recorded. No concurrent-user limit, response-time guarantee, completed usability score, or successful physical two-phone test is invented.
- Added the combined paired-plus-pending capacity rule, reserved QR behavior at full capacity, per-installation identity, separate account session scopes, and staff FN/MI/LN form behavior.
- Updated max_pairs and remember_phone dictionary descriptions. Counts remain twelve public tables, three private tables, 174 fields, and twenty total Word tables including five requirements tables.
- Refreshed the generated DFD, role use-case, and physical ERD assets and embedded image relationships.

Verification and limits

verify-chapters.ps1 passed after the changes: document XML, relevant bolding, stale role wording, punctuation, image relationships, SDG placement, new technical citations, updated workflow statements, and dictionary counts were checked. The introduction comparison also passed. Formatting remains regular in body paragraphs, captions, and table data, with bold headings and table headers.

Existing interface images remain prototype illustrations. Current authenticated production screenshots were not captured or substituted. The paper now states their illustrative role. Full Word pagination and page-by-page visual layout remain unverified because the earlier Word automation preview stalled. No claim of guaranteed error-free pagination or complete bibliography verification is made.

Primary technical sources consulted:

- https://supabase.com/docs/guides/deployment/going-into-prod
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/auth/sessions

## Follow-up — November 8, 2026

Chapter 3 now states that members sign in using email, staff and administrators retain username sign-in, and member registration does not collect a separate username. It also documents rejection of numeric characters in person-name fields and clarifies that authorized staff as well as administrators review membership applications. Chapter 1 was rechecked and already described the approval roles correctly. The Chapter 3 XML, figure links, punctuation, and dictionary-count verification passed. Full Word pagination remains unverified.

Identifier wording was checked again during the login-page review. Chapter 1 now distinguishes duplicate email validation from username checks where those identifiers are supported. Chapter 3's nullable username fields now distinguish staff/admin sign-in from legacy member/application values retained for compatibility; new members use email and do not receive a username. Chapter verification now checks these statements.

## Chapter 2 source and citation review - November 9, 2026

Chapter 2 was checked against the cited original pages and revised where wording could overstate or misidentify a source. Y Combinator's product claim was replaced with Supabase's official platform documentation; the QR Code statement now cites ISO/IEC 18004:2024; the DeLone and McLean review count was corrected to 102 Scopus-indexed scholarly articles and conference papers; and the Philippine privacy-law statements now identify the relevant Act sections. Commercial product functions are identified as vendor-advertised. A complete Chapter 2 References list was added for its in-text citations.

The GymFlow source remains explicitly identified as an author-posted project report hosted on ResearchGate, with metrics labeled as author-reported and not peer-reviewed journal findings. The review found inconsistent DOI metadata between its ResearchGate and Zenodo records, so the chapter reference links to the report without asserting a DOI. The source-audit details and verification record are in Chapter Review Notes.md and Review Evidence/Chapter Review Verification.txt. This review confirms source identity and claim alignment; it does not independently validate the underlying studies' methods or results.
