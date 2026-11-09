/* ========== AUTH GUARD ========== */
let activeDashboardRole = 'admin';
function validPersonName(value) {
    const name = String(value || '').trim();
    return name.length > 0 && name.length <= 150 && /\p{L}/u.test(name) && !/[\p{N}\p{Cc}\p{Cf}]/u.test(name);
}
function composeAdminMemberName(firstName, middleInitial, lastName) {
    const first = String(firstName || '').trim().replace(/\s+/g, ' ');
    const middle = String(middleInitial || '').trim();
    const last = String(lastName || '').trim().replace(/\s+/g, ' ');
    if (!validPersonName(first) || !validPersonName(last)) {
        throw new Error('Enter the member’s first and last names; numbers are not allowed.');
    }
    if (first.length > 70 || last.length > 70) {
        throw new Error('First and last names must each be 70 characters or fewer.');
    }
    if (middle && !/^\p{L}\.?$/u.test(middle)) {
        throw new Error('Enter one letter for the middle initial, optionally followed by a period.');
    }
    const fullName = [first, middle ? `${middle.replace('.', '').toUpperCase()}.` : '', last].filter(Boolean).join(' ');
    if (fullName.length > 150) throw new Error('The combined name must be 150 characters or fewer.');
    return fullName;
}
(function guardAdmin() {
    let session = null;
    try {
        session = JSON.parse(localStorage.getItem('irongrind_session') || sessionStorage.getItem('irongrind_session') || 'null');
    } catch {
        window.clearIronGrindUiSession?.();
    }
    // This browser value is only a display hint. Supabase is verified before the
    // dashboard is revealed, so a stale or missing UI session cannot grant access.
    if (session?.role === 'admin') {
        document.getElementById('currentUserName').textContent = session.fullName || session.username;
    }
})();

function adminStoreUnlockKey() {
    const session = JSON.parse(localStorage.getItem('irongrind_session') || sessionStorage.getItem('irongrind_session') || 'null');
    const account = String(session?.username || '').trim().toLowerCase();
    return account ? `ig_store_unlocked:${encodeURIComponent(account)}` : '';
}

/* ========== STATE ========== */
let members = [];
let products = [];
let archivedProducts = [];
let sales = [];
let approvedRenewalApplications = [];
let attendance = [];
let pendingApprovals = [];
let users = [];
let planArchives = [];
let membershipArchives = [];
let currentPlanFilter = 'all';
let currentMemberTab = 'members';
let currentApprovalType = 'registration';
let currentSalesView = 'membership';
let currentSalesTransactionType = 'membership';
let currentSalesSubType = 'all';
let currentMembershipSalesPeriodMode = 'day';
let currentMembershipSalesDay = localDateStr();
let currentMembershipSalesFrom = localDateStr();
let currentMembershipSalesTo = localDateStr();
let currentMembershipSalesYear = localDateStr().slice(0, 4);
let currentSalesProductName = 'all';
let activeQRScanner = null;
let qrScanHandled = false;
let qrCameraHintTimer = null;
let activeMobileAttendanceSessionId = null;
let activeMobileAttendancePersistent = false;
let mobileAttendancePollTimer = null;
let mobileAttendancePollBusy = new Set();
let mobileAttendanceProcessedScanIds = new Set();
let mobileAttendanceSessionIds = new Set();
let mobileAttendanceSessionPersistence = new Map();
let activeMobileAttendancePairingUrl = null;
let pairedPhoneListRefreshBusy = false;
let pairedPhoneListLastRefreshAt = 0;
let pairingPasswordPromptResolver = null;
let pairingRemovalPinPromptResolver = null;
let pendingPairingLimitPin = null;
let phoneCameraAuthorization = null;
let phoneCameraRememberPreference = true;
let phonePairQrManuallyHidden = false;
let phonePairingWasAtDeviceLimit = false;
let phonePairingListPollTimer = null;
let adminRealtimeChannel = null;
let adminMembershipRefreshTimer = null;
let adminMembershipRefreshBusy = false;
let realtimeRefreshTimer = null;
let realtimeRefreshBusy = false;
let realtimeRefreshPending = false;
let reportPreviewZoom = 110;

/* ========== HELPERS ========== */
function localDateStr(date = new Date()) {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
    const part = type => parts.find(item => item.type === type)?.value;
    return `${part('year')}-${part('month')}-${part('day')}`;
}
function todayStr() { return localDateStr(); }
function addDays(dateStr, days) {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(Date.UTC(year, month - 1, day + days, 12)).toISOString().slice(0, 10);
}
function formatPeso(n) { return '₱' + Number(n).toLocaleString('en-PH'); }
function formatAttendanceClock(value) {
    if (!value) return '—';
    const match = /^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$/i.exec(String(value).trim());
    if (!match) return String(value);
    let hour = Number(match[1]);
    const minute = match[2];
    const suffix = match[3]?.toUpperCase();
    if (suffix) return `${hour}:${minute} ${suffix}`;
    const period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 || 12;
    return `${hour}:${minute} ${period}`;
}
function manilaClock(date = new Date()) {
    return new Intl.DateTimeFormat('en-PH', {
        timeZone: 'Asia/Manila', hour: '2-digit', minute: '2-digit', hour12: false
    }).format(date);
}
function uid(prefix) { return prefix + Math.floor(Math.random() * 9000 + 1000); }
function nextSaleReference() {
    const highest = sales.reduce((max, sale) => {
        const match = String(sale.id || '').match(/^IG-(\d+)$/);
        return match ? Math.max(max, Number(match[1])) : max;
    }, 0);
    return `IG-${String(highest + 1).padStart(4, '0')}`;
}
function initials(name) { return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase(); }
function escapeHTML(value) {
    return String(value).replace(/[&<>"']/g, char => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[char]);
}

function setupPhMobileInput(input) {
    if (!input) return;
    input.type = 'tel';
    input.inputMode = 'numeric';
    input.maxLength = 11;
    input.pattern = '09[0-9]{9}';
    input.autocomplete = 'tel';
    input.placeholder = '09171234567';
    input.value = input.value.replace(/\D/g, '').slice(0, 11);
    input.addEventListener('input', () => {
        input.value = input.value.replace(/\D/g, '').slice(0, 11);
    });
}

function loadDB(key) {
    try { return JSON.parse(localStorage.getItem('ig_' + key)) || []; }
    catch { return []; }
}
function saveDB(key, data) { localStorage.setItem('ig_' + key, JSON.stringify(data)); }
function isUUID(value) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || '')); }

const INVENTORY_UNIT_TO_BASE = { gram: 1, kilogram: 1000, ounce: 28.349523125, pound: 453.59237, milliliter: 1, liter: 1000, fluid_ounce: 29.5735295625, item: 1, piece: 1, box: 1 };
const DISCRETE_UNITS = new Set(['item', 'piece', 'box']);
function isDiscreteUnit(unit) { return DISCRETE_UNITS.has(unit); }
function supplementSaleUnit(form, stockUnit = '') {
    if (form === 'powder') return 'gram';
    if (form === 'drinkable') return 'milliliter';
    if (form === 'capsule' || form === 'tablet') return ['piece', 'box'].includes(stockUnit) ? stockUnit : 'piece';
    return 'item';
}
function stockUnitLabel(unit) { return ({ gram: 'g', kilogram: 'kg', ounce: 'oz', pound: 'lb', milliliter: 'ml', liter: 'L', fluid_ounce: 'fl oz', item: 'items', piece: 'pcs', box: 'boxes' })[unit] || unit; }
function saleUnitLabel(unit) { return ({ gram: 'g', kilogram: 'kg', ounce: 'oz', pound: 'lb', milliliter: 'ml', liter: 'L', fluid_ounce: 'fl oz', item: 'item', piece: 'pc', box: 'box' })[unit] || unit; }
function saleUnitsForProduct(product) {
    const baseUnit = product.inventoryUnit || 'item';
    if (baseUnit === 'gram') return [['gram', 'g'], ['kilogram', 'kg'], ['ounce', 'oz'], ['pound', 'lb']];
    if (baseUnit === 'milliliter') return [['milliliter', 'ml'], ['liter', 'L'], ['fluid_ounce', 'fl oz']];
    if (baseUnit === 'piece') return [['piece', 'pcs']];
    if (baseUnit === 'box') return [['box', 'boxes']];
    return [['item', 'item']];
}
function productStockInSaleUnits(product) {
    const stockUnit = product.stockUnit || 'item';
    const saleUnit = product.inventoryUnit || 'item';
    return Number(product.stock || 0) * (INVENTORY_UNIT_TO_BASE[stockUnit] || 1) / (INVENTORY_UNIT_TO_BASE[saleUnit] || 1);
}
function stockDeductionForSale(product, quantity) {
    const stockUnit = product.stockUnit || 'item';
    const saleUnit = product.inventoryUnit || 'item';
    return Number(quantity) * (INVENTORY_UNIT_TO_BASE[saleUnit] || 1) / (INVENTORY_UNIT_TO_BASE[stockUnit] || 1);
}
function productSaleUnitLabel(product) { return saleUnitLabel(product.inventoryUnit || (product.category === 'Supplement' ? 'gram' : 'item')); }
function productClassification(product) {
    return product.category === 'Supplement'
        ? `${supplementTypeLabel(product.supplementType || 'other')} · ${supplementFormLabel(product.supplementForm || 'powder')}`
        : merchandiseTypeLabel(product.merchType || (product.size ? 'apparel' : 'other'));
}
function lowStockThreshold(product) {
    if (product.category === 'Merch') return 4;
    if (product.inventoryUnit === 'milliliter') return 1000;
    if (product.inventoryUnit === 'item' || product.inventoryUnit === 'piece') return 30;
    if (product.inventoryUnit === 'box') return 4;
    return 2000;
}
function productIsLowStock(product) {
    return productStockInSaleUnits(product) <= lowStockThreshold(product);
}
function formatProductStock(product) {
    const amount = Number(product.stock || 0);
    const formatted = Number.isInteger(amount) ? amount.toLocaleString('en-PH') : amount.toLocaleString('en-PH', { maximumFractionDigits: 6 });
        return `${formatted} ${stockUnitLabel(product.stockUnit || (product.category === 'Supplement' ? 'gram' : 'item'))}`;
}

function mapSupabaseProduct(row) {
    return {
        id: row.id,
        name: row.name,
        category: row.category === 'supplement' ? 'Supplement' : 'Merch',
        price: Number(row.price_per_unit) || 0,
        stock: Number(row.stock) || 0,
        stockUnit: row.stock_unit || (row.category === 'supplement' ? 'gram' : 'item'),
        size: row.size || '',
        merchType: row.merch_type || (row.category === 'merchandise' ? (row.size ? 'apparel' : 'other') : ''),
        supplementType: row.supplement_type || (row.category === 'supplement' ? 'other' : ''),
        supplementForm: row.supplement_form || (row.category === 'supplement' ? 'powder' : ''),
        inventoryUnit: row.unit || (row.category === 'supplement' ? 'gram' : 'item'),
        image: row.image_path || '',
        isActive: row.is_active !== false,
        archivedAt: row.archived_at || null
    };
}

function mapSupabaseSale(row) {
    const items = (row.sale_items || []).map(item => ({
        name: item.item_name,
        productId: item.product_id,
        category: item.category === 'supplement' ? 'Supplement' : item.category === 'merchandise' ? 'Merch' : 'Membership',
        quantity: Number(item.quantity),
        quantityUnit: saleUnitLabel(item.unit),
        unitPrice: Number(item.unit_price),
        total: Number(item.line_total)
    }));
    const soldAt = new Date(row.sold_at);
    return {
        id: row.receipt_number,
        databaseId: row.id,
        customer: row.customer_name,
        source: row.customer_type === 'walk_in' ? 'walk-in' : 'member',
        memberId: row.member_id,
        items: items.map(item => `${item.name} x${item.quantity} ${item.quantityUnit}`).join(', '),
        lineItems: items,
        total: Number(row.total),
        date: Number.isNaN(soldAt.getTime()) ? todayStr() : localDateStr(soldAt),
        createdAt: row.sold_at,
        status: row.status === 'voided' ? 'Voided' : 'Paid'
    };
}

function mapApprovedRenewalApplication(row) {
    const member = members.find(item => String(item.id) === String(row.member_id));
    const reference = `IG-R-${String(row.id).slice(0, 8).toUpperCase()}`;
    return {
        id: 'Not recorded',
        expectedSaleReference: reference,
        saleRecorded: false,
        customer: member?.name || row.full_name || 'Name not recorded',
        memberId: row.member_id,
        source: 'dashboard-renewal',
        items: `${row.plan || member?.plan || 'Membership'} Membership Renewal`,
        total: Number(row.plan_price) || 0,
        date: row.reviewed_at ? localDateStr(new Date(row.reviewed_at)) : '',
        status: 'Paid'
    };
}

function mapSupabaseAttendance(row) {
    const timeIn = new Date(row.time_in);
    const timeOut = row.time_out ? new Date(row.time_out) : null;
    const localDate = date => localDateStr(date);
    const localTime = date => new Intl.DateTimeFormat('en-PH', { timeZone: 'Asia/Manila', hour: '2-digit', minute: '2-digit', hour12: false }).format(date);
    const member = members.find(item => String(item.id) === String(row.member_id));
    return {
        id: row.id,
        memberId: row.member_id,
        memberName: member?.name || row.members?.full_name || 'Member',
        date: Number.isNaN(timeIn.getTime()) ? todayStr() : localDate(timeIn),
        timeIn: Number.isNaN(timeIn.getTime()) ? '' : localTime(timeIn),
        timeOut: timeOut && !Number.isNaN(timeOut.getTime()) ? localTime(timeOut) : null,
        databaseTimeIn: row.time_in
    };
}

/* ========== TOAST & MODAL ========== */
let toastTimer;
function toast(msg, type = '') {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.className = 'toast ' + type;
    el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 3000);
}
function openModal(html) {
    document.getElementById('modalContent').innerHTML = html;
    document.getElementById('modalOverlay').classList.remove('hidden');
}
async function runWithButtonLoading(button, action, loadingLabel = 'Working…') {
    if (!button || button.disabled) return;
    const originalHTML = button.innerHTML;
    button.disabled = true;
    button.classList.add('is-loading');
    button.setAttribute('aria-busy', 'true');
    button.innerHTML = `<i class="fas fa-spinner fa-spin" aria-hidden="true"></i> ${escapeHTML(loadingLabel)}`;
    try {
        await action();
    } catch (error) {
        console.error('Button action failed:', error);
        toast(error?.message || 'The action could not be completed. Please try again.', 'error');
    } finally {
        button.disabled = false;
        button.classList.remove('is-loading');
        button.removeAttribute('aria-busy');
        button.innerHTML = originalHTML;
    }
}
function closeModal(preservePhoneCameraAuthorization = false) {
    if (pairingPasswordPromptResolver) {
        const resolve = pairingPasswordPromptResolver;
        pairingPasswordPromptResolver = null;
        resolve(null);
    }
    if (pairingRemovalPinPromptResolver) {
        const resolve = pairingRemovalPinPromptResolver;
        pairingRemovalPinPromptResolver = null;
        resolve(null);
    }
    pendingPairingLimitPin = null;
    if (!preservePhoneCameraAuthorization) phoneCameraAuthorization = null;
    document.getElementById('modalOverlay').classList.add('hidden');
    document.getElementById('modalContent').classList.remove('report-pdf-modal');
    stopQRScanner();
}
let pendingConfirmationAction = null;
function escapeDialogText(value) {
    const element = document.createElement('span');
    element.textContent = value;
    return element.innerHTML;
}
function askConfirmation(title, message, actionLabel, callback, danger = false) {
    pendingConfirmationAction = callback;
    openModal(`<div class="confirm-dialog">
        <div class="confirm-dialog-icon"><i class="fas ${danger ? 'fa-triangle-exclamation' : 'fa-circle-question'}"></i></div>
        <h3>${escapeDialogText(title)}</h3>
        <p class="modal-sub">${escapeDialogText(message)}</p>
        <div class="modal-actions">
            <button class="btn-sm" onclick="cancelConfirmation()">Cancel</button>
            <button class="${danger ? 'btn-danger' : 'btn-primary'}" onclick="runConfirmation()">${escapeDialogText(actionLabel)}</button>
        </div>
    </div>`);
}
function cancelConfirmation() {
    pendingConfirmationAction = null;
    closeModal();
}
function runConfirmation() {
    const callback = pendingConfirmationAction;
    pendingConfirmationAction = null;
    closeModal();
    callback?.();
}

/* ========== NAV ========== */
function setAdminTheme(theme) {
    const selectedTheme = theme === 'light' ? 'light' : 'dark';
    window.setDashboardTheme(selectedTheme);
}

setAdminTheme(document.documentElement.dataset.dashboardTheme || 'dark');

function setAdminAccountMenu(open) {
    const menu = document.getElementById('adminAccountMenu');
    const button = document.querySelector('.admin-menu-button');
    if (!menu || !button) return;
    menu.hidden = !open;
    button.setAttribute('aria-expanded', String(open));
}
function toggleAdminAccountMenu(event) {
    event?.stopPropagation();
    const menu = document.getElementById('adminAccountMenu');
    if (!menu) return;
    setAdminAccountMenu(menu.hidden);
}
function closeAdminAccountMenu() { setAdminAccountMenu(false); }
function openActivityLogsFromMenu() {
    closeAdminAccountMenu();
    showAdminSection('activity');
}
function showAdminSection(section, event) {
    document.querySelectorAll('.admin-section').forEach(el => el.classList.add('hidden'));
    const target = document.getElementById('section-' + section);
    if (target) target.classList.remove('hidden');

    document.querySelectorAll('.sidebar .nav-item').forEach(el => el.classList.remove('active'));
    const activityButton = document.getElementById('activityLogsButton');
    activityButton?.classList.toggle('active', section === 'activity');
    activityButton?.setAttribute('aria-pressed', String(section === 'activity'));
    const clicked = event?.target?.closest('.nav-item') || document.querySelector(`.sidebar .nav-item[data-section="${section}"]`);
    if (clicked) clicked.classList.add('active');

    if (section === 'store') {
        const unlocked = Boolean(adminStoreUnlockKey() && localStorage.getItem(adminStoreUnlockKey()) === 'true');
        document.getElementById('storeLocked').classList.toggle('hidden', unlocked);
        document.getElementById('storeUnlocked').classList.toggle('hidden', !unlocked);
        if (unlocked) renderStore();
    }
    if (section === 'membership') switchMemberTab(currentMemberTab);
    if (section === 'attendance') renderAttendance();
    if (section === 'sales') {
        switchSalesView(currentSalesView);
    }
    if (section === 'reports') renderReports();
    if (section === 'activity') loadActivityLogs();
    if (section === 'staff') loadStaffAccounts();
    if (section === 'dashboard') renderDashboard();
    const content = document.querySelector('.main-content');
    if (content) content.scrollTop = 0;
}

function switchMemberTab(tab) {
    currentMemberTab = tab;
    document.querySelectorAll('.admin-tab').forEach(t => t.classList.toggle('active', t.dataset.tab === tab));
    document.getElementById('tab-members').classList.toggle('hidden', tab !== 'members');
    document.getElementById('tab-approvals').classList.toggle('hidden', tab !== 'approvals');
    document.getElementById('tab-expired').classList.toggle('hidden', tab !== 'expired');
    if (tab === 'approvals') renderApprovals();
    else if (tab === 'members' || tab === 'expired') renderMembers();
}

function switchApprovalType(type) {
    currentApprovalType = type === 'renewal' ? 'renewal' : 'registration';
    document.querySelectorAll('[data-approval-type]').forEach(button => button.classList.toggle('active', button.dataset.approvalType === currentApprovalType));
    document.getElementById('registrationApprovalsList').classList.toggle('hidden', currentApprovalType !== 'registration');
    document.getElementById('renewalApprovalsList').classList.toggle('hidden', currentApprovalType !== 'renewal');
    renderApprovals(currentApprovalType);
}

function logout() {
    askConfirmation('Log out?', 'Are you sure you want to log out?', 'Log out', async () => {
        // Signing out stops this dashboard, but trusted phone pairings remain active.
        if (mobileAttendancePollTimer) clearInterval(mobileAttendancePollTimer);
        mobileAttendancePollTimer = null;
        const storeUnlockKey = adminStoreUnlockKey();
        if (storeUnlockKey) localStorage.removeItem(storeUnlockKey);
        if (activeDashboardRole === 'admin') {
            try {
                const result = await window.ironGrindSupabase?.rpc('admin_log_session_event', { p_event: 'sign_out_requested' });
                if (result?.error) console.error('Could not record sign-out request:', result.error);
            } catch (error) { console.error('Could not record sign-out request:', error); }
        }
        await window.ironGrindSupabase?.auth.signOut({ scope: 'local' });
        localStorage.removeItem('irongrind_session');
        sessionStorage.removeItem('irongrind_session');
        document.getElementById('page-loader')?.classList.remove('hidden-loader');
        window.setTimeout(() => window.location.replace('index.html'), 1200);
    }, true);
}

/* ========== RENDER: DASHBOARD ========== */
function renderDashboard() {
    const currentMemberships = members.filter(member => getMemberActivityStatus(member) === 'Active');
    document.getElementById('statTotalMembers').textContent = currentMemberships.length;

    const today = todayStr();
    const todayAtt = attendance.filter(a => a.date === today);
    const inside = todayAtt.filter(a => !a.timeOut).length;
    document.getElementById('statCheckins').textContent = todayAtt.length;
    document.getElementById('statInside').textContent = inside;

    const todaySales = sales.filter(s => s.date === today && s.status === 'Paid');
    const total = todaySales.reduce((sum, s) => sum + Number(s.total), 0);
    document.getElementById('statSales').textContent = formatPeso(total);

    const low = products.filter(productIsLowStock);
    document.getElementById('statLowStock').textContent = low.length;

    const attTable = document.getElementById('dashboardAttendanceTable');
    if (todayAtt.length === 0) attTable.innerHTML = '<div class="empty-state">No check-ins yet today.</div>';
    else attTable.innerHTML = `
        <table class="attendance-table">
            <thead><tr><th>Member</th><th>Time In</th><th>Time Out</th><th>Status</th></tr></thead>
            <tbody>${todayAtt.map(a => `
                <tr><td>${a.memberName}</td><td>${formatAttendanceClock(a.timeIn)}</td><td>${formatAttendanceClock(a.timeOut)}</td>
                <td>${a.timeOut ? '<span class="badge-status out">Checked Out</span>' : attendanceVisitIncomplete(a.date, a.timeOut) ? '<span class="badge-status incomplete">Incomplete</span>' : '<span class="badge-status in">Inside</span>'}</td></tr>
            `).join('')}</tbody>
        </table>`;

    const lowList = document.getElementById('lowStockList');
    if (low.length === 0) lowList.innerHTML = '<div class="empty-state">All items are well-stocked.</div>';
    else lowList.innerHTML = low.map(p => `<div class="low-stock-item" role="status" aria-label="Low stock: ${escapeHTML(p.name)}, ${escapeHTML(formatProductStock(p))} remaining"><div class="low-stock-info"><span class="name">${escapeHTML(p.name)}${p.category === 'Merch' && p.size ? ' — ' + escapeHTML(p.size) : ''}</span><span class="low-stock-badge"><i class="fas fa-triangle-exclamation" aria-hidden="true"></i> LOW STOCK</span></div><span class="qty"><strong>${escapeHTML(formatProductStock(p))}</strong><small>remaining</small></span></div>`).join('');

    const pending = pendingApprovals.filter(p => p.status === 'pending');
    document.getElementById('pendingBadge').textContent = pending.length;
    document.getElementById('approvalsCount').textContent = pending.length;
    document.getElementById('registrationApprovalsCount').textContent = pending.filter(p => p.source !== 'dashboard-renewal').length;
    document.getElementById('renewalApprovalsCount').textContent = pending.filter(p => p.source === 'dashboard-renewal').length;
    const registrationCount = pending.filter(p => p.source !== 'dashboard-renewal').length;
    document.getElementById('dashboardRegistrationNotice')?.classList.toggle('hidden', registrationCount === 0);
    const registrationNoticeText = document.getElementById('dashboardRegistrationNoticeText');
    if (registrationNoticeText) registrationNoticeText.textContent = `${registrationCount} ${registrationCount === 1 ? 'application is' : 'applications are'} waiting for approval.`;
}

/* ========== RENDER: MEMBERS ========== */
function getPlanDurationDays(plan) {
    if (plan === 'Monthly') return 30;
    if (plan === 'Half Month') return 15;
    if (plan === 'Weekly') return 7;
    return 1;
}

function getPlanPrice(plan, member = null) {
    if (plan === 'Monthly') return 800;
    if (plan === 'Half Month') return 400;
    if (plan === 'Weekly') return Number(member?.planPrice) || 0;
    return 80;
}

function isPastMembershipArchiveGrace(member) {
    return isInactiveMember(member);
}

function isMembershipArchiveReady(record) {
    if (record?.renewedAt) return true;
    const member = members.find(item => String(item.id) === String(record?.memberId));
    return Boolean(record?.expiry && todayStr() >= addDays(record.expiry, 5) && !hasPendingRenewalForMember(member));
}

function hasPendingRenewalForMember(member) {
    return pendingApprovals.some(application =>
        application.source === 'dashboard-renewal'
        && String(application.memberId || '') === String(member?.id || '')
        && application.status === 'pending'
    );
}

function isInactiveMember(member, today = todayStr()) {
    if (hasPendingRenewalForMember(member)) return false;
    return String(member?.status || '').toLowerCase() === 'inactive'
        || Boolean(member?.expiry && today >= addDays(member.expiry, 5));
}

function renderMembers() {
    const isExpiredTab = currentMemberTab === 'expired';
    const searchEl = document.getElementById(isExpiredTab ? 'expiredMemberSearch' : 'memberSearch');
    const query = searchEl ? searchEl.value.toLowerCase() : '';
    const today = todayStr();
    let filtered = members.filter(m => {
        if (isExpiredTab) return Boolean(m.expiry && m.expiry < today && !isInactiveMember(m, today));
        return Boolean(m.expiry && m.expiry >= today) && !isInactiveMember(m, today);
    }).filter(m => {
        if (currentPlanFilter !== 'all' && m.plan !== currentPlanFilter) return false;
        if (query && !String(m.name || '').toLowerCase().includes(query)) return false;
        return true;
    });

    const listEl = document.getElementById(isExpiredTab ? 'expiredMembersList' : 'membersList');
    document.getElementById('expiredMembersCount').textContent = members.filter(m => m.expiry && m.expiry < today && !isInactiveMember(m, today)).length;
    if (filtered.length === 0) {
        const groupName = isExpiredTab ? 'recently expired' : 'active';
        listEl.innerHTML = `<div class="empty-state">No ${groupName} members match these filters.</div>`;
        return;
    }

    listEl.innerHTML = filtered.map(m => {
        const statusClass = isExpiredTab ? 'expired' : (m.paid ? '' : 'pending');
        const statusText = isExpiredTab ? 'Expired' : (m.paid ? 'Paid' : 'Pending');
        return `
            <div class="member-row">
                <div class="member-info">
                    <div class="member-avatar">${initials(m.name)}</div>
                    <div class="member-details">
                        <h4>${m.name}</h4>
                        <p>${m.plan} · Expires ${m.expiry}${isExpiredTab ? ' · EXPIRED' : ''}</p>
                    </div>
                </div>
                <div class="member-actions">
                    ${isExpiredTab ? '' : `<button class="renew-btn" onclick="openChangePlanModal('${m.id}')"><i class="fas fa-exchange-alt"></i> Change Plan</button>`}
                    <button class="renew-btn" onclick="renewMember('${m.id}')"><i class="fas fa-sync-alt"></i> Renew</button>
                    <button class="renew-btn" onclick="viewMemberDetails('${m.id}')"><i class="fas fa-user"></i> Details</button>
                    <span class="approve-badge ${statusClass}">${statusText}</span>
                </div>
            </div>`;
    }).join('');
}

function filterPlan(plan) {
    currentPlanFilter = plan;
    document.querySelectorAll('#planPills .pill, #expiredPlanPills .pill').forEach(p => p.classList.toggle('active', p.dataset.plan === plan));
    renderMembers();
}

