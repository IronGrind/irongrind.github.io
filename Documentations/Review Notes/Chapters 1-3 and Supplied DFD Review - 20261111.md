# Chapters 1–3 and supplied DFD review

Review date: November 11, 2026. Verdict: the main business scope is consistent, but the manuscript is **not yet fully aligned with the latest implementation**. It needs targeted corrections, not a new topic, objectives, or a complete rewrite.

## What was reviewed and changed

Reviewed Chapter 1.docx, Chapter 2.docx, Chapter 3.docx, the combined manuscript, current migration/source evidence, and the user's `final dfd2.drawio (1).svg`. The paragraph identifiers below refer to the **pre-edit extraction snapshots** in `Review Evidence/Current Manuscript Review/`, not Word page numbers.

At the user's explicit selection, replaced the five existing Level 1 DFD panels in **Chapter 3 and the combined manuscript** with the supplied complete SVG. The original diagram was preserved byte-for-byte, embedded as a vector with a PNG fallback. A source copy and its editable embedded draw.io model are in `Chapter 3 Diagrams/03-user-supplied-dfd.svg` and `.drawio`. Its arrows were not silently corrected. Updated the DFD caption and three associated explanation paragraphs to refer to one supplied figure and its actual public-table labels.

Chapter 1 and Chapter 2 were not edited. Other manuscript prose and tables were not rewritten. The DFD replacement passed a preservation comparison before TOC refresh: body content outside the DFD replacement and its four text paragraphs was unchanged, and unrelated package parts were byte-identical. All tables and the 57 prototype figures were retained.

Desktop Word repaginated a temporary copy of the revised combined manuscript and reported **168 pages**. Its **38 existing TOC entries** were verified against the original heading labels and bookmark targets, then only their cached page-reference values were transferred back. Chapter 1 begins at 7, Chapter 2 at 22 and Chapter 3 at 29. The prior helper's fixed expectation of 39 entries and its hardcoded 150-page report were historical assumptions; the helper now checks actual entry counts and reads Word's reported page total. A full visual print-layout approval is still separate.

Backups: `Review Backups/supplied-dfd-20261111-175809/` and `Review Backups/toc-refresh-20261111-175930/`. Verification: `Review Evidence/Current Manuscript Review/DFD Preservation Verification.txt` and `Review Evidence/Manuscript TOC Refresh Verification.txt`.

## Corrections needed before calling the paper final

| Priority | Location | Finding | Required correction |
|---|---|---|---|
| High | Chapter 1 P0042–P0043; Chapter 3 P0234–P0236 | Administrator browser trust is still described as authorizing scanner login and revoking both dashboard and scanner scopes. | Limit administrator browser-key/TOTP trust to the website. Describe the password-only attendance session separately. Website trust transfer/forget now preserves the independent scanner scope. |
| High | Chapter 3 P0267 and data dictionary, Tables 6–26 | The model still says 21 tables / 224 fields / 33 FKs and ends before the new scanner tables. | Reconcile the declared scope with migrations 20261111000001–03. The checked-in 21-table model plus the two new tables yields **23 application tables, 235 fields and 38 declared FKs**: 12 public and 11 private. These are repository-derived counts, not a fresh live-schema inspection. |
| High | Supplied DFD, process 5.0 and D12 | The SVG depicts an active “Paired device history” write into `mobile_attendance_scan_events`. | This is retained legacy storage, not a current authenticated scanner dependency. Remove or explicitly mark that inactive path in a future diagram revision. Do not describe it as current implemented recording. |
| High | Supplied DFD, process 9.0 and D9 | The graphic routes “Activity logs” between the vertically arranged processes, with a downward event path from the Activity Logs process to the log store. The intended read-only viewer is not clearly represented by a store-to-viewer read. | Draw operational audit writes toward D9 and a **D9 → 9.0** read of recorded events. Keep the administrator's filter input and filtered-results output. Do not imply that the log viewer performs business operations or that report generation must pass through an event-processing chain. |
| Medium | Supplied DFD at manuscript width | The SVG is 5527×3755 with many long crossing routes and very small labels when reduced to the existing 6-inch figure width. | The embedded vector supports zoom, but ordinary paper-size readability needs a printed check. A larger-sheet appendix or readable detail panels may be needed. Vector sharpness alone does not make tiny print labels readable. |
| Medium | Chapter 3 P0019–P0024, verification/evaluation | Functional verification is described carefully, but a complete stakeholder-evaluation protocol is not supplied here. | If required by the institution, specify the actual intended respondents/sampling, instrument, tasks, consent/data handling and analysis criteria. Do not invent participant counts, survey scores, interviews or completed evaluation. |
| Medium | Chapter 1 P0006 versus Chapter 2 P0014/P0032 | Chapter 1 cites GYMMANAGER as n.d.-a and n.d.-b, while the current reference list has a single n.d. entry. | Use matching suffixes throughout, or restore and distinguish the two actual sources. |
| Medium | Chapter 1 significance P0049–P0052 | “Benefited,” “helped,” and “recorded accurately” can read as measured outcomes despite the explicit pending-evaluation limitations. | Prefer “is intended to support,” or attach actual evidence if an observed benefit is being asserted. |
| Medium | Chapter 3 P0018/P0020–P0021 and prototype descriptions | Historical deployment/check reports and captured interface states can be mistaken for coverage of later scanner revisions. | Keep the existing dated history, then separately state the current revision and evidence limits. Supplied screenshots remain interface-state evidence, not proof of current deployment, completed camera tests or measured usability. |
| Low | Chapter 3 P0125–P0136 | “500 GB available” appears as an indicative hardware baseline although no client storage requirement was measured. | Separate a development-workstation example from the equipment required to use a cloud-backed browser application. The existing non-benchmark disclaimer helps, but the row is still easy to misread. |

