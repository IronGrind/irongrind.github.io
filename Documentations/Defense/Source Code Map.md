# Source Code Map

Generated from current source definitions. Use alongside the module explanations in Capstone Study and Defense Notes.md. Named functions are navigation points, not a line-by-line correctness certification. Inline callbacks and generated SQL patches require reading their surrounding module.

## Browser and development modules

### assets/js/activity-logs.js

[Open source](../../assets/js/activity-logs.js)

| Function / exported handler | Line |
|---|---:|
| actionLabel | 34 |
| renderLog | 43 |
| loadActivityLogs | 71 |

### assets/js/admin-access.js

[Open source](../../assets/js/admin-access.js)

| Function / exported handler | Line |
|---|---:|
| Module initialization and event handlers; read source | 1 |

### assets/js/admin-device-approval.js

[Open source](../../assets/js/admin-device-approval.js)

| Function / exported handler | Line |
|---|---:|
| waitForAdminDeviceApproval | 2 |
| finish | 19 |
| leave | 23 |
| stopAdminApprovalNotifications | 49 |
| startAdminApprovalNotifications | 50 |
| refresh | 53 |

### assets/js/admin-device-trust.js

[Open source](../../assets/js/admin-device-trust.js)

| Function / exported handler | Line |
|---|---:|
| readAdminDeviceKey | 2 |
| prepareAdminDeviceTrust | 29 |
| call | 31 |
| requireAdminMfa | 54 |
| forgetAdminDevice | 66 |

### assets/js/admin-mfa.js

[Open source](../../assets/js/admin-mfa.js)

| Function / exported handler | Line |
|---|---:|
| verifyAdminAuthenticator | 2 |
| finish | 50 |

### assets/js/admin.js

[Open source](../../assets/js/admin.js)

