Reviewed November 8, 2026.

The revised deliverables are Chapter 1.docx, Chapter 2.docx, and Chapter 3.docx in this folder. Original copies from before this review are retained under Review Backups/20261108-194334. Later backup folders capture intermediate revisions.

Formatting

- Body paragraphs, definition entries, captions, and table data use regular weight. Bold is reserved for chapter/section headings and table headers.
- Paragraph spacing, justified body text, first-line indents, caption alignment, and table spacing were standardized. Manual leading spaces and repeated spaces were removed.
- Table headers repeat across pages, table rows are kept together, and figure paragraphs are kept with their following captions where applicable.
- Duplicate ERD headings and the repeated data-dictionary explanation were removed. Garbled apostrophes were corrected.

Content consistency

- Chapter 1 keeps its introduction sequence and places the SDG paragraph immediately after the first Background of the Study paragraph. The vendor-comparison paragraph retains its role while avoiding unnecessary changing marketing counts.
- Staff counter registration, direct renewals, active-member plan changes, online request approval, product sales, and own-sales review are distinguished from profile access. Administrators view member personal profiles; members alone edit their own permitted personal details; staff cannot view or edit existing member profiles.
- No customer receipt provision is claimed. The database receipt_number field remains an internal transaction reference.
- Chapter 3 now describes duplicate account checks, password requirements, separate dashboard/scanner sessions, thirty-day phone pairing, the ten-minute setup QR, and the previous-day Incomplete attendance display.
- The dictionary now contains 15 application-owned tables: 12 public and 3 private. Together with five requirements tables, Chapter 3 contains 20 Word tables. The dictionary contains 174 fields. Auth-managed tables are outside the application-owned count.
- private.account_sessions and its composite key and Auth-user relationship were added to the dictionary and ERD. The DFD authentication process includes its session-ownership store. Other diagrams retain their appropriate notation.

Source review

Chapter 2 preserves the Literature, Applications, Studies, and Synthesis sections. Commercial scale claims and repeated assertions that another system proves IronGrind's effectiveness were removed. The GymFlow discussion identifies it as an author-posted project report and labels its metrics as author-reported rather than independently verified results.

Primary sources consulted:

- Al-Kofahi, Hassan, and Mohamad (2025), publisher abstract: https://www.inderscience.com/info/inarticle.php?artid=145551
- Villanueva, Sevilla, and Verecio (2025), journal article/PDF: https://ojs.southfloridapublishing.com/ojs/index.php/jdev/article/view/5151/3491
- Bulaclac et al. (2025), full paper; the 80%, 95%, and 88/100 values appear in its abstract and evaluation: https://www.ijikm.org/Volume20/IJIKMv20Art035Bulaclac12314.pdf
- Babili (2026), author-posted report; not treated as a peer-reviewed journal article: https://www.researchgate.net/publication/404417460_An_Integrated_Smart_Management_System_for_Fitness_Centers
- Gymdesk founder account (December 18, 2025): https://gymdesk.com/originals/gymdesk-founder-story-eran-galperin
- GymMaster product features: https://www.gymmaster.com/
- GYMMANAGER product features: https://gymmanager.io/

These checks verify the cited topics and identified claims; they are not a complete bibliography audit or an endorsement of each study's methods. Source results are not presented as IronGrind evaluation results. Existing bibliography formatting outside Chapters 1–3 was not available for review.

Verification and limits

Review Evidence/Chapter Review Verification.txt records the XML, bolding, stale wording, figure-link, SDG-placement, dictionary-count, and field-count checks. Generated diagrams were visually inspected. The Word preview/export attempt stalled and was stopped; complete Word pagination and page-by-page appearance were not verified. The documents should not be described as guaranteed error-free.

## Chapter 2 source audit - November 9, 2026

Chapter 2 was rechecked against primary publisher, government, standards-body, and product-owner pages. Its in-text citations now have a complete References list in Chapter 2.

- Replaced the Y Combinator product description with Supabase's official platform documentation. The paragraph now describes Supabase as a hosted platform and lists the services the official page confirms.
- Added ISO/IEC 18004:2024 as the source for the QR Code symbology statement.
- Corrected the DeLone and McLean review count: Al-Kofahi et al. reviewed 102 scholarly articles and conference papers indexed in Scopus, not simply 102 studies. The reported date range and weighted findings match the publisher abstract.
- Tied the Data Privacy Act statements to Sections 11 and 3(l)(2), and used the NPC's own page for its March 7, 2016 constitution date.
- Rephrased GymMaster and GYMMANAGER features as vendor-advertised functions, not independently verified product performance.
- Verified the Villanueva et al. paper on its journal page and the Bulaclac et al. paper on the journal's full-text PDF. Their reported methods and outcomes are attributed to their respective studies and are not represented as IronGrind results.
- Babili's GymFlow document is an author-posted project report hosted on ResearchGate and is not labeled a peer-reviewed journal article. Its numerical metrics remain explicitly identified as author-reported. The reference links to the report record and does not repeat the DOI because the report host's DOI metadata is inconsistent with the separate Zenodo record found during review.
- Gymdesk is represented through its own founder-story page. GymMaster and GYMMANAGER are represented through their own product pages; these are vendor sources, appropriate for advertised feature descriptions but not independent product evaluations.

The sources are authentic as publisher, government, standards-body, platform-owner, product-vendor, or author-hosted pages as identified above. Authenticity does not by itself establish that a study's methods are strong or its findings generalize. Chapter 2 reports study-specific claims with attribution and keeps them separate from IronGrind outcomes. This is a source and claim audit of Chapter 2, not an independent review of every study's methodology or a legal compliance opinion.
