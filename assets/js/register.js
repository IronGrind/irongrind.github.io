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
function loadDB(key) {
    try { return JSON.parse(localStorage.getItem('ig_' + key)) || []; }
    catch { return []; }
}

function saveDB(key, data) { localStorage.setItem('ig_' + key, JSON.stringify(data)); }
function composeRegistrationName() {
    return ['regFirstName', 'regMiddleName', 'regLastName']
        .map(id => document.getElementById(id).value.trim()).filter(Boolean).join(' ');
}
function validPersonName(value) {
    const name = String(value || '').trim();
    return name.length > 0 && name.length <= 150 && /\p{L}/u.test(name) && !/[\p{N}\p{Cc}\p{Cf}]/u.test(name);
}
function phLocalToStored(value) {
    const digits = String(value || '').replace(/\D/g, '');
    return /^9\d{9}$/.test(digits) ? `0${digits}` : '';
}
function toggleRegPassword(inputId, iconId) {
    const input = document.getElementById(inputId);
    const icon = document.getElementById(iconId);
    if (input.type === 'password') { input.type = 'text'; icon.classList.replace('fa-eye', 'fa-eye-slash'); }
    else { input.type = 'password'; icon.classList.replace('fa-eye-slash', 'fa-eye'); }
}
function showError(msg) {
    document.getElementById('regErrorText').textContent = msg;
    document.getElementById('regError').classList.remove('hidden');
    window.scrollTo({ top: document.getElementById('regError').offsetTop - 100, behavior: 'smooth' });
}
function hideError() { document.getElementById('regError').classList.add('hidden'); }
function openModal(html) {
    document.getElementById('modalContent').innerHTML = html;
    document.getElementById('modalOverlay').classList.remove('hidden');
}
function closeModal() { document.getElementById('modalOverlay').classList.add('hidden'); }

const registrationSignature = initDigitalSignature('registrationSignature', 'clearRegistrationSignature');

const phoneInputs = [document.getElementById('regMobile'), document.getElementById('regEcContact')];
phoneInputs.forEach(input => {
    input.addEventListener('input', function() {
        const digits = this.value.replace(/\D/g, '');
        this.value = digits && !digits.startsWith('9') ? '' : digits.slice(0, 10);
        this.setCustomValidity(this.value && !/^9\d{9}$/.test(this.value) ? 'Enter 10 digits beginning with 9 after +63.' : '');
    });
});

const registrationHeight = document.getElementById('regHeight');
const registrationHeightUnit = document.getElementById('regHeightUnit');
let previousHeightUnit = registrationHeightUnit.value;
registrationHeightUnit.addEventListener('change', function() {
    const nextUnit = this.value;
    const enteredHeight = Number(registrationHeight.value);
    if (registrationHeight.value && Number.isFinite(enteredHeight) && enteredHeight > 0 && previousHeightUnit !== nextUnit) {
        const convertedHeight = previousHeightUnit === 'cm' ? enteredHeight / 30.48 : enteredHeight * 30.48;
        registrationHeight.value = String(Number(convertedHeight.toFixed(2)));
    }
    previousHeightUnit = nextUnit;
});

document.getElementById('regDob').addEventListener('change', function() {
    const dob = new Date(this.value);
    if (isNaN(dob)) return;
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const m = today.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
    document.getElementById('regAge').value = age >= 0 ? age : '';
});

const otherMedicalChoice = document.getElementById('otherMedicalChoice');
const otherMedicalDetailsGroup = document.getElementById('otherMedicalDetailsGroup');
const otherMedicalDetailsInput = document.getElementById('otherMedicalDetails');

function updateOtherMedicalDetails() {
    const hasOtherCondition = otherMedicalChoice.checked;
    otherMedicalDetailsGroup.classList.toggle('hidden', !hasOtherCondition);
    otherMedicalDetailsInput.required = hasOtherCondition;
    if (!hasOtherCondition) otherMedicalDetailsInput.value = '';
}

otherMedicalChoice.addEventListener('change', updateOtherMedicalDetails);
updateOtherMedicalDetails();