| Function / exported handler | Line |
|---|---:|
| validPersonName | 3 |
| composeAdminMemberName | 7 |
| guardAdmin | 24 |
| adminStoreUnlockKey | 38 |
| localDateStr | 97 |
| todayStr | 102 |
| addDays | 103 |
| formatPeso | 107 |
| formatAttendanceClock | 108 |
| manilaClock | 120 |
| uid | 125 |
| nextSaleReference | 126 |
| initials | 133 |
| escapeHTML | 134 |
| setupPhMobileInput | 140 |
| loadDB | 154 |
| saveDB | 158 |
| isUUID | 159 |
| isDiscreteUnit | 163 |
| supplementSaleUnit | 164 |
| stockUnitLabel | 170 |
| saleUnitLabel | 171 |
| saleUnitsForProduct | 172 |
| productStockInSaleUnits | 180 |
| stockDeductionForSale | 185 |
| productSaleUnitLabel | 190 |
| productClassification | 191 |
| lowStockThreshold | 196 |
| productIsLowStock | 206 |
| formatProductStock | 209 |
| mapSupabaseProduct | 215 |
| mapSupabaseSale | 234 |
| mapApprovedRenewalApplication | 260 |
| mapSupabaseAttendance | 277 |
| toast | 296 |
| openModal | 304 |
| runWithButtonLoading | 308 |
| closeModal | 327 |
| escapeDialogText | 345 |
| askConfirmation | 350 |
| cancelConfirmation | 362 |
| runConfirmation | 366 |
| setAdminTheme | 374 |
| setAdminAccountMenu | 381 |
| toggleAdminAccountMenu | 388 |
| closeAdminAccountMenu | 394 |
| openActivityLogsFromMenu | 395 |
| showAdminSection | 399 |
| switchMemberTab | 430 |
| switchApprovalType | 440 |
| logout | 448 |
| renderDashboard | 480 |
| getPlanDurationDays | 524 |
| getPlanPrice | 531 |
| isPastMembershipArchiveGrace | 538 |
| isMembershipArchiveReady | 542 |
| hasPendingRenewalForMember | 548 |
| isInactiveMember | 556 |
| renderMembers | 562 |
| filterPlan | 606 |
| viewMemberDetails | 612 |
| renderApprovals | 642 |
| approveApplication | 713 |
| completeApproval | 721 |
| completeSupabaseRegistrationApproval | 823 |
| completeSupabaseRenewalApproval | 826 |
| completeSupabaseRequestApproval | 829 |
| mapSupabaseMember | 840 |
| loadSupabaseMembershipData | 874 |
| loadSupabaseOperationalData | 937 |
| scheduleAdminRealtimeRefresh | 1027 |
| subscribeAdminRealtimeUpdates | 1050 |
| initializeSupabaseAdminData | 1074 |
| startAdminMembershipRefresh | 1120 |
| rejectApplication | 1136 |
| completeRejection | 1143 |
| openAddMemberModal | 1165 |
| clearSignature | 1341 |
| submitNewMember | 1345 |
| openChangePlanModal | 1452 |
| updatePlanChangePrice | 1468 |
| submitMemberPlanChange | 1477 |
| renewMember | 1574 |
| completeMemberRenewal | 1595 |
| renderAttendance | 1670 |
| startQRScanner | 1690 |
| startPhoneQRPairing | 1699 |
| createPhonePairingSession | 1720 |
| showMobileAttendancePairingModal | 1766 |
| startPhonePairingListPolling | 1804 |
| togglePhonePairingQrVisibility | 1816 |
| applyPhonePairingCapacityState | 1822 |
| requestPairingPassword | 1858 |
| submitPairingPassword | 1874 |
| cancelPairingPasswordPrompt | 1900 |
| requestPairingRemovalPin | 1907 |
| submitPairingRemovalPin | 1923 |
| cancelPairingRemovalPin | 1943 |
| renderPhonePairingSettings | 1950 |
| refreshPhonePairingLimitSummary | 1965 |
| changePhonePairingLimit | 1974 |
| cancelPhonePairingLimit | 1993 |
| authorizePhonePairingLimit | 1999 |
| startMobileAttendancePolling | 2026 |
| savePersistentMobileAttendanceSessions | 2038 |
| setAttendancePhoneStatus | 2045 |
| refreshPairedAttendancePhones | 2052 |
| refreshAttendancePhoneStatus | 2156 |
| restoreMobileAttendancePairing | 2179 |
| endMobileAttendanceSession | 2207 |
| restorePhonePairingModal | 2242 |
| pollMobileAttendanceScans | 2266 |
| startLocalQRScanner | 2277 |
| getQRScannerErrorMessage | 2417 |
| stopQRScanner | 2433 |
| findMemberFromQR | 2444 |
| resolveMemberFromQR | 2458 |
| recordMemberAttendanceScan | 2491 |
| checkOut | 2533 |
| unlockStore | 2558 |
| renderStore | 2594 |
| productCard | 2611 |
| restockProduct | 2639 |
| updateRestockQuantityInput | 2659 |
| submitRestock | 2667 |
| unitLabelPlural | 2696 |
| merchandiseSizeOptions | 2703 |
| merchandiseTypeOptions | 2710 |
| merchandiseTypeLabel | 2714 |
| supplementTypeOptions | 2718 |
| supplementTypeLabel | 2722 |
| supplementFormOptions | 2726 |
| supplementFormLabel | 2730 |
| stockUnitOptions | 2731 |
| stockStep | 2738 |
| productPhotoPicker | 2740 |
| openAddProductModal | 2756 |
| toggleAddProductSize | 2774 |
| convertInventoryUnit | 2804 |
| submitAddProduct | 2828 |
| editProduct | 2874 |
| toggleEditSupplementUnits | 2904 |
| toggleEditProductSize | 2930 |
| submitEditProduct | 2935 |
| previewProductPhoto | 2991 |
| getProductPhoto | 3011 |
| archiveProduct | 3040 |
| completeProductArchive | 3046 |
| openNewSaleModal | 3068 |
| updateSaleQuantityMode | 3088 |
| updateSaleTotalPreview | 3125 |
| submitNewSale | 3133 |
| switchSalesView | 3215 |
| renderWalkinSalesReport | 3233 |
| updateProductSalesPeriodControls | 3254 |
| getProductSalesPeriod | 3261 |
| isProductSaleInSelectedPeriod | 3280 |
| getMembershipSalesPeriod | 3285 |
| updateMembershipSalesPeriod | 3299 |
| isWalkinProductSale | 3309 |
| getSaleProductCategory | 3315 |
| getSaleProductNames | 3325 |
| isMembershipSale | 3333 |
| getMembershipPlanFromSale | 3342 |
| renderSales | 3353 |
| getMemberActivityStatus | 3458 |
| archiveExpiredMembership | 3470 |
| captureExpiredMemberships | 3491 |
| renderReports | 3498 |
| updateReportPeriodControls | 3574 |
| updateReportExportAction | 3579 |
| closeReportActionsMenus | 3590 |
| toggleReportActionsMenu | 3600 |
| printSelectedReport | 3610 |
| getSelectedReportPeriod | 3619 |
| reportDateMatchesPeriod | 3638 |
| isRenewalSale | 3645 |
| getRenewalChannel | 3652 |
| getRenewalPlan | 3660 |
| getRenewalReportRows | 3668 |
| groupAttendanceByMonth | 3683 |
| viewReport | 3700 |
| setReportPreviewZoom | 3767 |
| getMembershipIncomeBreakdown | 3776 |
| viewReportPDF | 3809 |
| printReportPDF | 3824 |
| reportDateBelongsToMonth | 3999 |
| createMonthlyReportPDF | 4007 |
| logReportExportRequest | 4128 |
| exportAllReports | 4135 |
| downloadReportPDF | 4204 |

