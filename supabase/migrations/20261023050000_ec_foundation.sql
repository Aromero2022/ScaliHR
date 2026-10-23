-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Loop 4 — Step 1: EC Foundation                                     ║
-- ║  legal_entities, business_units, locations; alter departments to     ║
-- ║  link to new tables; add is_pos_mgmt_active to tenants.             ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. LEGAL ENTITIES
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.legal_entities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code        text NOT NULL,
  name        text NOT NULL,
  country     text NOT NULL DEFAULT 'MX',
  rfc         text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_legal_entities_tenant ON public.legal_entities(tenant_id);

ALTER TABLE public.legal_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_entities FORCE ROW LEVEL SECURITY;

CREATE POLICY legal_entities_select ON public.legal_entities
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY legal_entities_insert ON public.legal_entities
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());
CREATE POLICY legal_entities_update ON public.legal_entities
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());

-- ═══════════════════════════════════════════════════════════════════
-- 2. BUSINESS UNITS
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.business_units (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code            text NOT NULL,
  name            text NOT NULL,
  legal_entity_id uuid NOT NULL REFERENCES public.legal_entities(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_business_units_tenant ON public.business_units(tenant_id);
CREATE INDEX IF NOT EXISTS idx_business_units_legal_entity ON public.business_units(legal_entity_id);

ALTER TABLE public.business_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_units FORCE ROW LEVEL SECURITY;

CREATE POLICY business_units_select ON public.business_units
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY business_units_insert ON public.business_units
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());
CREATE POLICY business_units_update ON public.business_units
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());

-- ═══════════════════════════════════════════════════════════════════
-- 3. LOCATIONS
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.locations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code        text NOT NULL,
  name        text NOT NULL,
  address     text,
  city        text,
  state       text,
  country     text NOT NULL DEFAULT 'MX',
  postal_code text,
  timezone    text NOT NULL DEFAULT 'America/Mexico_City',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_locations_tenant ON public.locations(tenant_id);

ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations FORCE ROW LEVEL SECURITY;

CREATE POLICY locations_select ON public.locations
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY locations_insert ON public.locations
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());
CREATE POLICY locations_update ON public.locations
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id() AND public.is_tenant_admin());

-- ═══════════════════════════════════════════════════════════════════
-- 4. ALTER DEPARTMENTS: add FK to legal_entity, business_unit, location
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.departments
  ADD COLUMN IF NOT EXISTS legal_entity_id  uuid REFERENCES public.legal_entities(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS business_unit_id uuid REFERENCES public.business_units(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS location_id      uuid REFERENCES public.locations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_departments_legal_entity  ON public.departments(legal_entity_id);
CREATE INDEX IF NOT EXISTS idx_departments_business_unit ON public.departments(business_unit_id);
CREATE INDEX IF NOT EXISTS idx_departments_location      ON public.departments(location_id);

-- ═══════════════════════════════════════════════════════════════════
-- 5. ALTER TENANTS: add is_pos_mgmt_active flag
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS is_pos_mgmt_active boolean NOT NULL DEFAULT false;

-- ═══════════════════════════════════════════════════════════════════
-- 6. GRANT to authenticated + prisma_app
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE ON public.legal_entities  TO authenticated;
  GRANT SELECT, INSERT, UPDATE ON public.business_units  TO authenticated;
  GRANT SELECT, INSERT, UPDATE ON public.locations       TO authenticated;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT SELECT, INSERT, UPDATE ON public.legal_entities  TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON public.business_units  TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON public.locations       TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. SEED DATA for acme-corp
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_tid uuid := 'a0000000-0000-0000-0000-000000000001';
  v_le  uuid;
  v_bu  uuid;
  v_loc uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = v_tid) THEN
    RAISE NOTICE 'No acme-corp tenant, skipping ec_foundation seed';
    RETURN;
  END IF;

  UPDATE tenants SET is_pos_mgmt_active = true WHERE id = v_tid;

  -- Legal entity
  INSERT INTO legal_entities (id, tenant_id, code, name, country, rfc)
  VALUES ('ae100000-0000-0000-0000-000000000001', v_tid, 'LE-ACME-MX', 'Acme Corp México S.A. de C.V.', 'MX', 'ACM010101AAA')
  ON CONFLICT (tenant_id, code) DO NOTHING
  RETURNING id INTO v_le;
  IF v_le IS NULL THEN
    SELECT id INTO v_le FROM legal_entities WHERE tenant_id = v_tid AND code = 'LE-ACME-MX';
  END IF;

  -- Business units
  INSERT INTO business_units (id, tenant_id, code, name, legal_entity_id)
  VALUES ('be100000-0000-0000-0000-000000000001', v_tid, 'BU-TECH', 'Technology Division', v_le)
  ON CONFLICT (tenant_id, code) DO NOTHING
  RETURNING id INTO v_bu;
  IF v_bu IS NULL THEN
    SELECT id INTO v_bu FROM business_units WHERE tenant_id = v_tid AND code = 'BU-TECH';
  END IF;

  INSERT INTO business_units (id, tenant_id, code, name, legal_entity_id)
  VALUES ('be100000-0000-0000-0000-000000000002', v_tid, 'BU-SALES', 'Sales Division', v_le)
  ON CONFLICT (tenant_id, code) DO NOTHING;

  INSERT INTO business_units (id, tenant_id, code, name, legal_entity_id)
  VALUES ('be100000-0000-0000-0000-000000000003', v_tid, 'BU-HR', 'Human Resources', v_le)
  ON CONFLICT (tenant_id, code) DO NOTHING;

  -- Locations
  INSERT INTO locations (id, tenant_id, code, name, city, state, country, timezone)
  VALUES ('ce100000-0000-0000-0000-000000000001', v_tid, 'LOC-CDMX-HQ', 'CDMX Headquarters', 'Ciudad de México', 'CDMX', 'MX', 'America/Mexico_City')
  ON CONFLICT (tenant_id, code) DO NOTHING
  RETURNING id INTO v_loc;
  IF v_loc IS NULL THEN
    SELECT id INTO v_loc FROM locations WHERE tenant_id = v_tid AND code = 'LOC-CDMX-HQ';
  END IF;

  INSERT INTO locations (id, tenant_id, code, name, city, state, country, timezone)
  VALUES ('ce100000-0000-0000-0000-000000000002', v_tid, 'LOC-GDL', 'Guadalajara Office', 'Guadalajara', 'Jalisco', 'MX', 'America/Mexico_City')
  ON CONFLICT (tenant_id, code) DO NOTHING;

  INSERT INTO locations (id, tenant_id, code, name, city, state, country, timezone)
  VALUES ('ce100000-0000-0000-0000-000000000003', v_tid, 'LOC-MTY', 'Monterrey Office', 'Monterrey', 'Nuevo León', 'MX', 'America/Monterrey')
  ON CONFLICT (tenant_id, code) DO NOTHING;

  -- Link existing departments
  UPDATE departments SET legal_entity_id = v_le, business_unit_id = v_bu, location_id = v_loc
  WHERE tenant_id = v_tid AND code IN ('ENG', 'FE', 'BE');

  UPDATE departments SET legal_entity_id = v_le,
    business_unit_id = 'be100000-0000-0000-0000-000000000002',
    location_id = v_loc
  WHERE tenant_id = v_tid AND code = 'SALES';

  UPDATE departments SET legal_entity_id = v_le,
    business_unit_id = 'be100000-0000-0000-0000-000000000003',
    location_id = v_loc
  WHERE tenant_id = v_tid AND code = 'HR';

END $$;