function updateDatesFromPlan() {
    const plan = document.querySelector('input[name="regPlan"]:checked');
    if (!plan) return;
    const name = plan.value.split('|')[0];
    const start = todayStr();
    let days = name === 'Monthly' ? 30 : name === 'Half Month' ? 15 : 1;
    document.getElementById('regStartDate').value = start;
    document.getElementById('regEndDate').value = addDays(start, days);
}
document.querySelectorAll('input[name="regPlan"]').forEach(r => r.addEventListener('change', updateDatesFromPlan));

async function submitRegistration(event) {
    event.preventDefault();
    hideError();

    const fullName = composeRegistrationName();
    const dob = document.getElementById('regDob').value;
    const age = Number(document.getElementById('regAge').value);
    const sex = document.getElementById('regSex').value;
    const mobileLocal = document.getElementById('regMobile').value.replace(/\D/g, '');
    const mobile = phLocalToStored(mobileLocal);
    const height = document.getElementById('regHeight').value;
    const heightUnit = height ? document.getElementById('regHeightUnit').value : null;
    const weight = document.getElementById('regWeight').value;
    const ecName = document.getElementById('regEcName').value.trim();
    const ecRelation = document.getElementById('regEcRelation').value.trim();
    const ecContactLocal = document.getElementById('regEcContact').value.replace(/\D/g, '');
    const ecContact = phLocalToStored(ecContactLocal);

    const planInput = document.querySelector('input[name="regPlan"]:checked');
    if (!planInput) { showError('Please select a membership plan.'); return; }
    const [planName, planPrice] = planInput.value.split('|');
    const startDate = document.getElementById('regStartDate').value || todayStr();
    let endDate = document.getElementById('regEndDate').value;
    if (!endDate) {
        const days = planName === 'Monthly' ? 30 : planName === 'Half Month' ? 15 : 1;
        endDate = addDays(startDate, days);
    }

    const healthConditions = [];
    if (document.getElementById('hcHighBp').checked) healthConditions.push('High Blood Pressure');
    if (document.getElementById('hcHeart').checked) healthConditions.push('Heart Condition');
    if (document.getElementById('hcAsthma').checked) healthConditions.push('Asthma');
    if (document.getElementById('hcInjury').checked) healthConditions.push('Recent Injury');
    const otherMedicalConditions = otherMedicalChoice.checked ? otherMedicalDetailsInput.value.trim() : '';

    const goals = Array.from(document.querySelectorAll('input[name="goal"]:checked')).map(g => g.value);

    if (!document.getElementById('agreeRules').checked) { showError('You must agree to the Rules and Agreement.'); return; }
    if (!document.getElementById('agreeWaiver').checked) { showError('You must accept the Liability Waiver.'); return; }
    if (otherMedicalChoice.checked && !otherMedicalConditions) { showError('Please specify your other medical condition details.'); return; }
    if (!registrationSignature || registrationSignature.isEmpty()) { showError('Please add your digital signature.'); return; }

    const email = document.getElementById('regEmail').value.trim().toLowerCase();
    const password = document.getElementById('regPassword').value;
    const confirm = document.getElementById('regConfirmPassword').value;

    if (!fullName || !dob || !mobile) { showError('Please complete all required personal information.'); return; }
    const nameFields = ['regFirstName', 'regMiddleName', 'regLastName'].map(id => document.getElementById(id).value.trim()).filter(Boolean);
    if (!validPersonName(fullName) || nameFields.some(name => !validPersonName(name)) || !validPersonName(ecName)) {
        showError('Names must contain letters and cannot contain numbers. Please check the member and emergency contact names.');
        return;
    }
    if (!/^9\d{9}$/.test(mobileLocal)) { showError('Enter the 10 digits after +63, beginning with 9.'); return; }
    if (age < 12) { showError('You must be at least 12 years old to register.'); return; }
    if (!ecName || !ecRelation || !ecContact) { showError('Please complete the emergency contact details.'); return; }
    if (!/^9\d{9}$/.test(ecContactLocal)) { showError('Enter the emergency contact’s 10 digits after +63, beginning with 9.'); return; }
    if (email.length > 254) { showError('Email address must be 254 characters or fewer.'); return; }
    if (!email || !document.getElementById('regEmail').checkValidity()) { showError('Enter a valid email address for your account.'); return; }
    if (!newPasswordValid(password, 8)) { showError(newPasswordMessage(8)); return; }
    if (password !== confirm) { showError('Passwords do not match.'); return; }

    const application = {
        id: null,
        fullName, dob, age, sex, mobile,
        height: height ? Number(height) : null,
        heightUnit,
        weight: weight ? Number(weight) : null,
        emergencyContact: { name: ecName, relationship: ecRelation, contact: ecContact },
        plan: planName, planPrice: Number(planPrice),
        startDate, endDate,
        healthConditions, otherMedicalConditions, goals,
        signature: registrationSignature.toDataURL(),
        email,
        submittedAt: new Date().toISOString(),
        status: 'pending'
    };

    const submitButton = document.querySelector('#registrationForm button[type="submit"]');
    if (submitButton.disabled) return;
    submitButton.disabled = true;
    submitButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating account…';
    try {
        const { data: emailAvailable, error: emailCheckError } = await window.ironGrindSupabase.rpc('is_registration_email_available', { p_email: email });
        if (emailCheckError) { showError('Could not check this email address. Please try again.'); return; }
        if (!emailAvailable) {
            await resumeExistingAccountRegistration(email, password, application);
            return;
        }
        const { data, error } = await window.ironGrindSupabase.functions.invoke('member-registration', {
            body: { email, password, application, acceptedRules: true, acceptedWaiver: true }
        });
        if (error || !data?.applicationId) {
            let details = data;
            try { if (error?.context) details = await error.context.json(); } catch { /* Keep the generic response when no JSON body is available. */ }
            if (details?.code === 'EMAIL_IN_USE') {
                await resumeExistingAccountRegistration(email, password, application);
                return;
            }
            showError(details?.error || 'The application could not be submitted. No account should have been kept; try again or contact gym staff.');
            return;
        }
        application.id = data.applicationId;
        application.submittedAt = new Date().toISOString();
        localStorage.removeItem('ig_registration_draft');
        showSuccessModal(application, true, false, true);
    } catch (error) {
        console.error('Registration submission failed:', error);
        showError('Could not connect to the registration service. Please try again.');
    } finally {
        submitButton.disabled = false;
        submitButton.innerHTML = '<i class="fas fa-paper-plane"></i> Submit Membership Application';
    }
}

