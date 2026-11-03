-- One-time cleanup approved for these nine old, unlinked memberships.
-- Run the whole file as postgres in Supabase SQL Editor.
-- Sales, attendance, membership history, and Auth users are not deleted.
reset role;
begin;

create temporary table approved_old_member_names (
    full_name text primary key,
    expected_count integer not null
) on commit drop;
insert into approved_old_member_names values
    ('Ana Jean Seripa', 1),
    ('Jamaica Bongcao', 1),
    ('Jecil', 1),
    ('Main Test Account', 1),
    ('roshe', 2),
    ('Roshe Mae I. Gomez', 1),
    ('Seripa, Ana Jean D.', 1),
    ('TestAccount2', 1);

-- Capture and lock the exact matching IDs before changing their status.
create temporary table approved_old_member_ids on commit drop as
select m.id, m.full_name
from public.members m
join approved_old_member_names n on n.full_name = m.full_name
where m.auth_user_id is null
for update of m;

do $$
begin
    if exists (
        select 1
        from approved_old_member_names n
        left join approved_old_member_ids m on m.full_name = n.full_name
        group by n.full_name, n.expected_count
        having count(m.id) <> n.expected_count
    ) then
        raise exception 'The nine approved memberships no longer match. No records changed; review the member list first.';
    end if;
end;
$$;

update public.members m
set status = 'inactive', updated_at = now()
from approved_old_member_ids approved
where m.id = approved.id
  and m.auth_user_id is null
  and m.status is distinct from 'inactive'
returning m.id, m.full_name, m.status;

commit;
