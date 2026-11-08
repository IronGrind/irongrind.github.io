Phone pairing counter — November 8, 2026

The top capacity summary previously refreshed when the dialog opened, while the paired-phone list continued refreshing afterward. A phone could therefore appear in the list while the top summary retained its earlier paired/pending values.

The list refresh now updates the summary and capacity controls from the latest settings response. Redundant dialog-opening requests were removed, the refresh lock covers the full asynchronous operation, and responses for a replaced dialog are ignored. No pairing records or limits were changed.

Validation simulated the transition from zero paired/two pending to one paired/zero pending, verified the matching device row and badges, and checked overlapping refresh protection. JavaScript syntax checks passed. Changes are local website files.