### assets/js/attendance-phone.js

[Open source](../../assets/js/attendance-phone.js)

| Function / exported handler | Line |
|---|---:|
| requirePhoneOperator | 6 |
| signInPhoneOperator | 17 |
| forgetPhoneAdminDevice | 64 |
| changePhoneOperator | 74 |
| setPhoneAttendanceStatus | 101 |
| getPhoneCameraErrorMessage | 108 |
| setPhoneAttendanceMode | 121 |
| isPhoneCameraAvailable | 128 |
| createPhoneQrScanner | 132 |
| setPhoneCameraButton | 149 |
| setPhoneNextScanButton | 157 |
| confirmPhoneCameraPreview | 164 |
| getPhoneDeviceLabel | 179 |
| registerPhoneAttendanceDevice | 194 |
| getAttendancePhoneIdentity | 206 |
| requestPhoneModelSetup | 215 |
| savePhoneModelAndContinue | 227 |
| savePhonePairing | 275 |
| readPhonePairing | 284 |
| clearPhonePairing | 300 |
| acceptPhonePairingLink | 305 |
| phonePairingRecoveryMessage | 313 |
| startPhonePairingScanner | 320 |
| startPhoneMemberScanner | 421 |
| submitPhoneMemberScan | 490 |
| stopPhoneAttendanceScanner | 524 |
| togglePhoneAttendanceCamera | 555 |
| resumePhoneAttendanceScanner | 587 |
| installPhoneAttendanceApp | 598 |
| configurePhoneAppInstall | 610 |
| startPhoneAttendanceApp | 644 |

### assets/js/auth.js

[Open source](../../assets/js/auth.js)

| Function / exported handler | Line |
|---|---:|
| togglePassword | 1 |
| showError | 10 |
| hideError | 15 |
| restoreRememberedLogin | 20 |
| showAuthRedirectMessage | 37 |
| showForgotPassword | 55 |
| closeForgotPassword | 69 |
| sendPasswordReset | 73 |
| recoverConfirmedRegistration | 116 |
| handleLogin | 175 |
| saveLoginSession | 339 |

### assets/js/button-feedback.js

[Open source](../../assets/js/button-feedback.js)

| Function / exported handler | Line |
|---|---:|
| Module initialization and event handlers; read source | 1 |

### assets/js/customer.js

[Open source](../../assets/js/customer.js)

