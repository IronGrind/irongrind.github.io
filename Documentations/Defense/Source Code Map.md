# Source Code Map

Generated from current source definitions. Use alongside the module explanations in Capstone Study and Defense Notes.md. Named functions are navigation points, not a line-by-line correctness certification. Inline callbacks and generated SQL patches require reading their surrounding module.

## Browser and development modules

### assets/js/activity-logs.js

[Open source](../../assets/js/activity-logs.js)

| Function / exported handler | Line |
|---|---:|
| actionLabel | 32 |
| renderLog | 41 |
| loadActivityLogs | 69 |

### assets/js/admin-access.js

[Open source](../../assets/js/admin-access.js)

| Function / exported handler | Line |
|---|---:|
| Module initialization and event handlers; read source | 1 |

### assets/js/admin-mfa.js

[Open source](../../assets/js/admin-mfa.js)

| Function / exported handler | Line |
|---|---:|
| requireAdminMfa | 2 |
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
| renderDashboard | 471 |
| getPlanDurationDays | 515 |
| getPlanPrice | 522 |
| isPastMembershipArchiveGrace | 529 |
| isMembershipArchiveReady | 533 |
| hasPendingRenewalForMember | 539 |
| isInactiveMember | 547 |
| renderMembers | 553 |
| filterPlan | 597 |
| viewMemberDetails | 603 |
| renderApprovals | 633 |
| approveApplication | 704 |
| completeApproval | 712 |
| completeSupabaseRegistrationApproval | 814 |
| completeSupabaseRenewalApproval | 817 |
| completeSupabaseRequestApproval | 820 |
| mapSupabaseMember | 831 |
| loadSupabaseMembershipData | 865 |
| loadSupabaseOperationalData | 928 |
| scheduleAdminRealtimeRefresh | 1018 |
| subscribeAdminRealtimeUpdates | 1041 |
| initializeSupabaseAdminData | 1065 |
| startAdminMembershipRefresh | 1111 |
| rejectApplication | 1127 |
| completeRejection | 1134 |
| openAddMemberModal | 1156 |
| clearSignature | 1332 |
| submitNewMember | 1336 |
| openChangePlanModal | 1443 |
| updatePlanChangePrice | 1459 |
| submitMemberPlanChange | 1468 |
| renewMember | 1565 |
| completeMemberRenewal | 1586 |
| renderAttendance | 1661 |
| startQRScanner | 1681 |
| startPhoneQRPairing | 1690 |
| createPhonePairingSession | 1711 |
| showMobileAttendancePairingModal | 1757 |
| startPhonePairingListPolling | 1795 |
| togglePhonePairingQrVisibility | 1807 |
| applyPhonePairingCapacityState | 1813 |
| requestPairingPassword | 1849 |
| submitPairingPassword | 1865 |
| cancelPairingPasswordPrompt | 1891 |
| requestPairingRemovalPin | 1898 |
| submitPairingRemovalPin | 1914 |
| cancelPairingRemovalPin | 1934 |
| renderPhonePairingSettings | 1941 |
| refreshPhonePairingLimitSummary | 1956 |
| changePhonePairingLimit | 1965 |
| cancelPhonePairingLimit | 1984 |
| authorizePhonePairingLimit | 1990 |
| startMobileAttendancePolling | 2017 |
| savePersistentMobileAttendanceSessions | 2029 |
| setAttendancePhoneStatus | 2036 |
| refreshPairedAttendancePhones | 2043 |
| refreshAttendancePhoneStatus | 2147 |
| restoreMobileAttendancePairing | 2170 |
| endMobileAttendanceSession | 2198 |
| restorePhonePairingModal | 2233 |
| pollMobileAttendanceScans | 2257 |
| startLocalQRScanner | 2268 |
| getQRScannerErrorMessage | 2408 |
| stopQRScanner | 2424 |
| findMemberFromQR | 2435 |
| resolveMemberFromQR | 2449 |
| recordMemberAttendanceScan | 2482 |
| checkOut | 2524 |
| unlockStore | 2549 |
| renderStore | 2585 |
| productCard | 2602 |
| restockProduct | 2630 |
| updateRestockQuantityInput | 2650 |
| submitRestock | 2658 |
| unitLabelPlural | 2687 |
| merchandiseSizeOptions | 2694 |
| merchandiseTypeOptions | 2701 |
| merchandiseTypeLabel | 2705 |
| supplementTypeOptions | 2709 |
| supplementTypeLabel | 2713 |
| supplementFormOptions | 2717 |
| supplementFormLabel | 2721 |
| stockUnitOptions | 2722 |
| stockStep | 2729 |
| productPhotoPicker | 2731 |
| openAddProductModal | 2747 |
| toggleAddProductSize | 2765 |
| convertInventoryUnit | 2795 |
| submitAddProduct | 2819 |
| editProduct | 2865 |
| toggleEditSupplementUnits | 2895 |
| toggleEditProductSize | 2921 |
| submitEditProduct | 2926 |
| previewProductPhoto | 2982 |
| getProductPhoto | 3002 |
| archiveProduct | 3031 |
| completeProductArchive | 3037 |
| openNewSaleModal | 3059 |
| updateSaleQuantityMode | 3079 |
| updateSaleTotalPreview | 3116 |
| submitNewSale | 3124 |
| switchSalesView | 3206 |
| renderWalkinSalesReport | 3224 |
| updateProductSalesPeriodControls | 3245 |
| getProductSalesPeriod | 3252 |
| isProductSaleInSelectedPeriod | 3271 |
| getMembershipSalesPeriod | 3276 |
| updateMembershipSalesPeriod | 3290 |
| isWalkinProductSale | 3300 |
| getSaleProductCategory | 3306 |
| getSaleProductNames | 3316 |
| isMembershipSale | 3324 |
| getMembershipPlanFromSale | 3333 |
| renderSales | 3344 |
| getMemberActivityStatus | 3449 |
| archiveExpiredMembership | 3461 |
| captureExpiredMemberships | 3482 |
| renderReports | 3489 |
| updateReportPeriodControls | 3565 |
| updateReportExportAction | 3570 |
| closeReportActionsMenus | 3581 |
| toggleReportActionsMenu | 3591 |
| printSelectedReport | 3601 |
| getSelectedReportPeriod | 3610 |
| reportDateMatchesPeriod | 3629 |
| isRenewalSale | 3636 |
| getRenewalChannel | 3643 |
| getRenewalPlan | 3651 |
| getRenewalReportRows | 3659 |
| groupAttendanceByMonth | 3674 |
| viewReport | 3691 |
| setReportPreviewZoom | 3758 |
| getMembershipIncomeBreakdown | 3767 |
| viewReportPDF | 3800 |
| printReportPDF | 3815 |
| reportDateBelongsToMonth | 3990 |
| createMonthlyReportPDF | 3998 |
| logReportExportRequest | 4119 |
| exportAllReports | 4126 |
| downloadReportPDF | 4195 |

