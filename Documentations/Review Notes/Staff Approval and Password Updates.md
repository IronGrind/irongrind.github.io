Updated November 8, 2026.

Staff dashboard

- Membership contains Add Member, Renewal, and Change Plan. Plan changes search active members; direct counter transactions retain standard plan and price restrictions.
- Requests approval lists pending online registration and renewal requests and supports approve or reject. Approval requires the operator to confirm payment received at the gym.
- Request summaries expose only name, request type, selected plan, price, and submission time. Staff still cannot open or edit member personal profiles.
- The shared review RPC checks active roles, locks the pending request, and commits membership, payment, renewal history, and review metadata together. Repeated processing is rejected. Nonstandard prices require administrator review.
- No additional database tables or customer receipt provision were introduced.

Password validation

- The strength indicator shows Weak, Fair, or Strong. Registration is blocked unless the password has 8–128 characters, uppercase and lowercase letters, a digit, and a symbol. Password confirmation must match.
- Staff-account creation retains a 12-character minimum with the same character rules. Existing login validation is unchanged.
- Supabase Auth configuration and both account-creation Edge Functions were updated remotely. The staff-review migration was also applied to the linked Supabase project.
- Website files were changed locally; this task did not publish the static website.

Documentation

- Chapters 1–3 were checked for role wording. Chapter 3 requirements, reviewer descriptions, use cases, staff explanation, and password discussion were updated.
- Context and Level 1 Gane–Sarson diagrams, use cases, and the staff operations illustration were refreshed. Duplicate embedded continuation panels were removed and the image relationships corrected.
- Use refresh-review-diagrams.ps1 to regenerate and embed these diagrams. Do not rerun older one-time prose-expansion scripts.

Validation

- Node checks covered changed JavaScript, shared password and pricing behavior, unique page IDs, registration submission, and administrator membership refresh.
- PostgreSQL tests using PGlite covered staff registration approval, active subscription extension, rejection, duplicate review, standard-price validation, inactive/member/anonymous denial, profile isolation, and rollback when payment recording fails.
- Diagram PNGs were visually inspected. Browser interactions and Word pagination were not visually tested.
