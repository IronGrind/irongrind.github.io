const staffClient = window.ironGrindSupabase;
const staffStatus = document.getElementById('staffStatus');
let staffUser;
let staffBusy = false;
let staffAttendanceRefreshing = false;
let staffLoaderDelayComplete = false;
let staffLoaderStartupComplete = false;
let staffScanner;
let pendingStaffScan = null;
let staffProducts = [];
let staffProductGroups = [];
let staffSignaturePad;
let staffSaleBusy = false;
let staffSelectedRenewalMember = null;
let staffSelectedPlanChangeMember = null;

function hideStaffLoaderWhenReady() {
    if (staffLoaderDelayComplete && staffLoaderStartupComplete) {
        document.getElementById('page-loader')?.classList.add('hidden-loader');
    }
}

function startStaffLoaderMinimumDuration() {
    window.setTimeout(() => {
        staffLoaderDelayComplete = true;
        hideStaffLoaderWhenReady();
    }, 2500);
}

if (document.readyState === 'complete') startStaffLoaderMinimumDuration();
else window.addEventListener('load', startStaffLoaderMinimumDuration, { once: true });

function setStaffView(view) {
    if (view === 'requests') loadStaffRequests();
    document.querySelectorAll('[data-staff-view]').forEach(button => {
        const active = button.dataset.staffView === view;
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-current', active ? 'page' : 'false');
    });
    document.querySelectorAll('.staff-view').forEach(panel => {
        panel.hidden = panel.id !== `staff${view[0].toUpperCase()}${view.slice(1)}View`;
    });
    if (view === 'membership' && !staffSignaturePad && !document.getElementById('staffMembershipAddPane').hidden) {
        requestAnimationFrame(() => {
            if (!staffSignaturePad && !document.getElementById('staffMembershipAddPane').hidden) {
                staffSignaturePad = initDigitalSignature('staffSignatureCanvas', 'clearStaffSignature');
            }
        });
    }
}

function setStaffMembershipAction(action) {
    document.querySelectorAll('[data-staff-membership-action]').forEach(button => {
        const active = button.dataset.staffMembershipAction === action;
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-current', active ? 'page' : 'false');
    });
    document.querySelectorAll('.staff-membership-pane').forEach(pane => {
        pane.hidden = pane.id !== ({ add: 'staffMembershipAddPane', renewal: 'staffRenewalPane', change: 'staffChangePlanPane' })[action];
    });
    if (action === 'add' && !staffSignaturePad) {
        requestAnimationFrame(() => {
            if (!staffSignaturePad && !document.getElementById('staffMembershipAddPane').hidden) {
                staffSignaturePad = initDigitalSignature('staffSignatureCanvas', 'clearStaffSignature');
            }
        });
    }
}

async function searchStaffMembers(query, resultsId, selectedId, onSelect, activeOnly = false) {
    const results = document.getElementById(resultsId);
    const selected = document.getElementById(selectedId);
    selected.hidden = true;
    selected.replaceChildren();
    onSelect(null);
    const normalized = query.trim();
    if (normalized.length < 2) { results.textContent = 'Enter at least 2 characters to search.'; return; }
    results.textContent = 'Searching members...';
    const rpcName = activeOnly ? 'staff_search_active_members' : 'staff_search_members';
    const { data, error } = await staffClient.rpc(rpcName, { p_query: normalized });
    if (error) { results.textContent = error.message; return; }
    results.replaceChildren();
    if (!data?.length) { results.textContent = 'No members found for this search.'; return; }
    data.forEach(member => {
        const button = document.createElement('button'); button.type = 'button'; button.className = 'staff-member-result';
        const details = document.createElement('span');
        const name = document.createElement('strong'); name.textContent = member.full_name;
        const meta = document.createElement('small'); meta.textContent = `${member.plan || 'No plan'} · ${member.email || 'No Gmail'} · Expires ${member.expiry_date || 'not set'}`;
        details.append(name, meta);
        const status = document.createElement('span'); status.className = `staff-member-status ${String(member.status || '').toLowerCase()}`; status.textContent = member.status || 'Unknown';
        button.append(details, status);
        button.addEventListener('click', () => {
            onSelect(member);
            const selected = document.getElementById(selectedId); selected.replaceChildren(); selected.hidden = false;
            const title = document.createElement('strong'); title.textContent = member.full_name;
            const info = document.createElement('span'); info.textContent = `${member.plan || 'No plan'} · ${formatStaffPeso(member.plan_price)} · Expires ${member.expiry_date || 'not set'}`;
            selected.append(title, info);
            results.querySelectorAll('.staff-member-result').forEach(item => item.classList.toggle('is-selected', item === button));
        });
        results.append(button);
    });
}