The supplied diagram has the expected **nine numbered processes (1.0–9.0)**, three external user groups, and D1–D12 public table labels. Those structural matches are useful, but do not resolve its event-flow and legacy-table discrepancies. It was inserted because the user selected that source, not because every arrow was certified implementation-exact.

## Chapter-by-chapter assessment

### Chapter 1

The background, problem, objectives and scope agree on membership/application review, QR attendance, product inventory and in-person sales, and administrative reporting. Staff/administrator online-request approval and member-only personal-profile edits are consistently distinguished. In-person payment recording is separated from online payment processing. The thirty-day pairing period is distinguished from the short-lived setup QR and the shared paired-plus-pending slot limit.

The specific corrections are the administrator/scanner security boundary, citation suffixes, and benefits wording above. The client location, existing manual practices, and reported planning/interview activities should be supported by the proponents' actual client evidence; this review did not independently verify those real-world facts.

### Chapter 2

The separation of technical literature, commercial applications and related studies is appropriate. Results from other systems are explicitly kept separate from IronGrind evaluation. The source review confirmed these key items against publisher/author pages:

- Al-Kofahi et al.: title, authors, 2025 publication, volume/pages, review of 102 articles/conference papers and the stated leading internal predictors match the [publisher record](https://www.inderscience.com/info/inarticle.php?artid=145551).
- Villanueva et al.: title, authors, 2025 publication, gym setting and proposed QR-supported operational scope match the [journal article](https://ojs.southfloridapublishing.com/ojs/index.php/jdev/article/view/5151).
- Bulaclac et al.: the 80%, 95% and 88/100 values attributed in Chapter 2 appear in the [publisher's findings](https://www.informingscience.org/Publications/5650). They remain results for that separate cashless-system study.
- ISO/IEC 18004:2024 exists and addresses QR symbology, as shown by the [ISO record](https://www.iso.org/standard/83389.html). This does not establish IronGrind's measured scan performance.
- Babili's GymFlow metrics appear in the [author-posted preprint](https://www.researchgate.net/publication/404417460_An_Integrated_Smart_Management_System_for_Fitness_Centers). The manuscript correctly qualifies it as author-posted rather than independently verified or peer-reviewed. It is a weaker source than the publisher-hosted studies and should not be used as proof of achievable IronGrind performance.

This was a targeted reference validation, not certification of every statement, hyperlink, legal conclusion or source in the bibliography. The privacy discussion does not establish legal compliance. Correct the GYMMANAGER suffix mismatch identified in Chapter 1, and retain consistent citation style across the manuscript.

### Chapter 3

Requirements, role boundaries, the nine main functions and business data-flow explanations mostly agree. Pairing, operator sign-in and installation are properly treated as separate concepts. The planned Gantt schedule is not presented as actual completion evidence, and the text avoids presenting functional checks as load-test or usability results.

The main outstanding alignment work is the current scanner-security/session description and full private-table dictionary. The public-schema ERD can remain a 12-table business overview: adding private scanner security tables does **not** require forcing them into a figure explicitly scoped to the public schema. It does require updating the separate full-schema count and dictionary if those are claimed to be current and complete.

The historical `verify-chapters.ps1` validator passes Chapters 1 and 2. For Chapter 3 it stops at a hardcoded obsolete schema-count sentence; that failure does not itself establish corrupt Word XML or missing pictures. The DFD preservation checks and dedicated 57-prototype verifier pass. The chapter-wide validator needs revision against the accepted current schema before it can certify that portion.

## Suggested replacement wording for the security boundary

For Chapter 1 P0042–P0043 and the corresponding Chapter 3 security explanation, reconcile with this wording rather than adding a tenth top-level function:

> Administrator website access uses the configured trusted-browser proof and authenticator workflow. The attendance scanner uses the same active staff or administrator credentials but activates a separate attendance-only session without an authenticator. A second scanner using the same account requests Approve/Deny from the current scanner before replacing it. Approval alone does not end the first session; the requesting scanner must successfully activate. Refresh within the same tab/app browsing session restores a still-current saved scanner session. If the prior scanner is no longer reporting activity, an explicit recovery action may replace it after the server's two-minute inactivity condition is met. This condition concerns application activity; a backgrounded phone may stop reporting activity. Website trust changes preserve the independent scanner scope. Administrator-managed phone pairing remains required to record attendance.

Do not replace historical dated verification statements with claims that every physical acceptance test is complete. The session migration history and isolated tests are repository evidence; physical-device acceptance remains a separate status.

## New private dictionary entries to add if describing the current full schema

**private.attendance_operator_sessions**: `session_id uuid` (PK, FK to auth.sessions; ON DELETE CASCADE), `user_id uuid` (NOT NULL, FK to auth.users; ON DELETE CASCADE), `last_seen_at timestamptz` (NOT NULL, default now()). This marks scanner-only Auth sessions and their last reported activity. Its session marker persists independently of whether that session is still the active attendance mapping; it is not proof of website authorization.

**private.scanner_login_approvals**: `id uuid` (PK, default gen_random_uuid()), `user_id uuid` (NOT NULL, FK to auth.users; ON DELETE CASCADE), `requesting_session_id uuid` (NOT NULL, UNIQUE, FK to auth.sessions; ON DELETE CASCADE), `approver_session_id uuid` (nullable FK to auth.sessions; ON DELETE SET NULL), `device_label text` (NOT NULL), `status text` (NOT NULL, default pending; CHECK pending/approved/denied/cancelled/consumed), `requested_at timestamptz` (NOT NULL, default now()), `expires_at timestamptz` (NOT NULL, default now()+2 minutes). Expiry is derived from the timestamp, not an additional stored status. The inactive recovery action is explicit and audited; ordinary request expiry does not grant access.

Count derivation: checked-in `schema-visualizer.json` = 21 tables/224 fields/33 FKs; scanner marker = +1 table/+3 fields/+2 FKs; scanner approvals = +1 table/+8 fields/+3 FKs. The later incomplete-attendance migration changes function behavior, not these table counts. Live-schema drift was not independently inspected for this document review.

## Completion status

- Completed: review findings, supplied DFD insertion in both requested manuscripts, source retention, backups, DFD preservation checks, prototype preservation and verified TOC page-reference refresh.
- Deliberately not rewritten: Chapter 1/2 prose, the full Chapter 3 dictionary, supplied DFD arrows, survey/evaluation results, client interview history or deployment outcomes.
- Still required for a final-paper sign-off: resolve the high-priority text/schema/DFD findings, use the institution's evaluation requirements, and perform final visual print-layout review. The paper's core topic, actors and nine business functions can remain.
