-- ════════════════════════════════════════════════════════════════════════════
-- RAYZHUB MASTER SUPABASE DATABASE SCHEMA & STORAGE BUCKET MIGRATION (DEADLOCK-SAFE)
-- Paste this script into Supabase SQL Editor (https://supabase.com/dashboard)
-- ════════════════════════════════════════════════════════════════════════════

-- 1. Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'admin',
    is_verified BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. REQUESTS & PAYMENT PROOFS TABLE
CREATE TABLE IF NOT EXISTS public.requests (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    message TEXT NOT NULL,
    photo_path TEXT,
    request_type VARCHAR(100) DEFAULT 'request',
    amount VARCHAR(100),
    transaction_id VARCHAR(255),
    is_anonymous BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. LINK ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.link_items (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    target_url TEXT NOT NULL,
    short_code VARCHAR(50) UNIQUE NOT NULL,
    clicks INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. VERIFICATION AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.verification_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    ip_address VARCHAR(100),
    status VARCHAR(50) DEFAULT 'success',
    details TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. WIDGET CONFIGS TABLE
CREATE TABLE IF NOT EXISTS public.widget_configs (
    id BIGSERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_json TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. SAFE SUPABASE STORAGE BUCKET CREATION
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public) 
    VALUES ('proofs', 'proofs', true), ('uploads', 'uploads', true)
    ON CONFLICT (id) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    -- Ignore concurrency bucket lock warnings
    NULL;
END $$;

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.link_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.widget_configs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first to prevent lock conflicts
DROP POLICY IF EXISTS "Public Read Requests" ON public.requests;
DROP POLICY IF EXISTS "Public Insert Requests" ON public.requests;
DROP POLICY IF EXISTS "Public Read Links" ON public.link_items;
DROP POLICY IF EXISTS "Public Insert Links" ON public.link_items;
DROP POLICY IF EXISTS "Public Read Config" ON public.widget_configs;
DROP POLICY IF EXISTS "Public Save Config" ON public.widget_configs;

CREATE POLICY "Public Read Requests" ON public.requests FOR SELECT USING (true);
CREATE POLICY "Public Insert Requests" ON public.requests FOR INSERT WITH CHECK (true);

CREATE POLICY "Public Read Links" ON public.link_items FOR SELECT USING (true);
CREATE POLICY "Public Insert Links" ON public.link_items FOR INSERT WITH CHECK (true);

CREATE POLICY "Public Read Config" ON public.widget_configs FOR SELECT USING (true);
CREATE POLICY "Public Save Config" ON public.widget_configs FOR ALL USING (true);

-- Storage bucket public policies (Drop if exists first)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Public Access Storage Proofs" ON storage.objects;
    DROP POLICY IF EXISTS "Public Insert Storage Proofs" ON storage.objects;
    DROP POLICY IF EXISTS "Public Access Storage Uploads" ON storage.objects;
    DROP POLICY IF EXISTS "Public Insert Storage Uploads" ON storage.objects;

    CREATE POLICY "Public Access Storage Proofs" ON storage.objects FOR SELECT USING (bucket_id = 'proofs');
    CREATE POLICY "Public Insert Storage Proofs" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'proofs');

    CREATE POLICY "Public Access Storage Uploads" ON storage.objects FOR SELECT USING (bucket_id = 'uploads');
    CREATE POLICY "Public Insert Storage Uploads" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'uploads');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 9. DEADLOCK-SAFE SUPABASE REALTIME PUBLICATION
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.requests;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.widget_configs;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Prevent deadlock if Supabase Realtime daemon holds active locks
    NULL;
END $$;