async function resumeExistingAccountRegistration(email, password, application) {
    const client = window.ironGrindSupabase;
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error || !data.session || !data.user) {
        const notConfirmed = error?.code === 'email_not_confirmed' || /email not confirmed/i.test(error?.message || '');
        if (notConfirmed) {
            const draft = { userId: null, application, savedAt: Date.now() };
            try { localStorage.setItem('ig_registration_draft', JSON.stringify(draft)); }
            catch { showError('This browser could not save your application. Enable browser storage and try again.'); return; }
            const { error: resendError } = await client.auth.resend({
                type: 'signup',
                email,
                options: { emailRedirectTo: 'https://irongrind-github-io.vercel.app/register.html?completeApplication=1' }
            });
            if (resendError) {
                console.error('Could not resend registration confirmation:', resendError);
                showError('This account still needs email confirmation, but a new confirmation link could not be sent. Try again later or contact gym staff.');
                return;
            }
            showSuccessModal(application, true);
            return;
        }
        showError('An account already uses this email. Enter its existing password, use Forgot Password, or contact gym staff if you never completed the earlier signup.');
        return;
    }

    const { error: sessionError } = await client.rpc('activate_account_session');
    if (sessionError) {
        console.error('Could not activate existing registration session:', sessionError);
        showError('We could not securely open this account to complete its application. Please sign in again or contact gym staff.');
        return;
    }
    const userId = data.user.id;
    const [{ data: member, error: memberError }, { data: prior, error: priorError }] = await Promise.all([
        client.from('members').select('id').eq('auth_user_id', userId).maybeSingle(),
        client.from('membership_applications').select('id, status').eq('auth_user_id', userId)
            .eq('application_type', 'registration').in('status', ['pending', 'approved'])
            .order('submitted_at', { ascending: false }).limit(1).maybeSingle()
    ]);
    if (memberError || priorError) {
        await client.auth.signOut({ scope: 'local' });
        console.error('Could not check existing registration records:', memberError || priorError);
        showError('We could not check this account’s membership records. Please contact gym staff.');
        return;
    }
    if (member || prior) {
        await client.auth.signOut({ scope: 'local' });
        showError(member
            ? 'This account already has a gym membership. Sign in to your member account or contact gym staff for help.'
            : `A ${prior.status} application is already on file for this account. Contact gym staff to check its status.`);
        return;
    }

    application.email = email;
    application.submittedAt = new Date().toISOString();
    const draft = { userId, application, savedAt: Date.now() };
    try { localStorage.setItem('ig_registration_draft', JSON.stringify(draft)); }
    catch {
        await client.auth.signOut({ scope: 'local' });
        showError('This browser could not save your application. Enable browser storage and try again.');
        return;
    }
    if (await insertSupabaseApplication(draft)) showSuccessModal(application, false);
}

