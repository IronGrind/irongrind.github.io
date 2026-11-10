# Source Code Map

Generated from current source definitions. Use alongside the module explanations in Capstone Study and Defense Notes.md. Named functions are navigation points, not a line-by-line correctness certification. Inline callbacks and generated SQL patches require reading their surrounding module.

## Browser and development modules

### assets/js/activity-logs.js

[Open source](../../assets/js/activity-logs.js)

| Function / exported handler | Line |
|---|---:|
| actionLabel | 37 |
| renderLog | 46 |
| loadActivityLogs | 74 |

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
| loadAdminTrustedDeviceInfo | 71 |

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
| closeAdminAccountMenu | 396 |
| openActivityLogsFromMenu | 397 |
| showAdminSection | 401 |
| switchMemberTab | 432 |
| switchApprovalType | 442 |
| logout | 450 |
| renderDashboard | 482 |
| getPlanDurationDays | 526 |
| getPlanPrice | 533 |
| isPastMembershipArchiveGrace | 540 |
| isMembershipArchiveReady | 544 |
| hasPendingRenewalForMember | 550 |
| isInactiveMember | 558 |
| renderMembers | 564 |
| filterPlan | 608 |
| viewMemberDetails | 614 |
| renderApprovals | 644 |
| approveApplication | 715 |
| completeApproval | 723 |
| completeSupabaseRegistrationApproval | 825 |
| completeSupabaseRenewalApproval | 828 |
| completeSupabaseRequestApproval | 831 |
| mapSupabaseMember | 842 |
| loadSupabaseMembershipData | 876 |
| loadSupabaseOperationalData | 939 |
| scheduleAdminRealtimeRefresh | 1029 |
| subscribeAdminRealtimeUpdates | 1052 |
| initializeSupabaseAdminData | 1076 |
| startAdminMembershipRefresh | 1122 |
| rejectApplication | 1138 |
| completeRejection | 1145 |
| openAddMemberModal | 1167 |
| clearSignature | 1343 |
| submitNewMember | 1347 |
| openChangePlanModal | 1454 |
| updatePlanChangePrice | 1470 |
| submitMemberPlanChange | 1479 |
| renewMember | 1576 |
| completeMemberRenewal | 1597 |
| renderAttendance | 1672 |
| startQRScanner | 1692 |
| startPhoneQRPairing | 1701 |
| createPhonePairingSession | 1722 |
| showMobileAttendancePairingModal | 1768 |
| startPhonePairingListPolling | 1806 |
| togglePhonePairingQrVisibility | 1818 |
| applyPhonePairingCapacityState | 1824 |
| requestPairingPassword | 1860 |
| submitPairingPassword | 1876 |
| cancelPairingPasswordPrompt | 1902 |
| requestPairingRemovalPin | 1909 |
| submitPairingRemovalPin | 1925 |
| cancelPairingRemovalPin | 1945 |
| renderPhonePairingSettings | 1952 |
| refreshPhonePairingLimitSummary | 1967 |
| changePhonePairingLimit | 1976 |
| cancelPhonePairingLimit | 1995 |
| authorizePhonePairingLimit | 2001 |
| startMobileAttendancePolling | 2028 |
| savePersistentMobileAttendanceSessions | 2040 |
| setAttendancePhoneStatus | 2047 |
| refreshPairedAttendancePhones | 2054 |
| refreshAttendancePhoneStatus | 2158 |
| restoreMobileAttendancePairing | 2181 |
| endMobileAttendanceSession | 2209 |
| restorePhonePairingModal | 2244 |
| pollMobileAttendanceScans | 2268 |
| startLocalQRScanner | 2279 |
| getQRScannerErrorMessage | 2419 |
| stopQRScanner | 2435 |
| findMemberFromQR | 2446 |
| resolveMemberFromQR | 2460 |
| recordMemberAttendanceScan | 2493 |
| checkOut | 2535 |
| unlockStore | 2560 |
| renderStore | 2596 |
| productCard | 2613 |
| restockProduct | 2641 |
| updateRestockQuantityInput | 2661 |
| submitRestock | 2669 |
| unitLabelPlural | 2698 |
| merchandiseSizeOptions | 2705 |
| merchandiseTypeOptions | 2712 |
| merchandiseTypeLabel | 2716 |
| supplementTypeOptions | 2720 |
| supplementTypeLabel | 2724 |
| supplementFormOptions | 2728 |
| supplementFormLabel | 2732 |
| stockUnitOptions | 2733 |
| stockStep | 2740 |
| productPhotoPicker | 2742 |
| openAddProductModal | 2758 |
| toggleAddProductSize | 2776 |
| convertInventoryUnit | 2806 |
| submitAddProduct | 2830 |
| editProduct | 2876 |
| toggleEditSupplementUnits | 2906 |
| toggleEditProductSize | 2932 |
| submitEditProduct | 2937 |
| previewProductPhoto | 2993 |
| getProductPhoto | 3013 |
| archiveProduct | 3042 |
| completeProductArchive | 3048 |
| openNewSaleModal | 3070 |
| updateSaleQuantityMode | 3090 |
| updateSaleTotalPreview | 3127 |
| submitNewSale | 3135 |
| switchSalesView | 3217 |
| renderWalkinSalesReport | 3235 |
| updateProductSalesPeriodControls | 3256 |
| getProductSalesPeriod | 3263 |
| isProductSaleInSelectedPeriod | 3282 |
| getMembershipSalesPeriod | 3287 |
| updateMembershipSalesPeriod | 3301 |
| isWalkinProductSale | 3311 |
| getSaleProductCategory | 3317 |
| getSaleProductNames | 3327 |
| isMembershipSale | 3335 |
| getMembershipPlanFromSale | 3344 |
| renderSales | 3355 |
| getMemberActivityStatus | 3460 |
| archiveExpiredMembership | 3472 |
| captureExpiredMemberships | 3493 |
| renderReports | 3500 |
| updateReportPeriodControls | 3576 |
| updateReportExportAction | 3581 |
| closeReportActionsMenus | 3592 |
| toggleReportActionsMenu | 3602 |
| printSelectedReport | 3612 |
| getSelectedReportPeriod | 3621 |
| reportDateMatchesPeriod | 3640 |
| isRenewalSale | 3647 |
| getRenewalChannel | 3654 |
| getRenewalPlan | 3662 |
| getRenewalReportRows | 3670 |
| groupAttendanceByMonth | 3685 |
| viewReport | 3702 |
| setReportPreviewZoom | 3769 |
| getMembershipIncomeBreakdown | 3778 |
| viewReportPDF | 3811 |
| printReportPDF | 3826 |
| reportDateBelongsToMonth | 4001 |
| createMonthlyReportPDF | 4009 |
| logReportExportRequest | 4130 |
| exportAllReports | 4137 |
| downloadReportPDF | 4206 |

