Email registration validation — November 8, 2026

Registration rejects an email address already linked to any account, including an account still awaiting email confirmation. Matching ignores capitalization and surrounding spaces. The same checks apply to administrator-created members, staff walk-in registration, and staff-account creation.

Forms display availability feedback and stop submission when an address is already registered. Public registration checks availability before sign-up and handles Supabase's empty-identities response for a repeated sign-up without presenting a false success message. Member and staff creation services check availability before account creation. Supabase Auth's account uniqueness and the normalized profile-email unique index enforce the account boundary when requests compete.

This checks email-address duplicates, including Gmail addresses. Existing support for other email providers is preserved. Gmail dot and plus aliases are not merged or rewritten. Existing account addresses are not changed.

Validation: PostgreSQL tests covered case/space duplicates, an unconfirmed Auth account, checks across anonymous/authenticated/service roles, invalid addresses, and database uniqueness. Shared UI checks and registration-submission tests passed. Website changes are local; database and account-creation functions are deployed separately to Supabase.