function viewMemberDetails(id) {
    const member = members.find(item => String(item.id) === String(id));
    if (!member) return;
    const field = (label, value) => `<div class="member-detail-field"><span>${escapeHTML(label)}</span><strong>${escapeHTML(value || '—')}</strong></div>`;
    const emergency = member.emergencyContact && typeof member.emergencyContact === 'object'
        ? [member.emergencyContact.name, member.emergencyContact.relationship, member.emergencyContact.contact].filter(Boolean).join(' · ')
        : member.emergencyContact || '—';
    const healthConditions = Array.isArray(member.healthConditions) && member.healthConditions.length
        ? member.healthConditions.join(', ')
        : 'None reported';
    const fitnessGoals = Array.isArray(member.goals) && member.goals.length
        ? member.goals.join(', ')
        : member.goal || 'General Fitness';
    const signature = member.signature
        ? `<div class="member-detail-signature"><span>Member signature</span><img src="${escapeHTML(member.signature)}" alt="${escapeHTML(member.name)}'s signature"></div>`
        : '';

    openModal(`<h3><i class="fas fa-user"></i> Member Details</h3>
        <p class="modal-sub">${escapeHTML(member.name)} · ${escapeHTML(member.registrationSource || 'Member record')}</p>
        <div class="member-detail-grid">
            ${field('Email', member.email)}${field('Mobile', member.contact)}
            ${field('Date of birth', member.dob)}${field('Age', member.age ? String(member.age) : '')}${field('Sex', member.sex)}
            ${field('Height', member.height ? `${member.height} ${member.heightUnit || 'cm'}` : '')}${field('Weight', member.weight ? `${member.weight} kg` : '')}${field('Emergency contact', emergency)}
            ${field('Plan', member.plan)}${field('Plan price', member.planPrice ? formatPeso(member.planPrice) : '')}${field('Membership status', member.status)}
            ${field('Start date', member.startDate)}${field('Expiry date', member.expiry)}${field('Fitness goals', fitnessGoals)}
            ${field('Health conditions', healthConditions)}${field('Other medical conditions', member.otherMedicalConditions || 'None reported')}
        </div>${signature}<div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Close</button></div>`);
}

/* ========== RENDER: APPROVALS ========== */
function renderApprovals(type = currentApprovalType) {
    const isRenewal = type === 'renewal';
    const el = document.getElementById(isRenewal ? 'renewalApprovalsList' : 'registrationApprovalsList');
    const allPending = pendingApprovals.filter(p => p.status === 'pending');
    const registrations = allPending.filter(p => p.source !== 'dashboard-renewal');
    const renewals = allPending.filter(p => p.source === 'dashboard-renewal');
    document.getElementById('approvalsCount').textContent = allPending.length;
    document.getElementById('registrationApprovalsCount').textContent = registrations.length;
    document.getElementById('renewalApprovalsCount').textContent = renewals.length;
    const pending = isRenewal ? renewals : registrations;

    if (pending.length === 0) {
        el.innerHTML = isRenewal
            ? '<div class="empty-state">No pending renewal requests.</div>'
            : '<div class="empty-state">No pending new registrations.</div>';
        return;
    }

    el.innerHTML = pending.map(p => `
        <article class="approval-card">
            <div class="approval-card-header">
                <div class="member-info">
                    <div class="member-avatar">${initials(p.fullName)}</div>
                    <div class="member-details">
                        <h4>${p.fullName}</h4>
                        <p><strong>${p.source === 'dashboard-renewal' ? 'Renewal application' : 'New member registration'}</strong> · Applied ${new Date(p.submittedAt).toLocaleString()}</p>
                    </div>
                </div>
                <div class="approval-card-badges"><span class="badge-status reserved">${p.source === 'dashboard-renewal' ? 'Renewal' : 'Registration'}</span><span class="badge-status reserved">Pending</span></div>
            </div>
            <div class="approval-detail-grid">
                    <div class="approval-detail">
                        <span class="approval-detail-label">Age · Sex</span>
                        <span>${p.age || '—'} · ${p.sex || '—'}</span>
                    </div>
                    <div class="approval-detail">
                        <span class="approval-detail-label">Mobile</span>
                        <span>${p.mobile || p.contact || '—'}</span>
                    </div>
                    <div class="approval-detail">
                        <span class="approval-detail-label">Height</span>
                        <span>${p.height !== null && p.height !== undefined && p.height !== '' ? `${p.height} ${p.heightUnit || 'cm'}` : 'Not provided'}</span>
                    </div>
                    <div class="approval-detail">
                        <span class="approval-detail-label">Plan</span>
                        <span><strong>${p.plan || 'Renewal'}</strong> — ₱${Number(p.planPrice || 0).toLocaleString('en-PH')}</span>
                    </div>
                    <div class="approval-detail">
                        <span class="approval-detail-label">Dates</span>
                        <span>${p.startDate || '—'} → ${p.endDate || '—'}</span>
                    </div>
                    <div class="approval-detail">
                        <span class="approval-detail-label">Emergency Contact</span>
                        <span>${p.emergencyContact ? `${p.emergencyContact.name} (${p.emergencyContact.relationship}) · ${p.emergencyContact.contact}` : 'Not provided for renewal'}</span>
                    </div>
                    ${p.email ? `<div class="approval-detail"><span class="approval-detail-label">Email</span><span>${escapeHTML(p.email)}</span></div>` : ''}
                    <div class="approval-detail">
                        <span class="approval-detail-label">Other Medical Conditions</span>
                        <span>${p.otherMedicalConditions ? escapeHTML(p.otherMedicalConditions) : 'None reported'}</span>
                    </div>
            </div>
            ${p.signature ? `<div class="approval-signature"><span class="approval-detail-label">Member Signature</span><img src="${p.signature}" alt="${p.fullName}'s digital signature"></div>` : ''}
            <div class="approval-actions">
                <button class="btn-sm" onclick="rejectApplication('${p.id}')"><i class="fas fa-times"></i> Reject</button>
                    <button class="btn-primary" onclick="runWithButtonLoading(this, () => approveApplication('${p.id}'), 'Processing…')"><i class="fas fa-check-circle"></i> ${p.source === 'dashboard-renewal' ? 'Approve Renewal' : 'Approve &amp; Create Account'}</button>
            </div>
        </article>
    `).join('');
}

/* ========== APPROVE / REJECT ========== */
function approveApplication(id) {
    const idx = pendingApprovals.findIndex(x => x.id === id);
    if (idx === -1) return;
    const p = pendingApprovals[idx];
    const isRenewal = p.source === 'dashboard-renewal';
    askConfirmation(isRenewal ? 'Approve renewal?' : 'Approve application?', isRenewal ? `Approve ${p.fullName}'s renewal and reactivate the membership?` : `Approve ${p.fullName}? This will create their account and generate their QR code.`, isRenewal ? 'Approve Renewal' : 'Approve', () => completeApproval(id));
}

function completeApproval(id) {
    const idx = pendingApprovals.findIndex(x => x.id === id);
    if (idx === -1) return;
    const p = pendingApprovals[idx];

    if (p.supabaseRecord) {
        if (p.source === 'dashboard-renewal') completeSupabaseRenewalApproval(p);
        else completeSupabaseRegistrationApproval(p);
        return;
    }

    // Member portal renewal requests update the existing member account.
    // Keep the old subscription snapshot before replacing its dates and plan.
    if (p.source === 'dashboard-renewal') {
        const member = members.find(item => item.id === p.memberId || item.username?.toLowerCase() === p.username?.toLowerCase());
        if (!member) { toast('Could not find the member for this renewal request.', 'error'); return; }
        archiveExpiredMembership(member, true);
        const duration = getPlanDurationDays(p.plan);
        const startDate = todayStr();
        member.plan = p.plan || member.plan;
        member.planPrice = Number(p.planPrice) || getPlanPrice(member.plan, member);
        member.startDate = startDate;
        member.expiry = addDays(startDate, duration);
        member.status = 'active';
        member.paid = true;
        saveDB('members', members);
        saveDB('membershipArchives', membershipArchives);
        sales.unshift({
            id: nextSaleReference(),
            customer: member.name,
            source: 'dashboard-renewal',
            items: member.plan + ' Renewal',
            lineItems: [{ name: member.plan + ' Membership Renewal', quantity: 1, unitPrice: member.planPrice, total: member.planPrice }],
            total: member.planPrice,
            date: todayStr(),
            createdAt: new Date().toISOString(),
            status: 'Paid'
        });
        saveDB('sales', sales);
        pendingApprovals.splice(idx, 1);
        saveDB('pendingApprovals', pendingApprovals);
        renderApprovals();
        renderMembers();
        renderDashboard();
        renderReports();
        toast(`${member.name}'s renewal was approved. Their previous subscription is saved in Archives.`, 'success');
        return;
    }

    users.push({
        email: p.email,
        fullName: p.fullName,
        role: 'customer',
        createdAt: new Date().toISOString()
    });
    saveDB('users', users);

    const memberId = uid('M');
    const newMember = {
        id: memberId,
        name: p.fullName,
        plan: p.plan,
        planPrice: Number(p.planPrice) || 0,
        startDate: p.startDate,
        expiry: p.endDate,
        status: 'active',
        registrationSource: 'Online application',
        paid: true,
        goal: p.goals[0] || 'General Fitness',
        contact: p.mobile,
        email: p.email || '',
        height: p.height ?? null,
        heightUnit: p.heightUnit || null,
        weight: p.weight ?? null,
        healthConditions: p.healthConditions || [],
        otherMedicalConditions: p.otherMedicalConditions || '',
        signature: p.signature || null,
        qrCode: 'IRONGRIND|' + memberId
    };
    members.push(newMember);
    saveDB('members', members);

    const registrationSaleId = nextSaleReference();
    sales.unshift({
        id: registrationSaleId,
        customer: p.fullName,
        items: p.plan + ' Membership',
        total: p.planPrice,
        date: todayStr(),
        status: 'Paid'
    });
    saveDB('sales', sales);

    pendingApprovals.splice(idx, 1);
    saveDB('pendingApprovals', pendingApprovals);

    toast(`${newMember.name}'s membership was approved.`, 'success');
    renderApprovals();
    renderMembers();
    renderDashboard();
}