### assets/js/attendance-phone.js

[Open source](../../assets/js/attendance-phone.js)

| Function / exported handler | Line |
|---|---:|
| requirePhoneOperator | 6 |
| signInPhoneOperator | 17 |
| forgetPhoneAdminDevice | 67 |
| changePhoneOperator | 77 |
| setPhoneAttendanceStatus | 104 |
| getPhoneCameraErrorMessage | 111 |
| setPhoneAttendanceMode | 124 |
| isPhoneCameraAvailable | 131 |
| createPhoneQrScanner | 135 |
| setPhoneCameraButton | 152 |
| setPhoneNextScanButton | 160 |
| confirmPhoneCameraPreview | 167 |
| getPhoneDeviceLabel | 182 |
| registerPhoneAttendanceDevice | 197 |
| getAttendancePhoneIdentity | 209 |
| requestPhoneModelSetup | 218 |
| savePhoneModelAndContinue | 230 |
| savePhonePairing | 278 |
| readPhonePairing | 287 |
| clearPhonePairing | 303 |
| acceptPhonePairingLink | 308 |
| phonePairingRecoveryMessage | 316 |
| startPhonePairingScanner | 323 |
| startPhoneMemberScanner | 424 |
| submitPhoneMemberScan | 494 |
| stopPhoneAttendanceScanner | 528 |
| togglePhoneAttendanceCamera | 559 |
| resumePhoneAttendanceScanner | 591 |
| installPhoneAttendanceApp | 602 |
| configurePhoneAppInstall | 614 |
| startPhoneAttendanceApp | 648 |

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
| recoverConfirmedRegistration | 119 |
| handleLogin | 178 |
| saveLoginSession | 350 |

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
| loadSupabaseMember | 1034 |
| mapCustomerAttendanceRecord | 1167 |
| refreshCustomerAttendance | 1182 |