async function submitStaffMembershipChange(eventType) {
    const isRenewal = eventType === 'renewal';
    const member = isRenewal ? staffSelectedRenewalMember : staffSelectedPlanChangeMember;
    const status = document.getElementById(isRenewal ? 'staffRenewalStatus' : 'staffChangeStatus');
    const select = document.getElementById(isRenewal ? 'staffRenewalPlan' : 'staffChangePlan');
    if (!member) { status.textContent = 'Search for and select a member first.'; return; }
    const [plan, priceText, daysText] = select.value.split('|');
    const start = new Date(); start.setHours(0, 0, 0, 0);
    const expiry = new Date(start); expiry.setDate(expiry.getDate() + Number(daysText));
    const receipt = `IG-${isRenewal ? 'SR' : 'SC'}-${crypto.randomUUID().replaceAll('-', '').slice(0, 16).toUpperCase()}`;
    status.textContent = isRenewal ? 'Recording renewal payment...' : 'Saving membership plan change...';
    const button = document.getElementById(isRenewal ? 'staffRenewMembership' : 'staffSavePlanChange'); button.disabled = true;
    try {
        const { data, error } = await staffClient.rpc('admin_record_membership_change', {
            p_member_id: member.id,
            p_event_type: eventType,
            p_new_plan: plan,
            p_new_price: Number(priceText),
            p_new_start_date: localDateString(start),
            p_new_expiry_date: localDateString(expiry),
            p_customer_name: member.full_name,
            p_mobile: member.mobile,
            p_receipt_number: receipt,
        });
        if (error) throw error;
        status.textContent = isRenewal
            ? `${member.full_name}'s membership renewed through ${data.expiry_date}.`
            : `${member.full_name}'s plan changed to ${plan}.`;
        if (isRenewal) staffSelectedRenewalMember = null; else staffSelectedPlanChangeMember = null;
        document.getElementById(isRenewal ? 'staffRenewalSelected' : 'staffChangeSelected').hidden = true;
        document.getElementById(isRenewal ? 'staffRenewalResults' : 'staffChangeResults').replaceChildren();
        document.getElementById(isRenewal ? 'staffRenewalSearch' : 'staffChangeSearch').value = '';
    } catch (error) { status.textContent = error.message || 'Could not save the membership transaction.'; }
    finally { button.disabled = false; }
}

function staffSaleUnits(product) {
    const unit = product.unit || 'item';
    if (unit === 'gram') return [['gram', 'g'], ['kilogram', 'kg'], ['ounce', 'oz'], ['pound', 'lb']];
    if (unit === 'milliliter') return [['milliliter', 'ml'], ['liter', 'L'], ['fluid_ounce', 'fl oz']];
    if (unit === 'piece') return [['piece', 'pcs']];
    if (unit === 'box') return [['box', 'boxes']];
    return [['item', 'item']];
}

function formatStaffPeso(value) {
    return new Intl.NumberFormat('en-PH', { style: 'currency', currency: 'PHP' }).format(Number(value || 0));
}

function staffProductAvailable(product) { return Number(product.stock || 0) > 0; }

function groupStaffProducts(products) {
    const groups = new Map();
    products.forEach(product => {
        const isMerch = product.category === 'merchandise';
        const key = isMerch ? `merch:${product.name.trim().toLowerCase()}` : `supplement:${product.id}`;
        if (!groups.has(key)) groups.set(key, { key, name: product.name, category: product.category, variants: [] });
        groups.get(key).variants.push(product);
    });
    const preferredSizes = ['XS', 'Small', 'Medium', 'Large', 'XL', 'XXL', 'XXXL', 'One Size'];
    return [...groups.values()].map(group => {
        group.variants.sort((a, b) => {
            const left = preferredSizes.indexOf(a.size || 'One Size');
            const right = preferredSizes.indexOf(b.size || 'One Size');
            if (left >= 0 || right >= 0) return (left < 0 ? 99 : left) - (right < 0 ? 99 : right);
            return String(a.size || '').localeCompare(String(b.size || ''));
        });
        return group;
    }).sort((a, b) => a.category.localeCompare(b.category) || a.name.localeCompare(b.name));
}

