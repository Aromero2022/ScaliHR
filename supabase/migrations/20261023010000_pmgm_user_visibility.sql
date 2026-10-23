-- ================================================================
-- Phase 7: PMGM — User-Level Visibility RLS
-- ================================================================
-- Columns due_date and progress_percentage were added to
-- performance_goals via ALTER TABLE (applied via Supabase MCP).
--
-- APPROACH: RESTRICTIVE policies layered on top of existing
-- permissive tenant_isolation + service_role_bypass policies.
-- Restrictive policies AND with permissive ones, so:
--   authenticated: tenant_isolation AND user_visibility
--   service_role:  service_role_bypass (full access preserved)
-- ================================================================

-- ─── PERFORMANCE GOALS: user-level visibility ───────────────────

CREATE POLICY "goals_user_visibility" ON performance_goals
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

CREATE POLICY "goals_user_insert" ON performance_goals
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
  );

CREATE POLICY "goals_user_update" ON performance_goals
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

-- ─── CONTINUOUS FEEDBACKS: participant visibility ────────────────

CREATE POLICY "feedback_participant_visibility" ON continuous_feedbacks
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    author_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR subject_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

CREATE POLICY "feedback_author_insert" ON continuous_feedbacks
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (
    author_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
  );

CREATE POLICY "feedback_author_update" ON continuous_feedbacks
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    author_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

-- ─── SEED DATA: Goals and Feedback for demo tenant ──────────────

DO $$
DECLARE
  v_tenant_id uuid;
  v_elena_id uuid;
  v_carlos_id uuid;
  v_marcus_id uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM tenants WHERE slug = 'acme-corp' LIMIT 1;
  IF v_tenant_id IS NULL THEN RETURN; END IF;

  SELECT id INTO v_elena_id FROM users WHERE email = 'elena.martinez@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;
  SELECT id INTO v_carlos_id FROM users WHERE email = 'carlos.reyes@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;
  SELECT id INTO v_marcus_id FROM users WHERE email = 'marcus.johnson@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;

  IF v_elena_id IS NULL THEN RETURN; END IF;

  INSERT INTO performance_goals (tenant_id, user_id, title, description, metric, target_value, actual_value, weight, status, due_date, progress_percentage, period_start, period_end)
  VALUES
    (v_tenant_id, v_elena_id, 'Reducir tiempo de contratación', 'Optimizar el pipeline de reclutamiento para reducir el time-to-hire promedio de 45 a 30 días', 'Días promedio', 30, 38, 0.3, 'ON_TRACK', '2026-12-31', 45, '2026-01-01', '2026-12-31'),
    (v_tenant_id, v_elena_id, 'Implementar programa de onboarding', 'Diseñar y lanzar un programa estructurado de onboarding para nuevos empleados', 'Programa completado', 100, 75, 0.25, 'ON_TRACK', '2026-09-30', 75, '2026-01-01', '2026-12-31'),
    (v_tenant_id, v_elena_id, 'Mejorar índice de retención', 'Incrementar la retención de empleados del 85% al 92% anual', 'Porcentaje retención', 92, 88, 0.25, 'AT_RISK', '2026-12-31', 60, '2026-01-01', '2026-12-31'),
    (v_tenant_id, v_elena_id, 'Certificación SHRM-SCP', 'Obtener la certificación SHRM Senior Certified Professional', 'Certificación', 1, 0, 0.2, 'NOT_STARTED', '2026-11-15', 10, '2026-01-01', '2026-12-31')
  ON CONFLICT DO NOTHING;

  IF v_carlos_id IS NOT NULL THEN
    INSERT INTO performance_goals (tenant_id, user_id, title, description, metric, target_value, actual_value, weight, status, due_date, progress_percentage, period_start, period_end)
    VALUES
      (v_tenant_id, v_carlos_id, 'Completar migración a microservicios', 'Migrar los 3 módulos core del monolito a arquitectura de microservicios', 'Módulos migrados', 3, 1, 0.4, 'ON_TRACK', '2026-12-31', 33, '2026-01-01', '2026-12-31'),
      (v_tenant_id, v_carlos_id, 'Reducir incidentes en producción', 'Disminuir incidentes P1/P2 en un 50% respecto al año anterior', 'Incidentes reducidos %', 50, 30, 0.3, 'ON_TRACK', '2026-12-31', 60, '2026-01-01', '2026-12-31')
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_carlos_id IS NOT NULL THEN
    INSERT INTO continuous_feedbacks (tenant_id, author_id, subject_id, content, visibility, category)
    VALUES
      (v_tenant_id, v_carlos_id, v_elena_id, 'Excelente trabajo coordinando el proceso de onboarding del equipo de ingeniería. La documentación y los materiales preparados fueron muy completos.', 'PUBLIC', 'RECOGNITION'),
      (v_tenant_id, v_elena_id, v_carlos_id, 'Carlos ha demostrado un liderazgo técnico sobresaliente en el proyecto de migración. Recomiendo considerar su desarrollo hacia un rol de Staff Engineer.', 'MANAGER_ONLY', 'DEVELOPMENT'),
      (v_tenant_id, v_carlos_id, v_elena_id, 'Sugerencia: sería valioso tener sesiones de feedback más frecuentes con el equipo de recruiting, quizás cada dos semanas en lugar de mensual.', 'PRIVATE', 'COACHING')
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_marcus_id IS NOT NULL THEN
    INSERT INTO continuous_feedbacks (tenant_id, author_id, subject_id, content, visibility, category)
    VALUES
      (v_tenant_id, v_marcus_id, v_elena_id, 'Elena facilitó una sesión de resolución de conflictos entre los equipos de ventas y producto que fue muy efectiva. Su capacidad de mediación es notable.', 'PUBLIC', 'RECOGNITION')
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