### assets/js/member-device-approval.js

[Open source](../../assets/js/member-device-approval.js)

| Function / exported handler | Line |
|---|---:|
| readMemberDeviceKey | 2 |
| requireMemberDeviceApproval | 32 |
| finish | 81 |
| stopMemberDeviceApprovalNotifications | 92 |
| startMemberDeviceApprovalNotifications | 93 |
| refresh | 96 |

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
| monitorAccountSession | 35 |
| check | 41 |
| startDashboardSessionMonitor | 94 |

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
| member-device-trust | [index.ts](../../supabase/functions/member-device-trust/index.ts) |
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
| private.member_device_session_is_trusted | 20261110000006_member_device_approval.sql:38 |
| private.normalize_profile_username | 20261108000002_unique_account_usernames.sql:5 |
| private.require_admin_login_scope | 20261110000004_admin_trusted_device.sql:35 |
| private.require_admin_mfa | 20261110000004_admin_trusted_device.sql:44 |
| private.require_attendance_removal_pin | 20261105043517_remote_schema.sql:195 |
| private.require_member_device_session | 20261110000006_member_device_approval.sql:46 |
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
| public.create_member_device_challenge | 20261110000006_member_device_approval.sql:73 |
| public.create_mobile_attendance_scan_session | 20261105043517_remote_schema.sql:649 |
| public.create_profile_for_auth_user | 20261105043517_remote_schema.sql:708 |
| public.current_account_session_is_active | 20261108000003_single_account_session.sql:22 |
| public.decide_admin_login_approval | 20261110000003_admin_device_approval.sql:74 |
| public.decide_member_device_approval | 20261110000006_member_device_approval.sql:187 |
| public.enforce_account_session | 20261108000003_single_account_session.sql:78 |
| public.enforce_member_renewal_window | 20261105043517_remote_schema.sql:727 |
| public.finish_admin_device_login | 20261110000004_admin_trusted_device.sql:80 |
| public.finish_member_device_login | 20261110000006_member_device_approval.sql:115 |
| public.forget_admin_trusted_device | 20261110000004_admin_trusted_device.sql:153 |
| public.get_admin_device_challenge | 20261110000004_admin_trusted_device.sql:71 |
| public.get_admin_mobile_attendance_device | 20261105043517_remote_schema.sql:756 |
| public.get_admin_trusted_device | 20261110000005_admin_trusted_device_label.sql:1 |
| public.get_member_device_approval_status | 20261110000006_member_device_approval.sql:103 |
| public.get_member_device_challenge | 20261110000006_member_device_approval.sql:95 |
| public.get_mobile_attendance_pairing_settings | 20261105043517_remote_schema.sql:786 |
| public.handle_new_auth_user | 20261105043517_remote_schema.sql:825 |
| public.is_admin | 20261105043517_remote_schema.sql:845 |
| public.is_admin_mobile_attendance_scan_session_active | 20261105043517_remote_schema.sql:860 |
| public.is_registration_email_available | 20261108000005_unique_registration_emails.sql:4 |
| public.is_registration_username_available | 20261108000002_unique_account_usernames.sql:16 |
| public.list_admin_login_approvals | 20261110000003_admin_device_approval.sql:63 |
| public.list_admin_mobile_attendance_devices | 20261105043517_remote_schema.sql:897 |
| public.list_admin_mobile_attendance_pending_sessions | 20261105043517_remote_schema.sql:923 |
| public.list_member_device_approvals | 20261110000006_member_device_approval.sql:173 |
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
