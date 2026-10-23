"use server";

import { createClient } from "@/lib/supabase/server";

export type ModuleFlags = {
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
  is_tih_active: boolean;
};

const DEFAULT_FLAGS: ModuleFlags = {
  is_ec_active: false,
  is_pmgm_active: false,
  is_sdm_active: false,
  is_rcm_active: false,
  is_lms_active: false,
  is_onb_active: false,
  is_comp_active: false,
  is_wfa_active: false,
  is_wfp_active: false,
  is_tme_active: false,
  is_tih_active: false,
};

export async function getModuleFlags(
  tenantId: string
): Promise<ModuleFlags> {
  const supabase = await createClient();

  const { data } = await supabase
    .from("tenants")
    .select(
      "is_ec_active, is_pmgm_active, is_sdm_active, is_rcm_active, is_lms_active, is_onb_active, is_comp_active, is_wfa_active, is_wfp_active, is_tme_active, is_tih_active"
    )
    .eq("id", tenantId)
    .single();

  if (!data) return DEFAULT_FLAGS;

  return data as ModuleFlags;
}
