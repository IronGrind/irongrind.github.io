// Keep loading feedback on the control that started the action.
(() => {
    const pendingLinks = new Map();
    document.addEventListener('click', event => {
        const link = event.target.closest('a[href]');
        if (!link || event.defaultPrevented || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey
            || link.hasAttribute('download') || (link.target && link.target !== '_self')) return;
        const destination = new URL(link.href, location.href);
        if (destination.origin !== location.origin || !/\.html$/.test(destination.pathname)) return;
        event.preventDefault();
        if (pendingLinks.has(link)) { event.preventDefault(); return; }
        pendingLinks.set(link, link.innerHTML);
        const label = /register/i.test(destination.pathname) ? 'Opening registration…' : 'Opening sign in…';
        link.innerHTML = '<i class="fas fa-spinner fa-spin" aria-hidden="true"></i> ' + label;
        link.classList.add('action-loading');
        link.setAttribute('aria-busy', 'true');
        // Keep navigation feedback visible even when the destination is cached.
        window.setTimeout(() => {
            window.location.assign(destination.href);
        }, 450);
    });
    window.addEventListener('pageshow', () => {
        pendingLinks.forEach((html, link) => {
            link.innerHTML = html;
            link.classList.remove('action-loading');
            link.removeAttribute('aria-busy');
        });
        pendingLinks.clear();
    });
    const updateButton = button => {
        const busy = button.disabled && Boolean(button.querySelector('.fa-spinner'));
        button.classList.toggle('action-loading', busy);
        if (busy) button.setAttribute('aria-busy', 'true');
        else button.removeAttribute('aria-busy');
    };
    const observer = new MutationObserver(records => {
        const buttons = new Set();
        records.forEach(record => {
            const button = record.target.closest?.('button');
            if (button) buttons.add(button);
        });
        buttons.forEach(updateButton);
    });
    observer.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['disabled'] });
    document.querySelectorAll('button').forEach(updateButton);
})();