async function completeSupabaseRegistrationApproval(application) {
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

function mapSupabaseMember(row, username = '', email = '') {
    const paidValue = row.paid;
    return {
        id: row.id,
        authUserId: row.auth_user_id,
        name: row.full_name,
        dob: row.date_of_birth,
        age: row.age,
        sex: row.sex,
        plan: row.plan,
        planPrice: Number(row.plan_price) || (typeof paidValue === 'number' ? paidValue : 0),
        startDate: row.start_date,
        expiry: row.expiry_date || row.end_date,
        status: row.status,
        paid: typeof paidValue === 'boolean' ? paidValue : Number(paidValue) > 0,
        goal: (row.fitness_goals || [])[0] || 'General Fitness',
        goals: row.fitness_goals || [],
        contact: row.mobile,
        email: row.email || email,
        username: row.username || username,
        height: row.height,
        heightUnit: row.height_unit,
        weight: row.weight_kg ?? row.weight,
        emergencyContact: row.emergency_contact && typeof row.emergency_contact === 'object'
            ? row.emergency_contact
            : { name: row.emergency_name, relationship: row.emergency_relationship, contact: row.emergency_contact },
        healthConditions: row.health_conditions || [],
        otherMedicalConditions: row.other_medical_conditions || '',
        signature: row.signature_path || row.signature_data || null,
        qrCode: `IRONGRIND|${row.id}`,
        registrationSource: row.registration_source || 'Online application'
    };
}

async function loadSupabaseMembershipData() {
    const supabaseClient = window.ironGrindSupabase;
    if (!supabaseClient) return;
    const [applicationsResult, membersResult] = await Promise.all([
        supabaseClient.from('membership_applications').select('*').eq('status', 'pending'),
        supabaseClient.from('members').select('*')
    ]);

    if (applicationsResult.error) {
        console.error('Could not load Supabase applications:', applicationsResult.error);
        toast(`Could not load online applications: ${applicationsResult.error.message}`, 'error');
    } else {
        const remoteApps = applicationsResult.data.map(row => ({
            id: row.id,
            fullName: row.full_name,
            dob: row.date_of_birth,
            age: row.age,
            sex: row.sex,
            mobile: row.mobile,
            height: row.height,
            heightUnit: row.height_unit,
            weight: row.weight_kg ?? row.weight,
            emergencyContact: row.emergency_contact_data && typeof row.emergency_contact_data === 'object'
                ? row.emergency_contact_data
                : row.emergency_contact && typeof row.emergency_contact === 'object'
                    ? row.emergency_contact
                : { name: row.emergency_name, relationship: row.emergency_relationship, contact: row.emergency_contact },
            plan: row.plan,
            planPrice: Number(row.plan_price) || 0,
            startDate: row.start_date,
            endDate: row.end_date,
            healthConditions: row.health_conditions || [],
            otherMedicalConditions: row.other_medical_conditions || '',
            goals: row.fitness_goals || [],
            signature: row.signature_path || row.signature_data || null,
            email: row.email,
            username: row.username,
            submittedAt: row.submitted_at || row.created_at,
            status: row.status,
            source: row.application_type === 'renewal' ? 'dashboard-renewal' : 'supabase-registration',
            memberId: row.member_id || null,
            supabaseRecord: row
        }));
        pendingApprovals = remoteApps;
        saveDB('pendingApprovals', []);
    }

    if (membersResult.error) {
        console.error('Could not load Supabase members:', membersResult.error);
        toast(`Could not load online members: ${membersResult.error.message}`, 'error');
    } else {
        const remoteMembers = membersResult.data.map(row => mapSupabaseMember(row));
        // Connected mode uses the database as the source of truth. An unlinked
        // cached member must not resurrect a row deleted from public.members.
        members = remoteMembers;
        saveDB('members', members);
    }

    renderDashboard();
    renderMembers();
    renderApprovals();
}

async function loadSupabaseOperationalData(options = {}) {
    const client = window.ironGrindSupabase;
    if (!client) return;
    if (options.captureExpiry !== false) {
        const { error: archiveError } = await client.rpc('admin_capture_expired_memberships');
        if (archiveError) console.error('Could not archive expired memberships:', archiveError);
    }
    const [productsResult, salesResult, attendanceResult, renewalsResult, historyResult] = await Promise.all([
        client.from('products').select('*').order('name'),
        client.from('sales')
            .select('*, sale_items!sale_items_sale_id_fkey(*)')
            .order('sold_at', { ascending: false }),
        client.from('attendance').select('*, members(full_name)').order('time_in', { ascending: false }),
        client.from('membership_applications').select('*')
            .eq('application_type', 'renewal').eq('status', 'approved')
            .order('reviewed_at', { ascending: false }),
        client.from('membership_history').select('*').order('recorded_at', { ascending: false })
    ]);

    if (productsResult.error) {
        console.error('Could not load Supabase products:', productsResult.error);
        toast(`Could not load inventory from Supabase: ${productsResult.error.message}`, 'error');
    } else {
        const mappedProducts = productsResult.data.map(mapSupabaseProduct);
        products = mappedProducts.filter(product => product.isActive);
        archivedProducts = mappedProducts.filter(product => !product.isActive);
    }
    if (salesResult.error) {
        console.error('Could not load Supabase sales:', salesResult.error);
        toast(`Could not load sales from Supabase: ${salesResult.error.message}`, 'error');
    } else {
        sales = salesResult.data.map(mapSupabaseSale);
    }
    if (attendanceResult.error) {
        console.error('Could not load Supabase attendance:', attendanceResult.error);
        toast(`Could not load attendance from Supabase: ${attendanceResult.error.message}`, 'error');
    } else {
        attendance = attendanceResult.data.map(mapSupabaseAttendance);
    }
    if (renewalsResult.error) {
        console.error('Could not load approved renewal applications:', renewalsResult.error);
        approvedRenewalApplications = [];
        toast(`Could not load approved renewals for the report: ${renewalsResult.error.message}`, 'error');
    } else {
        approvedRenewalApplications = renewalsResult.data.map(mapApprovedRenewalApplication);
    }
    if (historyResult.error) {
        console.error('Could not load membership history:', historyResult.error);
        const permissionDenied = /permission denied for table ["']?membership_history/i.test(historyResult.error.message || '');
        toast(permissionDenied
            ? 'Supabase still denies SELECT on membership_history. In the connected project, run migration 20261027000001_membership_history_read_access.sql and verify authenticated has SELECT permission.'
            : `Could not load membership archives from Supabase: ${historyResult.error.message}`, 'error');
    } else {
        const remoteHistory = historyResult.data.map(row => {
            const member = members.find(item => String(item.id) === String(row.member_id));
            return {
                id: row.id,
                memberId: row.member_id,
                memberName: member?.name || 'Member',
                username: member?.username || '',
                plan: row.previous_plan || row.new_plan || '—',
                startDate: row.previous_start_date || '',
                expiry: row.previous_expiry_date || '',
                price: Number(row.previous_price) || 0,
                archivedAt: row.recorded_at,
                renewedAt: row.notes?.includes('Archived when renewed') ? row.recorded_at : null,
                eventType: row.event_type,
                previousPlan: row.previous_plan,
                previousStartDate: row.previous_start_date,
                previousExpiry: row.previous_expiry_date,
                previousPrice: Number(row.previous_price) || 0,
                newPlan: row.new_plan,
                newStartDate: row.new_start_date,
                newExpiry: row.new_expiry_date,
                newPrice: Number(row.new_price) || 0,
                changedAt: row.recorded_at,
                changedBy: row.event_type
            };
        });
        membershipArchives = remoteHistory.filter(row => row.eventType === 'expired');
        planArchives = remoteHistory.filter(row => row.eventType === 'plan_change');
    }
    renderStore();
    renderSales();
    renderAttendance();
    renderDashboard();
    renderReports();
    renderWalkinSalesReport();
}

function scheduleAdminRealtimeRefresh(refreshMemberships) {
    if (refreshMemberships) realtimeRefreshPending = true;
    clearTimeout(realtimeRefreshTimer);
    realtimeRefreshTimer = setTimeout(async () => {
        if (realtimeRefreshBusy) {
            realtimeRefreshPending = true;
            return;
        }
        realtimeRefreshBusy = true;
        try {
            do {
                const includeMemberships = realtimeRefreshPending || refreshMemberships;
                realtimeRefreshPending = false;
                if (includeMemberships) await loadSupabaseMembershipData();
                await loadSupabaseOperationalData({ captureExpiry: false });
                refreshMemberships = false;
            } while (realtimeRefreshPending);
        } finally {
            realtimeRefreshBusy = false;
        }
    }, 300);
}

function subscribeAdminRealtimeUpdates() {
    const client = window.ironGrindSupabase;
    if (!client || adminRealtimeChannel) return;

    adminRealtimeChannel = client.channel('admin-live-application-and-attendance-updates')
        .on('postgres_changes', {
            event: '*', schema: 'public', table: 'membership_applications'
        }, payload => {
            console.info('Membership application changed in Supabase:', payload.eventType);
            scheduleAdminRealtimeRefresh(true);
        })
        .on('postgres_changes', {
            event: '*', schema: 'public', table: 'attendance'
        }, payload => {
            console.info('Attendance changed in Supabase:', payload.eventType);
            scheduleAdminRealtimeRefresh(false);
        })
        .subscribe(status => {
            if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
                console.error(`Supabase Realtime subscription status: ${status}`);
            }
        });
}

async function initializeSupabaseAdminData() {
    const client = window.ironGrindSupabase;
    if (!client) {
        toast('The login service did not load. Check your connection and reload.', 'error');
        return false;
    }

    const { data: { user } = {}, error: authError } = await client.auth.getUser();
    if (!user) {
        console.error('Admin page has no active Supabase Auth session:', authError);
        await window.redirectExpiredAdminSession(client);
        return false;
    }
    if (authError) {
        console.error('Could not validate the admin session:', authError);
        toast('Could not verify your session. Check your connection and reload.', 'error');
        return false;
    }

    const { data: profile, error: profileError } = await client
        .from('profiles')
        .select('role,full_name,username')
        .eq('id', user.id)
        .maybeSingle();
    if (profileError || profile?.role !== 'admin') {
        console.error('Could not verify the Supabase dashboard profile:', profileError || 'Profile is not an admin.');
        toast(profileError
            ? `Could not verify your account: ${profileError.message}`
            : 'This account is not an admin account.', 'error');
        if (!profileError) window.location.replace(profile?.role === 'staff' ? 'staff.html' : profile?.role === 'member' ? 'customer.html' : 'index.html');
        return false;
    }

    document.getElementById('currentUserName').textContent = profile.full_name || profile.username;
    activeDashboardRole = 'admin';
    subscribeAdminRealtimeUpdates();
    await loadSupabaseMembershipData();
    await loadSupabaseOperationalData();
    await restoreMobileAttendancePairing();
    startAdminMembershipRefresh();
    document.body.classList.remove('admin-auth-pending');
    document.body.classList.add('admin-auth-verified');
    document.getElementById('page-loader')?.classList.add('hidden-loader');
    return true;
}

function startAdminMembershipRefresh() {
    if (adminMembershipRefreshTimer) return;
    const refresh = async () => {
        if (document.hidden || adminMembershipRefreshBusy || !window.ironGrindSupabase) return;
        adminMembershipRefreshBusy = true;
        try { await loadSupabaseMembershipData(); }
        catch (error) { console.error('Could not refresh membership applications:', error); }
        finally { adminMembershipRefreshBusy = false; }
    };
    // Realtime is the primary path. Polling covers missed events or a tab that
    // was asleep when a registration was submitted on another device.
    adminMembershipRefreshTimer = window.setInterval(refresh, 30000);
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
}

function rejectApplication(id) {
    const idx = pendingApprovals.findIndex(x => x.id === id);
    if (idx === -1) return;
    const p = pendingApprovals[idx];
    askConfirmation('Reject application?', `Reject ${p.fullName}'s application?`, 'Reject', () => completeRejection(id), true);
}

async function completeRejection(id) {
    const idx = pendingApprovals.findIndex(x => x.id === id);
    if (idx === -1) return;
    const application = pendingApprovals[idx];
    if (application.supabaseRecord) {
        const { data: { user }, error: authError } = await window.ironGrindSupabase.auth.getUser();
        if (authError || !user) { toast('Your Supabase session expired. Please sign in again.', 'error'); return; }
        const { error } = await window.ironGrindSupabase.rpc('review_membership_request', {
            p_application_id: application.id, p_decision: 'rejected'
        });
        if (error) { toast(`Could not reject application: ${error.message}`, 'error'); return; }
    }
    pendingApprovals.splice(idx, 1);
    saveDB('pendingApprovals', pendingApprovals.filter(item => !item.supabaseRecord));
    renderApprovals();
    renderDashboard();
    toast('Application rejected.', 'error');
}

/* ========== ADD MEMBER (FULL REGISTRATION FORM) ========== */
let signaturePad = null;

function openAddMemberModal() {
    signaturePad = null;
    openModal(`
        <h3 style="display:flex; align-items:center; gap:10px;"><i class="fas fa-user-plus"></i> Add New Member</h3>
        <p class="modal-sub">Enter the member’s details, choose a membership plan, and capture their digital signature.</p>

        <!-- PERSONAL INFORMATION -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-user" style="color:#ff6b2b;"></i><span>Personal Information</span>
            </div>
            <div class="form-row" style="grid-template-columns:repeat(3,minmax(0,1fr));">
                <div class="form-group"><label for="wiFirstName">First name (FN) *</label><input type="text" id="wiFirstName" required maxlength="70" autocomplete="given-name" placeholder="Juan"></div>
                <div class="form-group"><label for="wiMiddleInitial">Middle initial (MI, optional)</label><input type="text" id="wiMiddleInitial" maxlength="2" autocomplete="additional-name" placeholder="M." title="Enter one letter, optionally followed by a period."></div>
                <div class="form-group"><label for="wiLastName">Last name (LN) *</label><input type="text" id="wiLastName" required maxlength="70" autocomplete="family-name" placeholder="Dela Cruz"></div>
            </div>
            <div class="form-row">
                <div class="form-group"><label for="wiDob">Date of Birth *</label><input type="date" id="wiDob"></div>
            </div>
            <div class="form-row" style="grid-template-columns:1fr 1fr 1fr;">
                <div class="form-group"><label>Age</label><input type="number" id="wiAge" readonly></div>
                <div class="form-group"><label>Sex</label>
                    <select id="wiSex">
                        <option>Male</option><option>Female</option><option>Prefer not to say</option>
                    </select>
                </div>
                <div class="form-group"><label>Mobile *</label><input type="tel" id="wiContact" inputmode="numeric" maxlength="11" pattern="09[0-9]{9}" placeholder="09171234567" autocomplete="tel"></div>
            </div>
            <div class="form-row">
                <div class="form-group"><label>Height (cm)</label><input type="number" id="wiHeight" placeholder="170"></div>
                <div class="form-group"><label>Weight (kg)</label><input type="number" id="wiWeight" placeholder="65"></div>
            </div>
        </div>

        <!-- EMERGENCY CONTACT -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-phone" style="color:#ff6b2b;"></i><span>Emergency Contact</span>
            </div>
            <div class="form-row" style="grid-template-columns:1fr 1fr 1fr;">
                <div class="form-group"><label>Name *</label><input type="text" id="wiEcName" placeholder="Maria Dela Cruz"></div>
                <div class="form-group"><label>Relationship *</label><input type="text" id="wiEcRelation" placeholder="Mother"></div>
                <div class="form-group"><label>Contact Number *</label><input type="tel" id="wiEcContact" inputmode="numeric" maxlength="11" pattern="09[0-9]{9}" placeholder="09171234567" autocomplete="tel"></div>
            </div>
        </div>

        <!-- MEMBERSHIP DETAILS -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-id-card" style="color:#ff6b2b;"></i><span>Membership Details</span>
            </div>
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(140px, 1fr)); gap:10px; margin-bottom:16px;">
                <label style="cursor:pointer; background:#11161f; border:2px solid #1e2533; border-radius:12px; padding:12px; display:block;">
                    <input type="radio" name="wiPlan" value="Monthly|800" required style="accent-color:#ff6b2b; margin-right:6px;">
                    <span style="font-weight:600; font-size:0.85rem;">Monthly</span>
                    <div style="font-size:1rem; font-weight:700; color:#ff6b2b; margin-top:4px;">₱800</div>
                </label>
                <label style="cursor:pointer; background:#11161f; border:2px solid #1e2533; border-radius:12px; padding:12px; display:block;">
                    <input type="radio" name="wiPlan" value="Half Month|400" style="accent-color:#ff6b2b; margin-right:6px;">
                    <span style="font-weight:600; font-size:0.85rem;">Half Month</span>
                    <div style="font-size:1rem; font-weight:700; color:#ff6b2b; margin-top:4px;">₱400</div>
                </label>
                <label style="cursor:pointer; background:#11161f; border:2px solid #1e2533; border-radius:12px; padding:12px; display:block;">
                    <input type="radio" name="wiPlan" value="Walk-in|80" style="accent-color:#ff6b2b; margin-right:6px;">
                    <span style="font-weight:600; font-size:0.85rem;">Walk-in</span>
                    <div style="font-size:1rem; font-weight:700; color:#ff6b2b; margin-top:4px;">₱80/day</div>
                </label>
            </div>
            <div class="form-row">
                <div class="form-group"><label>Start Date</label><input type="date" id="wiStartDate" readonly></div>
                <div class="form-group"><label>End Date</label><input type="date" id="wiEndDate" readonly></div>
            </div>
        </div>

        <!-- HEALTH & GOAL -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-heartbeat" style="color:#ff6b2b;"></i><span>Health Declaration &amp; Fitness Goal</span>
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px;">
                <div>
                    <p style="font-size:0.75rem; color:#8b95a9; margin-bottom:10px;">Health conditions:</p>
                    <div style="display:flex; flex-direction:column; gap:8px;">
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" id="wiHcBp" style="accent-color:#ff6b2b;"> High Blood Pressure</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" id="wiHcHeart" style="accent-color:#ff6b2b;"> Heart Condition</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" id="wiHcAsthma" style="accent-color:#ff6b2b;"> Asthma</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" id="wiHcInjury" style="accent-color:#ff6b2b;"> Recent Injury/Surgery</label>
                    </div>
                </div>
                <div>
                    <p style="font-size:0.75rem; color:#8b95a9; margin-bottom:10px;">Fitness goal:</p>
                    <div style="display:flex; flex-direction:column; gap:8px;">
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" name="wiGoal" value="Weight Loss" style="accent-color:#ff6b2b;"> Weight Loss</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" name="wiGoal" value="Muscle Gain" style="accent-color:#ff6b2b;"> Muscle Gain</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" name="wiGoal" value="Strength" style="accent-color:#ff6b2b;"> Strength</label>
                        <label style="display:flex; align-items:center; gap:8px; font-size:0.8rem;"><input type="checkbox" name="wiGoal" value="General Fitness" style="accent-color:#ff6b2b;"> General Fitness</label>
                    </div>
                </div>
            </div>
        </div>

        <!-- DIGITAL SIGNATURE -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-signature" style="color:#ff6b2b;"></i><span>Digital Signature</span>
            </div>
            <p style="font-size:0.75rem; color:#8b95a9; margin-bottom:10px;">Sign with your finger (mobile) or mouse (desktop).</p>
            <div style="background:#fff; border-radius:12px; overflow:hidden; position:relative;">
                <canvas id="signatureCanvas" style="width:100%; height:180px; display:block; touch-action:none; cursor:crosshair;"></canvas>
            </div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-top:10px;">
                <small style="color:#6a748b; font-size:0.7rem;">Signature required before submitting.</small>
                <button type="button" id="clearSignatureButton" class="btn-sm"><i class="fas fa-eraser"></i> Clear</button>
            </div>
        </div>

        <!-- MEMBER PORTAL ACCOUNT -->
        <div style="background:#0d1219; border:1px solid #1e2533; border-radius:14px; padding:18px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:8px; font-size:0.85rem; font-weight:600; margin-bottom:14px; padding-bottom:10px; border-bottom:1px solid #1e2533;">
                <i class="fas fa-key" style="color:#ff6b2b;"></i><span>Member Portal Account</span>
            </div>
            <p style="font-size:0.75rem; color:#8b95a9; margin-bottom:12px;">Create login credentials so the member can access their portal.</p>
            <div class="form-group"><label>Email Address *</label><input type="email" id="wiEmail" placeholder="member@example.com" autocomplete="email"></div>
            <div class="form-row">
                <div class="form-group"><label>Password *</label><input type="password" id="wiPassword" placeholder="Create a strong password" autocomplete="new-password"></div>
            </div>
            <div class="form-group" style="margin-bottom:0;"><label>Confirm Password *</label><input type="password" id="wiConfirmPassword" placeholder="Re-enter the password" autocomplete="new-password"></div>
        </div>

        <!-- ACTIONS -->
        <div class="modal-actions" style="position:sticky; bottom:0; background:#11161f; padding-top:12px;">
            <button class="btn-sm" onclick="closeModal()">Cancel</button>
            <button class="btn-primary" onclick="runWithButtonLoading(this, submitNewMember, 'Creating member…')"><i class="fas fa-check"></i> Add Member &amp; Generate QR</button>
        </div>
    `);

    setupPhMobileInput(document.getElementById('wiContact'));
    setupPhMobileInput(document.getElementById('wiEcContact'));

    // ---- Attach the signature canvas after the modal is visible ----
    setTimeout(() => {
        if (typeof initDigitalSignature !== 'function') {
            toast('The signature canvas could not load. Please refresh and try again.', 'error');
            return;
        }
        signaturePad = initDigitalSignature('signatureCanvas', 'clearSignatureButton');
    }, 100);

    // ---- Auto-compute age from DOB ----
    setTimeout(() => {
        const dobInput = document.getElementById('wiDob');
        if (dobInput) {
            dobInput.addEventListener('change', function () {
                const dob = new Date(this.value);
                if (isNaN(dob)) return;
                const today = new Date();
                let age = today.getFullYear() - dob.getFullYear();
                const m = today.getMonth() - dob.getMonth();
                if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
                document.getElementById('wiAge').value = age >= 0 ? age : '';
            });
        }

        // ---- Auto-compute end date from plan ----
        const updateWiDates = () => {
            const plan = document.querySelector('input[name="wiPlan"]:checked');
            if (!plan) return;
            const name = plan.value.split('|')[0];
            const days = name === 'Monthly' ? 30 : name === 'Half Month' ? 15 : 1;
            const start = todayStr();
            document.getElementById('wiStartDate').value = start;
            document.getElementById('wiEndDate').value = addDays(start, days);
        };
        document.querySelectorAll('input[name="wiPlan"]').forEach(r => r.addEventListener('change', updateWiDates));
    }, 100);
}

function clearSignature() {
    if (signaturePad) signaturePad.clear();
}

async function submitNewMember() {
    // ---- Personal ----
    let name;
    try {
        name = composeAdminMemberName(
            document.getElementById('wiFirstName').value,
            document.getElementById('wiMiddleInitial').value,
            document.getElementById('wiLastName').value
        );
    } catch (error) {
        toast(error.message, 'error');
        return;
    }
    const dob = document.getElementById('wiDob').value;
    const age = Number(document.getElementById('wiAge').value);
    const sex = document.getElementById('wiSex').value;
    const contact = document.getElementById('wiContact').value.trim();
    const email = document.getElementById('wiEmail').value.trim().toLowerCase();
    const password = document.getElementById('wiPassword').value;
    const confirmPassword = document.getElementById('wiConfirmPassword').value;
    const height = document.getElementById('wiHeight').value;
    const weight = document.getElementById('wiWeight').value;

    // ---- Emergency ----
    const ecName = document.getElementById('wiEcName').value.trim();
    const ecRelation = document.getElementById('wiEcRelation').value.trim();
    const ecContact = document.getElementById('wiEcContact').value.trim();

    // ---- Plan ----
    const planInput = document.querySelector('input[name="wiPlan"]:checked');
    if (!planInput) { toast('Please select a membership plan.', 'error'); return; }
    const [plan, price] = planInput.value.split('|');
    const startDate = document.getElementById('wiStartDate').value || todayStr();
    const endDate = document.getElementById('wiEndDate').value;
    const days = plan === 'Monthly' ? 30 : plan === 'Half Month' ? 15 : 1;

    // ---- Health ----
    const healthConditions = [];
    if (document.getElementById('wiHcBp').checked) healthConditions.push('High Blood Pressure');
    if (document.getElementById('wiHcHeart').checked) healthConditions.push('Heart Condition');
    if (document.getElementById('wiHcAsthma').checked) healthConditions.push('Asthma');
    if (document.getElementById('wiHcInjury').checked) healthConditions.push('Recent Injury');

    // ---- Goals ----
    const goals = Array.from(document.querySelectorAll('input[name="wiGoal"]:checked')).map(g => g.value);

    // ---- Validation ----
    if (!validPersonName(name) || !validPersonName(ecName)) {
        toast('Names must contain letters and cannot contain numbers. Check the member and emergency contact names.', 'error');
        return;
    }
    if (!dob) { toast('Date of Birth is required.', 'error'); return; }
    if (age < 12) { toast('Member must be at least 12 years old.', 'error'); return; }
    if (!contact) { toast('Mobile Number is required.', 'error'); return; }
    if (!/^09\d{9}$/.test(contact)) { toast('Enter an 11-digit PH mobile number starting with 09.', 'error'); return; }
    if (!email || !document.getElementById('wiEmail').checkValidity()) { toast('Enter a valid email address for the member account.', 'error'); return; }
    if (!ecName || !ecRelation || !ecContact) { toast('Emergency contact is required.', 'error'); return; }
    if (!/^09\d{9}$/.test(ecContact)) { toast('Enter an 11-digit PH emergency contact number starting with 09.', 'error'); return; }
    if (!newPasswordValid(password, 8)) { toast(newPasswordMessage(8), 'error'); return; }
    if (password !== confirmPassword) { toast('Passwords do not match.', 'error'); return; }
    if (users.some(user => user.email?.toLowerCase() === email) || members.some(member => member.email?.toLowerCase() === email) || pendingApprovals.some(application => application.email?.toLowerCase() === email)) {
        toast('That email address is already in use.', 'error');
        return;
    }

    // ---- SIGNATURE VALIDATION ----
    if (!signaturePad || signaturePad.isEmpty()) {
        toast('Digital signature is required.', 'error');
        return;
    }
    const signatureData = signaturePad.toDataURL('image/png');

    if (window.ironGrindSupabase) {
        const { data: authData, error: authError } = await window.ironGrindSupabase.auth.getUser();
        if (authError || !authData.user) { toast('Your Supabase session expired. Please sign in again.', 'error'); return; }
        const { error } = await window.ironGrindSupabase.functions.invoke('admin-create-member', {
            body: {
                email, password, fullName: name, mobile: contact,
                dateOfBirth: dob, age, sex, height, heightUnit: height ? 'cm' : null,
                weight, emergencyName: ecName, emergencyRelationship: ecRelation, emergencyContact: ecContact,
                plan, planPrice: Number(price), startDate,
                expiryDate: endDate || addDays(startDate, days), fitnessGoals: goals,
                healthConditions, otherMedicalConditions: '',
                signatureData
            }
        });
        if (error) {
            const details = error.context?.json ? await error.context.json().catch(() => null) : null;
            const serverMessage = details?.error || '';
            if (error.name === 'FunctionsFetchError' || /failed to send a request to the edge function/i.test(error.message || '')) {
                toast('Could not reach Supabase Edge Function admin-create-member. Confirm it is deployed to this project, then check the browser Network/Console for a network or CORS error.', 'error');
            } else {
                toast(`Could not create member in Supabase: ${serverMessage || error.message}`, 'error');
            }
            return;
        }
        signaturePad = null;
        closeModal();
        await loadSupabaseMembershipData();
        await loadSupabaseOperationalData();
        toast(`${name} was registered in Supabase and their membership payment was recorded.`, 'success');
        return;
    }

    toast('Supabase is unavailable. Member accounts can only be created securely when the database connection is active.', 'error');
}

function openChangePlanModal(id) {
    const member = members.find(item => String(item.id) === String(id));
    if (!member) return;
    openModal(`<h3><i class="fas fa-exchange-alt"></i> Change Membership Plan</h3>
        <p class="modal-sub">Changing ${escapeHTML(member.name)} from <strong>${escapeHTML(member.plan || 'No plan')}</strong>. The new plan starts today and replaces the current expiry; the previous plan and dates will be kept in the archive. The previous payment is non-refundable, including unused days.</p>
        <div class="form-group" style="margin-bottom:14px;"><label>New Plan</label><select id="changePlanSelect" onchange="updatePlanChangePrice()">
            <option value="Monthly" data-days="30" data-price="800">Monthly — ₱800 / 30 days</option>
            <option value="Half Month" data-days="15" data-price="400">Half Month — ₱400 / 15 days</option>
            <option value="Walk-in" data-days="1" data-price="80">Walk-in — ₱80 / day</option>
        </select></div>
        <div class="form-group"><label>New Plan Charge (₱)</label><input type="number" id="changePlanPrice" min="0" step="0.01" placeholder="Enter amount"></div>
        <p style="font-size:0.75rem; color:#8b95a9;">Previous plan: ${escapeHTML(member.plan || '—')} · Expires ${escapeHTML(member.expiry || '—')}</p>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="submitMemberPlanChange('${encodeURIComponent(String(member.id))}')"><i class="fas fa-archive"></i> Save Change &amp; Archive</button></div>`);
    updatePlanChangePrice();
}

function updatePlanChangePrice() {
    const select = document.getElementById('changePlanSelect');
    const priceInput = document.getElementById('changePlanPrice');
    if (!select || !priceInput) return;
    const selectedPrice = select.selectedOptions[0]?.dataset.price;
    priceInput.value = selectedPrice || '';
    priceInput.readOnly = Boolean(selectedPrice);
}

async function submitMemberPlanChange(encodedId) {
    const id = decodeURIComponent(encodedId);
    const member = members.find(item => String(item.id) === id);
    const select = document.getElementById('changePlanSelect');
    const priceValue = document.getElementById('changePlanPrice')?.value.trim();
    const price = Number(priceValue);
    if (!member || !select) return;
    const newPlan = select.value;
    const duration = Number(select.selectedOptions[0]?.dataset.days) || getPlanDurationDays(newPlan);
    if (!priceValue || !Number.isFinite(price) || price <= 0) { toast('Enter an amount greater than zero for the new plan.', 'error'); return; }
    if (newPlan === member.plan && price === Number(member.planPrice || getPlanPrice(member.plan, member))) {
        toast('The member already has this plan and price.', 'error');
        return;
    }

    const changedAt = new Date().toISOString();
    const nextStartDate = todayStr();
    const nextExpiry = addDays(nextStartDate, duration);
    if (window.ironGrindSupabase) {
        if (!isUUID(member.id)) { toast('This member is not linked to a Supabase member record.', 'error'); return; }
        const transactionReference = `IG-PC-${crypto.randomUUID().toUpperCase()}`;
        const { error } = await window.ironGrindSupabase.rpc('admin_record_membership_change', {
            p_member_id: member.id,
            p_event_type: 'plan_change',
            p_new_plan: newPlan,
            p_new_price: price,
            p_new_start_date: nextStartDate,
            p_new_expiry_date: nextExpiry,
            p_customer_name: member.name,
            p_mobile: member.contact || null,
            p_receipt_number: transactionReference
        });
        if (error) { toast(`Could not save plan change to Supabase: ${error.message}`, 'error'); return; }
        closeModal();
        await loadSupabaseMembershipData();
        await loadSupabaseOperationalData();
        toast(`${member.name}'s plan changed to ${newPlan}. Previous plan archived.`, 'success');
        return;
    }
    const previous = {
        plan: member.plan || '—',
        startDate: member.startDate || null,
        expiry: member.expiry || null,
        planPrice: Number(member.planPrice || getPlanPrice(member.plan, member)) || 0
    };
    archiveExpiredMembership(member, true);
    const archiveRecord = {
        id: 'PA-' + Date.now().toString().slice(-8),
        memberId: member.id,
        memberName: member.name,
        previousPlan: previous.plan,
        previousStartDate: previous.startDate,
        previousExpiry: previous.expiry,
        previousPrice: previous.planPrice,
        newPlan,
        newStartDate: nextStartDate,
        newExpiry: nextExpiry,
        newPrice: price,
        refundIssued: false,
        refundAmount: 0,
        refundPolicy: 'No refund for the previous plan, including unused days.',
        changedAt,
        changedBy: 'admin'
    };

    planArchives.unshift(archiveRecord);
    member.plan = newPlan;
    member.planPrice = price;
    member.startDate = nextStartDate;
    member.expiry = nextExpiry;
    member.paid = true;
    member.status = 'active';

    const saleId = nextSaleReference();
    sales.unshift({
        id: saleId,
        customer: member.name,
        items: `${newPlan} Membership Plan Change`,
        lineItems: [{ name: `${newPlan} Membership Plan Change`, quantity: 1, unitPrice: price, total: price }],
        total: price,
        date: todayStr(),
        createdAt: changedAt,
        status: 'Paid'
    });

    saveDB('members', members);
    saveDB('planArchives', planArchives);
    saveDB('membershipArchives', membershipArchives);
    saveDB('sales', sales);
    closeModal();
    renderMembers();
    renderDashboard();
    renderSales();
    renderReports();
    toast(`${member.name}'s plan changed to ${newPlan}. Previous plan archived.`, 'success');
}

function renewMember(id) {
    const member = members.find(item => item.id === id);
    if (!member) return;
    const selectedPlan = ['Monthly', 'Half Month', 'Walk-in'].includes(member.plan) ? member.plan : 'Monthly';
    openModal(`
        <h3><i class="fas fa-sync-alt"></i> Counter Membership Renewal</h3>
        <p class="modal-sub">Choose the renewal plan and record the counter payment.</p>
        <div class="form-row">
            <div class="form-group"><label for="crName">Full Name *</label><input type="text" id="crName" value="${escapeHTML(member.name || '')}" required></div>
            <div class="form-group"><label for="crContact">Contact Number *</label><input type="tel" id="crContact" value="${escapeHTML(member.contact || '')}" inputmode="numeric" maxlength="11" pattern="09[0-9]{9}" placeholder="09171234567" autocomplete="tel" required></div>
        </div>
        <div class="form-group"><label for="crPlan">Membership Plan</label><select id="crPlan">
            <option value="Monthly|800" ${selectedPlan === 'Monthly' ? 'selected' : ''}>Monthly — ₱800</option>
            <option value="Half Month|400" ${selectedPlan === 'Half Month' ? 'selected' : ''}>Half Month — ₱400</option>
            <option value="Walk-in|80" ${selectedPlan === 'Walk-in' ? 'selected' : ''}>Walk-in — ₱80</option>
        </select></div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="runWithButtonLoading(this, () => completeMemberRenewal('${member.id}'), 'Saving renewal…')"><i class="fas fa-coins"></i> Complete Renewal</button></div>
    `);
    setupPhMobileInput(document.getElementById('crContact'));
}

async function completeMemberRenewal(id) {
    const member = members.find(item => item.id === id);
    if (!member) return;
    const name = document.getElementById('crName').value.trim();
    const contact = document.getElementById('crContact').value.trim();
    const [plan, priceText] = document.getElementById('crPlan').value.split('|');
    const price = Number(priceText);
    if (!name || !contact) { toast('Enter the member name and contact number.', 'error'); return; }
    if (!/^\d+$/.test(contact) || !/^09\d{9}$/.test(contact)) { toast('Enter a valid PH mobile number using digits only (e.g. 09171234567).', 'error'); return; }

    const changedAt = new Date().toISOString();
    const startDate = todayStr();
    const expiry = addDays(startDate, getPlanDurationDays(plan));
    if (window.ironGrindSupabase) {
        if (!isUUID(member.id)) { toast('This member is not linked to a Supabase member record.', 'error'); return; }
        const transactionReference = `IG-CR-${crypto.randomUUID().toUpperCase()}`;
        const { error } = await window.ironGrindSupabase.rpc('admin_record_membership_change', {
            p_member_id: member.id,
            p_event_type: 'renewal',
            p_new_plan: plan,
            p_new_price: price,
            p_new_start_date: startDate,
            p_new_expiry_date: expiry,
            p_customer_name: name,
            p_mobile: contact,
            p_receipt_number: transactionReference
        });
        if (error) { toast(`Could not save renewal to Supabase: ${error.message}`, 'error'); return; }
        closeModal();
        await loadSupabaseMembershipData();
        await loadSupabaseOperationalData();
        toast(`${name}'s membership renewed until ${expiry}.`, 'success');
        return;
    }
    const previous = {
        plan: member.plan || '—', startDate: member.startDate || null, expiry: member.expiry || null,
        planPrice: Number(member.planPrice || getPlanPrice(member.plan, member)) || 0
    };
    archiveExpiredMembership(member, true);
    if (plan !== previous.plan) {
        planArchives.unshift({
            id: 'PA-' + Date.now().toString().slice(-8), memberId: member.id, memberName: member.name,
            previousPlan: previous.plan, previousStartDate: previous.startDate, previousExpiry: previous.expiry,
            previousPrice: previous.planPrice, newPlan: plan, newStartDate: startDate, newExpiry: expiry,
            newPrice: price, refundIssued: false, refundAmount: 0,
            refundPolicy: 'No refund for the previous plan, including unused days.', changedAt, changedBy: 'admin-counter-renewal'
        });
    }
    member.name = name;
    member.contact = contact;
    member.plan = plan;
    member.planPrice = price;
    member.startDate = startDate;
    member.expiry = expiry;
    member.paid = true;
    member.status = 'active';
    const saleId = nextSaleReference();
    sales.unshift({
        id: saleId, customer: name, source: 'counter-renewal', items: `${plan} Membership Renewal`,
        lineItems: [{ name: `${plan} Membership Renewal`, quantity: 1, unitPrice: price, total: price }],
        total: price, date: todayStr(), createdAt: changedAt, status: 'Paid'
    });
    saveDB('members', members);
    saveDB('membershipArchives', membershipArchives);
    saveDB('planArchives', planArchives);
    saveDB('sales', sales);
    closeModal();
    renderMembers();
    renderDashboard();
    renderSales();
    renderReports();
    toast(`${name}'s membership renewed until ${expiry}.`, 'success');
}

/* ========== ATTENDANCE ========== */
function renderAttendance() {
    const today = todayStr();
    const dateInput = document.getElementById('attendanceLogDate');
    if (dateInput && !dateInput.value) dateInput.value = today;
    const selectedDate = dateInput?.value || today;
    const dateAtt = attendance.filter(a => a.date === selectedDate);
    const el = document.getElementById('attendanceLogTable');
    if (!el) return;
    if (dateAtt.length === 0) { el.innerHTML = `<div class="empty-state">No attendance records for ${selectedDate === today ? 'today' : escapeHTML(selectedDate)}.</div>`; return; }
    el.innerHTML = `
        <table class="attendance-table">
            <thead><tr><th>Member</th><th>Time In</th><th>Time Out</th><th>Status</th><th>Action</th></tr></thead>
            <tbody>${dateAtt.map(a => `
                <tr><td>${a.memberName}</td><td>${formatAttendanceClock(a.timeIn)}</td><td>${formatAttendanceClock(a.timeOut)}</td>
                <td>${a.timeOut ? '<span class="badge-status out">Checked Out</span>' : attendanceVisitIncomplete(a.date, a.timeOut) ? '<span class="badge-status incomplete">Incomplete</span>' : '<span class="badge-status in">Inside</span>'}</td>
                <td>${a.timeOut ? '' : `<button class="btn-sm" onclick="checkOut('${a.id}')">Check Out</button>`}</td></tr>
            `).join('')}</tbody>
        </table>`;
}

function startQRScanner() {
    openModal(`<div class="qr-camera-modal">
        <h3><i class="fas fa-qrcode"></i> Choose a Camera</h3>
        <p class="modal-sub">Scan with a camera connected to this device or pair a phone camera.</p>
        <p class="phone-pair-remember">Paired phones stay connected for 30 days. Scan the pairing QR within 10 minutes.</p>
        <div class="modal-actions"><button class="btn-primary" onclick="startLocalQRScanner()"><i class="fas fa-laptop"></i> This device</button><button class="btn-primary" onclick="startPhoneQRPairing(true)"><i class="fas fa-mobile-screen-button"></i> Phone camera</button><button class="btn-sm" onclick="closeModal()">Cancel</button></div>
    </div>`);
}

async function startPhoneQRPairing(rememberPhone = true) {
    try { await window.requireVerifiedAdmin(); }
    catch (error) { toast(error.message, 'error'); return; }
    const pairingPassword = await requestPairingPassword('Phone camera access', 'Enter the admin-only phone-pairing password to create a secure QR.');
    if (!pairingPassword) return;
    phoneCameraAuthorization = pairingPassword;
    phoneCameraRememberPreference = rememberPhone;
    const { data: settings, error } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    if (error) { toast(`Could not check phone pairing setup: ${error.message}`, 'error'); return; }
    if (!settings?.password_configured) {
        toast('The phone-camera password has not been set in Supabase yet. Ask the database administrator to configure it.', 'error');
        return;
    }
    if (Number(settings?.active_count) >= Number(settings?.max_pairs)) {
        showMobileAttendancePairingModal(null, null, false, true);
        applyPhonePairingCapacityState(settings);
        return;
    }
    await createPhonePairingSession(rememberPhone, pairingPassword);
}

async function createPhonePairingSession(rememberPhone = true, pairingPassword) {
    if (!window.ironGrindSupabase) {
        toast('Phone scanning needs an active Supabase connection.', 'error');
        return;
    }
    try { await window.requireVerifiedAdmin(); }
    catch (error) { toast(error.message, 'error'); return; }
    const { data, error } = await window.ironGrindSupabase.rpc('create_mobile_attendance_scan_session', {
        p_remember_phone: rememberPhone,
        p_pairing_password: pairingPassword
    });
    if (error || !data?.session_id || !data?.token) {
        toast(`Could not connect a phone scanner${error?.message ? `: ${error.message}` : '.'}`, 'error');
        if (/pairing limit reached/i.test(error?.message || '')) showMobileAttendancePairingModal(null, null, false, true);
        return;
    }
    const { data: pairingValid, error: validationError } = await window.ironGrindSupabase.rpc('validate_mobile_attendance_scan_session', {
        p_session_id: data.session_id,
        p_token: data.token
    });
    if (validationError || pairingValid !== true) {
        const removalPin = await requestPairingRemovalPin('Remove incomplete pairing', 'The new QR did not validate. Enter the four-digit admin PIN to remove its reserved slot.');
        if (removalPin) {
            await window.ironGrindSupabase.rpc('close_mobile_attendance_scan_session', { p_session_id: data.session_id, p_pairing_pin: removalPin });
        }
        toast(validationError
            ? `Supabase could not validate the new phone pairing: ${validationError.message}. Apply migrations 20261104000009 and 20261104000010.`
            : 'Supabase rejected the new phone pairing. Apply migrations 20261104000009 and 20261104000010, then try again.', 'error');
        return;
    }
    activeMobileAttendanceSessionId = data.session_id;
    phoneCameraAuthorization = pairingPassword;
    phoneCameraRememberPreference = rememberPhone;
    activeMobileAttendancePersistent = Boolean(data.remember_phone);
    mobileAttendanceSessionPersistence.set(data.session_id, activeMobileAttendancePersistent);
    const phoneUrl = new URL('attendance-phone.html', window.location.href);
    phoneUrl.searchParams.set('session', data.session_id);
    phoneUrl.searchParams.set('token', data.token);
    phoneUrl.searchParams.set('remember', activeMobileAttendancePersistent ? '1' : '0');
    phoneUrl.searchParams.set('expires', data.expires_at || '');
    activeMobileAttendancePairingUrl = phoneUrl.toString();
    showMobileAttendancePairingModal(data.session_id, activeMobileAttendancePairingUrl, activeMobileAttendancePersistent);
    startMobileAttendancePolling(data.session_id);
    refreshPairedAttendancePhones(true);
}

function showMobileAttendancePairingModal(sessionId, pairingUrl, persistent, capacityReached = false) {
    const localOnly = pairingUrl && ['localhost', '127.0.0.1', '::1'].includes(new URL(pairingUrl).hostname);
    openModal(`<div class="qr-camera-modal">
        <h3><i class="fas fa-mobile-screen-button"></i> Connect Phone Camera</h3>
        <p class="modal-sub">${capacityReached ? 'Pairing limit reached.' : pairingUrl ? `Scan to pair · ${persistent ? '30 days' : '10 minutes'}` : 'Create a QR to pair a phone.'}</p>
        ${localOnly ? '<p class="qr-camera-status">This is localhost, which phones cannot reach. Open the hosted HTTPS admin site to pair.</p>' : ''}
        <section class="paired-phones-section">
            <a class="scanner-install-link" href="attendance-phone.html" target="_blank" rel="noopener"><i class="fas fa-mobile-screen-button" aria-hidden="true"></i> Open / install scanner <i class="fas fa-arrow-up-right-from-square" aria-hidden="true"></i></a>
            <p class="qr-camera-status">Already paired? Open this link on your phone to reinstall.</p>
        </section>
        ${pairingUrl ? `<div class="phone-pair-qr-shell"><div id="phonePairQr" data-session-id="${sessionId}" data-pairing-state="pending" class="phone-pair-qr" aria-label="Phone scanner pairing QR code"></div><button id="phonePairQrVisibility" class="btn-sm phone-pair-qr-visibility" type="button" onclick="togglePhonePairingQrVisibility()" aria-pressed="false"><i class="fas fa-eye-slash" aria-hidden="true"></i> Hide QR</button></div>` : ''}
        <p id="phonePairStatus" class="qr-camera-status" role="status">${capacityReached ? 'Pairing limit reached.' : pairingUrl ? 'Waiting for phone…' : 'Ready to pair.'}</p>
        <p id="phonePairCapacityMessage" class="qr-camera-status ${capacityReached ? '' : 'hidden'}" role="status">End a phone or pending QR to free a slot.</p>
        <div class="phone-pairing-limit-controls">
            <p id="phonePairingLimitSummary" class="qr-camera-status">Loading…</p>
            <button class="btn-sm" onclick="changePhonePairingLimit()">Change phone limit</button>
        </div>
        <section class="paired-phones-section" aria-labelledby="pairedPhonesHeading">
            <h4 id="pairedPhonesHeading">Paired phones <span id="pairedPhonesCount" class="paired-phone-count">0</span></h4>
            <div id="pairedPhonesList" class="paired-phone-list"><p class="paired-phone-empty">Loading paired phones…</p></div>
        </section>
        <section class="paired-phones-section pending-phone-pairings" aria-labelledby="pendingPhonePairingsHeading">
            <h4 id="pendingPhonePairingsHeading">Pending QR codes <span id="pendingPhonePairingsCount" class="paired-phone-count">0</span></h4>
            <div id="pendingPhonePairingsList" class="paired-phone-list"><p class="paired-phone-empty">Loading pending QR codes...</p></div>
        </section>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Close window</button><button id="createPhonePairingQrButton" class="btn-primary ${capacityReached ? 'hidden' : ''}" onclick="startPhoneQRPairing(true)">${pairingUrl || sessionId ? 'Pair another phone' : 'Create pairing QR'}</button>${sessionId ? `<button class="btn-danger phone-pair-end-button" onclick="endMobileAttendanceSession('${sessionId}')">End this pairing</button>` : ''}</div>
    </div>`);
    if (pairingUrl && typeof QRCode !== 'undefined') {
        new QRCode(document.getElementById('phonePairQr'), {
            text: pairingUrl, width: 230, height: 230,
            colorDark: '#101010', colorLight: '#ffffff', correctLevel: QRCode.CorrectLevel.M
        });
    } else if (pairingUrl) {
        document.getElementById('phonePairStatus').textContent = 'The pairing QR could not load. Reload the admin page while connected to the internet.';
    }
    refreshPairedAttendancePhones(true);
    startPhonePairingListPolling();
}

function startPhonePairingListPolling() {
    if (phonePairingListPollTimer !== null) return;
    phonePairingListPollTimer = window.setInterval(() => {
        if (!document.getElementById('pairedPhonesList')) {
            window.clearInterval(phonePairingListPollTimer);
            phonePairingListPollTimer = null;
            return;
        }
        refreshPairedAttendancePhones().catch(error => console.warn('Could not refresh phone pairings:', error));
    }, 5000);
}

function togglePhonePairingQrVisibility() {
    phonePairQrManuallyHidden = !phonePairQrManuallyHidden;
    const settings = window.currentPhonePairingSettings;
    if (settings) applyPhonePairingCapacityState(settings);
}

function applyPhonePairingCapacityState(settings) {
    if (!settings) return;
    const usedSlots = Number(settings.paired_count || 0) + Number(settings.pending_count || 0);
    const slotsFull = usedSlots >= Number(settings.max_pairs);
    if (phonePairingWasAtDeviceLimit !== slotsFull) {
        phonePairQrManuallyHidden = false;
        phonePairingWasAtDeviceLimit = slotsFull;
    }
    const qr = document.getElementById('phonePairQr');
    const visibilityButton = document.getElementById('phonePairQrVisibility');
    const notice = document.getElementById('phonePairCapacityMessage');
    const createButton = document.getElementById('createPhonePairingQrButton');
    const status = document.getElementById('phonePairStatus');
    const qrUsable = Boolean(qr && qr.dataset.pairingState === 'pending');
    const qrHidden = !qrUsable || phonePairQrManuallyHidden;
    if (qr) qr.classList.toggle('hidden', qrHidden);
    if (visibilityButton) {
        visibilityButton.disabled = !qrUsable;
        visibilityButton.setAttribute('aria-pressed', String(!qrHidden));
        visibilityButton.innerHTML = !qrUsable
            ? '<i class="fas fa-eye-slash" aria-hidden="true"></i> QR unavailable'
            : qrHidden
                ? '<i class="fas fa-eye" aria-hidden="true"></i> Show QR'
                : '<i class="fas fa-eye-slash" aria-hidden="true"></i> Hide QR';
    }
    if (notice) notice.classList.toggle('hidden', !slotsFull);
    if (notice && slotsFull) notice.textContent = qrUsable
        ? 'All slots are reserved. Scan this QR to complete its pending pairing.'
        : 'No free slots. End an unused pending QR or a paired phone to create a new pairing.';
    if (createButton) createButton.classList.toggle('hidden', slotsFull);
    if (status && qr && !qrUsable) status.textContent = 'This QR is already used or is no longer active.';
    else if (status && qrUsable && qrHidden) status.textContent = 'QR hidden. Select Show QR when ready.';
    else if (status && qrUsable) status.textContent = 'Waiting for this phone to scan its reserved QR.';
    else if (status && slotsFull) status.textContent = 'No free pairing slots.';
}

function requestPairingPassword(title, description) {
    if (pairingPasswordPromptResolver) pairingPasswordPromptResolver(null);
    return new Promise(resolve => {
        pairingPasswordPromptResolver = resolve;
        openModal(`<form class="qr-camera-modal" onsubmit="submitPairingPassword(event)">
            <h3><i class="fas fa-lock"></i> ${escapeDialogText(title)}</h3>
            <p class="modal-sub">${escapeDialogText(description)} This is separate from your account password.</p>
            <label for="phonePairingPassword">Phone-pairing password</label>
            <input id="phonePairingPassword" type="password" maxlength="72" autocomplete="current-password" required autofocus>
            <p id="phonePairingPasswordError" class="qr-camera-status hidden" role="alert"></p>
            <div class="modal-actions"><button class="btn-primary" type="submit">Continue</button><button class="btn-sm" type="button" onclick="cancelPairingPasswordPrompt()">Cancel</button></div>
        </form>`);
        document.getElementById('phonePairingPassword')?.focus();
    });
}

async function submitPairingPassword(event) {
    event.preventDefault();
    const value = document.getElementById('phonePairingPassword')?.value || '';
    if (!value) return;
    const errorEl = document.getElementById('phonePairingPasswordError');
    try { await window.requireVerifiedAdmin(); }
    catch (error) {
        if (errorEl) { errorEl.textContent = error.message; errorEl.classList.remove('hidden'); }
        return;
    }
    const { data, error } = await window.ironGrindSupabase.rpc('verify_mobile_attendance_pairing_password', { p_password: value });
    if (error || data !== true) {
        if (errorEl) {
            errorEl.textContent = error?.message || 'That phone-pairing password is incorrect. Try again.';
            errorEl.classList.remove('hidden');
        }
        const input = document.getElementById('phonePairingPassword');
        if (input) { input.value = ''; input.focus(); }
        return;
    }
    const resolve = pairingPasswordPromptResolver;
    pairingPasswordPromptResolver = null;
    closeModal(true);
    resolve?.(value);
}

function cancelPairingPasswordPrompt() {
    const resolve = pairingPasswordPromptResolver;
    pairingPasswordPromptResolver = null;
    closeModal();
    resolve?.(null);
}

function requestPairingRemovalPin(title, description) {
    if (pairingRemovalPinPromptResolver) pairingRemovalPinPromptResolver(null);
    return new Promise(resolve => {
        pairingRemovalPinPromptResolver = resolve;
        openModal(`<form class="qr-camera-modal" onsubmit="submitPairingRemovalPin(event)">
            <h3><i class="fas fa-lock"></i> ${escapeDialogText(title)}</h3>
            <p class="modal-sub">${escapeDialogText(description)}</p>
            <label for="phonePairingRemovalPin">Four-digit admin PIN</label>
            <input id="phonePairingRemovalPin" type="password" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" autocomplete="off" required autofocus>
            <p id="phonePairingRemovalPinError" class="qr-camera-status hidden" role="alert"></p>
            <div class="modal-actions"><button class="btn-danger" type="submit">Confirm</button><button class="btn-sm" type="button" onclick="cancelPairingRemovalPin()">Cancel</button></div>
        </form>`);
        document.getElementById('phonePairingRemovalPin')?.focus();
    });
}

async function submitPairingRemovalPin(event) {
    event.preventDefault();
    const pin = document.getElementById('phonePairingRemovalPin')?.value || '';
    const errorEl = document.getElementById('phonePairingRemovalPinError');
    const { data, error } = await window.ironGrindSupabase.rpc('verify_mobile_attendance_removal_pin', { p_pin: pin });
    if (error || data?.valid !== true) {
        if (errorEl) { errorEl.textContent = error?.message || 'Incorrect PIN. Enter the four-digit admin PIN.'; errorEl.classList.remove('hidden'); }
        if (!error && data?.configured === false && errorEl) {
            errorEl.textContent = 'The four-digit removal PIN has not been set in the database yet.';
        }
        const input = document.getElementById('phonePairingRemovalPin');
        if (input) { input.value = ''; input.focus(); }
        return;
    }
    const resolve = pairingRemovalPinPromptResolver;
    pairingRemovalPinPromptResolver = null;
    closeModal(true);
    resolve?.(pin);
}

function cancelPairingRemovalPin() {
    const resolve = pairingRemovalPinPromptResolver;
    pairingRemovalPinPromptResolver = null;
    closeModal(true);
    resolve?.(null);
}

function renderPhonePairingSettings(data) {
    if (!data) return;
    window.currentPhonePairingSettings = data;
    applyPhonePairingCapacityState(data);
    const summary = document.getElementById('phonePairingLimitSummary');
    const paired = Number(data.paired_count || 0);
    const reserved = Number(data.pending_count || 0);
    const available = Math.max(0, Number(data.max_pairs) - paired - reserved);
    if (summary) summary.textContent = `${paired} ${paired === 1 ? 'phone' : 'phones'} paired · ${reserved} ${reserved === 1 ? 'QR' : 'QRs'} reserved · ${available} ${available === 1 ? 'slot' : 'slots'} available`;
    const limit = document.getElementById('pairedPhonesLimit');
    if (limit) limit.textContent = `Limit: ${data.max_pairs} · ${reserved} ${reserved === 1 ? 'QR' : 'QRs'} reserved`;
    const count = document.getElementById('activePhoneSessionCount');
    if (count) count.textContent = String(data.active_count);
}

async function refreshPhonePairingLimitSummary() {
    const target = document.getElementById('phonePairingLimitSummary');
    if (!target || !window.ironGrindSupabase) return;
    const { data, error } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    if (!document.getElementById('phonePairingLimitSummary')) return;
    if (error || !data) { target.textContent = 'Could not load pairing limit.'; return; }
    renderPhonePairingSettings(data);
}

async function changePhonePairingLimit() {
    const removalPin = await requestPairingRemovalPin('Authorize limit change', 'Enter the same four-digit PIN used to remove a paired device.');
    if (!removalPin) {
        await restorePhonePairingModal(false);
        return;
    }
    pendingPairingLimitPin = removalPin;
    openModal(`<form class="qr-camera-modal" onsubmit="authorizePhonePairingLimit(event)">
        <h3><i class="fas fa-mobile-screen-button"></i> Phone pairing limit</h3>
        <p class="modal-sub">Choose the maximum number of active phone pairings. The default is two.</p>
        <label for="phonePairingLimitInput">Maximum slots (paired phones + pending QRs)</label>
        <input id="phonePairingLimitInput" type="number" min="2" max="50" step="1" value="2" required>
        <div class="modal-actions"><button class="btn-primary" type="submit">Save limit</button><button class="btn-sm" type="button" onclick="cancelPhonePairingLimit()">Cancel</button></div>
    </form>`);
    const { data } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    const input = document.getElementById('phonePairingLimitInput');
    if (input && Number.isInteger(data?.max_pairs)) input.value = data.max_pairs;
}

async function cancelPhonePairingLimit() {
    pendingPairingLimitPin = null;
    closeModal(true);
    await restorePhonePairingModal(false);
}

async function authorizePhonePairingLimit(event) {
    event.preventDefault();
    const desired = Number(document.getElementById('phonePairingLimitInput')?.value);
    if (!Number.isInteger(desired) || desired < 2 || desired > 50) {
        toast('Choose a whole number from 2 to 50.', 'error');
        return;
    }
    const removalPin = pendingPairingLimitPin;
    if (!removalPin) return;
    const { error } = await window.ironGrindSupabase.rpc('set_mobile_attendance_pairing_limit', { p_max_pairs: desired, p_removal_pin: removalPin });
    pendingPairingLimitPin = null;
    if (error) {
        toast(`Could not change phone limit: ${error.message}`, 'error');
        await restorePhonePairingModal(false);
        return;
    }
    toast(`Phone pairing limit set to ${desired}.`, 'success');
    const { data: settings } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    if (activeMobileAttendanceSessionId && activeMobileAttendancePairingUrl) {
        showMobileAttendancePairingModal(activeMobileAttendanceSessionId, activeMobileAttendancePairingUrl, activeMobileAttendancePersistent);
    } else if (settings && Number(settings.paired_count) < Number(settings.max_pairs) && phoneCameraAuthorization) {
        await createPhonePairingSession(phoneCameraRememberPreference, phoneCameraAuthorization);
    } else {
        showMobileAttendancePairingModal(null, null, false, settings ? Number(settings.paired_count) >= Number(settings.max_pairs) : false);
    }
}

function startMobileAttendancePolling(sessionId) {
    mobileAttendanceSessionIds.add(sessionId);
    savePersistentMobileAttendanceSessions();
    setAttendancePhoneStatus('Pairing QR ready. Waiting for a phone to connect…');
    if (!mobileAttendancePollTimer) {
        mobileAttendancePollTimer = window.setInterval(() => {
            for (const activeSessionId of mobileAttendanceSessionIds) pollMobileAttendanceScans(activeSessionId);
        }, 1200);
    }
    pollMobileAttendanceScans(sessionId);
}

function savePersistentMobileAttendanceSessions() {
    const ids = [...mobileAttendanceSessionIds].filter(id => mobileAttendanceSessionPersistence.get(id));
    if (ids.length) localStorage.setItem('ig_mobile_attendance_session_ids', JSON.stringify(ids));
    else localStorage.removeItem('ig_mobile_attendance_session_ids');
    localStorage.removeItem('ig_mobile_attendance_session_id');
}

function setAttendancePhoneStatus(message, connected = false) {
    const status = document.getElementById('attendancePhoneStatus');
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('connected', connected);
}

async function refreshPairedAttendancePhones(force = false) {
    const list = document.getElementById('pairedPhonesList');
    if (!list || !window.ironGrindSupabase || pairedPhoneListRefreshBusy) return;
    if (!force && Date.now() - pairedPhoneListLastRefreshAt < 5000) return;
    pairedPhoneListRefreshBusy = true;
    try {
    let data;
    let error;
    try {
        ({ data, error } = await window.ironGrindSupabase.rpc('list_admin_mobile_attendance_devices'));
    } catch (requestError) {
        error = requestError;
    }
    if (document.getElementById('pairedPhonesList') !== list) return;
    if (error) {
        const count = document.getElementById('pairedPhonesCount');
        if (count) count.textContent = '—';
        list.innerHTML = `<p class="paired-phone-empty">Could not load paired phones: ${escapeHTML(error.message)}. Apply migration 20261104000012.</p>`;
        return;
    }
    const phones = (Array.isArray(data) ? data : []).filter(phone => phone.paired === true || Boolean(phone.paired_at));
    const count = document.getElementById('pairedPhonesCount');
    const pairedPhones = phones;
    const { data: pairingSettings, error: pairingSettingsError } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    if (document.getElementById('pairedPhonesList') !== list) return;
    const actualPairedCount = Number(pairingSettings?.paired_count);
    if (count) count.textContent = String(Number.isFinite(actualPairedCount) ? actualPairedCount : pairedPhones.length);
    if (!pairingSettingsError && pairingSettings) {
        renderPhonePairingSettings(pairingSettings);
    }
    const listOutOfSync = !pairingSettingsError && Number.isFinite(actualPairedCount) && actualPairedCount > pairedPhones.length;
    const activeSessionCount = document.getElementById('activePhoneSessionCount');
    if (activeSessionCount && !pairingSettingsError) activeSessionCount.textContent = String(pairingSettings.active_count);
    const modalStatus = document.getElementById('phonePairStatus');
    if (modalStatus && !modalStatus.textContent.startsWith('Last scan processed') && !modalStatus.textContent.startsWith('Phone connection issue')) {
        const currentPhone = phones.find(phone => phone.session_id === activeMobileAttendanceSessionId);
        if (currentPhone?.paired !== false && currentPhone) {
            modalStatus.textContent = 'Connected · ready to scan.';
        } else if (currentPhone) {
            modalStatus.textContent = 'Waiting for phone…';
        } else if (!document.getElementById('phonePairQr') && !pairingSettingsError && Number(pairingSettings?.active_count) >= Number(pairingSettings?.max_pairs)) {
            modalStatus.textContent = 'Pairing limit reached.';
        } else if (phones.length) {
            modalStatus.textContent = 'Waiting for phone…';
        } else {
            modalStatus.textContent = 'Waiting for phone…';
        }
    }
    if (!phones.length) {
        list.innerHTML = listOutOfSync
            ? `<p class="paired-phone-empty">Supabase reports ${actualPairedCount} paired phones, but this list returned none. Apply migration 20261104000019_list_only_paired_attendance_phones.sql, then reload the admin page.</p>`
            : '<p class="paired-phone-empty">No phones have paired yet.</p>';
    } else {
        list.innerHTML = phones.map(phone => {
            const isPaired = phone.paired !== false;
            const relevantTime = isPaired ? phone.paired_at : phone.created_at;
            const connectedAt = relevantTime
                ? new Date(relevantTime).toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' })
                : 'Unknown';
            const model = isPaired ? (phone.device || 'Phone') : 'Waiting for phone to scan';
            return `<div class="paired-phone-row">
                <div class="paired-phone-meta"><strong>${escapeHTML(model)}</strong><small>${isPaired ? 'Paired' : 'QR created'} ${escapeHTML(connectedAt)}</small></div>
                <button class="btn-danger" onclick="endMobileAttendanceSession('${phone.session_id}', true)">End pairing</button>
            </div>`;
        }).join('') + (listOutOfSync
            ? `<p class="paired-phone-empty">Supabase counts ${actualPairedCount} paired phones, but the device list returned ${pairedPhones.length}. Apply migration 20261104000019_list_only_paired_attendance_phones.sql and refresh the page.</p>`
            : '');
    }

    const pendingList = document.getElementById('pendingPhonePairingsList');
    if (pendingList) {
        const { data: pendingSessions, error: pendingError } = await window.ironGrindSupabase.rpc('list_admin_mobile_attendance_pending_sessions');
        if (document.getElementById('pairedPhonesList') !== list) return;
        const pendingCount = document.getElementById('pendingPhonePairingsCount');
        const pending = Array.isArray(pendingSessions) ? pendingSessions : [];
        const qr = document.getElementById('phonePairQr');
        if (qr && !pendingError) {
            qr.dataset.pairingState = pending.some(session => session.session_id === qr.dataset.sessionId) ? 'pending' : 'unavailable';
            if (window.currentPhonePairingSettings) applyPhonePairingCapacityState(window.currentPhonePairingSettings);
        }
        if (pendingCount) pendingCount.textContent = pendingError ? '--' : String(pending.length);
        pendingList.innerHTML = pendingError
            ? `<p class="paired-phone-empty">Could not load pending QR codes: ${escapeHTML(pendingError.message)}. Apply migration 20261104000021_pending_attendance_pairings.sql.</p>`
            : pending.length
                ? pending.map(session => {
                    const createdAt = session.created_at
                        ? new Date(session.created_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' })
                        : 'Unknown';
                    const expiresAt = session.expires_at
                        ? new Date(session.expires_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila', timeStyle: 'short' })
                        : '';
                    return `<div class="paired-phone-row pending-phone-pairing-row">
                        <div class="paired-phone-meta"><strong>Waiting for phone to scan</strong><small>QR created ${escapeHTML(createdAt)}</small></div>
                        <button class="btn-danger" onclick="endMobileAttendanceSession('${session.session_id}', true)">End QR</button>
                    </div>`;
                }).join('')
                : '<p class="paired-phone-empty">No pending pairing QR codes.</p>';
    }
    } finally {
        pairedPhoneListRefreshBusy = false;
        pairedPhoneListLastRefreshAt = Date.now();
    }
}

async function refreshAttendancePhoneStatus(sessionId) {
    const { data, error } = await window.ironGrindSupabase.rpc('get_admin_mobile_attendance_device', {
        p_session_id: sessionId
    });
    refreshPairedAttendancePhones();
    if (sessionId !== activeMobileAttendanceSessionId) return;
    if (error) {
        setAttendancePhoneStatus(`Phone pairing status unavailable: ${error.message}. Apply migration 20261104000011.`);
        return;
    }
    if (!data?.paired) {
        setAttendancePhoneStatus('Pairing QR ready. Waiting for a phone to connect…');
        return;
    }
    const pairedTime = data.paired_at
        ? new Date(data.paired_at).toLocaleTimeString('en-PH', { timeZone: 'Asia/Manila', hour: 'numeric', minute: '2-digit' })
        : '';
    const message = `Paired phone: ${data.device || 'Phone'}${pairedTime ? ` · connected ${pairedTime}` : ''}`;
    setAttendancePhoneStatus(message, true);
    const modalStatus = document.getElementById('phonePairStatus');
    if (modalStatus && !modalStatus.textContent.startsWith('Last scan processed')) modalStatus.textContent = message;
}

async function restoreMobileAttendancePairing() {
    if (!window.ironGrindSupabase) return;
    let savedIds = [];
    try {
        savedIds = JSON.parse(localStorage.getItem('ig_mobile_attendance_session_ids') || '[]');
    } catch {}
    const legacyId = localStorage.getItem('ig_mobile_attendance_session_id');
    if (legacyId) savedIds.push(legacyId);
    let pairingRestoreFailed = false;
    for (const sessionId of [...new Set(savedIds.filter(Boolean))]) {
        const { data: isActive, error } = await window.ironGrindSupabase.rpc('is_admin_mobile_attendance_scan_session_active', {
            p_session_id: sessionId
        });
        if (error) { pairingRestoreFailed = true; continue; }
        if (isActive !== true) continue;
        mobileAttendanceSessionPersistence.set(sessionId, true);
        if (!activeMobileAttendanceSessionId) {
            activeMobileAttendanceSessionId = sessionId;
            activeMobileAttendancePersistent = true;
        }
        startMobileAttendancePolling(sessionId);
    }
    if (!pairingRestoreFailed) {
        savePersistentMobileAttendanceSessions();
        if (!mobileAttendanceSessionIds.size) localStorage.removeItem('ig_mobile_attendance_session_id');
    }
}

async function endMobileAttendanceSession(sessionId = activeMobileAttendanceSessionId, keepModalOpen = false, removalPin = null, autoCreateQrWhenSlotFree = true) {
    if (!sessionId || !window.ironGrindSupabase) return;
    if (!removalPin) removalPin = await requestPairingRemovalPin('End phone pairing', 'Enter the four-digit admin PIN to remove this paired phone.');
    if (!removalPin) {
        if (keepModalOpen) restorePhonePairingModal(autoCreateQrWhenSlotFree);
        return;
    }
    const { error } = await window.ironGrindSupabase.rpc('close_mobile_attendance_scan_session', { p_session_id: sessionId, p_pairing_pin: removalPin });
    if (error) {
        toast(`Could not end phone pairing: ${error.message}`, 'error');
        if (keepModalOpen) restorePhonePairingModal(autoCreateQrWhenSlotFree);
        return;
    }
    mobileAttendanceSessionIds.delete(sessionId);
    mobileAttendanceSessionPersistence.delete(sessionId);
    mobileAttendancePollBusy.delete(sessionId);
    savePersistentMobileAttendanceSessions();
    if (activeMobileAttendanceSessionId === sessionId) {
        activeMobileAttendancePairingUrl = null;
        activeMobileAttendanceSessionId = mobileAttendanceSessionIds.values().next().value || null;
        activeMobileAttendancePersistent = Boolean(activeMobileAttendanceSessionId && mobileAttendanceSessionPersistence.get(activeMobileAttendanceSessionId));
    }
    if (!mobileAttendanceSessionIds.size) {
        clearInterval(mobileAttendancePollTimer);
        mobileAttendancePollTimer = null;
        mobileAttendancePollBusy.clear();
        setAttendancePhoneStatus('No phone camera paired.');
    } else if (activeMobileAttendanceSessionId) {
        refreshAttendancePhoneStatus(activeMobileAttendanceSessionId);
    }
    if (keepModalOpen) restorePhonePairingModal(autoCreateQrWhenSlotFree);
    else closeModal();
    toast('Phone attendance pairing ended.', 'success');
}

async function restorePhonePairingModal(autoCreateQrWhenSlotFree = true) {
    const { data: settings } = await window.ironGrindSupabase.rpc('get_mobile_attendance_pairing_settings');
    const activeSessionId = activeMobileAttendanceSessionId;
    const activeUrl = activeMobileAttendancePairingUrl;
    const activePersistent = activeMobileAttendancePersistent;
    const hasCurrentSession = activeSessionId && mobileAttendanceSessionIds.has(activeSessionId) && activeUrl;
    const hasDeviceSlot = settings && Number(settings.active_count) < Number(settings.max_pairs)
        && Number(settings.paired_count) < Number(settings.max_pairs);
    if (!hasCurrentSession && autoCreateQrWhenSlotFree && hasDeviceSlot && phoneCameraAuthorization) {
        await createPhonePairingSession(phoneCameraRememberPreference, phoneCameraAuthorization);
        return;
    }
    showMobileAttendancePairingModal(
        hasCurrentSession ? activeSessionId : null,
        hasCurrentSession ? activeUrl : null,
        hasCurrentSession ? activePersistent : false,
        Number(settings?.active_count) >= Number(settings?.max_pairs)
    );
    if (hasCurrentSession) {
        startMobileAttendancePolling(activeSessionId);
        refreshAttendancePhoneStatus(activeSessionId);
    }
}

async function pollMobileAttendanceScans(sessionId) {
    if (mobileAttendancePollBusy.has(sessionId) || !mobileAttendanceSessionIds.has(sessionId) || !window.ironGrindSupabase) return;
    mobileAttendancePollBusy.add(sessionId);
    try {
        // Phones save attendance as the signed-in operator; do not replay old anonymous scans.
        await refreshAttendancePhoneStatus(sessionId);
    } catch (error) {
        console.warn('Could not check paired phone status:', error.message);
    } finally { mobileAttendancePollBusy.delete(sessionId); }
}

function startLocalQRScanner() {
    if (typeof Html5Qrcode === 'undefined') {
        toast('The QR scanner could not load. Check your internet connection and reload.', 'error');
        return;
    }
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
        toast('Camera access requires this page to be opened over HTTPS or localhost in a supported browser.', 'error');
        return;
    }

    qrScanHandled = false;
    openModal(`<div class="qr-camera-modal">
        <h3><i class="fas fa-camera"></i> Scan Member QR</h3>
        <p class="modal-sub">Allow camera access and hold the member QR code in the frame.</p>
        <div class="qr-reader-frame">
            <div id="qrReader" class="qr-reader"></div>
            <div id="qrScanProcessing" class="qr-scan-processing" hidden role="status" aria-live="polite">
                <span class="qr-scan-spinner" aria-hidden="true"><i class="fas fa-qrcode"></i></span>
                <strong>Recording attendance</strong>
                <span>Checking whether this member is entering or leaving…</span>
            </div>
        </div>
        <p id="qrCameraStatus" class="qr-camera-status" role="status">Starting camera…</p>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button></div>
    </div>`);

    const scanner = new Html5Qrcode('qrReader');
    activeQRScanner = scanner;
    const scanConfig = { fps: 10, qrbox: { width: 240, height: 240 }, aspectRatio: 1 };
    const handleScanSuccess = async decodedText => {
            if (qrScanHandled) return;
            qrScanHandled = true;
            const scannedText = decodedText.trim();
            const processing = document.getElementById('qrScanProcessing');
            const status = document.getElementById('qrCameraStatus');
            if (processing) {
                processing.hidden = false;
                const heading = processing.querySelector('strong');
                const detail = processing.querySelector('span:not(.qr-scan-spinner)');
                if (heading) heading.textContent = 'Looking up member';
                if (detail) detail.textContent = 'Checking the QR code with the member records…';
            }
            if (status) status.textContent = 'QR detected. Looking up member…';

            let member;
            try {
                member = await Promise.race([
                    resolveMemberFromQR(scannedText),
                    new Promise((_, reject) => window.setTimeout(
                        () => reject(new Error('Member lookup timed out. Check the connection and try again.')),
                        10000
                    ))
                ]);
            } catch (error) {
                closeModal();
                toast(`Could not look up scanned QR: ${error.message || 'Please try again.'}`, 'error');
                return;
            }

            if (!member) {
                closeModal();
                toast('QR code not recognized. Scan a QR code issued by Iron Grind.', 'error');
                return;
            }

            const openVisit = attendance.find(
                a => String(a.memberId) === String(member.id) && !a.timeOut
            );
            if (processing) {
                const heading = processing.querySelector('strong');
                const detail = processing.querySelector('span:not(.qr-scan-spinner)');
                if (heading) heading.textContent = openVisit ? 'Checking out' : 'Checking in';
                if (detail) detail.textContent = `${member.name} — attendance is being updated.`;
            }
            if (status) status.textContent = openVisit
                ? 'Open visit found. Checking out…'
                : 'No open visit found. Checking in…';
            await new Promise(resolve => window.setTimeout(resolve, 350));
            closeModal();
            await recordMemberAttendanceScan(member);
    };
    const startCamera = async () => {
        let permissionStream;
        try {
            // Request permission directly from this user action, then start
            // the QR library with the browser-selected camera device ID.
            permissionStream = await navigator.mediaDevices.getUserMedia({
                audio: false,
                video: { facingMode: { ideal: 'environment' } }
            });
            if (activeQRScanner !== scanner) return;

            const deviceId = permissionStream.getVideoTracks()[0]?.getSettings?.().deviceId;
            permissionStream.getTracks().forEach(track => track.stop());
            permissionStream = null;
            if (activeQRScanner !== scanner) return;

            if (deviceId) {
                try {
                    await scanner.start(deviceId, scanConfig, handleScanSuccess, () => {});
                    return;
                } catch (deviceError) {
                    console.warn('Could not start the initially selected camera; trying another available camera.', deviceError);
                }
            }

            const cameras = await Html5Qrcode.getCameras();
            const camera = cameras.find(item => /back|rear|environment/i.test(item.label)) || cameras[0];
            if (!camera) throw new Error('No camera device is available to the browser.');
            await scanner.start(camera.id, scanConfig, handleScanSuccess, () => {});
        } finally {
            permissionStream?.getTracks().forEach(track => track.stop());
        }
    };

    clearTimeout(qrCameraHintTimer);
    qrCameraHintTimer = window.setTimeout(() => {
        const status = document.getElementById('qrCameraStatus');
        if (status?.textContent === 'Starting camera…') {
            status.textContent = 'Waiting for browser camera permission. If no prompt appeared, allow Camera for this site in browser settings and try again.';
        }
    }, 8000);

    startCamera().then(() => {
        clearTimeout(qrCameraHintTimer);
        qrCameraHintTimer = null;
        const status = document.getElementById('qrCameraStatus');
        if (status) status.textContent = 'Camera is on. Point it at the member’s QR code.';
    }).catch(error => {
        clearTimeout(qrCameraHintTimer);
        qrCameraHintTimer = null;
        stopQRScanner();
        const status = document.getElementById('qrCameraStatus');
        const message = getQRScannerErrorMessage(error);
        if (status) status.textContent = message;
        toast(message, 'error');
        console.warn('QR camera failed to start:', error);
    });
}

function getQRScannerErrorMessage(error) {
    if (['NotAllowedError', 'PermissionDeniedError', 'SecurityError'].includes(error?.name)) {
        return 'Camera access is off. Allow camera access in your browser settings, then try again.';
    }
    if (error?.name === 'NotFoundError') {
        return 'No camera was found on this device. You can use the paired attendance phone instead.';
    }
    if (error?.name === 'NotReadableError') {
        return 'The camera is busy right now. Close other apps using it, then try again.';
    }
    if (['OverconstrainedError', 'ConstraintNotSatisfiedError'].includes(error?.name)) {
        return 'A compatible camera is unavailable. Check the camera connection or use the paired attendance phone.';
    }
    return 'The camera is unavailable right now. Check camera access or use the paired attendance phone.';
}

function stopQRScanner() {
    clearTimeout(qrCameraHintTimer);
    qrCameraHintTimer = null;
    const scanner = activeQRScanner;
    activeQRScanner = null;
    if (!scanner) return;
    scanner.stop().catch(() => {}).finally(() => {
        try { scanner.clear(); } catch {}
    });
}

function findMemberFromQR(value) {
    const exactMatch = members.find(member => member.qrCode && member.qrCode === value);
    if (exactMatch) return exactMatch;
    const parts = value.split('|');
    if (parts[0]?.toUpperCase() !== 'IRONGRIND' || !parts[1]) return null;
    const identifier = parts[1].trim();
    const normalizedIdentifier = identifier.toLowerCase();
    return members.find(member =>
        String(member.id).toLowerCase() === normalizedIdentifier
        || String(member.authUserId || '').toLowerCase() === normalizedIdentifier
        || String(member.username || '').toLowerCase() === normalizedIdentifier
    ) || null;
}

async function resolveMemberFromQR(value) {
    const cachedMember = findMemberFromQR(value);
    if (cachedMember) return cachedMember;

    const [prefix, ...identifierParts] = value.split('|');
    const identifier = identifierParts.join('|').trim();
    if (prefix?.toUpperCase() !== 'IRONGRIND' || !identifier || !window.ironGrindSupabase) return null;

    const client = window.ironGrindSupabase;
    let result;
    if (isUUID(identifier)) {
        result = await client.from('members').select('*').eq('id', identifier).maybeSingle();
        if (!result.error && !result.data) {
            result = await client.from('members').select('*').eq('auth_user_id', identifier).maybeSingle();
        }
    } else {
        result = await client.from('members').select('*').ilike('username', identifier).maybeSingle();
    }

    if (result?.error) {
        console.error('Could not resolve scanned member QR from Supabase:', result.error);
        return null;
    }
    if (!result?.data) return null;

    const member = mapSupabaseMember(result.data, result.data.username, result.data.email);
    const existingIndex = members.findIndex(item => String(item.id) === String(member.id));
    if (existingIndex >= 0) members[existingIndex] = member;
    else members.push(member);
    return member;
}

const pendingAdminAttendanceScans = new Map();
async function recordMemberAttendanceScan(member) {
    if (!member) return;
    if (window.ironGrindSupabase) {
        const key = String(member.id);
        const requestId = pendingAdminAttendanceScans.get(key) || crypto.randomUUID();
        pendingAdminAttendanceScans.set(key, requestId);
        const { data, error } = await window.ironGrindSupabase.rpc('record_attendance_scan', {
            p_identifier: key, p_request_id: requestId
        });
        if (error) {
            if (error.code) pendingAdminAttendanceScans.delete(key);
            toast(error.message, 'error'); return;
        }
        pendingAdminAttendanceScans.delete(key);
        await loadSupabaseOperationalData({ captureExpiry: false });
        renderAttendance(); renderDashboard();
        toast(data.member_name + (data.action === 'duplicate' ? ' was already scanned just now.' : data.action === 'check_out' ? ' checked out.' : ' checked in.'), 'success');
        return;
    }

    // The same member QR toggles the open visit closed when scanned again.
    // Check this before expiry so staff can always check a member out.
    const openVisit = attendance.find(a => String(a.memberId) === String(member.id) && !a.timeOut);
    if (openVisit) {
        await checkOut(openVisit.id);
        return;
    }

    if (member.expiry && member.expiry < todayStr()) {
        toast('Membership is expired. Check the member’s renewal status.', 'error');
        return;
    }
    const today = todayStr();
    const now = new Date();
    const timeIn = manilaClock(now);
    attendance.push({ id: uid('A'), memberId: member.id, memberName: member.name, date: today, timeIn, timeOut: null });
    saveDB('attendance', attendance);
    renderAttendance();
    renderDashboard();
    toast(`${member.name} checked in at ${formatAttendanceClock(timeIn)}. Scan their QR again to check them out.`, 'success');
}

async function checkOut(id) {
    const a = attendance.find(x => x.id === id);
    if (!a) return;
    const now = new Date();
    if (window.ironGrindSupabase) {
        const { data: { user }, error: authError } = await window.ironGrindSupabase.auth.getUser();
        if (authError || !user) { toast('Sign in again before checking a member out.', 'error'); return; }
        const { data, error } = await window.ironGrindSupabase.from('attendance')
            .update({ time_out: now.toISOString(), checked_out_by: user.id }).eq('id', id).is('time_out', null).select('id').maybeSingle();
        if (error) { toast(`Could not save check-out: ${error.message}`, 'error'); return; }
        if (!data) {
            await loadSupabaseOperationalData({ captureExpiry: false });
            toast('This visit was already checked out. Attendance has been updated.', 'error');
            return;
        }
    } else {
        saveDB('attendance', attendance);
    }
    a.timeOut = manilaClock(now);
    renderAttendance();
    renderDashboard();
    toast(`${a.memberName} checked out at ${formatAttendanceClock(a.timeOut)}.`, 'success');
}

/* ========== STORE ========== */
async function unlockStore() {
    const passwordInput = document.getElementById('storeAccessPassword');
    const status = document.getElementById('storeAccessStatus');
    const password = passwordInput?.value || '';
    if (!password) {
        status.textContent = 'Enter the Store password to continue.';
        return;
    }
    const client = window.ironGrindSupabase;
    if (!client) {
        status.textContent = 'Store password verification is unavailable. Reload and try again.';
        return;
    }

    status.textContent = 'Checking password…';
    const { data, error } = await client.functions.invoke('verify-store-password', {
        body: { password },
    });
    if (error || !data?.authorized) {
        status.textContent = error
            ? 'Could not verify the password. Check that the Supabase function is deployed and STORE_ACCESS_PASSWORD is configured.'
            : (data?.error || 'Incorrect Store password.');
        passwordInput.value = '';
        passwordInput.focus();
        return;
    }

    status.textContent = '';
    passwordInput.value = '';
    const storeUnlockKey = adminStoreUnlockKey();
    if (storeUnlockKey) localStorage.setItem(storeUnlockKey, 'true');
    document.getElementById('storeLocked').classList.add('hidden');
    document.getElementById('storeUnlocked').classList.remove('hidden');
    renderStore();
}

function renderStore() {
    const supp = products.filter(p => p.category === 'Supplement');
    const merch = products.filter(p => p.category === 'Merch');
    document.getElementById('supplementsGrid').innerHTML = supp.map(productCard).join('') || '<div class="empty-state">No supplements.</div>';
    document.getElementById('merchGrid').innerHTML = merch.map(productCard).join('') || '<div class="empty-state">No merchandise.</div>';
}

function productCard(p) {
    const supplement = p.category === 'Supplement';
    const photo = catalogProductPhoto(p);
    const merchType = p.merchType || (p.size ? 'apparel' : 'other');
    const productType = supplement ? `${supplementTypeLabel(p.supplementType || 'other')} · ${supplementFormLabel(p.supplementForm || 'powder')}` : merchandiseTypeLabel(merchType);
    const low = productIsLowStock(p);
    const stockLabel = `${formatProductStock(p)} in stock`;
    return `
        <div class="product-card">
            ${photo ? `<div class="product-img-wrap"><img src="${escapeHTML(photo)}" alt="${escapeHTML(p.name)}" loading="lazy"></div>` : ''}
            <span class="cat">${p.category} · ${productType}</span>
            <h4>${p.name}${!supplement && p.size ? ' — ' + p.size : ''}</h4>
            <div class="price">${formatPeso(productPriceQuote(p.price, p.inventoryUnit).amount)} / ${productPriceQuote(p.price, p.inventoryUnit).quantity} ${productSaleUnitLabel(p)}</div>
            <div class="stock ${low ? 'low' : ''}">${low ? '⚠ ' : ''}${stockLabel}</div>
            <div class="product-actions">
                <button class="btn-restock" onclick="restockProduct('${p.id}')">Restock</button>
                <button class="btn-edit" onclick="editProduct('${p.id}')">Edit</button>
                <button class="btn-delete" aria-label="Archive ${escapeHTML(p.name)}" title="Archive product" onclick="archiveProduct('${p.id}')"><i class="fas fa-box-archive"></i></button>
            </div>
        </div>`;
}

function restockProduct(id) {
    const product = products.find(item => item.id === id);
    if (!product) return;
    const currentUnit = product.stockUnit || 'item';
    const unitLabel = stockUnitLabel(currentUnit);
    const compatibleUnits = product.category === 'Merch'
        ? [['item', 'items']]
        : isDiscreteUnit(product.inventoryUnit)
            ? [[product.stockUnit, stockUnitLabel(product.stockUnit)]]
        : product.inventoryUnit === 'milliliter'
            ? [['milliliter', 'ml'], ['liter', 'L'], ['fluid_ounce', 'fl oz']]
            : [['gram', 'g'], ['kilogram', 'kg'], ['ounce', 'oz'], ['pound', 'lb']];
    openModal(`
        <h3><i class="fas fa-boxes-stacked"></i> Restock ${escapeHTML(product.name)}</h3>
        <p class="modal-sub">Current stock: ${escapeHTML(formatProductStock(product))}. Choose the unit for the quantity being added.</p>
        <div class="form-row" style="margin-bottom:14px;"><div class="form-group"><label for="rsQuantity">Quantity to add</label><input type="number" id="rsQuantity" min="0.001" step="${isDiscreteUnit(currentUnit) ? '1' : '0.001'}" placeholder="Enter quantity"></div><div class="form-group"><label for="rsUnit">Unit</label><select id="rsUnit" onchange="updateRestockQuantityInput()">${compatibleUnits.map(([value, label]) => `<option value="${value}"${value === currentUnit ? ' selected' : ''}>${label}</option>`).join('')}</select></div></div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="runWithButtonLoading(this, () => submitRestock('${product.id}'), 'Adding stock…')">Add stock</button></div>
    `);
}

function updateRestockQuantityInput() {
    const unit = document.getElementById('rsUnit')?.value;
    const quantity = document.getElementById('rsQuantity');
    if (!quantity) return;
    quantity.step = isDiscreteUnit(unit) ? '1' : '0.001';
    quantity.min = isDiscreteUnit(unit) ? '1' : '0.001';
}

async function submitRestock(id) {
    const product = products.find(item => item.id === id);
    const quantity = Number(document.getElementById('rsQuantity')?.value);
    const quantityUnit = document.getElementById('rsUnit')?.value || product?.stockUnit || 'item';
    const unit = product?.stockUnit || 'item';
    if (!product || !Number.isFinite(quantity) || quantity <= 0 || (isDiscreteUnit(quantityUnit) && !Number.isInteger(quantity))) {
        toast(isDiscreteUnit(quantityUnit) ? `Enter a positive whole number of ${stockUnitLabel(quantityUnit)}.` : 'Enter a positive stock quantity.', 'error');
        return;
    }
    if (window.ironGrindSupabase) {
        if (!isUUID(id)) { toast('This product is not stored in Supabase and cannot be restocked yet.', 'error'); return; }
        const { data, error } = await window.ironGrindSupabase.rpc('restock_product', {
            p_product_id: id,
            p_quantity: quantity,
            p_quantity_unit: quantityUnit
        });
        if (error) { toast(`Could not restock in Supabase: ${error.message}`, 'error'); return; }
        product.stock = Number(data);
    } else {
        product.stock = Number(product.stock || 0) + stockDeductionForSale({ ...product, inventoryUnit: quantityUnit, stockUnit: unit }, quantity);
        try { saveDB('products', products); }
        catch { product.stock -= quantity; toast('Could not save the updated stock.', 'error'); return; }
    }
    closeModal();
    renderStore();
    renderDashboard();
    toast(`Added ${quantity} ${unitLabelPlural(quantityUnit, quantity)} to ${product.name}.`, 'success');
}

function unitLabelPlural(unit, quantity) {
    if (unit === 'item') return quantity === 1 ? 'item' : 'items';
    if (unit === 'piece') return quantity === 1 ? 'pc' : 'pcs';
    if (unit === 'box') return quantity === 1 ? 'box' : 'boxes';
    return stockUnitLabel(unit);
}

function merchandiseSizeOptions(selected = '') {
    const sizes = ['XS', 'Small', 'Medium', 'Large', 'XL', 'XXL', 'XXXL', 'One Size'];
    const current = String(selected || '');
    if (current && !sizes.includes(current)) sizes.push(current);
    return `<option value="">Select size</option>${sizes.map(size => `<option value="${escapeHTML(size)}">${escapeHTML(size)}</option>`).join('')}`;
}

function merchandiseTypeOptions() {
    return '<option value="apparel">Apparel</option><option value="accessories">Accessories</option><option value="drinkware">Drinkware</option><option value="gym_gear">Gym gear</option><option value="other">Other</option>';
}

function merchandiseTypeLabel(type) {
    return ({ apparel: 'Apparel', accessories: 'Accessories', drinkware: 'Drinkware', gym_gear: 'Gym gear', other: 'Other' })[type] || 'Other';
}

function supplementTypeOptions() {
    return '<option value="">Choose type</option><option value="protein">Protein</option><option value="creatine">Creatine</option><option value="pre_workout">Pre-workout</option><option value="vitamins">Vitamins</option><option value="amino_acids">Amino acids</option><option value="other">Other</option>';
}

function supplementTypeLabel(type) {
    return ({ protein: 'Protein', creatine: 'Creatine', pre_workout: 'Pre-workout', vitamins: 'Vitamins', amino_acids: 'Amino acids', other: 'Other' })[type] || 'Other';
}

function supplementFormOptions(selected = 'powder') {
    const forms = [['powder', 'Powder'], ['drinkable', 'Drinkable / liquid'], ['capsule', 'Capsule'], ['tablet', 'Tablet'], ['other', 'Other']];
    return forms.map(([value, label]) => `<option value="${value}"${selected === value ? ' selected' : ''}>${label}</option>`).join('');
}
function supplementFormLabel(form) { return ({ powder: 'Powder', drinkable: 'Drinkable / liquid', capsule: 'Capsule', tablet: 'Tablet', other: 'Other' })[form] || 'Powder'; }
function stockUnitOptions(form, selected = '') {
    const units = form === 'powder' ? [['gram', 'g'], ['kilogram', 'kg'], ['ounce', 'oz'], ['pound', 'lb']]
        : form === 'drinkable' ? [['milliliter', 'ml'], ['liter', 'L'], ['fluid_ounce', 'fl oz']]
            : (form === 'capsule' || form === 'tablet') ? [['piece', 'pcs'], ['box', 'boxes']]
                : [['item', 'items']];
    return units.map(([value, label]) => `<option value="${value}"${selected === value ? ' selected' : ''}>${label}</option>`).join('');
}
function stockStep(unit) { return isDiscreteUnit(unit) ? '1' : '0.001'; }

function productPhotoPicker(prefix, image = '') {
    return `<div class="form-group product-photo-field">
        <input class="product-photo-file-input" type="file" id="${prefix}Image" accept="image/*" aria-label="Product photo (optional)" onchange="previewProductPhoto(this, '${prefix}ImagePreview')" style="display:none!important" hidden>
        <div class="product-photo-upload${image ? ' has-photo' : ''}">
            <div id="${prefix}ImagePreview" class="product-photo-preview">${image ? `<img src="${escapeHTML(image)}" alt="Current product photo">` : ''}</div>
            <button type="button" class="product-photo-upload-button" onclick="document.getElementById('${prefix}Image').click()" aria-label="${image ? 'Change' : 'Upload'} product photo">
                <i class="fas fa-cloud-arrow-up" aria-hidden="true"></i>
                <span>${image ? 'Change photo' : 'Upload photo'}</span>
                <small>Choose an image</small>
            </button>
        </div>
        ${prefix === 'ep' ? '<label class="product-photo-remove"><input type="checkbox" id="epRemoveImage"> Remove current photo</label>' : ''}
        <small>Photos fit automatically without cropping. Click a selected photo to enlarge.</small>
    </div>`;
}

function openAddProductModal() {
    openModal(`
        <h3><i class="fas fa-plus"></i> Add Product</h3>
        ${productPhotoPicker('ap')}
        <div class="form-group" style="margin-bottom:14px;"><label>Name</label><input type="text" id="apName" placeholder="Whey Protein — Vanilla"></div>
        <div class="form-group" style="margin-bottom:14px;"><label>Category</label><select id="apCat" onchange="toggleAddProductSize()"><option value="Supplement">Supplement</option><option value="Merch">Merchandise</option></select></div>
        <div id="apMerchTypeGroup" class="form-group" style="margin-bottom:14px;display:none"><label for="apMerchType">Merchandise type</label><select id="apMerchType" onchange="toggleAddProductSize()">${merchandiseTypeOptions()}</select></div>
        <div id="apSupplementTypeGroup" class="form-group" style="margin-bottom:14px;"><label for="apSupplementType">Supplement type</label><select id="apSupplementType">${supplementTypeOptions()}</select></div>
        <div id="apSupplementFormGroup" class="form-group" style="margin-bottom:14px;"><label for="apSupplementForm">Form</label><select id="apSupplementForm" onchange="toggleAddProductSize()">${supplementFormOptions()}</select></div>
        <div id="apSizeGroup" class="form-group" style="margin-bottom:14px;display:none"><label for="apSize">Size / variant (optional)</label><input id="apSize" list="apSizeSuggestions" maxlength="30" placeholder="Choose or type an available size"><datalist id="apSizeSuggestions">${merchandiseSizeOptions()}</datalist></div>
        <div class="form-row">
            <div class="form-group"><label for="apPrice">Price (₱)</label><input type="number" id="apPrice" min="0.01" step="0.01" placeholder="e.g. 80"><label for="apPriceQuantity">For this quantity (<span id="apPriceUnit">g</span>)</label><input type="number" id="apPriceQuantity" min="0.001" step="0.001" value="10"><small>Example: ₱80 for 10 g. Checkout uses the equivalent unit price.</small></div>
            <div class="form-group"><label>Starting stock</label><div class="form-row"><input type="number" id="apStock" min="0" step="0.001" placeholder="Enter available stock"><select id="apStockUnit" aria-label="Stock unit" onchange="convertInventoryUnit(this, 'apStock')"><option value="gram">g</option><option value="kilogram">kg</option><option value="ounce">oz</option><option value="pound">lb</option></select></div><small id="apStockHint">Stock is tracked and deducted in grams sold.</small></div>
        </div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="runWithButtonLoading(this, submitAddProduct, 'Adding product…')">Add</button></div>
    `);
}

function toggleAddProductSize() {
    const group = document.getElementById('apSizeGroup');
    const isMerch = document.getElementById('apCat')?.value === 'Merch';
    const typeGroup = document.getElementById('apMerchTypeGroup');
    const supplementTypeGroup = document.getElementById('apSupplementTypeGroup');
    const formGroup = document.getElementById('apSupplementFormGroup');
    const form = document.getElementById('apSupplementForm')?.value || 'powder';
    const unitSelect = document.getElementById('apStockUnit');
    const priceUnit = document.getElementById('apPriceUnit');
    const hint = document.getElementById('apStockHint');
    if (typeGroup) typeGroup.style.display = isMerch ? '' : 'none';
    if (supplementTypeGroup) supplementTypeGroup.style.display = isMerch ? 'none' : '';
    if (formGroup) formGroup.style.display = isMerch ? 'none' : '';
    if (group) group.style.display = isMerch ? '' : 'none';
    if (unitSelect) {
        const oldUnit = unitSelect.value;
        const units = isMerch ? [['item','items']] : form === 'powder' ? [['gram','g'],['kilogram','kg'],['ounce','oz'],['pound','lb']] : form === 'drinkable' ? [['milliliter','ml'],['liter','L'],['fluid_ounce','fl oz']] : (form === 'capsule' || form === 'tablet') ? [['piece','pcs'],['box','boxes']] : [['item','items']];
        const nextUnit = units.some(([value]) => value === oldUnit) ? oldUnit : units[0][0];
        unitSelect.innerHTML = units.map(([value, label]) => `<option value="${value}">${label}</option>`).join('');
        unitSelect.value = nextUnit;
        unitSelect.dataset.previousUnit = nextUnit;
        document.getElementById('apStock').step = stockStep(nextUnit);
    }
    const saleUnit = isMerch ? 'item' : supplementSaleUnit(form, unitSelect?.value);
    if (priceUnit) priceUnit.textContent = saleUnitLabel(saleUnit);
    const basis = document.getElementById('apPriceQuantity');
    if (basis) { basis.step = isDiscreteUnit(saleUnit) ? '1' : '0.001'; if (basis.dataset.unit !== saleUnit) { basis.value = saleUnit === 'gram' ? '10' : '1'; basis.dataset.unit = saleUnit; } }
    if (hint) hint.textContent = isDiscreteUnit(saleUnit) ? `Each sale deducts one ${saleUnitLabel(saleUnit)}.` : `Sales are deducted in ${saleUnitLabel(saleUnit)}; stock converts automatically.`;
}

function convertInventoryUnit(select, inputId) {
    const input = document.getElementById(inputId);
    const previous = select.dataset.previousUnit || select.value;
    const next = select.value;
    if (input && previous !== next) {
        const amount = Number(input.value);
        if (isDiscreteUnit(previous) || isDiscreteUnit(next)) {
            input.value = '0';
        } else if (Number.isFinite(amount)) {
            input.value = (amount * INVENTORY_UNIT_TO_BASE[previous] / INVENTORY_UNIT_TO_BASE[next]).toFixed(3).replace(/\.000$/, '').replace(/(\.\d*?)0+$/, '$1').replace(/\.$/, '');
        }
    }
    select.dataset.previousUnit = next;
    const prefix = select.id === 'apStockUnit' ? 'ap' : select.id === 'epStockUnit' ? 'ep' : '';
    if (prefix) {
        const form = document.getElementById(`${prefix}SupplementForm`)?.value || 'other';
        const saleUnit = supplementSaleUnit(form, next);
        const priceUnit = document.getElementById(`${prefix}PriceUnit`);
        const hint = document.getElementById(`${prefix}StockHint`);
        if (priceUnit) priceUnit.textContent = saleUnitLabel(saleUnit);
        if (hint) hint.textContent = isDiscreteUnit(saleUnit) ? `Each sale deducts one ${saleUnitLabel(saleUnit)}.` : `Sales are deducted in ${saleUnitLabel(saleUnit)}; stock converts automatically.`;
    }
}

async function submitAddProduct() {
    const name = document.getElementById('apName').value.trim();
    if (document.getElementById('apSize').value.trim().length > 30) { toast('Size must be 30 characters or fewer.', 'error'); return; }
    const category = document.getElementById('apCat').value;
    const merchType = category === 'Merch' ? document.getElementById('apMerchType').value : '';
    const supplementType = category === 'Supplement' ? document.getElementById('apSupplementType').value : '';
    const supplementForm = category === 'Supplement' ? document.getElementById('apSupplementForm').value : '';
    const size = category === 'Merch' ? document.getElementById('apSize').value.trim() : '';
    const price = productUnitPrice(document.getElementById('apPrice').value, document.getElementById('apPriceQuantity').value, category === 'Merch' || ['capsule', 'tablet', 'other'].includes(supplementForm));
    if (price === null) { toast('Enter a positive price and quantity that give a unit price with at most two decimal places.', 'error'); return; }
    const stock = Number(document.getElementById('apStock').value);
    const stockUnit = document.getElementById('apStockUnit').value;
    if (!name || !Number.isFinite(price) || price <= 0 || !Number.isFinite(stock) || stock < 0 || (isDiscreteUnit(stockUnit) && !Number.isInteger(stock)) || (category === 'Supplement' && (!supplementType || !supplementForm))) { toast('Enter a name, choose a product type and form, and provide a valid price and stock amount.', 'error'); return; }
    const image = await getProductPhoto('apImage');
    if (image === false) return;
    const inventoryUnit = category === 'Supplement' ? supplementSaleUnit(supplementForm, stockUnit) : 'item';
    const product = { name, category, price, stock, stockUnit, ...(category === 'Merch' ? { merchType } : { supplementType, supplementForm }), ...(category === 'Merch' && size ? { size } : {}), inventoryUnit, ...(image ? { image } : {}) };
    if (window.ironGrindSupabase) {
        const { data, error } = await window.ironGrindSupabase.from('products').insert({
            name,
            category: category === 'Supplement' ? 'supplement' : 'merchandise',
            price_per_unit: price,
            unit: inventoryUnit,
            stock_unit: stockUnit,
            merch_type: category === 'Merch' ? merchType : null,
            supplement_type: category === 'Supplement' ? supplementType : null,
            supplement_form: category === 'Supplement' ? supplementForm : null,
            size: category === 'Merch' ? (size || null) : null,
            stock,
            image_path: image || null,
            is_active: true
        }).select('*').single();
        if (error) { toast(`Could not save product to Supabase: ${error.message}`, 'error'); return; }
        products.push(mapSupabaseProduct(data));
    } else {
        product.id = uid('P');
        products.push(product);
        try { saveDB('products', products); }
        catch { products.pop(); toast('Could not save product photo. Try a smaller image or remove photos from other products.', 'error'); return; }
    }
    closeModal();
    renderStore();
    renderDashboard();
    toast(`✅ Added ${name}.`, 'success');
}

function editProduct(id) {
    const p = products.find(x => x.id === id);
    if (!p) return;
    openModal(`
        <h3><i class="fas fa-edit"></i> Edit Product</h3>
        <p class="modal-sub">Supplement pricing and stock units follow the selected form. Supabase checks admin access when saving.</p>
        ${productPhotoPicker('ep', catalogProductPhoto(p))}
        <div class="form-group" style="margin-bottom:14px;"><label>Name</label><input type="text" id="epName" value="${p.name}"></div>
        ${p.category === 'Merch' ? `<div class="form-group" style="margin-bottom:14px;"><label for="epMerchType">Merchandise type</label><select id="epMerchType" onchange="toggleEditProductSize('${p.id}')">${merchandiseTypeOptions()}</select></div><div id="epSizeGroup" class="form-group" style="margin-bottom:14px;"><label for="epSize">Size / variant (optional)</label><input id="epSize" list="epSizeSuggestions" maxlength="30" placeholder="Choose or type an available size"><datalist id="epSizeSuggestions">${merchandiseSizeOptions(p.size)}</datalist></div>` : `<div class="form-group" style="margin-bottom:14px;"><label for="epSupplementType">Supplement type</label><select id="epSupplementType">${supplementTypeOptions()}</select></div><div class="form-group" style="margin-bottom:14px;"><label for="epSupplementForm">Form</label><select id="epSupplementForm" onchange="toggleEditSupplementUnits()">${supplementFormOptions(p.supplementForm || 'powder')}</select></div>`}
        <div class="form-row">
            <div class="form-group"><label for="epPrice">Price (₱)</label><input type="number" id="epPrice" min="0.01" step="0.01" value="${productPriceQuote(p.price, p.inventoryUnit).amount}"><label for="epPriceQuantity">For this quantity (<span id="epPriceUnit">${productSaleUnitLabel(p)}</span>)</label><input type="number" id="epPriceQuantity" min="0.001" step="0.001" value="${productPriceQuote(p.price, p.inventoryUnit).quantity}"><small>Edit the price and quantity separately. Checkout uses the equivalent unit price.</small></div>
            <div class="form-group"><label>Current stock</label><div class="form-row"><input type="number" id="epStock" min="0" step="${stockStep(p.stockUnit || 'item')}" value="${Number(p.stock) || 0}"><select id="epStockUnit" aria-label="Stock unit" onchange="convertInventoryUnit(this, 'epStock')">${p.category === 'Supplement' ? stockUnitOptions(p.supplementForm || 'powder', p.stockUnit) : stockUnitOptions('item', 'item')}</select></div><small id="epStockHint">${isDiscreteUnit(p.inventoryUnit) ? `Each sale deducts one ${saleUnitLabel(p.inventoryUnit)}.` : `Sales deduct in ${saleUnitLabel(p.inventoryUnit)}.`}</small></div>
        </div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="runWithButtonLoading(this, () => submitEditProduct('${p.id}'), 'Saving…')">Save</button></div>
    `);
    const stockUnit = document.getElementById('epStockUnit');
    stockUnit.value = p.stockUnit || (p.category === 'Supplement' ? 'gram' : 'item');
    stockUnit.dataset.previousUnit = stockUnit.value;
    if (p.category === 'Merch') {
        const merchType = document.getElementById('epMerchType');
        merchType.value = p.merchType || (p.size ? 'apparel' : 'other');
        document.getElementById('epSize').value = p.size || '';
        toggleEditProductSize(p.id);
    } else {
        document.getElementById('epSupplementType').value = p.supplementType || 'other';
        document.getElementById('epSupplementForm').value = p.supplementForm || 'powder';
        document.getElementById('epSupplementForm').dataset.previousForm = p.supplementForm || 'powder';
    }
}

function toggleEditSupplementUnits() {
    const form = document.getElementById('epSupplementForm')?.value || 'powder';
    const formSelect = document.getElementById('epSupplementForm');
    const previousForm = formSelect?.dataset.previousForm || form;
    const select = document.getElementById('epStockUnit');
    if (!select) return;
    const oldUnit = select.value;
    const previousSaleUnit = supplementSaleUnit(previousForm, oldUnit);
    const unitOptions = form === 'powder' ? [['gram','g'],['kilogram','kg'],['ounce','oz'],['pound','lb']] : form === 'drinkable' ? [['milliliter','ml'],['liter','L'],['fluid_ounce','fl oz']] : (form === 'capsule' || form === 'tablet') ? [['piece','pcs'],['box','boxes']] : [['item','items']];
    const nextUnit = unitOptions.some(([value]) => value === oldUnit) ? oldUnit : unitOptions[0][0];
    const nextSaleUnit = supplementSaleUnit(form, nextUnit);
    if (previousSaleUnit !== nextSaleUnit) {
        document.getElementById('epStock').value = '0';
        document.getElementById('epPriceQuantity').value = nextSaleUnit === 'gram' ? '10' : '1';
        document.getElementById('epStockHint').textContent = 'Unit changed. Enter the actual stock using the new unit.';
    }
    select.innerHTML = unitOptions.map(([value,label]) => `<option value="${value}">${label}</option>`).join('');
    select.value = nextUnit;
    select.dataset.previousUnit = nextUnit;
    document.getElementById('epStock').step = stockStep(nextUnit);
    const saleUnit = nextSaleUnit;
    document.getElementById('epPriceUnit').textContent = saleUnitLabel(saleUnit);
    document.getElementById('epStockHint').textContent = isDiscreteUnit(saleUnit) ? `Each sale deducts one ${saleUnitLabel(saleUnit)}.` : `Sales deduct in ${saleUnitLabel(saleUnit)}.`;
    if (formSelect) formSelect.dataset.previousForm = form;
}

function toggleEditProductSize() {
    const group = document.getElementById('epSizeGroup');
    if (group) group.style.display = '';
}

async function submitEditProduct(id) {
    const p = products.find(x => x.id === id);
    if (!p) return;
    if ((document.getElementById('epSize')?.value || '').trim().length > 30) { toast('Size must be 30 characters or fewer.', 'error'); return; }
    const priceForm = document.getElementById('epSupplementForm')?.value;
    const newPrice = productUnitPrice(document.getElementById('epPrice').value, document.getElementById('epPriceQuantity').value, p.category === 'Merch' || ['capsule', 'tablet', 'other'].includes(priceForm));
    if (newPrice === null) { toast('Enter a positive price and quantity that give a unit price with at most two decimal places.', 'error'); return; }
    const stockInput = document.getElementById('epStock').value.trim();
    const stockUnit = document.getElementById('epStockUnit').value;
    const merchType = p.category === 'Merch' ? document.getElementById('epMerchType').value : '';
    const supplementType = p.category === 'Supplement' ? document.getElementById('epSupplementType').value : '';
    const supplementForm = p.category === 'Supplement' ? document.getElementById('epSupplementForm').value : '';
    if (!Number.isFinite(newPrice) || newPrice <= 0 || !Number.isFinite(Number(stockInput)) || Number(stockInput) < 0 || (isDiscreteUnit(stockUnit) && !Number.isInteger(Number(stockInput)))) { toast('Enter a valid price and stock amount.', 'error'); return; }
    const image = await getProductPhoto('epImage');
    if (image === false) return;
    const oldProduct = { ...p };
    const updatedProduct = { ...p, name: document.getElementById('epName').value.trim(), price: newPrice };
    if (p.category === 'Merch') {
        updatedProduct.merchType = merchType;
        updatedProduct.size = document.getElementById('epSize').value.trim();
    } else delete updatedProduct.size;
    updatedProduct.stock = Number(stockInput);
    updatedProduct.stockUnit = stockUnit;
    updatedProduct.inventoryUnit = p.category === 'Supplement' ? supplementSaleUnit(supplementForm, stockUnit) : 'item';
    if (p.category === 'Supplement') { updatedProduct.supplementType = supplementType; updatedProduct.supplementForm = supplementForm; }
    if (image) updatedProduct.image = image;
    else if (document.getElementById('epRemoveImage').checked) updatedProduct.image = '';
    if (window.ironGrindSupabase) {
        if (!isUUID(id)) { toast('This product is not linked to a Supabase record.', 'error'); return; }
        const { data, error } = await window.ironGrindSupabase.from('products').update({
            name: updatedProduct.name,
            category: p.category === 'Supplement' ? 'supplement' : 'merchandise',
            price_per_unit: updatedProduct.price,
            unit: updatedProduct.inventoryUnit,
            stock_unit: stockUnit,
            merch_type: p.category === 'Merch' ? merchType : null,
            supplement_type: p.category === 'Supplement' ? supplementType : null,
            supplement_form: p.category === 'Supplement' ? supplementForm : null,
            size: p.category === 'Merch' ? (updatedProduct.size || null) : null,
            stock: updatedProduct.stock,
            image_path: updatedProduct.image || null,
            updated_at: new Date().toISOString()
        }).eq('id', id).select('*').single();
        if (error) { toast(`Could not update product in Supabase: ${error.message}`, 'error'); return; }
        Object.assign(p, mapSupabaseProduct(data));
    } else {
        Object.assign(p, updatedProduct);
        try { saveDB('products', products); }
        catch { Object.assign(p, oldProduct); toast('Could not save product photo. Try a smaller image or remove photos from other products.', 'error'); return; }
    }
    closeModal();
    renderStore();
    renderDashboard();
    toast(`✅ Updated ${p.name}.`, 'success');
}

function previewProductPhoto(input, previewId) {
    const preview = document.getElementById(previewId);
    const file = input.files && input.files[0];
    if (!preview || !file) return;
    if (!file.type.startsWith('image/')) { input.value = ''; toast('Choose an image file.', 'error'); return; }
    const reader = new FileReader();
    reader.onload = () => {
        if (input.files?.[0] !== file) return;
        preview.innerHTML = `<img src="${reader.result}" alt="Selected product photo preview">`;
        const frame = preview.closest('.product-photo-upload');
        frame?.classList.add('has-photo');
        const button = frame?.querySelector('.product-photo-upload-button');
        if (button) { button.querySelector('span').textContent = 'Change photo'; button.setAttribute('aria-label', 'Change product photo'); }
        const remove = document.getElementById('epRemoveImage');
        if (input.id === 'epImage' && remove) remove.checked = false;
    };
    reader.onerror = () => toast('Could not read that image.', 'error');
    reader.readAsDataURL(file);
}

function getProductPhoto(inputId) {
    const file = document.getElementById(inputId)?.files?.[0];
    if (!file) return Promise.resolve('');
    if (!file.type.startsWith('image/')) { toast('Choose an image file.', 'error'); return Promise.resolve(false); }
    return new Promise(resolve => {
        const reader = new FileReader();
        reader.onerror = () => { toast('Could not read that image.', 'error'); resolve(false); };
        reader.onload = () => {
            const img = new Image();
            img.onerror = () => { toast('Could not process that image.', 'error'); resolve(false); };
            img.onload = () => {
                const scale = Math.min(1, 900 / Math.max(img.width, img.height));
                const canvas = document.createElement('canvas');
                canvas.width = Math.max(1, Math.round(img.width * scale));
                canvas.height = Math.max(1, Math.round(img.height * scale));
                const context = canvas.getContext('2d');
                const preserveTransparency = ['image/png', 'image/webp', 'image/gif', 'image/svg+xml'].includes(file.type);
                if (!preserveTransparency) {
                    context.fillStyle = '#ffffff'; context.fillRect(0, 0, canvas.width, canvas.height);
                }
                context.drawImage(img, 0, 0, canvas.width, canvas.height);
                resolve(preserveTransparency ? canvas.toDataURL('image/png') : canvas.toDataURL('image/jpeg', 0.78));
            };
            img.src = reader.result;
        };
        reader.readAsDataURL(file);
    });
}

function archiveProduct(id) {
    const p = products.find(x => x.id === id);
    if (!p) return;
    askConfirmation('Archive product?', `Move ${p.name} to Archives? It will be removed from the active store and recorded in Reports.`, 'Archive', () => completeProductArchive(id));
}

async function completeProductArchive(id) {
    const p = products.find(x => x.id === id);
    if (!p) return;
    const archivedAt = new Date().toISOString();
    if (window.ironGrindSupabase) {
        const { error } = await window.ironGrindSupabase.from('products')
            .update({ is_active: false, archived_at: archivedAt, updated_at: archivedAt }).eq('id', id);
        if (error) { toast(`Could not archive product in Supabase: ${error.message}`, 'error'); return; }
    }
    p.isActive = false;
    p.archivedAt = archivedAt;
    products = products.filter(x => x.id !== id);
    archivedProducts = [p, ...archivedProducts.filter(x => String(x.id) !== String(id))];
    if (!window.ironGrindSupabase) {
        saveDB('products', products);
        saveDB('archivedProducts', archivedProducts);
    }
    renderStore();
    renderDashboard();
    toast(`Archived ${p.name}.`, 'success');
}

function openNewSaleModal() {
    const available = products.filter(p => p.stock > 0);
    if (available.length === 0) {
        toast('No stock.', 'error');
        return;
    }
    openModal(`
        <h3><i class="fas fa-cash-register"></i> New Sale</h3>
        <div class="form-group" style="margin-bottom:14px;"><label for="nsCustomer">Customer name</label><input type="text" id="nsCustomer" placeholder="Enter customer name" required></div>
        <div class="form-group" style="margin-bottom:14px;"><label>Product</label><select id="nsProduct" onchange="updateSaleQuantityMode()">
            ${available.map(p => `<option value="${p.id}">${p.name}${p.category === 'Merch' && p.size ? ' (' + p.size + ')' : ''} — ${formatPeso(p.price)} / ${productSaleUnitLabel(p)}</option>`).join('')}
        </select></div>
        <div class="form-row" style="margin-bottom:14px;"><div class="form-group"><label id="nsQtyLabel" for="nsQty">Quantity</label><input type="number" id="nsQty" value="1" min="0.01" step="0.01" oninput="updateSaleTotalPreview()"></div><div class="form-group"><label for="nsUnit">Sell by</label><select id="nsUnit" onchange="updateSaleQuantityMode()"></select></div></div>
        <p class="modal-sub" id="nsPriceHint"></p>
        <div class="sale-total-preview">Sale total <strong id="nsTotalPreview">₱0</strong></div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Cancel</button><button class="btn-primary" onclick="runWithButtonLoading(this, submitNewSale, 'Recording sale…')">Complete</button></div>
    `);
    updateSaleQuantityMode();
}

function updateSaleQuantityMode() {
    const product = products.find(item => item.id === document.getElementById('nsProduct')?.value);
    const quantityInput = document.getElementById('nsQty');
    const unitSelect = document.getElementById('nsUnit');
    if (!product || !quantityInput || !unitSelect) return;
    const productChanged = unitSelect.dataset.productId !== String(product.id);
    const previousUnit = unitSelect.dataset.previousUnit;
    const previousQuantity = Number(quantityInput.value);
    const options = saleUnitsForProduct(product);
    if (productChanged) {
        unitSelect.innerHTML = options.map(([value, label]) => `<option value="${value}">${label}</option>`).join('');
        unitSelect.value = product.inventoryUnit || 'item';
        unitSelect.dataset.productId = String(product.id);
    }
    const saleUnit = unitSelect.value || product.inventoryUnit || 'item';
    const factor = INVENTORY_UNIT_TO_BASE[saleUnit] || 1;
    const available = productStockInSaleUnits(product) / factor;
    const unitLabel = saleUnitLabel(saleUnit);
    const fractional = !isDiscreteUnit(saleUnit);
    quantityInput.min = fractional ? '0.001' : '1';
    quantityInput.step = fractional ? (['kilogram', 'pound', 'liter'].includes(saleUnit) ? '0.001' : '0.01') : '1';
    quantityInput.max = available;
    if (productChanged) {
        const baseUnit = product.inventoryUnit || 'item';
        quantityInput.value = isDiscreteUnit(baseUnit) ? '1' : String(Math.min(100, productStockInSaleUnits(product)));
    } else if (previousUnit && previousUnit !== saleUnit && Number.isFinite(previousQuantity)) {
        const converted = previousQuantity * (INVENTORY_UNIT_TO_BASE[previousUnit] || 1) / factor;
        quantityInput.value = String(Math.min(available, Number(converted.toFixed(3))));
    }
    quantityInput.value = String(Math.min(Number(quantityInput.value) || 0, available));
    unitSelect.dataset.previousUnit = saleUnit;
    const unitPrice = product.price * factor;
    document.getElementById('nsQtyLabel').textContent = fractional ? `Amount to sell (${unitLabel})` : 'Quantity';
    document.getElementById('nsPriceHint').textContent = `${formatPeso(unitPrice)} per ${unitLabel} · ${available.toLocaleString('en-PH')} ${unitLabel} available`;
    updateSaleTotalPreview();
}

function updateSaleTotalPreview() {
    const product = products.find(item => item.id === document.getElementById('nsProduct')?.value);
    const quantity = Number(document.getElementById('nsQty')?.value);
    const output = document.getElementById('nsTotalPreview');
    const unit = document.getElementById('nsUnit')?.value || product?.inventoryUnit || 'item';
    if (output) output.textContent = formatPeso(product && Number.isFinite(quantity) ? product.price * (INVENTORY_UNIT_TO_BASE[unit] || 1) * quantity : 0);
}

async function submitNewSale() {
    const customer = document.getElementById('nsCustomer').value.trim();
    const pid = document.getElementById('nsProduct').value;
    const qty = Number(document.getElementById('nsQty').value);
    const p = products.find(x => x.id === pid);
    const saleUnit = document.getElementById('nsUnit')?.value || p?.inventoryUnit || 'item';
    const fractional = !isDiscreteUnit(saleUnit);
    if (!customer) { toast('Enter the walk-in customer name.', 'error'); document.getElementById('nsCustomer').focus(); return; }
    const stockLimit = p ? productStockInSaleUnits(p) / (INVENTORY_UNIT_TO_BASE[saleUnit] || 1) : 0;
    if (!p || !Number.isFinite(qty) || qty <= 0 || qty > stockLimit || (!fractional && !Number.isInteger(qty))) { toast('Enter a valid amount within available stock.', 'error'); return; }
    const saleId = nextSaleReference();
    const quantityUnit = saleUnitLabel(saleUnit);
    const unitPrice = p.price * (INVENTORY_UNIT_TO_BASE[saleUnit] || 1);
    let sale;
    if (window.ironGrindSupabase) {
        if (!isUUID(p.id)) { toast('This product is not stored in Supabase and cannot be sold yet.', 'error'); return; }
        const { data, error } = await window.ironGrindSupabase.rpc('record_walk_in_sale', {
            p_receipt_number: saleId,
            p_customer_name: customer,
            p_product_id: p.id,
            p_quantity: qty,
            p_quantity_unit: saleUnit
        });
        if (error) { toast(`Could not record sale in Supabase: ${error.message}`, 'error'); return; }
        const line = {
            name: data.item_name,
            productId: data.product_id,
            category: data.category === 'supplement' ? 'Supplement' : 'Merch',
            quantity: Number(data.quantity),
            quantityUnit: saleUnitLabel(data.unit),
            unitPrice: Number(data.unit_price),
            total: Number(data.line_total)
        };
        p.stock = data.stock ?? p.stock;
        sale = {
            id: data.receipt_number,
            databaseId: data.id,
            customer: data.customer_name,
            source: 'walk-in',
            category: p.category,
            productId: data.product_id,
            productName: line.name,
            quantity: line.quantity,
            quantityUnit: line.quantityUnit,
            items: `${line.name} x${line.quantity} ${line.quantityUnit}`,
            lineItems: [line],
            total: Number(data.total),
            date: String(data.sold_at).slice(0, 10),
            createdAt: data.sold_at,
            status: 'Paid'
        };
    } else {
        p.stock -= stockDeductionForSale({ ...p, inventoryUnit: saleUnit }, qty);
        const total = unitPrice * qty;
        sale = {
            id: saleId,
            customer,
            source: 'walk-in',
            category: p.category,
            productId: p.id,
            productName: p.name,
            quantity: qty,
            quantityUnit,
            items: `${p.name} x${qty} ${quantityUnit}`,
            lineItems: [{ name: p.name, productId: p.id, category: p.category, quantity: qty, quantityUnit, unitPrice, total }],
            total,
            date: todayStr(),
            createdAt: new Date().toISOString(),
            status: 'Paid'
        };
        saveDB('products', products);
    }
    sales.unshift(sale);
    if (!window.ironGrindSupabase) saveDB('sales', sales);
    closeModal();
    renderStore();
    renderSales();
    renderDashboard();
    renderWalkinSalesReport();
    toast(`✅ Sale complete — ${formatPeso(sale.total)}.`, 'success');
}

function switchSalesView(view) {
    currentSalesView = view === 'products' ? 'products' : 'membership';
    currentSalesTransactionType = currentSalesView;
    currentSalesSubType = 'all';
    currentSalesProductName = 'all';
    const transactionsPanel = document.getElementById('salesTransactionsPanel');
    const productIncomeSummary = document.getElementById('walkinSalesPanel');
    if (productIncomeSummary.parentElement !== transactionsPanel) {
        transactionsPanel.insertBefore(productIncomeSummary, transactionsPanel.firstChild);
    }
    document.querySelectorAll('[data-sales-view]').forEach(button =>
        button.classList.toggle('active', button.dataset.salesView === currentSalesView)
    );
    transactionsPanel.classList.remove('hidden');
    productIncomeSummary.classList.toggle('hidden', currentSalesView !== 'products');
    renderSales();
}

function renderWalkinSalesReport() {
    const today = todayStr();
    const dayInput = document.getElementById('productSalesDay');
    const fromInput = document.getElementById('productSalesFrom');
    const toInput = document.getElementById('productSalesTo');
    const yearInput = document.getElementById('productSalesYear');
    if (dayInput && !dayInput.value) dayInput.value = today;
    if (fromInput && !fromInput.value) fromInput.value = today;
    if (toInput && !toInput.value) toInput.value = today;
    if (yearInput && !yearInput.value) yearInput.value = today.slice(0, 4);
    updateProductSalesPeriodControls();
    const daySales = sales.filter(sale => isProductSaleInSelectedPeriod(sale) && sale.status === 'Paid'
        && getSaleProductCategory(sale));
    const supplementSales = daySales.filter(sale => getSaleProductCategory(sale) === 'Supplement');
    const merchSales = daySales.filter(sale => getSaleProductCategory(sale) === 'Merchandise');
    const sumIncome = items => items.reduce((sum, sale) => sum + Number(sale.total || 0), 0);
    document.getElementById('walkinTotalIncome').textContent = formatPeso(sumIncome(daySales));
    document.getElementById('walkinSupplementIncome').textContent = formatPeso(sumIncome(supplementSales));
    document.getElementById('walkinMerchIncome').textContent = formatPeso(sumIncome(merchSales));
}

function updateProductSalesPeriodControls() {
    const mode = document.getElementById('productSalesPeriodMode')?.value || 'day';
    document.querySelectorAll('[data-product-sales-period]').forEach(label => {
        label.hidden = label.dataset.productSalesPeriod !== mode;
    });
}

function getProductSalesPeriod() {
    const mode = document.getElementById('productSalesPeriodMode')?.value || 'day';
    if (mode === 'day') {
        const day = document.getElementById('productSalesDay')?.value;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(day || '')) throw new Error('Choose a sales day.');
        return { mode, from: day, to: day, label: day, slug: day };
    }
    if (mode === 'range') {
        const from = document.getElementById('productSalesFrom')?.value;
        const to = document.getElementById('productSalesTo')?.value;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(from || '') || !/^\d{4}-\d{2}-\d{2}$/.test(to || '')) throw new Error('Choose both sales dates.');
        if (from > to) throw new Error('The From date must be on or before the To date.');
        return { mode, from, to, label: `${from} to ${to}`, slug: `${from}_to_${to}` };
    }
    const year = String(document.getElementById('productSalesYear')?.value || '');
    if (!/^\d{4}$/.test(year)) throw new Error('Choose a sales year.');
    return { mode, from: `${year}-01-01`, to: `${year}-12-31`, label: year, slug: year };
}

