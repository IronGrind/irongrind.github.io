// Shared form guidance, product pricing presentation, and accessible photo viewer.
(() => {
    window.attendanceVisitIncomplete = (timeIn, timeOut, now = new Date()) => {
        if (timeOut || !timeIn) return false;
        const dateKey = value => {
            if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
            const date = new Date(value);
            if (Number.isNaN(date.getTime())) return '';
            const parts = new Intl.DateTimeFormat('en', { timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
            return ['year', 'month', 'day'].map(type => parts.find(p => p.type === type).value).join('-');
        };
        const checkInDate = dateKey(timeIn), today = dateKey(now);
        return Boolean(checkInDate && today && checkInDate < today);
    };
    // Curated replacements for the five products whose cutouts were supplied.
    // Require both product family and flavor so unrelated catalog items keep their photos.
    window.catalogProductPhoto = product => {
        const name = String(product?.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
        let asset = '';
        if (name.includes('bcaa')) {
            if (name.includes('fruitpunch')) asset = 'bcaa-fruit-punch';
            else if (name.includes('peachmango')) asset = 'bcaa-peach-mango';
        } else if (name.includes('roar')) {
            if (name.includes('fruitpunch')) asset = 'roar-fruit-punch';
            else if (name.includes('peachmango')) asset = 'roar-peach-mango';
        } else if (name.includes('whey') && name.includes('strawberry') && !name.includes('iso')) {
            asset = 'whey-strawberry';
        }
        return asset ? `assets/images/products/transparent/${asset}.png` : (product?.image || product?.image_path || '');
    };
    const quoteQuantity = unit => unit === 'gram' ? 10 : 1;
    const labels = { gram: 'g', milliliter: 'ml', item: 'item', piece: 'pc', box: 'box', kilogram: 'kg', liter: 'L', ounce: 'oz', pound: 'lb', fluid_ounce: 'fl oz' };
    window.productPriceQuote = (price, unit = 'item') => {
        const quantity = quoteQuantity(unit);
        return { amount: Math.round(Number(price) * quantity * 100) / 100, quantity, unit: labels[unit] || unit };
    };
    window.productUnitPrice = (amount, quantity, discrete = false) => {
        amount = Number(amount); quantity = Number(quantity);
        if (!Number.isFinite(amount) || amount <= 0 || !Number.isFinite(quantity) || quantity <= 0 || (discrete && !Number.isInteger(quantity))) return null;
        const raw = amount / quantity;
        const rounded = Math.round((raw + Number.EPSILON) * 100) / 100;
        // The database currently stores unit prices with two decimal places.
        if (rounded <= 0 || Math.abs(raw - rounded) > 0.0000001) return null;
        return rounded;
    };
    window.newPasswordValid = (value, minimum = 8) => typeof value === 'string' && value.length >= Math.max(8, minimum) && value.length <= 128 && /[a-z]/.test(value) && /[A-Z]/.test(value) && /[0-9]/.test(value) && /[^A-Za-z0-9\s]/.test(value);
    window.newPasswordMessage = minimum => `Use ${Math.max(8, minimum)}–128 characters with uppercase and lowercase letters, a number, and a symbol.`;
    window.passwordStrength = (value, minimum = 8) => {
        if (!value) return { label: 'Not entered', score: 0 };
        const score = [value.length >= Math.max(8, minimum), /[a-z]/.test(value), /[A-Z]/.test(value), /[0-9]/.test(value), /[^A-Za-z0-9\s]/.test(value)].filter(Boolean).length;
        return { label: window.newPasswordValid(value, minimum) ? 'Strong' : score >= 4 ? 'Fair' : 'Weak', score };
    };

    const passwordFields = { regPassword: 8, wiPassword: 8, walkinPassword: 8, staffPassword: 12, newPassword: 8, settingsPassword: 8 };
    const confirmationFields = { regConfirmPassword: 'regPassword', wiConfirmPassword: 'wiPassword', walkinConfirmPassword: 'walkinPassword', staffConfirmPassword: 'staffPassword', confirmPassword: 'newPassword', settingsPasswordConfirm: 'settingsPassword' };
    function attachPasswordGuidance(input) {
        if (input.dataset.passwordGuidance) return;
        const minimum = passwordFields[input.id];
        if (!minimum && !confirmationFields[input.id]) return;
        input.dataset.passwordGuidance = 'true';
        const hint = document.createElement('small'); hint.className = 'password-guidance'; hint.id = `${input.id}Guidance`;
        hint.setAttribute('aria-live', 'polite');
        input.maxLength = 128;
        input.setAttribute('aria-describedby', [input.getAttribute('aria-describedby'), hint.id].filter(Boolean).join(' '));
        const wrapper = input.closest('.password-wrapper') || input;
        wrapper.insertAdjacentElement('afterend', hint);
        const meter = minimum ? document.createElement('meter') : null;
        if (meter) {
            meter.className = 'password-strength-meter'; meter.min = 0; meter.max = 5; meter.low = 3; meter.high = 5; meter.optimum = 5;
            meter.setAttribute('aria-label', 'Password strength');
            hint.insertAdjacentElement('beforebegin', meter);
        }
        function update() {
            const value = input.value;
            if (minimum) {
                input.minLength = minimum;
                const valid = window.newPasswordValid(value, minimum);
                input.setCustomValidity(value && !valid ? window.newPasswordMessage(minimum) : '');
                const strength = window.passwordStrength(value, minimum);
                meter.value = valid ? 5 : Math.min(4, strength.score);
                meter.setAttribute('aria-valuetext', strength.label);
                hint.textContent = !value ? window.newPasswordMessage(minimum) : `${strength.label} password. ${valid ? 'Password requirements met.' : window.newPasswordMessage(minimum)}`;
                hint.dataset.state = !value ? 'neutral' : valid ? 'valid' : 'invalid';
            } else {
                const original = document.getElementById(confirmationFields[input.id]);
                const matches = Boolean(value && original && value === original.value);
                input.setCustomValidity(value && !matches ? 'Passwords do not match.' : '');
                hint.textContent = !value ? 'Enter the same password again.' : matches ? 'Passwords match.' : 'Passwords do not match.';
                hint.dataset.state = !value ? 'neutral' : matches ? 'valid' : 'invalid';
            }
        }
        input.addEventListener('input', update);
        const original = document.getElementById(confirmationFields[input.id]);
        if (original) original.addEventListener('input', update);
        input.form?.addEventListener('reset', () => setTimeout(update));
        update();
    }
    function attachUsernameGuidance(input) {
        if (!['staffUsername', 'regEmail', 'wiEmail', 'walkinEmail', 'staffEmail'].includes(input.id) || input.dataset.usernameGuidance) return;
        const isEmail = input.id.endsWith('Email');
        const fieldName = isEmail ? 'Email address' : 'Username';
        input.dataset.usernameGuidance = 'true'; input.maxLength = isEmail ? 254 : 30;
        const hint = document.createElement('small'); hint.className = 'password-guidance'; hint.id = `${input.id}Availability`;
        hint.setAttribute('aria-live', 'polite'); input.insertAdjacentElement('afterend', hint);
        input.setAttribute('aria-describedby', [input.getAttribute('aria-describedby'), hint.id].filter(Boolean).join(' '));
        let timer; let revision = 0;
        input.addEventListener('input', () => {
            clearTimeout(timer); const current = ++revision;
            const username = input.value.trim().toLowerCase();
            input.setCustomValidity(''); hint.textContent = ''; hint.dataset.state = 'neutral';
            if (!username) return;
            const minimum = 3;
            const characters = input.id === 'staffUsername' ? 'a-z0-9_' : 'a-z0-9_.';
            if (isEmail ? !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(username) : !new RegExp(`^[${characters}]{${minimum},30}$`).test(username)) {
                const message = isEmail ? 'Enter a valid email address.' : `Use ${minimum}–30 letters, numbers, and underscores${input.id === 'staffUsername' ? '.' : ', or dots.'}`;
                input.setCustomValidity(message); hint.textContent = message; hint.dataset.state = 'invalid'; return;
            }
            hint.textContent = `Checking ${fieldName.toLowerCase()} availability...`;
            timer = setTimeout(async () => {
                try {
                    const { data, error } = await window.ironGrindSupabase.rpc(isEmail ? 'is_registration_email_available' : 'is_registration_username_available', isEmail ? { p_email: username } : { p_username: username });
                    if (current !== revision) return;
                    if (error) throw error;
                    const message = data ? `${fieldName} is available.` : isEmail ? 'This email is linked to an account or an earlier registration. Submit with that account’s password to continue, or return to sign in and use Forgot Password.' : 'That username is already in use. Choose another username.';
                    hint.textContent = message; hint.dataset.state = data ? 'valid' : 'invalid';
                    // Registration can resume an existing Auth account that
                    // has no application yet; let its submit flow authenticate
                    // and complete that application instead of blocking here.
                    input.setCustomValidity(data || input.id === 'regEmail' ? '' : message);
                } catch {
                    if (current !== revision) return;
                    hint.textContent = 'Could not check availability. Try again before submitting.'; hint.dataset.state = 'invalid';
                }
            }, 400);
        });
    }
    function attachPasswordVisibility(input) {
        if (input.type !== 'password' || input.dataset.visibilityReady) return;
        input.dataset.visibilityReady = 'true';
        let wrapper = input.closest('.password-wrapper');
        if (wrapper?.querySelector('.toggle-password')) return;
        if (!wrapper) {
            wrapper = document.createElement('div');
            wrapper.className = 'password-wrapper password-visibility-wrapper';
            input.parentNode.insertBefore(wrapper, input);
            wrapper.appendChild(input);
        }
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'toggle-password';
        if (input.id) button.setAttribute('aria-controls', input.id);
        function conceal() {
            input.type = 'password';
            button.setAttribute('aria-label', 'Show password');
            button.setAttribute('aria-pressed', 'false');
            button.innerHTML = '<i class="fas fa-eye" aria-hidden="true"></i>';
        }
        conceal();
        button.addEventListener('click', () => {
            if (input.type === 'text') conceal();
            else {
                input.type = 'text';
                button.setAttribute('aria-label', 'Hide password');
                button.setAttribute('aria-pressed', 'true');
                button.innerHTML = '<i class="fas fa-eye-slash" aria-hidden="true"></i>';
            }
        });
        input.form?.addEventListener('reset', conceal);
        wrapper.appendChild(button);
    }
    function enhance(root = document) {
        root.querySelectorAll('input[type="password"]').forEach(attachPasswordVisibility);
        root.querySelectorAll('input').forEach(attachPasswordGuidance);
        root.querySelectorAll('input').forEach(attachUsernameGuidance);
        root.querySelectorAll('.product-img-wrap img, .product-photo-preview img, .staff-product-photo').forEach(img => {
            if (img.dataset.zoomReady) return;
            img.dataset.zoomReady = 'true'; img.tabIndex = 0; img.setAttribute('role', 'button');
            img.setAttribute('aria-label', `Enlarge ${img.alt || 'product photo'}`);
            img.title = 'Click to enlarge';
        });
    }
    let viewer;
    function openPhoto(img) {
        if (!viewer) {
            viewer = document.createElement('dialog'); viewer.className = 'product-photo-dialog';
            viewer.setAttribute('aria-label', 'Product photo');
            viewer.innerHTML = `<div class="photo-lightbox">
                <header class="photo-lightbox-header"><div><span class="photo-lightbox-eyebrow">PRODUCT PHOTO</span><p class="photo-lightbox-title"></p></div><button type="button" class="photo-lightbox-close" aria-label="Close photo" title="Close (Esc)"><i class="fas fa-xmark" aria-hidden="true"></i></button></header>
                <div class="photo-viewer-stage"><img alt="" draggable="false"></div>
                <footer class="photo-lightbox-footer"><div class="photo-lightbox-controls" role="group" aria-label="Photo zoom"><button type="button" data-photo-action="out" aria-label="Zoom out"><i class="fas fa-minus" aria-hidden="true"></i></button><output aria-live="polite">100%</output><button type="button" data-photo-action="in" aria-label="Zoom in"><i class="fas fa-plus" aria-hidden="true"></i></button><span class="photo-control-divider" aria-hidden="true"></span><button type="button" data-photo-action="fit" class="photo-fit-button" aria-label="Fit full photo"><i class="fas fa-expand" aria-hidden="true"></i><span>Fit</span></button></div><p>Double-click to zoom · Drag to explore · Esc to close</p></footer>
            </div>`;
            document.body.append(viewer);
            const photo = viewer.querySelector('img');
            const stage = viewer.querySelector('.photo-viewer-stage');
            let zoom = 1, panX = 0, panY = 0, drag, moved = false;
            function paint() {
                photo.style.transform = `translate(${panX}px, ${panY}px) scale(${zoom})`;
                viewer.querySelector('output').textContent = `${Math.round(zoom * 100)}%`;
                viewer.querySelector('[data-photo-action="out"]').disabled = zoom <= 1;
                viewer.querySelector('[data-photo-action="in"]').disabled = zoom >= 3;
                stage.classList.toggle('is-zoomed', zoom > 1);
            }
            function setZoom(value) { zoom = Math.max(1, Math.min(3, value)); panX = 0; panY = 0; paint(); }
            viewer.resetPhoto = () => { drag = null; moved = false; setZoom(1); };
            viewer.querySelector('[data-photo-action="out"]').addEventListener('click', () => setZoom(zoom - .25));
            viewer.querySelector('[data-photo-action="in"]').addEventListener('click', () => setZoom(zoom + .25));
            viewer.querySelector('[data-photo-action="fit"]').addEventListener('click', () => setZoom(1));
            photo.addEventListener('dblclick', () => { if (!viewer.classList.contains('photo-bubble')) setZoom(zoom > 1 ? 1 : 2); });
            viewer.addEventListener('keydown', event => {
                if (viewer.classList.contains('photo-bubble')) return;
                if (event.key === '+' || event.key === '=') { event.preventDefault(); setZoom(zoom + .25); }
                if (event.key === '-') { event.preventDefault(); setZoom(zoom - .25); }
            });
            stage.addEventListener('pointerdown', event => {
                moved = false;
                if (zoom <= 1) return;
                event.preventDefault(); stage.setPointerCapture(event.pointerId);
                drag = { x: event.clientX, y: event.clientY, panX, panY };
            });
            stage.addEventListener('pointermove', event => {
                if (!drag) return;
                if (Math.abs(event.clientX - drag.x) + Math.abs(event.clientY - drag.y) > 5) moved = true;
                const maxX = Math.max(0, (photo.offsetWidth * zoom - stage.clientWidth) / 2);
                const maxY = Math.max(0, (photo.offsetHeight * zoom - stage.clientHeight) / 2);
                panX = Math.max(-maxX, Math.min(maxX, drag.panX + event.clientX - drag.x));
                panY = Math.max(-maxY, Math.min(maxY, drag.panY + event.clientY - drag.y));
                paint();
            });
            stage.addEventListener('pointerup', () => { drag = null; });
            stage.addEventListener('pointercancel', () => { drag = null; });
            viewer.querySelector('.photo-lightbox-close').addEventListener('click', () => viewer.close());
            stage.addEventListener('click', event => { if (event.target === stage && !moved) viewer.close(); });
            viewer.addEventListener('click', event => {
                if (event.target !== viewer) return;
                const bounds = viewer.getBoundingClientRect();
                if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) viewer.close();
            });
            viewer.addEventListener('close', () => document.body.classList.remove('photo-lightbox-open'));
        }
        viewer.classList.toggle('photo-bubble', document.body.classList.contains('member-dashboard'));
        const photo = viewer.querySelector('img'); photo.src = img.currentSrc || img.src; photo.alt = img.alt || 'Product photo';
        viewer.querySelector('.photo-lightbox-title').textContent = img.alt || 'Product photo';
        viewer.resetPhoto();
        img.focus({ preventScroll: true });
        document.body.classList.add('photo-lightbox-open');
        viewer.showModal();
    }
    const targetPhoto = target => target.closest?.('img[data-zoom-ready]');
    document.addEventListener('click', event => { const img = targetPhoto(event.target); if (img) { event.preventDefault(); openPhoto(img); } });
    document.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { const img = targetPhoto(event.target); if (img) { event.preventDefault(); openPhoto(img); } } });
    enhance();
    new MutationObserver(() => enhance()).observe(document.body, { childList: true, subtree: true });
})();