function renderStaffProductCatalog() {
    const target = document.getElementById('staffProductCatalog');
    target.replaceChildren();
    for (const [category, heading] of [['supplement', 'Supplements'], ['merchandise', 'Merchandise']]) {
        const items = staffProductGroups.filter(group => group.category === category);
        const section = document.createElement('section'); section.className = 'staff-catalog-section';
        const title = document.createElement('div'); title.className = 'staff-catalog-section-title';
        const label = document.createElement('h4'); label.textContent = heading;
        const count = document.createElement('span'); count.textContent = `${items.length} ${items.length === 1 ? 'item' : 'items'}`;
        title.append(label, count); section.append(title);
        const grid = document.createElement('div'); grid.className = 'staff-product-grid';
        if (!items.length) {
            const empty = document.createElement('p'); empty.className = 'staff-empty-catalog'; empty.textContent = `No ${heading.toLowerCase()} are listed.`; grid.append(empty);
        }
        items.forEach(group => group.variants.forEach(product => {
            const available = staffProductAvailable(product);
            const card = document.createElement('article'); card.className = `staff-product-card ${available ? 'is-available' : 'is-unavailable'}`;
            const top = document.createElement('div'); top.className = 'staff-product-card-top';
            const icon = document.createElement('span'); icon.className = 'staff-product-icon'; icon.innerHTML = category === 'supplement' ? '<i class="fas fa-capsules" aria-hidden="true"></i>' : '<i class="fas fa-shirt" aria-hidden="true"></i>';
            const badge = document.createElement('span'); badge.className = `staff-stock-badge ${available ? 'available' : 'unavailable'}`; badge.textContent = available ? 'Available' : 'Unavailable';
            const imageSource = catalogProductPhoto(product);
            if (imageSource) { const photo = document.createElement('img'); photo.className = 'staff-product-photo'; photo.src = imageSource; photo.alt = product.name; photo.loading = 'lazy'; card.append(photo); }
            top.append(icon, badge);
            const name = document.createElement('h5'); name.textContent = group.name;
            const details = document.createElement('p'); details.textContent = category === 'merchandise' ? `Size: ${product.size || 'One size'}` : 'Supplement';
            const bottom = document.createElement('div'); bottom.className = 'staff-product-card-bottom';
            const price = document.createElement('strong'); price.textContent = `${formatStaffPeso(productPriceQuote(product.price_per_unit, product.unit).amount)} / ${productPriceQuote(product.price_per_unit, product.unit).quantity} ${productPriceQuote(product.price_per_unit, product.unit).unit}`;
            const stock = document.createElement('span'); stock.textContent = `${product.stock ?? 0} ${product.stock_unit || product.unit} in stock`;
            bottom.append(price, stock); card.append(top, name, details, bottom); grid.append(card);
        }));
        section.append(grid); target.append(section);
    }
}

function updateStaffSaleSummary() {
    const product = getSelectedStaffSaleProduct();
    const quantity = Number(document.getElementById('staffSaleQuantity').value) || 0;
    const unit = document.getElementById('staffSaleUnit').value;
    const factors = { gram: 1, kilogram: 1000, ounce: 28.349523125, pound: 453.59237, milliliter: 1, liter: 1000, fluid_ounce: 29.5735295625, item: 1, piece: 1, box: 1 };
    const total = product ? Number(product.price_per_unit) * quantity * (factors[unit] || 1) : 0;
    document.getElementById('staffSaleTotal').textContent = formatStaffPeso(total);
}

async function loadStaffProducts() {
    const select = document.getElementById('staffSaleProduct');
    const { data, error } = await staffClient.from('products')
        .select('id,name,category,size,price_per_unit,unit,stock_unit,stock,is_active,image_path')
        .eq('is_active', true).order('name');
    if (error) throw error;
    staffProducts = data || [];
    staffProductGroups = groupStaffProducts(staffProducts);
    renderStaffProductCatalog();
    select.replaceChildren(new Option(staffProductGroups.length ? 'Select a product' : 'No active products available', ''));
    staffProductGroups.forEach(group => {
        const available = group.variants.some(staffProductAvailable);
        const option = new Option(`${group.category === 'supplement' ? 'Supplement' : 'Merchandise'} - ${group.name}${available ? '' : ' - Unavailable'}`, group.key);
        option.disabled = !available;
        select.add(option);
    });
    updateStaffSaleUnits();
}