async function insertSupabaseApplication(draft) {
    const app = draft.application;
    const emergency = app.emergencyContact || {};
    const userId = draft.userId;
    const row = {
        auth_user_id: userId,
        member_id: null,
        application_type: 'registration',
        full_name: app.fullName,
        email: app.email,
        mobile: app.mobile,
        date_of_birth: app.dob,
        age: app.age,
        sex: app.sex,
        height: app.height,
        height_unit: app.heightUnit,
        weight_kg: app.weight,
        emergency_contact_data: emergency,
        plan: app.plan,
        plan_price: app.planPrice,
        start_date: app.startDate,
        end_date: app.endDate,
        fitness_goals: app.goals,
        health_conditions: app.healthConditions,
        other_medical_conditions: app.otherMedicalConditions,
        signature_path: app.signature,
        status: 'pending',
        submitted_at: app.submittedAt,
        reviewed_at: null,
        reviewed_by: null
    };
    const { data, error } = await window.ironGrindSupabase
        .from('membership_applications')
        .insert(row)
        .select('id, status, auth_user_id')
        .single();

    if (error || !data?.id || data.auth_user_id !== userId || data.status !== 'pending') {
        console.error('Application save failed:', error);
        showError('Your account was created, but we could not submit your application. Your form is saved in this browser. Please try again or contact the gym for help.');
        return false;
    }
    app.id = data.id;
    localStorage.removeItem('ig_registration_draft');
    return true;
}

async function completeConfirmedRegistration() {
    let draft;
    try { draft = JSON.parse(localStorage.getItem('ig_registration_draft') || 'null'); }
    catch { draft = null; }
    if (draft && Date.now() - draft.savedAt > 24 * 60 * 60 * 1000) {
        localStorage.removeItem('ig_registration_draft');
        draft = null;
    }
    if (new URLSearchParams(window.location.search).get('completeApplication') !== '1') return;
    const { data: { session }, error } = await window.ironGrindSupabase.auth.getSession();
    if (!draft && session && !error) {
        const { error: activationError } = await window.ironGrindSupabase.rpc('activate_account_session');
        if (activationError) {
            showError('Your email is confirmed, but we could not securely check your application. Sign in and contact gym staff if needed.');
            return;
        }
        const { data: submitted, error: lookupError } = await window.ironGrindSupabase
            .from('membership_applications').select('id, full_name, email, plan, plan_price, status')
            .eq('auth_user_id', session.user.id).eq('application_type', 'registration')
            .order('submitted_at', { ascending: false }).limit(1).maybeSingle();
        if (lookupError || !submitted) {
            showError(lookupError
                ? 'Your email is confirmed, but we could not load the application status. Contact gym staff.'
                : 'Your email is confirmed, but no application is on file. Return to the registration form or contact gym staff.');
            return;
        }
        showSuccessModal(submitted, false, true, true);
        return;
    }
    if (!draft) {
        showError('Your email confirmation did not open a signed-in session. Return to sign in or request a new confirmation email.');
        return;
    }
    const callbackEmail = String(session?.user?.email || '').trim().toLowerCase();
    if (error || !session || (draft.userId && session.user.id !== draft.userId)
        || (!draft.userId && callbackEmail !== String(draft.application?.email || '').trim().toLowerCase())) {
        showError('Your registration could not be completed in this browser. Sign in with your email and password to try submitting the saved application again. If it is still missing, contact the gym admin.');
        return;
    }
    draft.userId = session.user.id;
    const { error: activationError } = await window.ironGrindSupabase.rpc('activate_account_session');
    if (activationError) {
        console.error('Could not activate confirmed registration session:', activationError);
        showError('Your email is confirmed, but we could not securely submit the application. Sign in and try again.');
        return;
    }
    if (await insertSupabaseApplication(draft)) showSuccessModal(draft.application, false, true);
}