function isProductSaleInSelectedPeriod(sale) {
    try { return reportDateMatchesPeriod(sale.date || sale.createdAt, getProductSalesPeriod()); }
    catch { return false; }
}

function getMembershipSalesPeriod() {
    if (currentMembershipSalesPeriodMode === 'day') {
        const day = currentMembershipSalesDay;
        return { mode: 'day', from: day, to: day, label: day, slug: day };
    }
    if (currentMembershipSalesPeriodMode === 'range') {
        const from = currentMembershipSalesFrom;
        const to = currentMembershipSalesTo;
        return { mode: 'range', from, to, label: `${from} to ${to}`, slug: `${from}_to_${to}` };
    }
    const year = currentMembershipSalesYear;
    return { mode: 'year', from: `${year}-01-01`, to: `${year}-12-31`, label: year, slug: year };
}

function updateMembershipSalesPeriod(field, value) {
    if (field === 'mode') currentMembershipSalesPeriodMode = ['day', 'range', 'year'].includes(value) ? value : 'day';
    else if (field === 'day' && /^\d{4}-\d{2}-\d{2}$/.test(value)) currentMembershipSalesDay = value;
    else if (field === 'from' && /^\d{4}-\d{2}-\d{2}$/.test(value)) currentMembershipSalesFrom = value;
    else if (field === 'to' && /^\d{4}-\d{2}-\d{2}$/.test(value)) currentMembershipSalesTo = value;
    else if (field === 'year' && /^\d{4}$/.test(value)) currentMembershipSalesYear = value;
    currentSalesSubType = 'all';
    renderSales();
}