function getSelectedStaffSaleProduct() {
    const group = staffProductGroups.find(item => item.key === document.getElementById('staffSaleProduct').value);
    if (!group) return null;
    if (group.category === 'merchandise') {
        const selectedId = document.getElementById('staffSaleSize').value;
        return group.variants.find(product => product.id === selectedId) || null;
    }
    return group.variants[0] || null;
}

function updateStaffSaleUnits() {
    const group = staffProductGroups.find(item => item.key === document.getElementById('staffSaleProduct').value);
    const sizeGroup = document.getElementById('staffSaleSizeGroup');
    const sizeSelect = document.getElementById('staffSaleSize');
    sizeSelect.replaceChildren();
    sizeGroup.hidden = !group || group.category !== 'merchandise';
    if (group?.category === 'merchandise') {
        group.variants.forEach(product => {
            const available = staffProductAvailable(product);
            const label = `${product.size || 'One size'} - ${formatStaffPeso(product.price_per_unit)}${available ? ` - ${product.stock} in stock` : ' - Unavailable'}`;
            const option = new Option(label, product.id); option.disabled = !available; sizeSelect.add(option);
        });
        const firstAvailable = [...sizeSelect.options].find(option => !option.disabled);
        if (firstAvailable) sizeSelect.value = firstAvailable.value;
    }
    const product = group?.category === 'merchandise'
        ? group.variants.find(item => item.id === sizeSelect.value)
        : group?.variants[0];
    const unitSelect = document.getElementById('staffSaleUnit');
    unitSelect.replaceChildren();
    (product ? staffSaleUnits(product) : []).forEach(([value, label]) => unitSelect.add(new Option(label, value)));
    updateStaffSaleSummary();
}

async function refreshStaffProductSales() {
    const { data, error } = await staffClient.rpc('staff_list_own_product_sales');
    if (error) throw error;
    const target = document.getElementById('staffSalesHistory');
    target.replaceChildren();
    if (!data?.length) { const empty = document.createElement('p'); empty.className = 'staff-help'; empty.textContent = 'No product sales recorded yet.'; target.append(empty); return; }
    data.forEach(sale => {
        const card = document.createElement('article'); card.className = 'staff-sale-record';
        const heading = document.createElement('div'); heading.className = 'staff-sale-record-heading';
        const name = document.createElement('strong'); name.textContent = sale.customer_name;
        const total = document.createElement('strong'); total.textContent = formatStaffPeso(sale.total);
        heading.append(name, total);
        const detail = document.createElement('p'); detail.textContent = (sale.items || []).map(item => `${item.item_name} · ${item.quantity} ${item.unit}`).join(', ');
        const meta = document.createElement('small'); meta.textContent = `${sale.receipt_number} · ${new Date(sale.sold_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`;
        card.append(heading, detail, meta); target.append(card);
    });
}

async function submitStaffProductSale(event) {
    event.preventDefault();
    if (staffSaleBusy) return;
    const status = document.getElementById('staffSalesStatus');
    const product = getSelectedStaffSaleProduct();
    if (!product || !staffProductAvailable(product)) { status.textContent = 'Choose an available product and size.'; return; }
    const quantity = Number(document.getElementById('staffSaleQuantity').value);
    staffSaleBusy = true;
    const button = document.getElementById('staffCompleteSale'); button.disabled = true;
    status.textContent = 'Recording sale…';
    try {
        const receipt = `IG-ST-${crypto.randomUUID().replaceAll('-', '').slice(0, 16).toUpperCase()}`;
        const { data, error } = await staffClient.rpc('record_walk_in_sale', {
            p_receipt_number: receipt,
            p_customer_name: document.getElementById('staffSaleCustomer').value.trim(),
            p_product_id: product.id,
            p_quantity: quantity,
            p_quantity_unit: document.getElementById('staffSaleUnit').value,
        });
        if (error) throw error;
        status.textContent = `Sale completed · ${data.receipt_number} · ${formatStaffPeso(data.total)}`;
        document.getElementById('staffSaleForm').reset();
        document.getElementById('staffSaleQuantity').value = '1';
        await Promise.all([loadStaffProducts(), refreshStaffProductSales()]);
    } catch (error) { status.textContent = error.message || 'Could not complete the sale.'; }
    finally { staffSaleBusy = false; button.disabled = false; }
}

