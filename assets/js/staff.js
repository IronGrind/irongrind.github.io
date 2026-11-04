const staffClient = window.ironGrindSupabase;
const staffStatus = document.getElementById('staffStatus');
let staffUser;
let staffBusy = false;
let staffScanner;
let pendingStaffScan = null;
let staffProducts = [];
let staffSignaturePad;
let staffSaleBusy = false;

function setStaffView(view) {
    document.querySelectorAll('[data-staff-view]').forEach(button => {
        const active = button.dataset.staffView === view;
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-current', active ? 'page' : 'false');
    });
    document.querySelectorAll('.staff-view').forEach(panel => {
        panel.hidden = panel.id !== `staff${view[0].toUpperCase()}${view.slice(1)}View`;
    });
    if (view === 'walkin' && !staffSignaturePad) {
        requestAnimationFrame(() => { staffSignaturePad = initDigitalSignature('staffSignatureCanvas', 'clearStaffSignature'); });
    }
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

function updateStaffSaleSummary() {
    const product = staffProducts.find(item => item.id === document.getElementById('staffSaleProduct').value);
    const quantity = Number(document.getElementById('staffSaleQuantity').value) || 0;
    const unit = document.getElementById('staffSaleUnit').value;
    const factors = { gram: 1, kilogram: 1000, ounce: 28.349523125, pound: 453.59237, milliliter: 1, liter: 1000, fluid_ounce: 29.5735295625, item: 1, piece: 1, box: 1 };
    const total = product ? Number(product.price_per_unit) * quantity * (factors[unit] || 1) : 0;
    document.getElementById('staffSaleTotal').textContent = formatStaffPeso(total);
}

async function loadStaffProducts() {
    const select = document.getElementById('staffSaleProduct');
    const { data, error } = await staffClient.from('products')
        .select('id,name,category,price_per_unit,unit,stock_unit,stock,is_active')
        .eq('is_active', true).order('name');
    if (error) throw error;
    staffProducts = data || [];
    select.replaceChildren(new Option(staffProducts.length ? 'Select a product' : 'No active products available', ''));
    staffProducts.forEach(product => select.add(new Option(`${product.name} · ${formatStaffPeso(product.price_per_unit)} / ${product.stock_unit || product.unit}`, product.id)));
    updateStaffSaleUnits();
}

function updateStaffSaleUnits() {
    const product = staffProducts.find(item => item.id === document.getElementById('staffSaleProduct').value);
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
    const productId = document.getElementById('staffSaleProduct').value;
    const product = staffProducts.find(item => item.id === productId);
    if (!product) { status.textContent = 'Select an active product.'; return; }
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
    } catch (error) { staffScanner = null; staffStatus.textContent = `Could not open camera: ${error.message || error}`; }
};
document.getElementById('staffLogout').onclick = async () => {
    try {
        const { error } = await staffClient.rpc('admin_log_session_event', { p_event: 'sign_out_requested' });
        if (error) console.error('Could not record staff sign-out:', error);
    } catch (error) { console.error('Could not record staff sign-out:', error); }
    await staffClient.auth.signOut();
    localStorage.removeItem('irongrind_session'); sessionStorage.removeItem('irongrind_session');
    location.replace('index.html');
};
document.querySelectorAll('[data-staff-view]').forEach(button => button.addEventListener('click', () => setStaffView(button.dataset.staffView)));
document.getElementById('staffSaleProduct').addEventListener('change', updateStaffSaleUnits);
document.getElementById('staffSaleQuantity').addEventListener('input', updateStaffSaleSummary);
document.getElementById('staffSaleUnit').addEventListener('change', updateStaffSaleSummary);
document.getElementById('staffSaleForm').addEventListener('submit', submitStaffProductSale);
document.getElementById('refreshStaffSales').addEventListener('click', async () => {
    const status = document.getElementById('staffSalesStatus'); status.textContent = 'Refreshing…';
    try { await Promise.all([loadStaffProducts(), refreshStaffProductSales()]); status.textContent = ''; }
    catch (error) { status.textContent = error.message; }
});
document.getElementById('staffWalkinForm').addEventListener('submit', submitStaffWalkin);
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
    } catch (error) { staffStatus.textContent = error.message; }
})();