### assets/js/attendance-phone.js

[Open source](../../assets/js/attendance-phone.js)

| Function / exported handler | Line |
|---|---:|
| requirePhoneOperator | 6 |
| signInPhoneOperator | 17 |
| changePhoneOperator | 62 |
| setPhoneAttendanceStatus | 88 |
| getPhoneCameraErrorMessage | 95 |
| setPhoneAttendanceMode | 108 |
| isPhoneCameraAvailable | 115 |
| createPhoneQrScanner | 119 |
| setPhoneCameraButton | 136 |
| setPhoneNextScanButton | 144 |
| confirmPhoneCameraPreview | 151 |
| getPhoneDeviceLabel | 166 |
| registerPhoneAttendanceDevice | 181 |
| getAttendancePhoneIdentity | 193 |
| requestPhoneModelSetup | 202 |
| savePhoneModelAndContinue | 214 |
| savePhonePairing | 262 |
| readPhonePairing | 271 |
| clearPhonePairing | 287 |
| acceptPhonePairingLink | 292 |
| phonePairingRecoveryMessage | 300 |
| startPhonePairingScanner | 307 |
| startPhoneMemberScanner | 408 |
| submitPhoneMemberScan | 477 |
| stopPhoneAttendanceScanner | 511 |
| togglePhoneAttendanceCamera | 542 |
| resumePhoneAttendanceScanner | 574 |
| installPhoneAttendanceApp | 585 |
| configurePhoneAppInstall | 597 |
| startPhoneAttendanceApp | 631 |