function isWalkinProductSale(sale) {
    return sale.source === 'walk-in' || sale.customer === 'Walk-in'
        || ['Supplement', 'Merch'].includes(sale.category)
        || sale.lineItems?.some(item => ['Supplement', 'Merch'].includes(item.category));
}

function getSaleProductCategory(sale) {
    const lineCategory = sale.lineItems?.map(item => item.category).find(category =>
        ['supplement', 'merch', 'merchandise'].includes(String(category || '').toLowerCase())
    );
    const category = String(lineCategory || sale.category || '').toLowerCase();
    if (category === 'supplement') return 'Supplement';
    if (category === 'merch' || category === 'merchandise') return 'Merchandise';
    return null;
}

function getSaleProductNames(sale) {
    const itemNames = (sale.lineItems || [])
        .filter(item => ['supplement', 'merch', 'merchandise'].includes(String(item.category || '').toLowerCase()))
        .map(item => String(item.name || '').trim()).filter(Boolean);
    if (itemNames.length) return [...new Set(itemNames)];
    return sale.productName ? [String(sale.productName)] : [];
}

function isMembershipSale(sale) {
    return Boolean(sale.lineItems?.some(item =>
        String(item.category || '').toLowerCase() === 'membership'
        || /\bmembership\b/i.test(item.name || '')
    ) || String(sale.category || '').toLowerCase() === 'membership'
        || /\bmembership\b/i.test(sale.items || '') || sale.source === 'counter-renewal'
        || sale.source === 'dashboard-renewal' || sale.source === 'member-portal-renewal');
}

