import fs from 'node:fs';
function edit(path, fn) { fs.writeFileSync(path, fn(fs.readFileSync(path, 'utf8'))); }
edit('staff.html', s => s.replace('Attendance, product sales, and walk-in member registration.', 'Attendance, sales, registration, subscription renewals, plan changes, and request approvals.')
    .replace('</nav>\n<div class="staff-view"', '<button class="staff-tab" type="button" data-staff-view="requests"><i class="fas fa-clipboard-check"></i> Requests approval</button></nav>\n<div class="staff-view"')
    .replace('</main>', `<section class="panel staff-view" id="staffRequestsView" hidden aria-labelledby="staffRequestsTitle"><div class="panel-header"><h2 id="staffRequestsTitle"><i class="fas fa-clipboard-check"></i> Requests approval</h2><button id="refreshStaffRequests" class="btn-logout" type="button">Refresh</button></div><p class="staff-help">Review online registration and renewal requests. Confirm payment at the gym before approving. Member personal profiles remain unavailable to staff.</p><p id="staffRequestsStatus" class="staff-status" role="status" aria-live="polite"></p><div id="staffRequestList" class="staff-request-list"></div></section></main>`));
// Admin and staff use the same atomic review operation to prevent duplicate payments.
edit('assets/js/admin.js', s => {
    const start = s.indexOf('async function completeSupabaseRegistrationApproval(');
    const end = s.indexOf('function mapSupabaseMember(', start);
    if (start < 0 || end < 0) throw new Error('Approval functions not found');
    return s.slice(0, start) + `async function completeSupabaseRegistrationApproval(application) {
    return completeSupabaseRequestApproval(application);
}
async function completeSupabaseRenewalApproval(application) {
    return completeSupabaseRequestApproval(application);
}
async function completeSupabaseRequestApproval(application) {
    const { error } = await window.ironGrindSupabase.rpc('review_membership_request', {
        p_application_id: application.supabaseRecord.id, p_decision: 'approved'
    });
    if (error) { toast(error.message, 'error'); return; }
    await loadSupabaseMembershipData();
    await loadSupabaseOperationalData();
    renderApprovals(); renderMembers(); renderDashboard();
    toast('Membership request approved and payment recorded.', 'success');
}

` + s.slice(end);
});
for (const path of ['assets/js/register.js','assets/js/staff.js','assets/js/admin.js']) edit(path, s => s.replaceAll('newPasswordValid(password, 6)', 'newPasswordValid(password, 8)').replaceAll('newPasswordValid(body.password, 6)', 'newPasswordValid(body.password, 8)').replaceAll('newPasswordMessage(6)', 'newPasswordMessage(8)'));
edit('supabase/functions/admin-create-member/index.ts', s => s.replace(/Use 6[^']*characters, including at least one letter and one number\./, 'Use 8–128 characters with uppercase and lowercase letters, a number, and a symbol.').replace('password.length < 6', 'password.length < 8'));
for (const path of ['assets/js/register.js','assets/js/customer.js']) edit(path, s => s.replaceAll('admin approval','staff or administrator approval').replaceAll('admin review','staff or administrator review').replaceAll('The gym admin must approve','Authorized staff or the administrator must approve'));
for (const path of ['staff.html','admin.html','register.html','customer.html','reset-password.html']) edit(path, s => s.replace(/(assets\/(?:js\/(?:staff|admin|register|customer|ui-improvements)\.js|css\/(?:style|staff)\.css))\?v=[^"\s]+/g, '$1?v=20261108-staff-reviews').replace(/minlength="6"/g,'minlength="8"'));
