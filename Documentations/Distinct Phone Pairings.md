Distinct phone pairings — November 8, 2026

The prior registration function updated one pairing record whenever its QR was reused. A second phone could replace the model name in the first record, so two physical phones could still appear as one paired record. Separately, the capacity summary needed the previously implemented refresh fix.

Each attendance browser installation now stores a random UUID. A pairing QR can be claimed by one such identifier, and the server rejects reuse by another installation. The same installation can reconnect to its pairing, while a second phone uses Pair another phone to obtain its own QR. Registration errors no longer appear as successful pairing or permit the updated UI to continue to member scanning.

The backend migration is deployed. The administrator and phone-page updates are local website files and must be published before a public website loads them. Refreshing an unpublished public website cannot load local changes.

Existing shared pairings cannot be split into two valid records from the overwritten model label alone. End the shared pairing and create a separate QR for each phone. Existing records were not deleted automatically. Browser installation identity is not hardware identification; clearing browser storage may require ending the old pairing and pairing again.

Tests cover two records for two phones using different QRs, rejection of same-QR reuse, preservation of the first device label, same-phone reconnection, and denial of the legacy overwrite API. Counter refresh tests continue to pass.

Schema addition: public.mobile_attendance_scan_sessions.paired_device_id, nullable UUID. No new table was added. Chapter 3's dictionary and editable ERD source include the additional field.