document.addEventListener('DOMContentLoaded', completeConfirmedRegistration);

function showSuccessModal(app, confirmationRequired = false, emailJustConfirmed = false, applicationAlreadySubmitted = false) {
    openModal(`
        <div style="text-align:center; padding:8px 0;">
            <div style="width:72px; height:72px; border-radius:50%; background:rgba(46,204,113,0.15); color:#2ecc71; display:flex; align-items:center; justify-content:center; font-size:2rem; margin:0 auto 16px;">
                <i class="fas fa-check-circle"></i>
            </div>
            <h3 style="justify-content:center; display:flex;"><i class="fas ${confirmationRequired ? 'fa-envelope' : 'fa-check-circle'}"></i> ${confirmationRequired ? 'Confirm Your Email' : 'Application Submitted!'}</h3>
            <p class="modal-sub" style="text-align:center;">${confirmationRequired
                ? applicationAlreadySubmitted
                    ? `Your application has been received, ${app.fullName}, and is waiting for gym review. Confirm your email before signing in.`
                    : `Your account was created, ${app.fullName}. Confirm your email to submit your application for staff or administrator review.`
                : emailJustConfirmed
                    ? `Your application has been sent to the gym for review, ${app.fullName}, and is awaiting approval.`
                    : `Thank you, <strong>${app.fullName}</strong>. Your application is now pending staff or administrator approval.`}</p>
            <div class="registration-summary">
                ${confirmationRequired && !applicationAlreadySubmitted ? '' : `<div style="display:flex; justify-content:space-between; margin-bottom:8px;"><span style="color:#8b95a9;">Application ID:</span><code style="color:#ff6b2b;">${app.id}</code></div>`}
                <div style="display:flex; justify-content:space-between; margin-bottom:8px;"><span style="color:#8b95a9;">Plan:</span><strong>${app.plan}</strong></div>
                <div style="display:flex; justify-content:space-between; margin-bottom:8px;"><span style="color:#8b95a9;">Amount:</span><strong>₱${app.planPrice.toLocaleString()}</strong></div>
                <div style="display:flex; justify-content:space-between; margin-bottom:8px;"><span style="color:#8b95a9;">Email:</span><strong>${app.email}</strong></div>
                <div style="display:flex; justify-content:space-between;"><span style="color:#8b95a9;">Status:</span><span class="badge-status reserved">${confirmationRequired && !applicationAlreadySubmitted ? 'Confirm email first' : 'Pending review'}</span></div>
            </div>
            <div style="background:rgba(255,107,43,0.08); border:1px solid rgba(255,107,43,0.25); border-radius:14px; padding:14px; font-size:0.8rem; color:#8b95a9; text-align:left; margin-top:16px;">
                <i class="fas fa-info-circle" style="color:#ff6b2b;"></i>
                ${confirmationRequired
                    ? applicationAlreadySubmitted
                        ? 'Your application is already in the gym review queue. Confirm your email to activate sign-in, then wait for staff or administrator review.'
                        : 'Check your email and confirm your account. Return to this browser after confirmation to finish submitting your application. Your form is saved here temporarily; your password is not stored.'
                    : emailJustConfirmed
                        ? 'Authorized staff or the administrator must approve your registration before you can access the member portal. Contact the gym if you need to follow up.'
                        : 'Visit the gym to complete your payment. Once approved, sign in with your email and password.'}
            </div>
        </div>
        <div class="modal-actions">
            <a href="index.html" class="btn-primary" style="text-decoration:none; justify-content:center; padding:12px;">Go to Login</a>
        </div>
    `);
}