function localDateString(date) {
    const year = date.getFullYear(); const month = String(date.getMonth() + 1).padStart(2, '0'); const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

async function submitStaffWalkin(event) {
    event.preventDefault();
    const status = document.getElementById('staffWalkinStatus');
    const button = document.getElementById('createWalkinMember');
    if (!staffSignaturePad || staffSignaturePad.isEmpty()) { status.textContent = 'The member signature is required.'; return; }
    const [plan, priceText, daysText] = document.getElementById('walkinPlan').value.split('|');
    const price = Number(priceText); const days = Number(daysText);
    const start = new Date(); start.setHours(0, 0, 0, 0);
    const expiry = new Date(start); expiry.setDate(expiry.getDate() + days);
    const birthDate = document.getElementById('walkinBirthDate').value;
    const today = new Date(); let age = today.getFullYear() - new Date(`${birthDate}T00:00:00`).getFullYear();
    const birthday = new Date(`${birthDate}T00:00:00`); if (today < new Date(today.getFullYear(), birthday.getMonth(), birthday.getDate())) age--;
    const body = {
        fullName: document.getElementById('walkinFullName').value.trim(),
        email: document.getElementById('walkinEmail').value.trim(),
        username: document.getElementById('walkinUsername').value.trim(),
        password: document.getElementById('walkinPassword').value,
        mobile: document.getElementById('walkinMobile').value.trim(),
        dateOfBirth: birthDate, age, sex: document.getElementById('walkinSex').value,
        emergencyName: document.getElementById('walkinEmergencyName').value.trim(),
        emergencyRelationship: document.getElementById('walkinEmergencyRelationship').value.trim(),
        emergencyContact: document.getElementById('walkinEmergencyPhone').value.trim(),
        plan, planPrice: price, startDate: localDateString(start), expiryDate: localDateString(expiry),
        signatureData: staffSignaturePad.toDataURL(), fitnessGoals: [], healthConditions: [],
        staffWalkinRegistration: true,
    };
    button.disabled = true; status.textContent = 'Creating member account and recording payment…';
    try {
        if (!newPasswordValid(body.password, 8)) throw new Error(newPasswordMessage(8));
        if (body.password !== document.getElementById('walkinConfirmPassword').value) throw new Error('Passwords do not match.');
        const { data, error } = await staffClient.functions.invoke('admin-create-member', { body });
        if (error) {
            const detail = error.context?.json ? await error.context.json().catch(() => null) : null;
            throw new Error(detail?.error || error.message);
        }
        status.textContent = `Member registered and paid · ${data.full_name} · receipt ${data.receipt_number}`;
        document.getElementById('staffWalkinForm').reset();
        staffSignaturePad.clear();
    } catch (error) { status.textContent = error.message || 'Could not register the walk-in member.'; }
    finally { button.disabled = false; }
}
async function refreshStaffAttendance() {
    if (staffAttendanceRefreshing || !staffUser) return;
    staffAttendanceRefreshing = true;
    try {
        const { data, error } = await staffClient.rpc('staff_list_attendance');
        if (error) throw error;
        const rows = document.getElementById('staffAttendanceRows');
        rows.replaceChildren();
        if (!data?.length) {
            const row = rows.insertRow();
            const cell = row.insertCell();
            cell.colSpan = 3;
            cell.textContent = 'No attendance records yet.';
        }
        for (const visit of data || []) {
            const row = document.createElement('tr');
            for (const [index, value] of [visit.member_name, visit.time_in, visit.time_out].entries()) {
                const cell = document.createElement('td');
                cell.textContent = index === 0 ? value || 'Unknown member' : value
                    ? new Date(value).toLocaleString('en-PH', { timeZone: 'Asia/Manila', month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })
                    : 'Still checked in';
                if (index === 2 && !value) cell.classList.add('staff-visit-open');
                row.append(cell);
            }
            rows.append(row);
        }
    } finally {
        staffAttendanceRefreshing = false;
    }
}
async function recordStaffAttendance(value) {
    if (staffBusy || !staffUser) return;
    staffBusy = true;
    try {
        const identifier = value.trim();
        if (pendingStaffScan && pendingStaffScan.identifier !== identifier) throw new Error('Retry the previous member scan first to confirm its result.');
        pendingStaffScan ||= { identifier, requestId: crypto.randomUUID() };
        const { data, error } = await staffClient.rpc('record_attendance_scan', {
            p_identifier: identifier, p_request_id: pendingStaffScan.requestId
        });
        if (error) { if (error.code) pendingStaffScan = null; throw error; }
        pendingStaffScan = null;
        staffStatus.textContent = data.member_name + (data.action === 'duplicate' ? ' was already scanned just now.' : data.action === 'check_out' ? ' checked out.' : ' checked in.');
        document.getElementById('staffIdentifier').value = '';
        await refreshStaffAttendance();
    } catch (error) { staffStatus.textContent = error.message; }
    finally { staffBusy = false; }
}
document.getElementById('staffScanForm').addEventListener('submit', event => { event.preventDefault(); recordStaffAttendance(document.getElementById('staffIdentifier').value); });
document.getElementById('refreshStaffAttendance').onclick = () => refreshStaffAttendance().catch(error => { staffStatus.textContent = error.message; });
document.getElementById('startStaffCamera').onclick = async () => {
    if (!staffUser || staffScanner || staffBusy) return;
    try {
        staffScanner = new Html5Qrcode('staffCamera');
        await staffScanner.start({ facingMode: 'environment' }, { fps: 10, qrbox: 250 }, async value => {
            if (!staffScanner || staffBusy) return;
            const scanner = staffScanner;
            staffScanner = null;
            staffBusy = true;
            try { await scanner.stop(); } finally { staffBusy = false; }
            await recordStaffAttendance(value);
        }, () => {});
    } catch (error) {
        staffScanner = null;
        console.warn('Staff QR camera could not start:', error);
        const message = ['NotAllowedError', 'PermissionDeniedError', 'SecurityError'].includes(error?.name)
            ? 'Camera access is off. Allow camera access in your browser settings, then try again.'
            : error?.name === 'NotFoundError'
                ? 'No camera was found on this device. You can enter the member code below instead.'
                : 'The camera is unavailable right now. You can enter the member code below instead.';
        staffStatus.textContent = message;
    }
};
document.getElementById('staffLogout').onclick = async () => {
    try {
        const { error } = await staffClient.rpc('admin_log_session_event', { p_event: 'sign_out_requested' });
        if (error) console.error('Could not record staff sign-out:', error);
    } catch (error) { console.error('Could not record staff sign-out:', error); }
    await staffClient.auth.signOut({ scope: 'local' });
    localStorage.removeItem('irongrind_session'); sessionStorage.removeItem('irongrind_session');
    location.replace('index.html');
};
document.querySelectorAll('[data-staff-view]').forEach(button => button.addEventListener('click', () => setStaffView(button.dataset.staffView)));
document.querySelectorAll('[data-staff-membership-action]').forEach(button => button.addEventListener('click', () => setStaffMembershipAction(button.dataset.staffMembershipAction)));
document.getElementById('staffRenewalSearchButton').addEventListener('click', () => searchStaffMembers(
    document.getElementById('staffRenewalSearch').value, 'staffRenewalResults', 'staffRenewalSelected', member => { staffSelectedRenewalMember = member; }
));
document.getElementById('staffChangeSearchButton').addEventListener('click', () => searchStaffMembers(
    document.getElementById('staffChangeSearch').value, 'staffChangeResults', 'staffChangeSelected', member => { staffSelectedPlanChangeMember = member; }, true
));
document.getElementById('staffRenewalSearch').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); document.getElementById('staffRenewalSearchButton').click(); } });
document.getElementById('staffChangeSearch').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); document.getElementById('staffChangeSearchButton').click(); } });
document.getElementById('staffRenewMembership').addEventListener('click', () => submitStaffMembershipChange('renewal'));
document.getElementById('staffSavePlanChange').addEventListener('click', () => submitStaffMembershipChange('plan_change'));
async function loadStaffRequests() {
    const list = document.getElementById('staffRequestList');
    const status = document.getElementById('staffRequestsStatus');
    status.textContent = 'Loading requests...';
    try {
        const { data, error } = await staffClient.rpc('staff_pending_membership_requests');
        if (error) throw error;
        list.replaceChildren();
        for (const request of data || []) {
            const card = document.createElement('article'); card.className = 'staff-request-card';
            const heading = document.createElement('h3'); heading.textContent = request.full_name;
            const details = document.createElement('p');
            details.textContent = `${request.application_type === 'renewal' ? 'Renewal' : 'Registration'} · ${request.plan} · ${formatStaffPeso(request.plan_price)}`;
            const date = document.createElement('small'); date.textContent = `Submitted ${new Date(request.submitted_at).toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`;
            const actions = document.createElement('div'); actions.className = 'staff-form-actions';
            for (const [decision, label] of [['approved', 'Approve'], ['rejected', 'Reject']]) {
                const button = document.createElement('button'); button.type = 'button';
                button.className = decision === 'approved' ? 'btn-primary' : 'btn-logout'; button.textContent = label;
                button.addEventListener('click', async () => {
                    const prompt = decision === 'approved'
                        ? `Approve ${request.full_name}'s ${request.application_type} for ${formatStaffPeso(request.plan_price)}? Confirm their in-person payment has been received.`
                        : `Reject ${request.full_name}'s ${request.application_type} request?`;
                    if (!window.confirm(prompt)) return;
                    actions.querySelectorAll('button').forEach(b => { b.disabled = true; });
                    try {
                        const { error } = await staffClient.rpc('review_membership_request', { p_application_id: request.id, p_decision: decision });
                        if (error) throw error;
                        await loadStaffRequests();
                        status.textContent = `Request ${decision}.`;
                    } catch (error) {
                        status.textContent = error.message || 'Could not review the request.';
                        actions.querySelectorAll('button').forEach(b => { b.disabled = false; });
                    }
                });
                actions.append(button);
            }
            card.append(heading, details, date, actions); list.append(card);
        }
        status.textContent = data?.length ? `${data.length} pending request(s).` : 'No pending requests.';
    } catch (error) { status.textContent = `Could not load requests: ${error.message}`; }
}
document.getElementById('refreshStaffRequests').addEventListener('click', loadStaffRequests);

