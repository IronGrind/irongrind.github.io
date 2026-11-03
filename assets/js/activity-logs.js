// Read-only view of activity written by the database, not local browser history.
(() => {
    const pageSize = 50;
    let page = 0;
    let requestNumber = 0;
    const areas = { profiles: 'Accounts', members: 'Members', membership_applications: 'Applications', attendance: 'Attendance', products: 'Products', sales: 'Sales', sale_items: 'Sale items', membership_history: 'Membership history', session: 'Session' };
    const actions = { insert: 'Created', update: 'Updated', delete: 'Deleted', check_in: 'Checked in', check_out: 'Checked out', signed_in: 'Signed in', sign_out_requested: 'Requested sign-out', approved: 'Approved', rejected: 'Rejected', archived: 'Archived', restored: 'Restored', renewal: 'Renewed', expired: 'Expired', plan_change: 'Changed plan' };
    const escape = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
    const dateFormat = new Intl.DateTimeFormat('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' });

    window.loadActivityLogs = async (requestedPage = 0) => {
        const thisRequest = ++requestNumber;
        page = Math.max(0, requestedPage);
        const status = document.getElementById('activityStatus');
        const refresh = document.getElementById('activityRefresh');
        const previous = document.getElementById('activityPrevious');
        const next = document.getElementById('activityNext');
        const table = document.getElementById('activityTable');
        previous.disabled = next.disabled = refresh.disabled = true;
        refresh.setAttribute('aria-busy', 'true');
        refresh.innerHTML = '<i class="fas fa-spinner fa-spin" aria-hidden="true"></i> Loading';
        table.setAttribute('aria-busy', 'true');
        status.textContent = 'Loading activity…';
        try {
            const client = window.ironGrindSupabase;
            if (!client) throw new Error('Connect to Supabase to view activity logs.');
            const from = document.getElementById('activityFrom').value;
            const to = document.getElementById('activityTo').value;
            if (from && to && from > to) throw new Error('The From date must be on or before the To date.');
            let query = client.from('activity_logs').select('*', { count: 'exact' })
                .order('occurred_at', { ascending: false }).order('id', { ascending: false });
            const actor = document.getElementById('activityActor').value.trim();
            const area = document.getElementById('activityArea').value;
            if (actor) query = query.ilike('actor_name', `%${actor.replace(/[\\%_]/g, '\\$&')}%`);
            if (area) query = query.eq('entity_type', area);
            if (from) query = query.gte('occurred_at', `${from}T00:00:00+08:00`);
            if (to) {
                const end = new Date(`${to}T00:00:00+08:00`);
                end.setUTCDate(end.getUTCDate() + 1);
                query = query.lt('occurred_at', end.toISOString());
            }
            const { data, count, error } = await query.range(page * pageSize, (page + 1) * pageSize - 1);
            if (thisRequest !== requestNumber) return;
            if (error) {
                console.error('Could not load activity logs:', error);
                throw new Error(['42P01', 'PGRST205'].includes(error.code)
                    ? 'Activity logging needs setup. Apply the activity_logs migration in Supabase, then refresh.'
                    : 'Could not load activity logs. Check your admin session and connection, then refresh.');
            }
            table.innerHTML = data.length ? `<table class="attendance-table" role="table"><thead role="rowgroup"><tr role="row"><th role="columnheader">Time (Manila)</th><th role="columnheader">Account</th><th role="columnheader">Action</th><th role="columnheader">Area</th><th role="columnheader">Record</th><th role="columnheader">Fields changed</th></tr></thead><tbody role="rowgroup">${data.map(log => `<tr role="row">
                <td role="cell" data-label="Time (Manila)">${escape(dateFormat.format(new Date(log.occurred_at)))}</td>
                <td role="cell" data-label="Account"><strong>${escape(log.actor_name)}</strong><small>${escape(log.actor_role)}${log.actor_id ? ` · ${escape(log.actor_id)}` : ''}</small></td>
                <td role="cell" data-label="Action">${escape(actions[log.action] || log.action)}</td>
                <td role="cell" data-label="Area">${escape(areas[log.entity_type] || log.entity_type)}</td>
                <td role="cell" data-label="Record">${escape(log.record_label || '—')}<small>${escape(log.entity_id || '')}</small></td>
                <td role="cell" data-label="Fields changed">${escape((log.changed_fields || []).join(', ') || '—')}</td>
            </tr>`).join('')}</tbody></table>` : '<div class="empty-state">No activity matches these filters. Logs begin after activity logging is enabled.</div>';
            status.textContent = `${count || 0} events found. Record changes are captured automatically; sign-in and sign-out entries describe app activity.`;
            document.getElementById('activityPage').textContent = `Page ${page + 1} of ${Math.max(1, Math.ceil((count || 0) / pageSize))}`;
            previous.disabled = page === 0;
            next.disabled = (page + 1) * pageSize >= (count || 0);
        } catch (error) {
            if (thisRequest !== requestNumber) return;
            table.innerHTML = '';
            status.textContent = error.message || 'Could not load activity logs.';
            document.getElementById('activityPage').textContent = 'Page 1';
        } finally {
            if (thisRequest === requestNumber) {
                refresh.disabled = false;
                refresh.removeAttribute('aria-busy');
                refresh.innerHTML = '<i class="fas fa-rotate" aria-hidden="true"></i> Refresh';
                table.removeAttribute('aria-busy');
            }
        }
    };
    document.getElementById('activityFilters').addEventListener('submit', event => { event.preventDefault(); loadActivityLogs(); });
    document.getElementById('activityFilters').addEventListener('reset', () => { window.setTimeout(() => loadActivityLogs(), 0); });
    document.getElementById('activityPrevious').addEventListener('click', () => loadActivityLogs(page - 1));
    document.getElementById('activityNext').addEventListener('click', () => loadActivityLogs(page + 1));
})();
