Phone scanner wording — November 8, 2026

The stopped-camera button now always reads Open camera. When there is no valid pairing, it opens the camera for scanning an administrator-generated phone-pairing QR. Once paired, it opens the member attendance scanner. Operator sign-in and device pairing remain separate checks.

An active saved pairing is still restored after sign-in. Stopping the camera preserves that pairing. Unpaired status messages now explain which QR to scan rather than suggesting that the operator is ready to scan member attendance.

Unpaired phones now explicitly show Phone not paired and explain that pairing is required before member attendance scanning. Successful pairing is valid for 30 days from pairing time; reopening the camera does not extend it. The initial pairing QR is usable for ten minutes. Phone pairing is saved across browser restarts, while operator sign-in remains separate. An administrator can still remove a pairing earlier, and clearing browser storage can remove the saved connection.

The 30-day rule was deployed to Supabase. Active short-lived pairings were extended to 30 days from their original pairing time; expired pairings were not revived. Tests verified the ten-minute QR window, thirty-day pairing, and unchanged expiry when reopening. The service-worker cache and local website script versions were increased.
