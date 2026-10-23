-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Bootstrap: Core enums + tables needed by early migrations          ║
-- ║  All IF NOT EXISTS / EXCEPTION WHEN duplicate_object so the later   ║
-- ║  core_schema_consolidation migration remains idempotent.            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. ENUM TYPES
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  CREATE TYPE "EmployeeStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ON_LEAVE', 'TERMINATED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "GoalStatus" AS ENUM ('NOT_STARTED', 'ON_TRACK', 'AT_RISK', 'COMPLETED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "FeedbackVisibility" AS ENUM ('PRIVATE', 'MANAGER_ONLY', 'PUBLIC');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "FeedbackCategory" AS ENUM ('GENERAL', 'RECOGNITION', 'COACHING', 'DEVELOPMENT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "TalentPoolType" AS ENUM ('LEADERSHIP', 'HIGH_POTENTIAL', 'CRITICAL_ROLE', 'EMERGING_TALENT', 'CUSTOM');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ReadinessLevel" AS ENUM ('READY_NOW', 'READY_1_YEAR', 'READY_2_YEARS', 'NOT_READY');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "PlanCriticality" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "PlanStatus" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. CORE TABLES
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.tenants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL UNIQUE,
  domain      text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  is_ec_active   boolean NOT NULL DEFAULT false,
  is_pmgm_active boolean NOT NULL DEFAULT false,
  is_sdm_active  boolean NOT NULL DEFAULT false,
  is_rcm_active  boolean NOT NULL DEFAULT false,
  is_lms_active  boolean NOT NULL DEFAULT false,
  is_onb_active  boolean NOT NULL DEFAULT false,
  is_comp_active boolean NOT NULL DEFAULT false,
  is_wfa_active  boolean NOT NULL DEFAULT false,
  is_wfp_active  boolean NOT NULL DEFAULT false,
  is_tme_active  boolean NOT NULL DEFAULT false,
  is_tih_active  boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  auth_uid      uuid UNIQUE,
  email         text NOT NULL,
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  employee_id   text,
  hire_date     timestamptz,
  status        "EmployeeStatus" NOT NULL DEFAULT 'ACTIVE',
  deleted_at    timestamptz,
  is_anonymized boolean NOT NULL DEFAULT false,
  performance_score double precision,
  potential_score   double precision,
  department_id uuid,
  job_info_id   uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, email)
);
CREATE INDEX IF NOT EXISTS idx_users_tenant ON public.users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON public.users(deleted_at);

CREATE TABLE IF NOT EXISTS public.departments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name        text NOT NULL,
  code        text,
  parent_id   uuid REFERENCES public.departments(id),
  cost_center text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);
CREATE INDEX IF NOT EXISTS idx_departments_tenant ON public.departments(tenant_id);

CREATE TABLE IF NOT EXISTS public.job_informations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title                 text NOT NULL,
  grade                 text,
  pay_band              text,
  salary_min            double precision,
  salary_max            double precision,
  effective_date        timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_job_informations_tenant ON public.job_informations(tenant_id);

-- ═══════════════════════════════════════════════════════════════════
-- 3. TALENT: PERFORMANCE & GOAL MANAGEMENT (PMGM)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.performance_goals (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id             uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title               text NOT NULL,
  description         text,
  metric              text,
  target_value        double precision,
  actual_value        double precision,
  weight              double precision,
  status              "GoalStatus" NOT NULL DEFAULT 'ON_TRACK',
  due_date            timestamptz,
  progress_percentage integer NOT NULL DEFAULT 0,
  period_start        timestamptz NOT NULL,
  period_end          timestamptz NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_performance_goals_tenant ON public.performance_goals(tenant_id);
CREATE INDEX IF NOT EXISTS idx_performance_goals_user ON public.performance_goals(user_id);

CREATE TABLE IF NOT EXISTS public.continuous_feedbacks (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  author_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content    text NOT NULL,
  visibility "FeedbackVisibility" NOT NULL DEFAULT 'PRIVATE',
  category   "FeedbackCategory"  NOT NULL DEFAULT 'GENERAL',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_continuous_feedbacks_tenant ON public.continuous_feedbacks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_continuous_feedbacks_author ON public.continuous_feedbacks(author_id);
CREATE INDEX IF NOT EXISTS idx_continuous_feedbacks_subject ON public.continuous_feedbacks(subject_id);

-- ═══════════════════════════════════════════════════════════════════
-- 4. TALENT: SUCCESSION & DEVELOPMENT MANAGEMENT (SDM)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.talent_pools (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text,
  pool_type   "TalentPoolType" NOT NULL DEFAULT 'LEADERSHIP',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_talent_pools_tenant ON public.talent_pools(tenant_id);

CREATE TABLE IF NOT EXISTS public.talent_pool_entries (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  talent_pool_id uuid NOT NULL REFERENCES public.talent_pools(id) ON DELETE CASCADE,
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  readiness      "ReadinessLevel" NOT NULL DEFAULT 'NOT_READY',
  notes          text,
  added_at       timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (talent_pool_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.succession_plans (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  position_title text NOT NULL,
  department     text,
  criticality    "PlanCriticality" NOT NULL DEFAULT 'MEDIUM',
  status         "PlanStatus"      NOT NULL DEFAULT 'DRAFT',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_succession_plans_tenant ON public.succession_plans(tenant_id);

CREATE TABLE IF NOT EXISTS public.succession_nominees (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  succession_plan_id uuid NOT NULL REFERENCES public.succession_plans(id) ON DELETE CASCADE,
  user_id            uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  readiness          "ReadinessLevel" NOT NULL DEFAULT 'NOT_READY',
  ranking            integer,
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (succession_plan_id, user_id)
);