function getMembershipPlanFromSale(sale) {
    const member = members.find(item => String(item.id) === String(sale.memberId));
    const text = [
        ...(sale.lineItems || []).filter(item => String(item.category || '').toLowerCase() === 'membership' || /\bmembership\b/i.test(item.name || '')).map(item => item.name),
        sale.items || ''
    ].join(' ');
    const knownPlans = ['Half Month', 'Monthly', 'Weekly', 'Walk-in'];
    const plan = knownPlans.find(name => text.toLowerCase().includes(name.toLowerCase()));
    return plan || member?.plan || 'Other';
}

function renderSales() {
    const el = document.getElementById('salesTable');
    if (currentSalesView === 'products') renderWalkinSalesReport();
    document.getElementById('salesTransactionsPanel')
        ?.classList.toggle('membership-sales-active', currentSalesTransactionType === 'membership');
    const membershipSales = sales.filter(isMembershipSale);
    const membershipSalesInPeriod = membershipSales.filter(sale => reportDateMatchesPeriod(sale.date || sale.createdAt, getMembershipSalesPeriod()));
    const productSales = sales.filter(sale => !isMembershipSale(sale) && Boolean(getSaleProductCategory(sale))
        && isProductSaleInSelectedPeriod(sale));
    const currentMonth = localDateStr().slice(0, 7);
    const currentMonthSales = sales.filter(sale => reportDateBelongsToMonth(sale.date || sale.createdAt, currentMonth));
    const currentMonthPaidSales = currentMonthSales.filter(sale => sale.status === 'Paid');
    const currentMonthPaidMembershipCount = currentMonthPaidSales.filter(isMembershipSale).length;
    const currentMonthPaidProductCount = currentMonthPaidSales.filter(sale => !isMembershipSale(sale) && Boolean(getSaleProductCategory(sale))).length;
    const currentMonthIncome = currentMonthPaidSales.reduce((sum, sale) => sum + (Number(sale.total) || 0), 0);
    const currentMonthLabel = new Intl.DateTimeFormat('en', { month: 'long', year: 'numeric' })
        .format(new Date(`${currentMonth}-01T00:00:00`));
    document.getElementById('salesMonthOverview').innerHTML = `<div class="sales-month-overview-copy"><span>This month · ${currentMonthLabel}</span><h3>Overall income</h3><p>Memberships: ${currentMonthPaidMembershipCount} paid sales · Products: ${currentMonthPaidProductCount} paid sales</p></div><strong class="sales-month-overview-total">${formatPeso(currentMonthIncome)}</strong>`;
    const salesByType = { membership: membershipSalesInPeriod, products: productSales };
    const typedSales = salesByType[currentSalesTransactionType] || [];
    const planOptions = [...new Set(membershipSalesInPeriod.map(getMembershipPlanFromSale))].sort((a, b) => {
        const order = ['Monthly', 'Half Month', 'Weekly', 'Walk-in', 'Other'];
        return (order.indexOf(a) < 0 ? order.length : order.indexOf(a)) - (order.indexOf(b) < 0 ? order.length : order.indexOf(b)) || a.localeCompare(b);
    });
    const productOptions = [...new Set(productSales.map(getSaleProductCategory).filter(Boolean))]
        .sort((a, b) => ['Supplement', 'Merchandise'].indexOf(a) - ['Supplement', 'Merchandise'].indexOf(b));
    const membershipSummaryEl = document.getElementById('membershipSalesSummary');
    if (currentSalesTransactionType === 'membership') {
        const selectedPeriod = getMembershipSalesPeriod();
        const summary = getMembershipIncomeBreakdown(selectedPeriod);
        membershipSummaryEl.classList.remove('hidden');
        membershipSummaryEl.innerHTML = `<div class="membership-sales-summary-heading"><div><h3>Membership income</h3><p>Paid membership transactions for the selected period</p></div>
            <div class="membership-sales-period-controls">
                <label>Period<select id="membershipSalesPeriodMode"><option value="day" ${currentMembershipSalesPeriodMode === 'day' ? 'selected' : ''}>Specific day</option><option value="range" ${currentMembershipSalesPeriodMode === 'range' ? 'selected' : ''}>Date range</option><option value="year" ${currentMembershipSalesPeriodMode === 'year' ? 'selected' : ''}>Full year</option></select></label>
                <label data-membership-sales-period="day" ${currentMembershipSalesPeriodMode !== 'day' ? 'hidden' : ''}>Day<input id="membershipSalesDay" type="date" value="${currentMembershipSalesDay}"></label>
                <label data-membership-sales-period="range" ${currentMembershipSalesPeriodMode !== 'range' ? 'hidden' : ''}>From<input id="membershipSalesFrom" type="date" value="${currentMembershipSalesFrom}"></label>
                <label data-membership-sales-period="range" ${currentMembershipSalesPeriodMode !== 'range' ? 'hidden' : ''}>To<input id="membershipSalesTo" type="date" value="${currentMembershipSalesTo}"></label>
                <label data-membership-sales-period="year" ${currentMembershipSalesPeriodMode !== 'year' ? 'hidden' : ''}>Year<input id="membershipSalesYear" type="number" min="2000" max="2100" step="1" value="${currentMembershipSalesYear}"></label>
            </div></div>
            <div class="membership-income-cards"><article class="membership-income-card overall"><span>Overall income</span><strong>${formatPeso(summary.totalIncome)}</strong><small>${summary.totalCount} paid sales</small></article>
                ${summary.rows.map(row => `<article class="membership-income-card"><span>${escapeHTML(row.label)}</span><strong>${formatPeso(row.income)}</strong><small>${row.count} paid sales</small></article>`).join('')}</div>`;
        document.getElementById('membershipSalesPeriodMode').addEventListener('change', event => updateMembershipSalesPeriod('mode', event.target.value));
        document.getElementById('membershipSalesDay').addEventListener('change', event => updateMembershipSalesPeriod('day', event.target.value));
        document.getElementById('membershipSalesFrom').addEventListener('change', event => updateMembershipSalesPeriod('from', event.target.value));
        document.getElementById('membershipSalesTo').addEventListener('change', event => updateMembershipSalesPeriod('to', event.target.value));
        document.getElementById('membershipSalesYear').addEventListener('change', event => updateMembershipSalesPeriod('year', event.target.value));
    } else {
        membershipSummaryEl.classList.add('hidden');
        membershipSummaryEl.innerHTML = '';
    }
    const subfilterEl = document.getElementById('salesSubFilters');
    const subOptions = currentSalesTransactionType === 'membership' ? planOptions
        : currentSalesTransactionType === 'products' ? productOptions : [];
    if (currentSalesSubType !== 'all' && !subOptions.includes(currentSalesSubType)) currentSalesSubType = 'all';
    if (subOptions.length) {
        const productNameOptions = currentSalesTransactionType === 'products'
            ? [...new Set(productSales
                .filter(sale => currentSalesSubType === 'all' || getSaleProductCategory(sale) === currentSalesSubType)
                .flatMap(getSaleProductNames))].sort((a, b) => a.localeCompare(b))
            : [];
        if (currentSalesProductName !== 'all' && !productNameOptions.includes(currentSalesProductName)) currentSalesProductName = 'all';
        subfilterEl.classList.remove('hidden');
        subfilterEl.innerHTML = `<button class="sales-subfilter ${currentSalesSubType === 'all' ? 'active' : ''}" data-sale-subfilter="all">All ${currentSalesTransactionType === 'membership' ? 'plans' : 'products'} <span>${typedSales.length}</span></button>
            ${subOptions.map(option => {
                const optionCount = currentSalesTransactionType === 'membership'
                    ? membershipSalesInPeriod.filter(sale => getMembershipPlanFromSale(sale) === option).length
                    : productSales.filter(sale => getSaleProductCategory(sale) === option).length;
                return `<button class="sales-subfilter ${currentSalesSubType === option ? 'active' : ''}" data-sale-subfilter="${escapeHTML(option)}">${escapeHTML(option)} <span>${optionCount}</span></button>`;
            }).join('')}
            ${currentSalesTransactionType === 'products' ? `<label class="sales-product-filter">Product
                <select id="salesProductNameFilter"><option value="all">All products</option>${productNameOptions.map(name => `<option value="${escapeHTML(name)}" ${currentSalesProductName === name ? 'selected' : ''}>${escapeHTML(name)}</option>`).join('')}</select>
            </label>` : ''}`;
        subfilterEl.querySelectorAll('[data-sale-subfilter]').forEach(button => button.addEventListener('click', () => {
            currentSalesSubType = button.dataset.saleSubfilter || 'all';
            renderSales();
        }));
        const productSelect = document.getElementById('salesProductNameFilter');
        productSelect?.addEventListener('change', () => {
            currentSalesProductName = productSelect.value || 'all';
            renderSales();
        });
    } else {
        subfilterEl.classList.add('hidden');
        subfilterEl.innerHTML = '';
    }
    const selectedSales = currentSalesSubType === 'all' ? typedSales
        : currentSalesTransactionType === 'membership'
            ? typedSales.filter(sale => getMembershipPlanFromSale(sale) === currentSalesSubType)
            : currentSalesTransactionType === 'products'
                ? typedSales.filter(sale => getSaleProductCategory(sale) === currentSalesSubType)
                : typedSales;
    const visibleSales = currentSalesTransactionType === 'products' && currentSalesProductName !== 'all'
        ? selectedSales.filter(sale => getSaleProductNames(sale).includes(currentSalesProductName))
        : selectedSales;
    if (visibleSales.length === 0) {
        el.innerHTML = '<div class="empty-state">No transactions match this filter.</div>';
        return;
    }
    el.innerHTML = `<div class="table-scroll"><table class="attendance-table">
        <thead><tr><th>Transaction reference</th><th>Customer</th><th>Items</th><th>Total</th><th>Date</th><th>Status</th></tr></thead>
        <tbody>${visibleSales.map(s => `<tr><td>#${escapeHTML(s.id)}</td><td>${escapeHTML(s.customer === 'Walk-in' ? 'Name not recorded' : (s.customer || 'Name not recorded'))}</td><td>${escapeHTML(s.items || '')}</td><td>${formatPeso(s.total)}</td><td>${escapeHTML(s.date || '')}</td>
            <td>${s.status === 'Paid' ? '<span class="badge-status paid">Paid</span>' : '<span class="badge-status reserved">Reserved</span>'}</td>
            </tr>`).join('')}</tbody></table></div>`;
}

