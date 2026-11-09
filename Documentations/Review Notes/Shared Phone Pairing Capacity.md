Shared pairing capacity — November 8, 2026

The configured limit covers paired phones and pending QR reservations together. At a limit of two, valid combinations are two paired/zero pending, one paired/one pending, or zero paired/two pending. A third active slot is rejected by the database. Pairing a pending QR changes that reservation into a paired phone without increasing the total.

The old QR-creation function checked only already-paired phones, allowing too many pending reservations. The function now counts all unexpired paired and pending sessions under the existing pairing advisory lock. The settings response reports that combined count, and the UI displays total slots used with separate paired and pending counts.

During deployment, surplus pending reservations expire, preserving already-paired phones and retaining the newest pending QRs within remaining capacity. No paired phone is disconnected by this cleanup. Reducing a configured limit trims surplus pending reservations and rejects a limit below the number of paired phones.

Tests cover the combined capacity, pending-to-paired transition, rejection at full capacity, overflow cleanup, slot reuse after expiration, and limit reduction. This changes no table or column count.