### assets/js/auth.js

[Open source](../../assets/js/auth.js)

| Function / exported handler | Line |
|---|---:|
| togglePassword | 1 |
| showError | 10 |
| hideError | 15 |
| restoreRememberedLogin | 20 |
| showAuthRedirectMessage | 37 |
| showForgotPassword | 50 |
| closeForgotPassword | 64 |
| sendPasswordReset | 68 |
| recoverConfirmedRegistration | 111 |
| handleLogin | 170 |
| saveLoginSession | 334 |

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
| monitorAccountSession | 31 |
| check | 37 |

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
| admin-manage-staff |  |
| admin-username-login | [handler.ts](../../supabase/functions/admin-username-login/handler.ts), [handler_test.ts](../../supabase/functions/admin-username-login/handler_test.ts), [index.ts](../../supabase/functions/admin-username-login/index.ts) |
| member-password-login | [index.ts](../../supabase/functions/member-password-login/index.ts) |
| verify-store-password | [index.ts](../../supabase/functions/verify-store-password/index.ts) |

## SQL routine definitions

A routine may be replaced or patched by a later migration. This lists the latest explicit CREATE FUNCTION occurrence, not the final live pg_get_functiondef result. Use migration order and SQL tests to understand later patches.

| Routine | Latest explicit source definition |
|---|---|
| private.account_session_is_current | 20261108000006_separate_attendance_sessions.sql:7 |
| private.admin_mfa_satisfied | 20261110000002_admin_mfa.sql:10 |
| private.capture_activity | 20261105043517_remote_schema.sql:54 |
| private.capture_password_change | 20261110000001_security_activity_events.sql:37 |
| private.capture_recovery_request | 20261110000001_security_activity_events.sql:54 |
| private.describe_sale_activity | 20261105043517_remote_schema.sql:115 |
| private.is_admin | 20261110000002_admin_mfa.sql:28 |
| private.is_staff | 20261105043517_remote_schema.sql:181 |
| private.is_valid_person_name | 20261108000012_validate_person_names.sql:4 |
| private.normalize_profile_username | 20261108000002_unique_account_usernames.sql:5 |
| private.require_admin_mfa | 20261110000002_admin_mfa.sql:17 |
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
| public.close_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:575 |
| public.consume_admin_login_attempt | 20261105043517_remote_schema.sql:604 |
| public.create_member_and_sale_with_actor | 20261105043517_remote_schema.sql:628 |
| public.create_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:649 |
| public.create_profile_for_auth_user | 20261105043517_remote_schema.sql:708 |
| public.current_account_session_is_active | 20261108000003_single_account_session.sql:22 |
| public.enforce_account_session | 20261108000003_single_account_session.sql:78 |
| public.enforce_member_renewal_window | 20261105043517_remote_schema.sql:727 |
| public.get_admin_mobile_attendance_device | 20261105043517_remote_schema.sql:756 |
| public.get_mobile_attendance_pairing_settings | 20261105043517_remote_schema.sql:786 |
| public.handle_new_auth_user | 20261105043517_remote_schema.sql:825 |
| public.is_admin | 20261105043517_remote_schema.sql:845 |
| public.is_admin_mobile_attendance_scan_session_active | 20261105043517_remote_schema.sql:860 |
| public.is_registration_email_available | 20261108000005_unique_registration_emails.sql:4 |
| public.is_registration_username_available | 20261108000002_unique_account_usernames.sql:16 |
| public.list_admin_mobile_attendance_devices | 20261105043517_remote_schema.sql:897 |
| public.list_admin_mobile_attendance_pending_sessions | 20261105043517_remote_schema.sql:923 |
| public.log_account_activity | 20261110000001_security_activity_events.sql:16 |
| public.record_attendance_scan | 20261105043517_remote_schema.sql:950 |
| public.record_security_failure | 20261110000001_security_activity_events.sql:2 |
| public.record_walk_in_sale | 20261105043517_remote_schema.sql:1015 |
| public.register_mobile_attendance_device | 20261108000008_bind_pairing_to_device.sql:3 |
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
