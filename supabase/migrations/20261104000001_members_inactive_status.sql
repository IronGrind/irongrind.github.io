-- Older projects allow active/expired/suspended but not inactive. Preserve the
-- existing suspended state while enabling the five-day and manual archive flows.
reset role;
begin;
alter table public.members drop constraint if exists members_status_check;
alter table public.members add constraint members_status_check
    check (status in ('active', 'expired', 'suspended', 'inactive'));
commit;
notify pgrst, 'reload schema';
