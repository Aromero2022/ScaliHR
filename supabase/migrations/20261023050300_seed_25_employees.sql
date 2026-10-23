-- ============================================================
-- Migration: Seed 15 additional employees (e11–e25) with history
-- Brings total from 10 to 25 demo employees for acme-corp
-- ============================================================

DO $$
DECLARE
  v_tid uuid := 'a0000000-0000-0000-0000-000000000001';
BEGIN
  -- Guard: only seed when the demo tenant exists
  IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_tid) THEN
    RAISE NOTICE 'Demo tenant not found, skipping employee seed (e11-e25)';
    RETURN;
  END IF;

  -- ── New users (e11–e25) ────────────────────────────────────────
  INSERT INTO users (id, tenant_id, auth_uid, email, first_name, last_name, employee_id, status)
  VALUES
    ('e0000000-0000-0000-0000-000000000011', v_tid, gen_random_uuid(), 'gabriela.morales@acme.dev',  'Gabriela', 'Morales',  'EMP-011', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000012', v_tid, gen_random_uuid(), 'fernando.ruiz@acme.dev',     'Fernando', 'Ruiz',     'EMP-012', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000013', v_tid, gen_random_uuid(), 'patricia.castro@acme.dev',   'Patricia', 'Castro',   'EMP-013', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000014', v_tid, gen_random_uuid(), 'ricardo.flores@acme.dev',    'Ricardo',  'Flores',   'EMP-014', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000015', v_tid, gen_random_uuid(), 'isabel.torres@acme.dev',     'Isabel',   'Torres',   'EMP-015', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000016', v_tid, gen_random_uuid(), 'miguel.vargas@acme.dev',     'Miguel',   'Vargas',   'EMP-016', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000017', v_tid, gen_random_uuid(), 'carmen.reyes@acme.dev',      'Carmen',   'Reyes',    'EMP-017', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000018', v_tid, gen_random_uuid(), 'alejandro.mendez@acme.dev',  'Alejandro','Méndez',   'EMP-018', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000019', v_tid, gen_random_uuid(), 'natalia.jimenez@acme.dev',   'Natalia',  'Jiménez',  'EMP-019', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000020', v_tid, gen_random_uuid(), 'daniel.herrera@acme.dev',    'Daniel',   'Herrera',  'EMP-020', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000021', v_tid, gen_random_uuid(), 'andrea.silva@acme.dev',      'Andrea',   'Silva',    'EMP-021', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000022', v_tid, gen_random_uuid(), 'jose.ramirez@acme.dev',      'José',     'Ramírez',  'EMP-022', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000023', v_tid, gen_random_uuid(), 'valeria.gutierrez@acme.dev', 'Valeria',  'Gutiérrez','EMP-023', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000024', v_tid, gen_random_uuid(), 'luis.ortiz@acme.dev',        'Luis',     'Ortiz',    'EMP-024', 'ACTIVE'),
    ('e0000000-0000-0000-0000-000000000025', v_tid, gen_random_uuid(), 'monica.salazar@acme.dev',    'Mónica',   'Salazar',  'EMP-025', 'ACTIVE')
  ON CONFLICT (id) DO NOTHING;

  -- ── Assign departments & positions ──────────────────────────────
  -- e11-13 → Engineering (FE team under Pedro e05)
  -- e14-16 → Engineering (BE team under Laura e06)
  -- e17-19 → Sales (under María e03)
  -- e20-22 → HR (under Ana e04)
  -- e23-25 → Executive staff

  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000005', position_id = 'b0000000-0000-0000-0000-000000000008' WHERE id = 'e0000000-0000-0000-0000-000000000011';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000005', position_id = 'b0000000-0000-0000-0000-000000000008' WHERE id = 'e0000000-0000-0000-0000-000000000012';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000005', position_id = 'b0000000-0000-0000-0000-000000000009' WHERE id = 'e0000000-0000-0000-0000-000000000013';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000006', position_id = 'b0000000-0000-0000-0000-000000000010' WHERE id = 'e0000000-0000-0000-0000-000000000014';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000006', position_id = 'b0000000-0000-0000-0000-000000000010' WHERE id = 'e0000000-0000-0000-0000-000000000015';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000006', position_id = 'b0000000-0000-0000-0000-000000000011' WHERE id = 'e0000000-0000-0000-0000-000000000016';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000003', position_id = 'b0000000-0000-0000-0000-000000000012' WHERE id = 'e0000000-0000-0000-0000-000000000017';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000003', position_id = 'b0000000-0000-0000-0000-000000000012' WHERE id = 'e0000000-0000-0000-0000-000000000018';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000003', position_id = 'b0000000-0000-0000-0000-000000000013' WHERE id = 'e0000000-0000-0000-0000-000000000019';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000004', position_id = 'b0000000-0000-0000-0000-000000000007' WHERE id = 'e0000000-0000-0000-0000-000000000020';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000004', position_id = 'b0000000-0000-0000-0000-000000000007' WHERE id = 'e0000000-0000-0000-0000-000000000021';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000004', position_id = 'b0000000-0000-0000-0000-000000000007' WHERE id = 'e0000000-0000-0000-0000-000000000022';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000001', position_id = 'b0000000-0000-0000-0000-000000000003' WHERE id = 'e0000000-0000-0000-0000-000000000023';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000001', position_id = 'b0000000-0000-0000-0000-000000000003' WHERE id = 'e0000000-0000-0000-0000-000000000024';
  UPDATE users SET department_id = 'd0000000-0000-0000-0000-000000000002', position_id = 'b0000000-0000-0000-0000-000000000004' WHERE id = 'e0000000-0000-0000-0000-000000000025';

  -- ── Job information with history ────────────────────────────────
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'insert_effective_record') THEN
    -- e11 Gabriela: joined as Jr FE Dev, promoted to FE Dev
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000011',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Jr. Frontend Developer","position_id":"b0000000-0000-0000-0000-000000000008","department_id":"d0000000-0000-0000-0000-000000000005","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000005","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-06-01');
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000011',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Frontend Developer","position_id":"b0000000-0000-0000-0000-000000000008","department_id":"d0000000-0000-0000-0000-000000000005","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000005","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Promoción"}'::jsonb,
      '2024-06-01');

    -- e12 Fernando: FE Dev
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000012',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Frontend Developer","position_id":"b0000000-0000-0000-0000-000000000008","department_id":"d0000000-0000-0000-0000-000000000005","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000005","location_id":"ce100000-0000-0000-0000-000000000002","event_reason":"Contratación"}'::jsonb,
      '2024-01-15');

    -- e13 Patricia: QA Engineer (FE team)
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000013',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"QA Engineer","position_id":"b0000000-0000-0000-0000-000000000009","department_id":"d0000000-0000-0000-0000-000000000005","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000005","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-09-01');

    -- e14 Ricardo: BE Dev
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000014',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Backend Developer","position_id":"b0000000-0000-0000-0000-000000000010","department_id":"d0000000-0000-0000-0000-000000000006","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000006","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-03-01');

    -- e15 Isabel: BE Dev, transferred to GDL
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000015',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Backend Developer","position_id":"b0000000-0000-0000-0000-000000000010","department_id":"d0000000-0000-0000-0000-000000000006","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000006","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-07-01');
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000015',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Backend Developer","position_id":"b0000000-0000-0000-0000-000000000010","department_id":"d0000000-0000-0000-0000-000000000006","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000006","location_id":"ce100000-0000-0000-0000-000000000002","event_reason":"Transferencia a GDL"}'::jsonb,
      '2024-04-01');

    -- e16 Miguel: DevOps
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000016',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"DevOps Engineer","position_id":"b0000000-0000-0000-0000-000000000011","department_id":"d0000000-0000-0000-0000-000000000006","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000006","location_id":"ce100000-0000-0000-0000-000000000003","event_reason":"Contratación"}'::jsonb,
      '2024-02-01');

    -- e17 Carmen: Sales Exec
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000017',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Sales Executive","position_id":"b0000000-0000-0000-0000-000000000012","department_id":"d0000000-0000-0000-0000-000000000003","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000003","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-04-01');

    -- e18 Alejandro: Sales Exec
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000018',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Sales Executive","position_id":"b0000000-0000-0000-0000-000000000012","department_id":"d0000000-0000-0000-0000-000000000003","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000003","location_id":"ce100000-0000-0000-0000-000000000002","event_reason":"Contratación"}'::jsonb,
      '2024-03-01');

    -- e19 Natalia: Sales Coordinator
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000019',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Sales Coordinator","position_id":"b0000000-0000-0000-0000-000000000013","department_id":"d0000000-0000-0000-0000-000000000003","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000003","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-11-01');

    -- e20 Daniel: HR Analyst
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000020',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"HR Analyst","position_id":"b0000000-0000-0000-0000-000000000007","department_id":"d0000000-0000-0000-0000-000000000004","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000004","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-08-01');

    -- e21 Andrea: HR Coordinator, promoted
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000021',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"HR Assistant","position_id":"b0000000-0000-0000-0000-000000000007","department_id":"d0000000-0000-0000-0000-000000000004","job_classification_id":"cc100000-0000-0000-0000-000000000009","manager_id":"e0000000-0000-0000-0000-000000000004","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-02-01');
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000021',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"HR Coordinator","position_id":"b0000000-0000-0000-0000-000000000007","department_id":"d0000000-0000-0000-0000-000000000004","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000004","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Promoción"}'::jsonb,
      '2024-02-01');

    -- e22 José: Payroll Specialist
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000022',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Payroll Specialist","position_id":"b0000000-0000-0000-0000-000000000007","department_id":"d0000000-0000-0000-0000-000000000004","job_classification_id":"cc100000-0000-0000-0000-000000000007","manager_id":"e0000000-0000-0000-0000-000000000004","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2024-05-01');

    -- e23 Valeria: Chief of Staff
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000023',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Chief of Staff","position_id":"b0000000-0000-0000-0000-000000000003","department_id":"d0000000-0000-0000-0000-000000000001","job_classification_id":"cc100000-0000-0000-0000-000000000005","manager_id":"e0000000-0000-0000-0000-000000000001","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2023-01-15');

    -- e24 Luis: Executive Assistant
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000024',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Executive Assistant","position_id":"b0000000-0000-0000-0000-000000000003","department_id":"d0000000-0000-0000-0000-000000000001","job_classification_id":"cc100000-0000-0000-0000-000000000008","manager_id":"e0000000-0000-0000-0000-000000000001","location_id":"ce100000-0000-0000-0000-000000000001","event_reason":"Contratación"}'::jsonb,
      '2024-01-01');

    -- e25 Mónica: Tech Lead (ENG)
    PERFORM insert_effective_record('ec_job_information', 'e0000000-0000-0000-0000-000000000025',
      '{"tenant_id":"a0000000-0000-0000-0000-000000000001","job_title":"Tech Lead","position_id":"b0000000-0000-0000-0000-000000000004","department_id":"d0000000-0000-0000-0000-000000000002","job_classification_id":"cc100000-0000-0000-0000-000000000005","manager_id":"e0000000-0000-0000-0000-000000000002","location_id":"ce100000-0000-0000-0000-000000000003","event_reason":"Contratación"}'::jsonb,
      '2023-05-01');

    -- ── Compensation records ────────────────────────────────────────
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000011', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":28000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-06-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000011', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":35000,"currency":"MXN","frequency":"monthly","event_reason":"Promoción"}'::jsonb, '2024-06-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000012', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":38000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2024-01-15');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000013', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":32000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-09-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000014', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":40000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-03-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000015', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":30000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-07-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000015', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":36000,"currency":"MXN","frequency":"monthly","event_reason":"Ajuste por transferencia"}'::jsonb, '2024-04-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000016', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":45000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2024-02-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000017', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":25000,"currency":"MXN","frequency":"monthly","bonus_target":15,"event_reason":"Contratación"}'::jsonb, '2023-04-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000018', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":22000,"currency":"MXN","frequency":"monthly","bonus_target":15,"event_reason":"Contratación"}'::jsonb, '2024-03-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000019', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":20000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-11-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000020', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":28000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-08-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000021', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":18000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2023-02-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000021', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":26000,"currency":"MXN","frequency":"monthly","event_reason":"Promoción"}'::jsonb, '2024-02-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000022', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":35000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2024-05-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000023', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":70000,"currency":"MXN","frequency":"monthly","bonus_target":20,"event_reason":"Contratación"}'::jsonb, '2023-01-15');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000024', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":22000,"currency":"MXN","frequency":"monthly","event_reason":"Contratación"}'::jsonb, '2024-01-01');
    PERFORM insert_effective_record('ec_compensation', 'e0000000-0000-0000-0000-000000000025', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","base_salary":65000,"currency":"MXN","frequency":"monthly","bonus_target":15,"event_reason":"Contratación"}'::jsonb, '2023-05-01');

    -- ── Personal information records ────────────────────────────────
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000011', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Gabriela","last_name":"Morales","phone":"+52 55 2211 3344","nationality":"MX","gender":"F","date_of_birth":"1995-03-12","event_reason":"Registro inicial"}'::jsonb, '2023-06-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000012', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Fernando","last_name":"Ruiz","phone":"+52 33 4455 6677","nationality":"MX","gender":"M","date_of_birth":"1992-08-25","event_reason":"Registro inicial"}'::jsonb, '2024-01-15');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000013', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Patricia","last_name":"Castro","phone":"+52 55 8899 0011","nationality":"MX","gender":"F","date_of_birth":"1990-11-05","event_reason":"Registro inicial"}'::jsonb, '2023-09-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000014', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Ricardo","last_name":"Flores","phone":"+52 55 1122 3344","nationality":"MX","gender":"M","date_of_birth":"1988-07-20","event_reason":"Registro inicial"}'::jsonb, '2023-03-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000015', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Isabel","last_name":"Torres","phone":"+52 33 5566 7788","nationality":"MX","gender":"F","date_of_birth":"1993-01-15","event_reason":"Registro inicial"}'::jsonb, '2023-07-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000016', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Miguel","last_name":"Vargas","phone":"+52 81 9900 1122","nationality":"MX","gender":"M","date_of_birth":"1991-04-30","event_reason":"Registro inicial"}'::jsonb, '2024-02-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000017', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Carmen","last_name":"Reyes","phone":"+52 55 3344 5566","nationality":"MX","gender":"F","date_of_birth":"1989-09-18","event_reason":"Registro inicial"}'::jsonb, '2023-04-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000018', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Alejandro","last_name":"Méndez","phone":"+52 33 7788 9900","nationality":"MX","gender":"M","date_of_birth":"1994-12-01","event_reason":"Registro inicial"}'::jsonb, '2024-03-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000019', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Natalia","last_name":"Jiménez","phone":"+52 55 1234 0000","nationality":"MX","gender":"F","date_of_birth":"1996-06-22","event_reason":"Registro inicial"}'::jsonb, '2023-11-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000020', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Daniel","last_name":"Herrera","phone":"+52 55 5678 0000","nationality":"MX","gender":"M","date_of_birth":"1992-02-14","event_reason":"Registro inicial"}'::jsonb, '2023-08-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000021', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Andrea","last_name":"Silva","phone":"+52 55 9012 3456","nationality":"MX","gender":"F","date_of_birth":"1997-10-08","event_reason":"Registro inicial"}'::jsonb, '2023-02-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000022', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"José","last_name":"Ramírez","phone":"+52 55 3456 7890","nationality":"MX","gender":"M","date_of_birth":"1990-05-17","event_reason":"Registro inicial"}'::jsonb, '2024-05-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000023', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Valeria","last_name":"Gutiérrez","phone":"+52 55 6789 0123","nationality":"MX","gender":"F","date_of_birth":"1987-03-28","event_reason":"Registro inicial"}'::jsonb, '2023-01-15');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000024', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Luis","last_name":"Ortiz","phone":"+52 55 0123 4567","nationality":"MX","gender":"M","date_of_birth":"1998-08-10","event_reason":"Registro inicial"}'::jsonb, '2024-01-01');
    PERFORM insert_effective_record('ec_personal_information', 'e0000000-0000-0000-0000-000000000025', '{"tenant_id":"a0000000-0000-0000-0000-000000000001","first_name":"Mónica","last_name":"Salazar","phone":"+52 81 4567 8901","nationality":"MX","gender":"F","date_of_birth":"1991-11-25","event_reason":"Registro inicial"}'::jsonb, '2023-05-01');
  ELSE
    RAISE NOTICE 'insert_effective_record function not found, skipping history seed';
  END IF;
END $$;