| Function / exported handler | Line |
|---|---:|
| guardCustomer | 13 |
| updateCustomerName | 25 |
| splitFullName | 38 |
| populateSettingsNameFields | 43 |
| composeSettingsFullName | 48 |
| validPersonName | 52 |
| storedPhoneToLocal | 56 |
| phLocalToStored | 57 |
| localDateStr | 61 |
| todayStr | 66 |
| addDays | 67 |
| getRenewalExpiryError | 71 |
| getRenewalGuidance | 82 |
| renderRenewalEligibility | 91 |
| getRenewalSubmissionErrorMessage | 97 |
| formatPeso | 104 |
| formatAttendanceClock | 105 |
| isUUID | 117 |
| loadDB | 118 |
| saveDB | 122 |
| saveExpiredMembershipSnapshot | 124 |
| productImage | 153 |
| toast | 164 |
| renewalFormMessage | 173 |
| openMemberSettings | 181 |
| closeMemberSettings | 188 |
| setMemberAccountMenu | 191 |
| toggleMemberAccountMenu | 198 |
| closeMemberAccountMenu | 206 |
| openMemberProfileFromMenu | 209 |
| showMemberSettingsSection | 213 |
| settingsFormMessage | 231 |
| setSettingsStatus | 234 |
| openModal | 240 |
| closeModal | 244 |
| escapeHTML | 252 |
| memberTourStorageKey | 258 |
| showMemberWelcome | 264 |
| finishMemberTour | 287 |
| printQRCode | 294 |
| confirmLogout | 301 |
| logout | 313 |
| completeLogout | 317 |
| getCurrentMember | 332 |
| updateMemberStatus | 343 |
| renderMembershipProgress | 362 |
| openMemberRenewalForm | 445 |
| renderAttendanceHistory | 453 |
| renderStore | 519 |
| productCard | 534 |
| showQRCode | 560 |
| renewMembership | 586 |
| confirmRenew | 610 |
| submitMembershipForm | 660 |
| submitMemberSettings | 768 |
| submitMemberEmail | 890 |
| submitMemberPassword | 921 |
| updateSettingsAge | 955 |
| populateMemberSettings | 968 |
| loadSupabaseMember | 1033 |
| mapCustomerAttendanceRecord | 1166 |
| refreshCustomerAttendance | 1181 |

### assets/js/register.js

[Open source](../../assets/js/register.js)

| Function / exported handler | Line |
|---|---:|
| localDateStr | 1 |
| todayStr | 6 |
| addDays | 7 |
| loadDB | 11 |
| saveDB | 16 |
| composeRegistrationName | 17 |
| validPersonName | 21 |
| phLocalToStored | 25 |
| toggleRegPassword | 29 |
| showError | 35 |
| hideError | 40 |
| openModal | 41 |
| closeModal | 45 |
| updateOtherMedicalDetails | 85 |
| updateDatesFromPlan | 95 |
| submitRegistration | 106 |
| insertSupabaseApplication | 244 |
| completeConfirmedRegistration | 291 |
| showSuccessModal | 314 |

### assets/js/reset-password.js

[Open source](../../assets/js/reset-password.js)

| Function / exported handler | Line |
|---|---:|
| showRecoveryError | 13 |
| enablePasswordForm | 20 |
| initializeRecovery | 28 |

### assets/js/signature.js

[Open source](../../assets/js/signature.js)

| Function / exported handler | Line |
|---|---:|
| initDigitalSignature | 1 |
| getPoint | 21 |
| stopDrawing | 49 |
| clear | 54 |

### assets/js/staff-accounts.js

[Open source](../../assets/js/staff-accounts.js)

| Function / exported handler | Line |
|---|---:|
| composeStaffName | 4 |
| setStaffAccountsMessage | 15 |
| callStaffAccountService | 22 |
| filterStaffDirectory | 32 |
| loadStaffAccounts | 45 |

### assets/js/staff.js

[Open source](../../assets/js/staff.js)

| Function / exported handler | Line |
|---|---:|
| hideStaffLoaderWhenReady | 19 |
| startStaffLoaderMinimumDuration | 25 |
| setStaffView | 35 |
| setStaffMembershipAction | 54 |
| searchStaffMembers | 72 |
| submitStaffMembershipChange | 106 |
| staffSaleUnits | 142 |
| formatStaffPeso | 151 |
| staffProductAvailable | 155 |
| staffSupplementForm | 157 |
| groupStaffProducts | 164 |
| renderStaffProductCatalog | 184 |
| updateStaffSaleSummary | 231 |
| loadStaffProducts | 243 |
| getSelectedStaffSaleProduct | 262 |
| updateStaffSaleUnits | 272 |
| refreshStaffProductSales | 296 |
| submitStaffProductSale | 314 |
| localDateString | 342 |
| staffMembershipDates | 346 |
| validPersonName | 352 |
| composeWalkinMemberName | 356 |
| submitStaffWalkin | 374 |
| refreshStaffAttendance | 423 |
| recordStaffAttendance | 454 |
| clearStaffAttendanceSelection | 475 |
| submitStaffAttendanceLookup | 485 |
| staffCameraErrorMessage | 524 |
| closeStaffCameraModal | 543 |
| filterStaffRequests | 669 |
| loadStaffRequests | 681 |

### assets/js/supabase-client.js

[Open source](../../assets/js/supabase-client.js)

