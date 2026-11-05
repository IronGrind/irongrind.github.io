alter table public.profiles
    add column if not exists phone_number text,
    add column if not exists gender text;

notify pgrst, 'reload schema';
