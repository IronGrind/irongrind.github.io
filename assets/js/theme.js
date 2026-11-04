(() => {
    const preferenceKey = 'ig_dashboard_theme';
    let preference = 'dark';
    try { preference = localStorage.getItem(preferenceKey) || localStorage.getItem('ig_admin_theme') || 'dark'; } catch {}

    function applyTheme(theme) {
        const selectedTheme = theme === 'light' ? 'light' : 'dark';
        document.documentElement.dataset.dashboardTheme = selectedTheme;
        // Keep the old admin attribute in sync for existing admin theme rules.
        document.documentElement.dataset.adminTheme = selectedTheme;
        try {
            localStorage.setItem(preferenceKey, selectedTheme);
            localStorage.setItem('ig_admin_theme', selectedTheme);
        } catch {}
        document.querySelectorAll('[data-dashboard-theme-option]').forEach(button => {
            button.setAttribute('aria-checked', String(button.dataset.dashboardThemeOption === selectedTheme));
        });
        document.querySelectorAll('[data-login-theme-toggle]').forEach(button => {
            const nextTheme = selectedTheme === 'light' ? 'dark' : 'light';
            button.setAttribute('aria-label', `Switch to ${nextTheme} mode`);
            button.setAttribute('title', `Switch to ${nextTheme} mode`);
            button.innerHTML = `<i class="fas fa-${nextTheme === 'light' ? 'sun' : 'moon'}" aria-hidden="true"></i>`;
        });
    }

    window.setDashboardTheme = applyTheme;
    window.toggleDashboardTheme = () => applyTheme(document.documentElement.dataset.dashboardTheme === 'light' ? 'dark' : 'light');
    applyTheme(preference);
    document.addEventListener('DOMContentLoaded', () => applyTheme(preference));

    window.toggleStaffAccountMenu = event => {
        event?.stopPropagation();
        const menu = document.getElementById('staffAccountMenu');
        const button = document.getElementById('staffMenuButton');
        if (!menu || !button) return;
        menu.hidden = !menu.hidden;
        button.setAttribute('aria-expanded', String(!menu.hidden));
    };
    window.closeStaffAccountMenu = () => {
        const menu = document.getElementById('staffAccountMenu');
        const button = document.getElementById('staffMenuButton');
        if (menu) menu.hidden = true;
        button?.setAttribute('aria-expanded', 'false');
    };
    document.addEventListener('click', event => {
        if (!event.target.closest('.staff-account-menu-wrap')) window.closeStaffAccountMenu();
    });
    document.addEventListener('keydown', event => {
        if (event.key === 'Escape') window.closeStaffAccountMenu();
    });
})();