| Function / exported handler | Line |
|---|---:|
| stopAccountSessionMonitor | 30 |
| monitorAccountSession | 34 |
| check | 40 |
| startDashboardSessionMonitor | 91 |

### assets/js/theme.js

[Open source](../../assets/js/theme.js)

| Function / exported handler | Line |
|---|---:|
| applyTheme | 6 |
| toggleDashboardTheme | 27 |
| toggleStaffAccountMenu | 31 |
| closeStaffAccountMenu | 39 |

### assets/js/ui-improvements.js

[Open source](../../assets/js/ui-improvements.js)

| Function / exported handler | Line |
|---|---:|
| catalogProductPhoto | 17 |
| productPriceQuote | 33 |
| productUnitPrice | 37 |
| newPasswordValid | 46 |
| newPasswordMessage | 47 |
| passwordStrength | 48 |
| attachPasswordGuidance | 56 |
| update | 73 |
| attachUsernameGuidance | 98 |
| attachPasswordVisibility | 134 |
| conceal | 149 |
| enhance | 168 |
| openPhoto | 180 |
| paint | 193 |
| setZoom | 200 |

### server.js

[Open source](../../server.js)

| Function / exported handler | Line |
|---|---:|
| Module initialization and event handlers; read source | 1 |

### attendance-phone-sw.js

[Open source](../../attendance-phone-sw.js)

| Function / exported handler | Line |
|---|---:|
| Module initialization and event handlers; read source | 1 |

## Edge Functions

| Function folder | Entrypoint / responsibility |
|---|---|
| admin-create-member | [index.ts](../../supabase/functions/admin-create-member/index.ts) |
| admin-create-staff | [index.ts](../../supabase/functions/admin-create-staff/index.ts) |
| admin-device-trust | [index.ts](../../supabase/functions/admin-device-trust/index.ts) |
| admin-manage-staff |  |
| admin-username-login | [handler.ts](../../supabase/functions/admin-username-login/handler.ts), [handler_test.ts](../../supabase/functions/admin-username-login/handler_test.ts), [index.ts](../../supabase/functions/admin-username-login/index.ts) |
| member-password-login | [index.ts](../../supabase/functions/member-password-login/index.ts) |
| verify-store-password | [index.ts](../../supabase/functions/verify-store-password/index.ts) |

## SQL routine definitions

A routine may be replaced or patched by a later migration. This lists the latest explicit CREATE FUNCTION occurrence, not the final live pg_get_functiondef result. Use migration order and SQL tests to understand later patches.