function getMemberActivityStatus(member) {
    const savedStatus = String(member.status || '').toLowerCase();
    const pendingRenewal = hasPendingRenewalForMember(member);
    const explicitlyInactive = ['inactive', 'disabled', 'suspended'].includes(savedStatus);
    if (explicitlyInactive && !pendingRenewal) return 'Inactive';
    if (savedStatus === 'expired' || (member.expiry && member.expiry < todayStr())) {
        if (!member.expiry) return 'Inactive';
        return todayStr() >= addDays(member.expiry, 5) && !pendingRenewal ? 'Inactive' : 'Expired';
    }
    return 'Active';
}

function archiveExpiredMembership(member, renewed = false) {
    if (!member?.expiry || member.expiry >= todayStr()) return;
    const exists = membershipArchives.find(record => record.memberId === member.id && record.expiry === member.expiry && record.plan === member.plan);
    if (exists) {
        if (renewed && !exists.renewedAt) exists.renewedAt = new Date().toISOString();
        return;
    }
    membershipArchives.unshift({
        id: `EA-${member.id}-${member.expiry}-${member.plan}`,
        memberId: member.id,
        memberName: member.name,
        username: member.username || '',
        plan: member.plan || '—',
        startDate: member.startDate || '',
        expiry: member.expiry,
        price: Number(member.planPrice || getPlanPrice(member.plan, member)) || 0,
        archivedAt: new Date().toISOString(),
        ...(renewed ? { renewedAt: new Date().toISOString() } : {})
    });
}

function captureExpiredMemberships() {
    if (window.ironGrindSupabase) return;
    const before = membershipArchives.length;
    members.forEach(archiveExpiredMembership);
    if (membershipArchives.length !== before) saveDB('membershipArchives', membershipArchives);
}

function renderReports() {
    const groups = [
        {
            name: 'Membership',
            reports: [
                { id: 'membership', name: 'Membership Report', icon: 'fa-id-card' },
                { id: 'member-status', name: 'Member Status', icon: 'fa-user-check' },
                { id: 'renewals', name: 'Renewal Report', icon: 'fa-rotate' },
                { id: 'archives', name: 'Archives', icon: 'fa-box-archive' }
            ]
        },
        {
            name: 'Daily Operations',
            reports: [
                { id: 'attendance', name: 'Attendance Report', icon: 'fa-clipboard-user' },
                { id: 'inventory', name: 'Inventory Report', icon: 'fa-boxes-stacked' }
            ]
        },
        {
            name: 'Payments & Sales',
            reports: [
                { id: 'payment', name: 'Payment Report', icon: 'fa-money-bill-wave' },
                { id: 'sales', name: 'Sales Report', icon: 'fa-coins' }
            ]
        }
    ];
    const grid = document.getElementById('reportsGrid');
    grid.className = 'reports-content';
    grid.innerHTML = `
        <div class="reports-toolbar">
            <div class="report-export-controls">
                <label>Area<select id="reportsExportArea" onchange="updateReportExportAction()"><option value="all">All report areas</option><option value="membership">Membership</option><option value="member-status">Member Status</option><option value="renewals">Renewals</option><option value="archives">Archives</option><option value="attendance">Attendance</option><option value="inventory">Inventory</option><option value="payment">Payments</option><option value="sales">Sales</option></select></label>
                <label>Period<select id="reportsPeriodMode" onchange="updateReportPeriodControls()"><option value="day">Specific day</option><option value="range">Date range</option><option value="year">Full year</option></select></label>
                <label data-report-period="day">Day<input id="reportsDay" type="date"></label>
                <label data-report-period="range" hidden>From<input id="reportsFrom" type="date"></label>
                <label data-report-period="range" hidden>To<input id="reportsTo" type="date"></label>
                <label data-report-period="year" hidden>Year<input id="reportsYear" type="number" min="2000" max="2100" step="1"></label>
                <div class="report-actions-menu">
                    <button class="report-icon-btn" type="button" onclick="toggleReportActionsMenu(this)" aria-label="Report actions" title="Report actions" aria-expanded="false"><i class="fas fa-bars" aria-hidden="true"></i></button>
                    <div class="report-actions-menu-popover" role="menu" hidden>
                        <button id="reportsExportMenuItem" type="button" role="menuitem" onclick="closeReportActionsMenus(); exportAllReports()"><i class="fas fa-file-pdf" aria-hidden="true"></i> Export as PDF</button>
                        <button type="button" role="menuitem" onclick="closeReportActionsMenus(); printSelectedReport()"><i class="fas fa-print" aria-hidden="true"></i> Print selected</button>
                    </div>
                </div>
            </div>
        </div>
        ${groups.map(group => `
            <section class="report-group" aria-label="${group.name} reports">
                <div class="report-group-heading">
                    <h3>${group.name}</h3>
                </div>
                <div class="report-grid">
                    ${group.reports.map(report => `
                        <article class="report-card">
                            <div class="report-card-icon"><i class="fas ${report.icon}" aria-hidden="true"></i></div>
                            <div class="report-card-copy">
                                <h4>${report.name}</h4>
                            </div>
                            <div class="report-card-actions" aria-label="${report.name} actions">
                                <button class="report-icon-btn" type="button" onclick="viewReportPDF('${report.id}')" aria-label="Preview ${report.name}" title="Preview"><i class="fas fa-eye" aria-hidden="true"></i></button>
                            </div>
                        </article>
                    `).join('')}
                </div>
            </section>
        `).join('')}
    `;
    const today = localDateStr();
    document.getElementById('reportsDay').value = today;
    document.getElementById('reportsFrom').value = today;
    document.getElementById('reportsTo').value = today;
    document.getElementById('reportsYear').value = today.slice(0, 4);
    updateReportPeriodControls();
    updateReportExportAction();
}

function updateReportPeriodControls() {
    const mode = document.getElementById('reportsPeriodMode')?.value || 'day';
    document.querySelectorAll('[data-report-period]').forEach(label => { label.hidden = label.dataset.reportPeriod !== mode; });
}

function updateReportExportAction() {
    const area = document.getElementById('reportsExportArea')?.value || 'all';
    const all = area === 'all';
    const exportItem = document.getElementById('reportsExportMenuItem');
    if (exportItem) {
        exportItem.title = all ? 'Export all report areas as a ZIP of PDFs' : 'Export selected report as PDF';
        exportItem.setAttribute('aria-label', exportItem.title);
        exportItem.innerHTML = `<i class="fas ${all ? 'fa-file-zipper' : 'fa-file-pdf'}" aria-hidden="true"></i> ${all ? 'Export PDFs as ZIP' : 'Export as PDF'}`;
    }
}

function closeReportActionsMenus(except = null) {
    document.querySelectorAll('.report-actions-menu').forEach(menu => {
        if (menu === except) return;
        const button = menu.querySelector('button[aria-expanded]');
        const popover = menu.querySelector('.report-actions-menu-popover');
        if (button) button.setAttribute('aria-expanded', 'false');
        if (popover) popover.hidden = true;
    });
}

function toggleReportActionsMenu(button) {
    const menu = button.closest('.report-actions-menu');
    const popover = menu?.querySelector('.report-actions-menu-popover');
    const shouldOpen = popover?.hidden;
    closeReportActionsMenus(menu);
    if (!popover) return;
    popover.hidden = !shouldOpen;
    button.setAttribute('aria-expanded', String(Boolean(shouldOpen)));
}

function printSelectedReport() {
    const area = document.getElementById('reportsExportArea')?.value || 'all';
    if (area === 'all') {
        toast('Choose one report area before printing.', 'error');
        return;
    }
    printReportPDF(area);
}

function getSelectedReportPeriod() {
    const mode = document.getElementById('reportsPeriodMode')?.value || 'day';
    if (mode === 'day') {
        const day = document.getElementById('reportsDay')?.value;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(day || '')) throw new Error('Choose a report day.');
        return { mode, from: day, to: day, label: day, slug: day };
    }
    if (mode === 'range') {
        const from = document.getElementById('reportsFrom')?.value;
        const to = document.getElementById('reportsTo')?.value;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(from || '') || !/^\d{4}-\d{2}-\d{2}$/.test(to || '')) throw new Error('Choose both From and To dates.');
        if (from > to) throw new Error('The From date must be on or before the To date.');
        return { mode, from, to, label: `${from} to ${to}`, slug: `${from}_to_${to}` };
    }
    const year = String(document.getElementById('reportsYear')?.value || '');
    if (!/^\d{4}$/.test(year)) throw new Error('Choose a valid report year.');
    return { mode, from: `${year}-01-01`, to: `${year}-12-31`, label: year, slug: year };
}

function reportDateMatchesPeriod(value, period) {
    if (!value || !period) return false;
    const text = String(value);
    const date = /^\d{4}-\d{2}-\d{2}/.test(text) ? text.slice(0, 10) : localDateStr(new Date(text));
    return /^\d{4}-\d{2}-\d{2}$/.test(date) && date >= period.from && date <= period.to;
}

function isRenewalSale(sale) {
    return ['counter-renewal', 'dashboard-renewal', 'member-portal-renewal'].includes(sale.source)
        || /^IG-R-/i.test(String(sale.id || ''))
        || /\brenewal\b/i.test(sale.items || '')
        || sale.lineItems?.some(item => /\brenewal\b/i.test(item.name || ''));
}

function getRenewalChannel(sale) {
    if (sale.source === 'counter-renewal') return 'Counter';
    if (/^IG-CR-/i.test(String(sale.id || ''))) return 'Counter';
    if (sale.source === 'dashboard-renewal' || /^IG-R-/i.test(String(sale.id || ''))) return 'Member portal approval';
    if (sale.source === 'member-portal-renewal') return 'Member portal';
    return 'Previously recorded';
}

function getRenewalPlan(sale) {
    const text = sale.lineItems?.[0]?.name || sale.items || '';
    const recordedPlan = text.replace(/\s+membership\s+renewal$/i, '').replace(/\s+renewal$/i, '');
    if (recordedPlan) return recordedPlan;
    const member = members.find(item => String(item.id) === String(sale.memberId));
    return member?.plan || '—';
}

function getRenewalReportRows() {
    const salesByReference = new Map(sales.map(sale => [String(sale.id), sale]));
    const approvedPortalRenewals = approvedRenewalApplications.map(application => {
        const recordedSale = salesByReference.get(String(application.expectedSaleReference));
        return recordedSale ? { ...recordedSale, source: 'dashboard-renewal', saleRecorded: true } : application;
    });
    const approvedSaleReferences = new Set(approvedPortalRenewals
        .filter(sale => sale.saleRecorded !== false).map(sale => String(sale.id)));
    const otherRenewalSales = sales.filter(sale =>
        isRenewalSale(sale) && !approvedSaleReferences.has(String(sale.id))
    );
    return [...approvedPortalRenewals, ...otherRenewalSales]
        .sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
}

function groupAttendanceByMonth(records) {
    const groups = new Map();
    [...records].sort((a, b) => String(b.date || '').localeCompare(String(a.date || ''))).forEach(record => {
        const match = /^(\d{4})-(\d{2})/.exec(String(record.date || ''));
        const key = match ? `${match[1]}-${match[2]}` : 'undated';
        const label = match
            ? new Intl.DateTimeFormat('en', { month: 'long', year: 'numeric' })
                .format(new Date(Number(match[1]), Number(match[2]) - 1, 1))
            : 'Date not recorded';
        if (!groups.has(key)) groups.set(key, { label, records: [] });
        groups.get(key).records.push(record);
    });
    return [...groups.entries()]
        .sort(([a], [b]) => a === 'undated' ? 1 : b === 'undated' ? -1 : b.localeCompare(a))
        .map(([, group]) => group);
}

