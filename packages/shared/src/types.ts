export interface Tenant {
  id: string;
  name: string;
  slug: string;
  domain: string | null;
  is_ec_active: boolean;
  is_pmgm_active: boolean;
  is_sdm_active: boolean;
  is_rcm_active: boolean;
  is_lms_active: boolean;
  is_onb_active: boolean;
  is_comp_active: boolean;
  is_wfa_active: boolean;
  is_wfp_active: boolean;
  is_tme_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface User {
  id: string;
  tenant_id: string;
  auth_uid: string | null;
  email: string;
  first_name: string;
  last_name: string;
  employee_id: string | null;
  hire_date: string | null;
  status: "ACTIVE" | "INACTIVE" | "ON_LEAVE" | "TERMINATED";
  deleted_at: string | null;
  is_anonymized: boolean;
  performance_score: number | null;
  potential_score: number | null;
  department_id: string | null;
  job_info_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Department {
  id: string;
  tenant_id: string;
  name: string;
  code: string | null;
  parent_id: string | null;
  cost_center: string | null;
  created_at: string;
  updated_at: string;
}

export interface JobInformation {
  id: string;
  tenant_id: string;
  title: string;
  job_code: string | null;
  job_family: string | null;
  grade: string | null;
  pay_band: string | null;
  salary_min: number | null;
  salary_max: number | null;
  effective_date: string;
  created_at: string;
  updated_at: string;
}

export interface PerformanceGoal {
  id: string;
  tenant_id: string;
  user_id: string;
  title: string;
  description: string | null;
  metric: string | null;
  target_value: number | null;
  actual_value: number | null;
  weight: number | null;
  status: "NOT_STARTED" | "ON_TRACK" | "AT_RISK" | "COMPLETED" | "CANCELLED";
  period_start: string;
  period_end: string;
  created_at: string;
  updated_at: string;
}

export interface ContinuousFeedback {
  id: string;
  tenant_id: string;
  author_id: string;
  subject_id: string;
  content: string;
  visibility: "PRIVATE" | "MANAGER_ONLY" | "PUBLIC";
  category: "GENERAL" | "RECOGNITION" | "COACHING" | "DEVELOPMENT";
  created_at: string;
  updated_at: string;
}

export interface TalentPool {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  pool_type: "LEADERSHIP" | "HIGH_POTENTIAL" | "CRITICAL_ROLE" | "EMERGING_TALENT" | "CUSTOM";
  created_at: string;
  updated_at: string;
}

export interface SuccessionPlan {
  id: string;
  tenant_id: string;
  position_title: string;
  department: string | null;
  criticality: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";
  status: "DRAFT" | "ACTIVE" | "ARCHIVED";
  created_at: string;
  updated_at: string;
}