| Routine | Latest explicit source definition |
|---|---|
| private.account_session_is_current | 20261108000006_separate_attendance_sessions.sql:7 |
| private.admin_mfa_satisfied | 20261110000004_admin_trusted_device.sql:26 |
| private.capture_activity | 20261105043517_remote_schema.sql:54 |
| private.capture_password_change | 20261110000001_security_activity_events.sql:37 |
| private.capture_recovery_request | 20261110000001_security_activity_events.sql:54 |
| private.describe_sale_activity | 20261105043517_remote_schema.sql:115 |
| private.is_admin | 20261110000003_admin_device_approval.sql:25 |
| private.is_staff | 20261105043517_remote_schema.sql:181 |
| private.is_valid_person_name | 20261108000012_validate_person_names.sql:4 |
| private.normalize_profile_username | 20261108000002_unique_account_usernames.sql:5 |
| private.require_admin_login_scope | 20261110000004_admin_trusted_device.sql:35 |
| private.require_admin_mfa | 20261110000004_admin_trusted_device.sql:44 |
| private.require_attendance_removal_pin | 20261105043517_remote_schema.sql:195 |
| private.require_pairing_password | 20261105043517_remote_schema.sql:214 |
| private.require_recent_admin_auth | 20261105043517_remote_schema.sql:234 |
| private.trim_pending_attendance_pairings | 20261108000009_shared_pairing_capacity.sql:14 |
| private.validate_person_name_record | 20261108000012_validate_person_names.sql:16 |
| public.activate_account_session | 20261108000003_single_account_session.sql:27 |
| public.activate_attendance_session | 20261108000006_separate_attendance_sessions.sql:26 |
| public.admin_capture_expired_memberships | 20261105043517_remote_schema.sql:255 |
| public.admin_create_member_and_sale | 20261105043517_remote_schema.sql:321 |
| public.admin_log_session_event | 20261105043517_remote_schema.sql:374 |
| public.admin_mfa_required | 20261110000002_admin_mfa.sql:3 |
| public.admin_record_membership_change | 20261105043518_staff_active_plan_change_search.sql:48 |
| public.admin_record_registration_sale | 20261105043517_remote_schema.sql:535 |
| public.cancel_admin_login_approval | 20261110000003_admin_device_approval.sql:95 |
| public.close_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:575 |
| public.consume_admin_login_attempt | 20261105043517_remote_schema.sql:604 |
| public.create_admin_device_challenge | 20261110000004_admin_trusted_device.sql:52 |
| public.create_member_and_sale_with_actor | 20261105043517_remote_schema.sql:628 |
| public.create_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:649 |
| public.create_profile_for_auth_user | 20261105043517_remote_schema.sql:708 |
| public.current_account_session_is_active | 20261108000003_single_account_session.sql:22 |
| public.decide_admin_login_approval | 20261110000003_admin_device_approval.sql:74 |
| public.enforce_account_session | 20261108000003_single_account_session.sql:78 |
| public.enforce_member_renewal_window | 20261105043517_remote_schema.sql:727 |
| public.finish_admin_device_login | 20261110000004_admin_trusted_device.sql:80 |
| public.forget_admin_trusted_device | 20261110000004_admin_trusted_device.sql:153 |
| public.get_admin_device_challenge | 20261110000004_admin_trusted_device.sql:71 |
| public.get_admin_mobile_attendance_device | 20261105043517_remote_schema.sql:756 |
| public.get_mobile_attendance_pairing_settings | 20261105043517_remote_schema.sql:786 |
| public.handle_new_auth_user | 20261105043517_remote_schema.sql:825 |
| public.is_admin | 20261105043517_remote_schema.sql:845 |
| public.is_admin_mobile_attendance_scan_session_active | 20261105043517_remote_schema.sql:860 |
| public.is_registration_email_available | 20261108000005_unique_registration_emails.sql:4 |
| public.is_registration_username_available | 20261108000002_unique_account_usernames.sql:16 |
| public.list_admin_login_approvals | 20261110000003_admin_device_approval.sql:63 |
| public.list_admin_mobile_attendance_devices | 20261105043517_remote_schema.sql:897 |
| public.list_admin_mobile_attendance_pending_sessions | 20261105043517_remote_schema.sql:923 |
| public.log_account_activity | 20261110000001_security_activity_events.sql:16 |
| public.record_attendance_scan | 20261105043517_remote_schema.sql:950 |
| public.record_security_failure | 20261110000001_security_activity_events.sql:2 |
| public.record_walk_in_sale | 20261105043517_remote_schema.sql:1015 |
| public.register_mobile_attendance_device | 20261108000008_bind_pairing_to_device.sql:3 |
| public.request_admin_login_approval | 20261110000003_admin_device_approval.sql:30 |
| public.restock_product | 20261105043517_remote_schema.sql:1185 |
| public.review_membership_request | 20261108000001_staff_request_reviews.sql:15 |
| public.set_mobile_attendance_pairing_limit | 20261105043517_remote_schema.sql:1251 |
| public.set_mobile_attendance_pairing_password | 20261105043517_remote_schema.sql:1294 |
| public.staff_list_attendance | 20261105043517_remote_schema.sql:1314 |
| public.staff_list_own_product_sales | 20261105043517_remote_schema.sql:1344 |
| public.staff_pending_membership_requests | 20261108000001_staff_request_reviews.sql:2 |
| public.staff_resolve_attendance_member | 20261105043517_remote_schema.sql:1382 |
| public.staff_search_active_members | 20261105043518_staff_active_plan_change_search.sql:6 |
| public.staff_search_members | 20261105043517_remote_schema.sql:1424 |
| public.submit_mobile_attendance_scan | 20261105043517_remote_schema.sql:1466 |
| public.sync_auth_user_email | 20261105043517_remote_schema.sql:1479 |
| public.sync_legacy_product_price | 20261105043517_remote_schema.sql:1496 |
| public.update_own_member_personal_info | 20261105043517_remote_schema.sql:1516 |
| public.validate_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:1622 |
| public.verify_mobile_attendance_pairing_password | 20261105043517_remote_schema.sql:1639 |
| public.verify_mobile_attendance_removal_pin | 20261105043517_remote_schema.sql:1653 |
