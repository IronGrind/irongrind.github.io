Username validation — November 8, 2026

Account usernames are unique across roles. Database enforcement compares names without surrounding spaces or letter-case differences, so Member_One and member_one cannot be used by separate accounts. New profile writes normalize usernames to lowercase and trim surrounding spaces.

Registration, administrator-created members, staff-created walk-ins, and staff-account creation show availability feedback. Registration and account-creation services recheck availability before creating the account; the database unique index handles competing requests. No existing accounts are renamed by the migration.

Public member registration retains a four-character minimum. Other account-creation forms permit three characters where already supported. All forms limit new usernames to thirty characters.

Validation: PostgreSQL tests covered duplicate insertions with case and spacing variations, conflicting username updates, normalization, and availability checks for anonymous, authenticated, and service-role callers. Existing shared UI and registration submission checks were also run.