document.getElementById('staffSaleProduct').addEventListener('change', updateStaffSaleUnits);
document.getElementById('staffSaleSize').addEventListener('change', updateStaffSaleSummary);
document.getElementById('staffSaleQuantity').addEventListener('input', updateStaffSaleSummary);
document.getElementById('staffSaleUnit').addEventListener('change', updateStaffSaleSummary);
document.getElementById('staffSaleForm').addEventListener('submit', submitStaffProductSale);
document.getElementById('refreshStaffSales').addEventListener('click', async () => {
    const status = document.getElementById('staffSalesStatus'); status.textContent = 'Refreshing…';
    try { await Promise.all([loadStaffProducts(), refreshStaffProductSales()]); status.textContent = ''; }
    catch (error) { status.textContent = error.message; }
});
document.getElementById('staffWalkinForm').addEventListener('submit', submitStaffWalkin);
window.setInterval(() => {
    if (!staffUser || document.hidden || staffBusy) return;
    refreshStaffAttendance().catch(error => console.warn('Could not refresh staff attendance:', error));
}, 30000);
document.addEventListener('visibilitychange', () => {
    if (staffUser && !document.hidden) {
        refreshStaffAttendance().catch(error => console.warn('Could not refresh staff attendance:', error));
    }
});
(async () => {
    try {
        const { data: { user }, error } = await staffClient.auth.getUser();
        if (error || !user) return location.replace('index.html');
        const { data: profile, error: profileError } = await staffClient.from('profiles').select('role,is_active,full_name').eq('id', user.id).single();
        if (profileError || profile?.role !== 'staff' || !profile.is_active) return location.replace('index.html');
        staffUser = user;
        document.getElementById('staffIdentity').textContent = profile.full_name;
        const results = await Promise.allSettled([refreshStaffAttendance(), loadStaffProducts(), refreshStaffProductSales()]);
        if (results[0].status === 'rejected') staffStatus.textContent = results[0].reason.message;
        if (results[1].status === 'rejected') document.getElementById('staffSalesStatus').textContent = results[1].reason.message;
        if (results[2].status === 'rejected') document.getElementById('staffSalesHistory').textContent = results[2].reason.message;
        staffLoaderStartupComplete = true;
        hideStaffLoaderWhenReady();
    } catch (error) {
        staffStatus.textContent = error.message;
        staffLoaderStartupComplete = true;
        hideStaffLoaderWhenReady();
    }
})();
