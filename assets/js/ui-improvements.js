// Shared form guidance, product pricing presentation, and accessible photo viewer.
(() => {
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
    window.newPasswordValid = (value, minimum = 8) => typeof value === 'string' && value.length >= minimum && value.length <= 128 && /[A-Za-z]/.test(value) && /[0-9]/.test(value);
    window.newPasswordMessage = minimum => `Use ${minimum}–128 characters, including at least one letter and one number.`;

    const passwordFields = { regPassword: 6, wiPassword: 6, walkinPassword: 6, staffPassword: 12, newPassword: 8, settingsPassword: 8 };
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
        function update() {
            const value = input.value;
            if (minimum) {
                input.minLength = minimum;
                const valid = window.newPasswordValid(value, minimum);
                input.setCustomValidity(value && !valid ? window.newPasswordMessage(minimum) : '');
                hint.textContent = !value ? window.newPasswordMessage(minimum) : valid ? 'Password meets the letter, number, and length requirements.' : window.newPasswordMessage(minimum);
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
    function enhance(root = document) {
        root.querySelectorAll('input').forEach(attachPasswordGuidance);
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
            viewer.setAttribute('aria-label', 'Product photo preview');
            viewer.innerHTML = '<div class="photo-viewer-toolbar"><label>Zoom <input type="range" min="50" max="250" value="100" step="10" aria-label="Photo zoom"></label><output>100%</output><button type="button" class="btn-sm">Close photo</button></div><div class="photo-viewer-stage"><img alt=""></div>';
            document.body.append(viewer);
            const slider = viewer.querySelector('input'); const photo = viewer.querySelector('img');
            const stage = viewer.querySelector('.photo-viewer-stage');
            let drag;
            slider.addEventListener('input', () => { photo.style.transform = `scale(${Number(slider.value) / 100})`; photo.dataset.panX = '0'; photo.dataset.panY = '0'; viewer.querySelector('output').textContent = `${slider.value}%`; });
            stage.addEventListener('pointerdown', event => {
                if (Number(slider.value) <= 100) return;
                event.preventDefault(); stage.setPointerCapture(event.pointerId);
                drag = { x: event.clientX, y: event.clientY, panX: Number(photo.dataset.panX || 0), panY: Number(photo.dataset.panY || 0) };
            });
            stage.addEventListener('pointermove', event => {
                if (!drag) return;
                const zoom = Number(slider.value) / 100;
                const maxX = (zoom - 1) * stage.clientWidth / 2;
                const maxY = (zoom - 1) * stage.clientHeight / 2;
                const x = Math.max(-maxX, Math.min(maxX, drag.panX + event.clientX - drag.x));
                const y = Math.max(-maxY, Math.min(maxY, drag.panY + event.clientY - drag.y));
                photo.dataset.panX = String(x); photo.dataset.panY = String(y);
                photo.style.transform = `translate(${x}px, ${y}px) scale(${zoom})`;
            });
            stage.addEventListener('pointerup', () => { drag = null; });
            stage.addEventListener('pointercancel', () => { drag = null; });
            viewer.querySelector('button').addEventListener('click', () => viewer.close());
            viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });
        }
        const photo = viewer.querySelector('img'); photo.src = img.currentSrc || img.src; photo.alt = img.alt || 'Product photo';
        photo.dataset.panX = '0'; photo.dataset.panY = '0';
        photo.style.transform = 'scale(1)'; viewer.querySelector('input').value = '100'; viewer.querySelector('output').textContent = '100%';
        img.focus({ preventScroll: true });
        viewer.showModal();
    }
    const targetPhoto = target => target.closest?.('img[data-zoom-ready]');
    document.addEventListener('click', event => { const img = targetPhoto(event.target); if (img) { event.preventDefault(); openPhoto(img); } });
    document.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { const img = targetPhoto(event.target); if (img) { event.preventDefault(); openPhoto(img); } } });
    enhance();
    new MutationObserver(() => enhance()).observe(document.body, { childList: true, subtree: true });
})();