function viewReport(type) {
    let body = '';
    if (type === 'membership') {
        const currentMembers = members.filter(member => !isPastMembershipArchiveGrace(member));
        body = `<table class="attendance-table"><thead><tr><th>Name</th><th>Plan</th><th>Started</th><th>Expires</th></tr></thead><tbody>
            ${currentMembers.map(m => `<tr><td>${m.name}</td><td>${m.plan}</td><td>${m.startDate || '—'}</td><td>${m.expiry}</td></tr>`).join('')}</tbody></table>`;
    } else if (type === 'member-status') {
        const activeMembers = members.filter(member => getMemberActivityStatus(member) === 'Active');
        const expiredMembers = members.filter(member => getMemberActivityStatus(member) === 'Expired');
        const inactiveMembers = members.filter(member => getMemberActivityStatus(member) === 'Inactive');
        const statusTable = (items, status) => `<h4 style="margin:18px 0 8px; color:${status === 'Active' ? '#2ecc71' : '#ff6b6b'};">${status} Members (${items.length})</h4>
            <table class="attendance-table"><thead><tr><th>Name</th><th>Registration Source</th><th>Plan</th><th>Expires</th></tr></thead><tbody>
            ${items.map(member => `<tr><td>${escapeHTML(member.name)}</td><td>${escapeHTML(member.registrationSource || 'Not recorded')}</td><td>${escapeHTML(member.plan || '—')}</td><td>${escapeHTML(member.expiry || '—')}</td></tr>`).join('') || '<tr><td colspan="4">No members in this group.</td></tr>'}</tbody></table>`;
        body = `<p class="modal-sub">Expired memberships remain in the five-day renewal window. After that, records without a pending renewal are tracked as inactive.</p>
            ${statusTable(activeMembers, 'Active')}${statusTable(expiredMembers, 'Expired')}${statusTable(inactiveMembers, 'Inactive')}`;
    } else if (type === 'archives') {
        captureExpiredMemberships();
        const archivedPlans = [...planArchives].sort((a, b) => String(b.changedAt || '').localeCompare(String(a.changedAt || '')));
        const expiredMembers = membershipArchives.filter(isMembershipArchiveReady).sort((a, b) => String(b.expiry || '').localeCompare(String(a.expiry || '')));
        const expiredTable = expiredMembers.length
            ? `<table class="attendance-table"><thead><tr><th>Member</th><th>Plan</th><th>Started</th><th>Expired</th><th>Fee</th></tr></thead><tbody>${expiredMembers.map(record => `<tr><td>${escapeHTML(record.memberName)}</td><td>${escapeHTML(record.plan)}</td><td>${escapeHTML(record.startDate || '—')}</td><td>${escapeHTML(record.expiry)}</td><td>${formatPeso(record.price)}</td></tr>`).join('')}</tbody></table>`
            : '<div class="empty-state">No expired subscriptions have been archived.</div>';
        const planTable = archivedPlans.length
            ? `<table class="attendance-table"><thead><tr><th>Member</th><th>Previous Plan</th><th>New Plan</th><th>Previous Expiry</th><th>New Expiry</th><th>Previous Fee</th><th>New Fee</th><th>Changed</th></tr></thead><tbody>${archivedPlans.map(record => `<tr><td>${escapeHTML(record.memberName)}</td><td>${escapeHTML(record.previousPlan)}</td><td>${escapeHTML(record.newPlan)}</td><td>${escapeHTML(record.previousExpiry || '—')}</td><td>${escapeHTML(record.newExpiry || '—')}</td><td>${formatPeso(record.previousPrice || 0)}</td><td>${formatPeso(record.newPrice || 0)}</td><td>${escapeHTML(record.changedAt ? new Date(record.changedAt).toLocaleString() : '—')}</td></tr>`).join('')}</tbody></table>`
            : '<div class="empty-state">No plan changes have been archived yet.</div>';
        const archivedProductRows = archivedProducts.slice().sort((a, b) => String(b.archivedAt || '').localeCompare(String(a.archivedAt || '')));
        const productTable = archivedProductRows.length
            ? `<table class="attendance-table"><thead><tr><th>Product</th><th>Category</th><th>Size</th><th>Price</th><th>Archived</th></tr></thead><tbody>${archivedProductRows.map(product => `<tr><td>${escapeHTML(product.name)}</td><td>${escapeHTML(product.category)}</td><td>${escapeHTML(product.size || '—')}</td><td>${formatPeso(product.price)} / ${productSaleUnitLabel(product)}</td><td>${escapeHTML(product.archivedAt ? new Date(product.archivedAt).toLocaleString() : '—')}</td></tr>`).join('')}</tbody></table>`
            : '<div class="empty-state">No products have been archived.</div>';
        body = `<section><h4>Expired Subscriptions (${expiredMembers.length})</h4>${expiredTable}</section><section style="margin-top:24px;"><h4>Plan Changes (${archivedPlans.length})</h4><p class="modal-sub">No refunds are issued for unused time on the previous plan.</p>${planTable}</section><section style="margin-top:24px;"><h4>Archived Products (${archivedProductRows.length})</h4>${productTable}</section>`;
    } else if (type === 'payment' || type === 'sales') {
        body = `<table class="attendance-table"><thead><tr><th>Transaction reference</th><th>Customer</th><th>Total</th><th>Date</th><th>Status</th></tr></thead><tbody>
            ${sales.map(s => `<tr><td>#${escapeHTML(s.id || '—')}</td><td>${escapeHTML(s.customer || 'Name not recorded')}</td><td>${formatPeso(s.total)}</td><td>${escapeHTML(s.date || '—')}</td><td>${escapeHTML(s.status || 'Unknown')}</td></tr>`).join('') || '<tr><td colspan="5">No payment records.</td></tr>'}</tbody></table>`;
    } else if (type === 'renewals') {
        const renewals = getRenewalReportRows();
        const income = renewals.reduce((total, sale) => total + (sale.saleRecorded === false ? 0 : Number(sale.total || 0)), 0);
        body = `<p class="modal-sub">${renewals.length} completed renewal${renewals.length === 1 ? '' : 's'} · Total collected: <strong>${formatPeso(income)}</strong></p>
            ${renewals.length ? `<div class="table-scroll"><table class="attendance-table"><thead><tr><th>Transaction reference</th><th>Member</th><th>Renewed Plan</th><th>Channel</th><th>Amount</th><th>Date</th><th>Payment record</th></tr></thead><tbody>
                ${renewals.map(sale => `<tr><td>${sale.saleRecorded === false ? 'Not recorded' : `#${escapeHTML(sale.id)}`}</td><td>${escapeHTML(sale.customer || 'Name not recorded')}</td><td>${escapeHTML(getRenewalPlan(sale))}</td><td>${escapeHTML(getRenewalChannel(sale))}</td><td>${formatPeso(sale.total)}</td><td>${escapeHTML(sale.date || '—')}</td><td>${sale.saleRecorded === false ? 'Missing payment record' : 'Recorded'}</td></tr>`).join('')}
            </tbody></table></div>` : '<div class="empty-state">No completed membership renewals recorded.</div>'}`;
    } else if (type === 'attendance') {
        const attendanceGroups = groupAttendanceByMonth(attendance);
        body = attendanceGroups.length ? attendanceGroups.map(group => `
            <section class="attendance-month-group" style="margin-bottom:22px;">
                <h4 style="margin:0 0 10px; padding:10px 12px; border-left:4px solid #ff6b2b; background:#20242c; color:#fff;">
                    ${escapeHTML(group.label)} <span style="float:right; color:#c4cad5;">${group.records.length} ${group.records.length === 1 ? 'visit' : 'visits'}</span>
                </h4>
                <table class="attendance-table"><thead><tr><th>Member</th><th>Date</th><th>In</th><th>Out</th></tr></thead><tbody>
                    ${group.records.map(a => `<tr><td>${escapeHTML(a.memberName)}</td><td>${escapeHTML(a.date || '—')}</td><td>${escapeHTML(formatAttendanceClock(a.timeIn))}</td><td>${escapeHTML(formatAttendanceClock(a.timeOut))}</td></tr>`).join('')}
                </tbody></table>
            </section>`).join('') : '<div class="empty-state">No attendance records.</div>';
    } else if (type === 'inventory') {
        body = `<table class="attendance-table"><thead><tr><th>Product</th><th>Category</th><th>Type</th><th>Price</th><th>Stock</th></tr></thead><tbody>
            ${products.map(p => `<tr><td>${escapeHTML(p.name)}${p.category === 'Merch' && p.size ? ` (${escapeHTML(p.size)})` : ''}</td><td>${p.category === 'Supplement' ? 'Supplement' : 'Merchandise'}</td><td>${escapeHTML(productClassification(p))}</td><td>${formatPeso(p.price)} / ${productSaleUnitLabel(p)}</td><td>${escapeHTML(formatProductStock(p))}</td></tr>`).join('') || '<tr><td colspan="5">No active products.</td></tr>'}</tbody></table>`;
    }
    const title = type === 'member-status'
        ? 'Active / Inactive Members Report'
        : type === 'archives'
        ? 'Archives'
            : type === 'renewals'
                ? 'Membership Renewal Report'
            : `${type.charAt(0).toUpperCase() + type.slice(1)} Report`;
    openModal(`<h3><i class="fas fa-chart-bar"></i> ${title}</h3>
        <div style="max-height:60vh; overflow:auto; margin-top:16px;">${body}</div>
        <div class="modal-actions"><button class="btn-sm" onclick="closeModal()">Close</button><button class="btn-primary" onclick="viewReportPDF('${type}')"><i class="fas fa-file-pdf"></i> View as PDF</button></div>`);
}

function setReportPreviewZoom(change) {
    reportPreviewZoom = Math.max(80, Math.min(160, reportPreviewZoom + change));
    const frame = document.getElementById('reportPdfPreviewFrame');
    if (!frame?.contentDocument?.body) return;
    frame.contentDocument.body.style.zoom = `${reportPreviewZoom}%`;
    const label = document.getElementById('reportPreviewZoomLabel');
    if (label) label.textContent = `${reportPreviewZoom}%`;
}

function getMembershipIncomeBreakdown(period) {
    const breakdown = {
        Monthly: { count: 0, income: 0 },
        'Half Month': { count: 0, income: 0 },
        WalkIn: { count: 0, income: 0 },
        Other: { count: 0, income: 0 }
    };
    sales.filter(sale => sale.status === 'Paid'
        && isMembershipSale(sale)
        && (!period || (typeof period === 'string'
            ? reportDateBelongsToMonth(sale.date || sale.createdAt, period)
            : reportDateMatchesPeriod(sale.date || sale.createdAt, period))))
        .forEach(sale => {
            const plan = getMembershipPlanFromSale(sale);
            const key = plan === 'Monthly' ? 'Monthly'
                : plan === 'Half Month' ? 'Half Month'
                    : plan === 'Walk-in' ? 'WalkIn' : 'Other';
            breakdown[key].count += 1;
            breakdown[key].income += Number(sale.total) || 0;
        });
    const rows = [
        { label: 'Monthly', ...breakdown.Monthly },
        { label: 'Half Month', ...breakdown['Half Month'] },
        { label: 'Walk-in (Daily)', ...breakdown.WalkIn },
        { label: 'Other plans', ...breakdown.Other }
    ];
    return {
        rows,
        totalCount: rows.reduce((sum, row) => sum + row.count, 0),
        totalIncome: rows.reduce((sum, row) => sum + row.income, 0)
    };
}

function viewReportPDF(type) {
    reportPreviewZoom = 110;
    openModal(`<div class="report-pdf-preview-toolbar">
        <strong><i class="fas fa-file-pdf"></i> Report preview</strong>
        <div class="report-pdf-preview-controls">
            <button class="btn-sm" aria-label="Zoom out" onclick="setReportPreviewZoom(-10)">−</button>
            <span id="reportPreviewZoomLabel">110%</span>
            <button class="btn-sm" aria-label="Zoom in" onclick="setReportPreviewZoom(10)">+</button>
            <button class="btn-sm" onclick="closeModal()">Close</button>
        </div>
    </div><iframe id="reportPdfPreviewFrame" class="report-pdf-preview-frame" title="Scrollable report PDF preview"></iframe>`);
    document.getElementById('modalContent').classList.add('report-pdf-modal');
    printReportPDF(type, true);
}

function printReportPDF(type, inAppPreview = false) {
    let selectedPeriod;
    try { selectedPeriod = getSelectedReportPeriod(); }
    catch (error) { toast(error.message, 'error'); return; }
    let reportWindow;
    if (inAppPreview) {
        reportWindow = document.getElementById('reportPdfPreviewFrame')?.contentWindow;
        if (!reportWindow) {
            toast('Could not open the report preview.', 'error');
            return;
        }
    } else {
        reportWindow = window.open('', '_blank');
    }
    if (!reportWindow) {
        toast('Allow pop-ups to print or save this report as a PDF.', 'error');
        return;
    }

    const reportNames = { membership: 'Membership', 'member-status': 'Member Status', archives: 'Archives', payment: 'Payment', attendance: 'Attendance', renewals: 'Membership Renewal', inventory: 'Inventory', sales: 'Sales' };
    const reportTitle = `${reportNames[type] || 'Gym'} Report`;
    let columns = [];
    let rows = [];
    let dateForRow = () => null;

    if (type === 'membership') {
        columns = ['Member', 'Plan', 'Started', 'Expires'];
        rows = members.filter(member => !isPastMembershipArchiveGrace(member)).map(member => ({
            cells: [member.name, member.plan, member.startDate || '—', member.expiry || '—'],
            date: member.startDate || member.registeredAt
        }));
        dateForRow = row => row.date;
    } else if (type === 'member-status') {
        columns = ['Member', 'Registration Source', 'Plan', 'Expires'];
        rows = members.map(member => ({
            cells: [member.name, member.registrationSource || 'Not recorded', member.plan || '—', member.expiry || '—'],
            status: getMemberActivityStatus(member)
        }));
    } else if (type === 'archives') {
        captureExpiredMemberships();
        columns = ['Record Type', 'Member / Product', 'Category / Details', 'Plan / Details', 'Previous Plan', 'New Plan', 'Started', 'Expired / Archived', 'New Expiry', 'Fee', 'New Fee', 'Recorded'];
        rows = [
            ...membershipArchives.filter(isMembershipArchiveReady).map(record => ({
                cells: ['Expired subscription', record.memberName, 'Membership', record.plan, '—', '—', record.startDate || '—', record.expiry, '—', formatPeso(record.price || 0), '—', record.expiry],
                date: record.expiry
            })),
            ...planArchives.map(record => ({
                cells: ['Plan change', record.memberName, '—', '—', record.previousPlan, record.newPlan, record.previousStartDate || '—', record.previousExpiry || '—', record.newExpiry || '—', formatPeso(record.previousPrice || 0), formatPeso(record.newPrice || 0), record.changedAt ? new Date(record.changedAt).toLocaleString() : '—'],
                date: record.changedAt
            })),
            ...archivedProducts.map(product => ({
                cells: ['Archived product', product.name, product.category, `${product.size ? `${product.size} · ` : ''}${formatPeso(product.price)} per ${productSaleUnitLabel(product)}`, '—', '—', '—', product.archivedAt ? new Date(product.archivedAt).toLocaleString() : '—', '—', '—', '—', product.archivedAt ? new Date(product.archivedAt).toLocaleString() : '—'],
                date: product.archivedAt
            }))
        ];
        dateForRow = row => row.date;
    } else if (type === 'payment' || type === 'sales') {
        columns = ['Transaction reference', 'Customer', 'Total', 'Date', 'Status'];
        rows = sales.map(sale => ({ cells: [sale.id, sale.customer || 'Name not recorded', formatPeso(sale.total), sale.date || '—', sale.status || 'Unknown'], date: sale.date }));
        dateForRow = row => row.date;
    } else if (type === 'renewals') {
        columns = ['Transaction reference', 'Member', 'Renewed Plan', 'Channel', 'Amount', 'Date', 'Payment record'];
        rows = getRenewalReportRows().map(sale => ({
            cells: [sale.saleRecorded === false ? 'Not recorded' : sale.id, sale.customer || 'Name not recorded', getRenewalPlan(sale), getRenewalChannel(sale), formatPeso(sale.total), sale.date || '—', sale.saleRecorded === false ? 'Missing payment record' : 'Recorded'],
            date: sale.date
        }));
        dateForRow = row => row.date;
    } else if (type === 'attendance') {
        columns = ['Member', 'Date', 'Time in', 'Time out'];
        rows = attendance.map(record => ({
            cells: [record.memberName, record.date, formatAttendanceClock(record.timeIn), formatAttendanceClock(record.timeOut)],
            date: record.date
        }));
        dateForRow = row => row.date;
    } else if (type === 'inventory') {
        columns = ['Product', 'Category', 'Type', 'Price', 'Stock'];
        rows = products.map(product => ({
            cells: [
                `${product.name}${product.size ? ` (${product.size})` : ''}`,
                product.category === 'Supplement' ? 'Supplement' : 'Merchandise',
                productClassification(product),
                `${formatPeso(product.price)} / ${productSaleUnitLabel(product)}`,
                formatProductStock(product)
            ]
        }));
    }

    // Keep status and inventory reports as current snapshots. Dated reports
    // follow the period selected in the Reports toolbar.
    if (['membership', 'archives', 'payment', 'sales', 'renewals', 'attendance'].includes(type)) {
        rows = rows.filter(row => reportDateMatchesPeriod(dateForRow(row), selectedPeriod));
    }

    const tableHTML = records => `<table><thead><tr>${columns.map(column => `<th>${escapeHTML(column)}</th>`).join('')}</tr></thead><tbody>${records.map(row =>
        `<tr>${row.cells.map(cell => `<td>${escapeHTML(cell ?? '—')}</td>`).join('')}</tr>`
    ).join('')}</tbody></table>`;

    let reportContent;
    if (type === 'inventory') {
        reportContent = `<section class="report-section"><div class="section-heading"><h2>Current Inventory Snapshot</h2><span>${rows.length} products</span></div>${rows.length ? tableHTML(rows) : '<p class="empty">No inventory records.</p>'}</section>`;
    } else if (type === 'member-status') {
        reportContent = ['Active', 'Expired', 'Inactive'].map(status => {
            const groupRows = rows.filter(row => row.status === status);
            return `<section class="report-section"><div class="section-heading"><h2>${status} Members</h2><span>${groupRows.length} ${groupRows.length === 1 ? 'member' : 'members'}</span></div>${groupRows.length ? tableHTML(groupRows) : '<p class="empty">No members in this group.</p>'}</section>`;
        }).join('');
    } else {
        const monthGroups = new Map();
        rows.forEach(row => {
            const value = dateForRow(row);
            const parsed = value ? new Date(value.length === 10 ? `${value}T00:00:00` : value) : null;
            const key = parsed && !Number.isNaN(parsed.getTime())
                ? `${parsed.getFullYear()}-${String(parsed.getMonth() + 1).padStart(2, '0')}`
                : 'undated';
            const label = key === 'undated'
                ? 'Date not recorded'
                : new Intl.DateTimeFormat('en', { month: 'long', year: 'numeric' }).format(parsed);
            if (!monthGroups.has(key)) monthGroups.set(key, { label, rows: [] });
            monthGroups.get(key).rows.push(row);
        });
        const orderedGroups = [...monthGroups.entries()].sort(([a], [b]) => {
            if (a === 'undated') return 1;
            if (b === 'undated') return -1;
            return b.localeCompare(a);
        });
        reportContent = orderedGroups.length
            ? orderedGroups.map(([, group]) => `<section class="report-section"><div class="section-heading"><h2>${escapeHTML(group.label)}</h2><span>${group.rows.length} ${group.rows.length === 1 ? 'record' : 'records'}</span></div>${tableHTML(group.rows)}</section>`).join('')
            : '<p class="empty">No report records available.</p>';
    }

    if (type === 'membership') {
        const income = getMembershipIncomeBreakdown(selectedPeriod);
        const incomeRows = [
            ...income.rows.map(row => ({ cells: [row.label, row.count, formatPeso(row.income)] })),
            { cells: ['Overall membership income', income.totalCount, formatPeso(income.totalIncome)] }
        ];
        reportContent = `<section class="report-section membership-income-section"><div class="section-heading"><h2>Membership Income</h2><span>${income.totalCount} paid sales · ${formatPeso(income.totalIncome)}</span></div>${tableHTML(incomeRows)}</section>${reportContent}`;
    }

    const generatedAt = new Date().toLocaleString();
    const logoURL = new URL('assets/images/iron-grind-mark.png', window.location.href).href;
    reportWindow.document.open();
    reportWindow.document.write(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Iron Grind - ${reportTitle} - ${todayStr()}</title>
        <style>
            @page { size: auto; margin: 14mm; }
            * { box-sizing: border-box; }
            body { margin: 0; color: #20242c; font: 11px Arial, sans-serif; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            .masthead { display: flex; align-items: center; gap: 14px; padding: 17px 20px; color: #fff; background: #11161f; border-bottom: 5px solid #d31212; }
            .masthead img { width: 48px; height: 48px; object-fit: contain; border-radius: 8px; background: #fff; }
            .brand { color: #c4cad5; font-size: 9px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; }
            h1 { margin: 4px 0 0; color: #fff; font-size: 21px; }
            .meta { display: flex; justify-content: space-between; gap: 12px; margin: 15px 0 20px; color: #636b78; font-size: 10px; }
            .report-section { margin: 0 0 22px; }
            .section-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; padding: 8px 11px; border-left: 4px solid #d31212; background: #f2f3f5; break-after: avoid; }
            .section-heading h2 { margin: 0; color: #242933; font-size: 13px; }
            .section-heading span { color: #727987; font-size: 9px; font-weight: 700; text-transform: uppercase; }
            table { width: 100%; border-collapse: collapse; }
            th, td { padding: 8px 9px; border-bottom: 1px solid #e1e4e9; text-align: left; vertical-align: top; }
            th { color: #fff; background: #282e38; font-size: 9px; letter-spacing: .5px; text-transform: uppercase; }
            tbody tr:nth-child(even) { background: #f7f8fa; }
            tr { break-inside: avoid; }
            .empty { padding: 18px; border: 1px dashed #cbd0d8; color: #707887; text-align: center; }
            .footer { margin-top: 28px; padding-top: 9px; border-top: 1px solid #d8dce2; color: #858c98; font-size: 9px; }
            @media print { thead { display: table-header-group; } }
        </style></head><body><header class="masthead"><img src="${logoURL}" alt="Iron Grind"><div><div class="brand">Iron Grind Fitness Gym</div><h1>${escapeHTML(reportTitle)}</h1></div></header><div class="meta"><span>Period: ${escapeHTML(selectedPeriod.label)} · ${rows.length} ${rows.length === 1 ? 'record' : 'records'}</span><span>Generated ${escapeHTML(generatedAt)}</span></div>${reportContent}<footer class="footer">Iron Grind Fitness Gym · Internal report · ${todayStr()}</footer></body></html>`);
    reportWindow.document.close();
    if (inAppPreview) {
        window.setTimeout(() => setReportPreviewZoom(0), 100);
    } else {
        window.setTimeout(() => {
            reportWindow.focus();
            reportWindow.print();
        }, 300);
    }
}

function reportDateBelongsToMonth(value, month) {
    if (!value) return false;
    const text = String(value);
    if (/^\d{4}-\d{2}$/.test(text) || /^\d{4}-\d{2}-\d{2}$/.test(text)) return text.slice(0, 7) === month;
    const parsed = new Date(text);
    return !Number.isNaN(parsed.getTime()) && localDateStr(parsed).slice(0, 7) === month;
}

function createMonthlyReportPDF(type, period) {
    const JsPDF = window.jspdf?.jsPDF;
    if (!JsPDF) throw new Error('PDF generator did not load. Check the internet connection and reload the admin page.');

    const reportNames = {
        membership: 'Membership Report',
        'member-status': 'Member Status Report',
        archives: 'Archives Report',
        payment: 'Payment Report',
        attendance: 'Attendance Report',
        renewals: 'Membership Renewal Report',
        inventory: 'Inventory Report',
        sales: 'Sales Report'
    };
    const sections = [];
    const rowsFor = (headers, rows) => ({ headers, rows });
    const membersForPeriod = members.filter(member => !isPastMembershipArchiveGrace(member)
        && reportDateMatchesPeriod(member.startDate || member.registeredAt, period));

    if (type === 'membership') {
        sections.push(rowsFor(['Member', 'Plan', 'Started', 'Expires'], membersForPeriod.map(member => [member.name, member.plan, member.startDate || '-', member.expiry || '-'])));
        const income = getMembershipIncomeBreakdown(period);
        sections.push(rowsFor(['Plan', 'Paid Sales', 'Income'], [
            ...income.rows.map(row => [row.label, String(row.count), `PHP ${row.income.toFixed(2)}`]),
            ['Overall membership income', String(income.totalCount), `PHP ${income.totalIncome.toFixed(2)}`]
        ]));
    } else if (type === 'member-status') {
        sections.push(rowsFor(['Member', 'Registration Source', 'Plan', 'Expires'], members.map(member => [
            member.name,
            member.registrationSource || 'Not recorded',
            member.plan || '-',
            member.expiry || '-'
        ])));
    } else if (type === 'archives') {
        captureExpiredMemberships();
        const archivedRows = [
            ...membershipArchives.filter(isMembershipArchiveReady)
                .filter(record => reportDateMatchesPeriod(record.archivedAt || record.expiry, period))
                .map(record => ['Expired membership', record.memberName, 'Membership', record.plan, record.expiry || '-']),
            ...planArchives.filter(record => reportDateMatchesPeriod(record.changedAt, period))
                .map(record => ['Plan change', record.memberName, `${record.previousPlan || '-'} to ${record.newPlan || '-'}`, record.previousExpiry || '-', record.changedAt || '-']),
            ...archivedProducts.filter(record => reportDateMatchesPeriod(record.archivedAt, period))
                .map(record => ['Archived product', record.name, record.category, record.size || '-', record.archivedAt || '-'])
        ];
        sections.push(rowsFor(['Record Type', 'Member / Product', 'Category / Details', 'Plan / Previous Expiry', 'Archived / Changed'], archivedRows));
    } else if (type === 'payment' || type === 'sales') {
        const filteredSales = sales.filter(sale => reportDateMatchesPeriod(sale.date || sale.createdAt, period));
        sections.push(rowsFor(['Transaction reference', 'Customer', 'Total', 'Date', 'Status'], filteredSales.map(sale => [sale.id || '-', sale.customer || 'Name not recorded', `PHP ${Number(sale.total || 0).toFixed(2)}`, sale.date || '-', sale.status || 'Unknown'])));
    } else if (type === 'attendance') {
        const filteredAttendance = attendance.filter(record => reportDateMatchesPeriod(record.date, period));
        sections.push(rowsFor(['Member', 'Date', 'Time in', 'Time out'], filteredAttendance.map(record => [record.memberName, record.date || '-', formatAttendanceClock(record.timeIn), formatAttendanceClock(record.timeOut)])));
    } else if (type === 'renewals') {
        const renewals = getRenewalReportRows().filter(record => reportDateMatchesPeriod(record.date, period));
        sections.push(rowsFor(['Transaction reference', 'Member', 'Renewed Plan', 'Channel', 'Amount', 'Date', 'Payment record'], renewals.map(record => [
            record.saleRecorded === false ? 'Not recorded' : record.id || '-',
            record.customer || 'Name not recorded',
            getRenewalPlan(record),
            getRenewalChannel(record),
            `PHP ${Number(record.total || 0).toFixed(2)}`,
            record.date || '-',
            record.saleRecorded === false ? 'Missing payment record' : 'Recorded'
        ])));
    } else if (type === 'inventory') {
        sections.push(rowsFor(['Product', 'Category', 'Type', 'Price', 'Stock'], products.map(product => [
            `${product.name}${product.size ? ` (${product.size})` : ''}`,
            product.category === 'Supplement' ? 'Supplement' : 'Merchandise',
            productClassification(product),
            `PHP ${Number(product.price || 0).toFixed(2)} / ${productSaleUnitLabel(product)}`,
            formatProductStock(product)
        ])));
    }

    const doc = new JsPDF({ orientation: ['archives', 'payment', 'sales', 'renewals'].includes(type) ? 'landscape' : 'portrait', unit: 'pt', format: 'a4' });
    const reportTitle = reportNames[type] || 'Iron Grind Report';
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(16);
    doc.setTextColor(211, 18, 18);
    doc.text('IRON GRIND FITNESS GYM', 40, 38);
    doc.setFontSize(12);
    doc.setTextColor(32, 36, 44);
    doc.text(reportTitle, 40, 59);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(100, 108, 120);
    doc.text(`Report period: ${period.label}  |  Generated: ${new Date().toLocaleString()}`, 40, 74);

    let cursorY = 88;
    sections.forEach(section => {
        if (!section.rows.length) {
            doc.setFontSize(10);
            doc.text('No records for the selected period.', 40, cursorY + 12);
            cursorY += 32;
            return;
        }
        doc.autoTable({
            head: [section.headers],
            body: section.rows.map(row => row.map(value => String(value ?? '-'))),
            startY: cursorY,
            margin: { left: 40, right: 40, bottom: 32 },
            styles: { font: 'helvetica', fontSize: 8, cellPadding: 5, overflow: 'linebreak' },
            headStyles: { fillColor: [40, 46, 56], textColor: [255, 255, 255], fontStyle: 'bold' },
            alternateRowStyles: { fillColor: [246, 247, 249] },
            didDrawPage: data => {
                const pageCount = doc.internal.getNumberOfPages();
                doc.setFont('helvetica', 'normal');
                doc.setFontSize(8);
                doc.setTextColor(120, 126, 136);
                doc.text(`Iron Grind Fitness Gym | ${period.label}`, 40, doc.internal.pageSize.getHeight() - 16);
                doc.text(`Page ${data.pageNumber} of ${pageCount}`, doc.internal.pageSize.getWidth() - 40, doc.internal.pageSize.getHeight() - 16, { align: 'right' });
            }
        });
        cursorY = (doc.lastAutoTable?.finalY || cursorY) + 20;
    });
    if (!sections.length) {
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(10);
        doc.text('No records for the selected period.', 40, cursorY);
    }
    return doc.output('blob');
}

async function exportAllReports() {
    let period;
    try { period = getSelectedReportPeriod(); }
    catch (error) { toast(error.message, 'error'); return; }
    const selectedArea = document.getElementById('reportsExportArea')?.value || 'all';
    const JsPDF = window.jspdf?.jsPDF;
    const pdfTableReady = typeof JsPDF === 'function' && typeof new JsPDF().autoTable === 'function';
    const missingTools = [
        selectedArea === 'all' && !window.JSZip && 'ZIP generator',
        !pdfTableReady && 'PDF table generator'
    ].filter(Boolean);
    if (missingTools.length) {
        console.error('Report export tools are unavailable:', {
            missingTools,
            jsPDF: typeof JsPDF,
            autoTable: typeof JsPDF === 'function' ? typeof new JsPDF().autoTable : 'unavailable',
            JSZip: typeof window.JSZip
        });
        toast(`Could not load ${missingTools.join(' and ')}. Reload the page and try again.`, 'error');
        return;
    }
    const allTypes = ['membership', 'member-status', 'archives', 'payment', 'attendance', 'renewals', 'inventory', 'sales'];
    const types = selectedArea === 'all' ? allTypes : allTypes.includes(selectedArea) ? [selectedArea] : [];
    const names = {
        membership: 'Membership Report',
        'member-status': 'Member Status Report',
        archives: 'Archives Report',
        payment: 'Payment Report',
        attendance: 'Attendance Report',
        renewals: 'Membership Renewal Report',
        inventory: 'Inventory Report',
        sales: 'Sales Report'
    };
    try {
        if (!types.length) throw new Error('Choose a valid report area.');
        toast(`Preparing PDFs for ${period.label}…`, 'success');
        if (types.length === 1) {
            const type = types[0];
            const pdfBlob = createMonthlyReportPDF(type, period);
            const url = URL.createObjectURL(pdfBlob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `${names[type]} (${period.slug}).pdf`;
            link.click();
            window.setTimeout(() => URL.revokeObjectURL(url), 1000);
            toast(`${names[type]} exported for ${period.label}.`, 'success');
            return;
        }
        const zip = new JSZip();
        const reportFolder = zip.folder('Iron Grind Reports');
        types.forEach(type => {
            const pdfBlob = createMonthlyReportPDF(type, period);
            reportFolder.file(`${names[type]} (${period.slug}).pdf`, pdfBlob);
        });
        const zipBlob = await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
        const url = URL.createObjectURL(zipBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `Iron Grind Reports (${period.slug}).zip`;
        link.click();
        window.setTimeout(() => URL.revokeObjectURL(url), 1000);
        toast(`Exported ${types.length} PDFs for ${period.label}.`, 'success');
    } catch (error) {
        console.error('Could not export monthly PDF reports:', error);
        toast(error.message || 'Could not create the monthly report archive.', 'error');
    }
}

function downloadReportPDF(type) {
    let period;
    try { period = getSelectedReportPeriod(); }
    catch (error) { toast(error.message, 'error'); return; }
    const names = {
        membership: 'Membership Report',
        'member-status': 'Member Status Report',
        archives: 'Archives Report',
        payment: 'Payment Report',
        attendance: 'Attendance Report',
        renewals: 'Membership Renewal Report',
        inventory: 'Inventory Report',
        sales: 'Sales Report'
    };
    try {
        const pdfBlob = createMonthlyReportPDF(type, period);
        const url = URL.createObjectURL(pdfBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${names[type] || 'Report'} (${period.slug}).pdf`;
        link.click();
        window.setTimeout(() => URL.revokeObjectURL(url), 1000);
        toast(`${names[type] || 'Report'} downloaded.`, 'success');
    } catch (error) {
        console.error('Could not download PDF report:', error);
        toast(error.message || 'Could not create this PDF report.', 'error');
    }
}

/* ========== INIT ========== */
document.addEventListener('DOMContentLoaded', () => {
    document.addEventListener('click', event => {
        if (!event.target.closest('.admin-account-menu-wrap')) closeAdminAccountMenu();
        if (!event.target.closest('.report-actions-menu')) closeReportActionsMenus();
    });
    document.addEventListener('keydown', event => {
        if (event.key === 'Escape') {
            closeAdminAccountMenu();
            closeReportActionsMenus();
        }
    });
    // Demo data is only created for offline mode. Supabase-backed dashboards
    // should start from the database instead of presenting fake records.
    if (!window.ironGrindSupabase) {
    if (!localStorage.getItem('ig_members')) {
        saveDB('members', [
            { id: 'M001', name: 'Juan Dela Cruz', plan: 'Monthly', startDate: '2025-03-15', expiry: '2025-04-15', status: 'active', paid: true, goal: 'Muscle Gain', contact: '09171234567' },
            { id: 'M002', name: 'Maria Santos', plan: 'Monthly', startDate: '2025-04-03', expiry: '2025-05-03', status: 'active', paid: true, goal: 'Weight Loss', contact: '09171234568' },
            { id: 'M003', name: 'Pedro Reyes', plan: 'Walk-in', startDate: '2025-04-08', expiry: '2025-04-08', status: 'active', paid: false, goal: 'General Fitness', contact: '09171234569' },
            { id: 'M004', name: 'Ana Lopez', plan: 'Monthly', startDate: '2025-04-02', expiry: '2025-05-02', status: 'active', paid: true, goal: 'Strength', contact: '09171234570' },
            { id: 'M005', name: 'Mark Villanueva', plan: 'Half Month', startDate: '2025-04-05', expiry: '2025-04-20', status: 'active', paid: true, goal: 'Endurance', contact: '09171234571' }
        ]);
    }
    if (!localStorage.getItem('ig_products')) {
        saveDB('products', [
            { id: 'P001', name: 'Whey Protein — Chocolate', category: 'Supplement', price: 2450, stock: 3, stockUnit: 'kilogram', size: '' },
            { id: 'P002', name: 'Creatine Monohydrate', category: 'Supplement', price: 1200, stock: 2, stockUnit: 'kilogram', size: '' },
            { id: 'P003', name: 'Pre-Workout — Fruit Punch', category: 'Supplement', price: 1850, stock: 4, stockUnit: 'kilogram', size: '' },
            { id: 'P004', name: 'Multivitamins', category: 'Supplement', price: 850, stock: 24, stockUnit: 'kilogram', size: '' },
            { id: 'P005', name: 'IronGrind Shirt', category: 'Merch', merchType: 'apparel', price: 650, stock: 1, stockUnit: 'item', size: 'Large' },
            { id: 'P006', name: 'IronGrind Shirt', category: 'Merch', merchType: 'apparel', price: 650, stock: 12, stockUnit: 'item', size: 'Medium' },
            { id: 'P007', name: 'IronGrind Shirt', category: 'Merch', merchType: 'apparel', price: 650, stock: 8, stockUnit: 'item', size: 'Small' }
        ]);
    }
    if (!localStorage.getItem('ig_sales')) {
        saveDB('sales', [
            { id: 'IG-1042', customer: 'Maria Santos', items: 'Whey Protein x1', total: 2450, date: todayStr(), status: 'Paid' },
            { id: 'IG-1041', customer: 'Walk-in — Carlo M.', items: 'Shirt (L) + Vitamins', total: 1500, date: todayStr(), status: 'Paid' },
            { id: 'IG-1040', customer: 'Juan Dela Cruz', items: 'Pre-Workout x1', total: 1850, date: todayStr(), status: 'Paid' }
        ]);
    }
    if (!localStorage.getItem('ig_attendance')) {
        saveDB('attendance', [
            { id: 'A1', memberId: 'M001', memberName: 'Juan Dela Cruz', date: todayStr(), timeIn: '06:12', timeOut: '07:45' },
            { id: 'A2', memberId: 'M002', memberName: 'Maria Santos', date: todayStr(), timeIn: '07:05', timeOut: '08:30' },
            { id: 'A3', memberId: 'M003', memberName: 'Pedro Reyes', date: todayStr(), timeIn: '08:15', timeOut: null },
            { id: 'A4', memberId: 'M004', memberName: 'Ana Lopez', date: todayStr(), timeIn: '08:45', timeOut: null }
        ]);
    }
    if (!localStorage.getItem('ig_pendingApprovals')) saveDB('pendingApprovals', []);
    if (!localStorage.getItem('ig_users')) saveDB('users', []);
    }

    if (window.ironGrindSupabase) {
        members = [];
        products = [];
        archivedProducts = [];
        sales = [];
        attendance = [];
        pendingApprovals = [];
        users = [];
        planArchives = [];
        membershipArchives = [];
    } else {
        members = loadDB('members');
        products = loadDB('products').filter(product => product.isActive !== false);
        archivedProducts = loadDB('archivedProducts');
        sales = loadDB('sales');
        attendance = loadDB('attendance');
        pendingApprovals = loadDB('pendingApprovals');
        users = loadDB('users').map(({ password, ...safeUser }) => safeUser);
        saveDB('users', users);
        planArchives = loadDB('planArchives');
        membershipArchives = loadDB('membershipArchives');
        captureExpiredMemberships();

        renderDashboard();
        renderMembers();
        renderApprovals();
        renderAttendance();
        renderSales();
        renderReports();
    }
    initializeSupabaseAdminData();

    if (activeDashboardRole === 'admin') window.setInterval(() => {
        captureExpiredMemberships();
        renderMembers();
    }, 60 * 1000);

});

window.addEventListener('load', () => {
    window.setTimeout(() => {
        if (document.body.classList.contains('admin-auth-verified')) {
            document.getElementById('page-loader')?.classList.add('hidden-loader');
        }
    }, 2500);
});
