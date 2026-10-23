# Scalia HR — Claude Code Guidelines

## Reglas del bucle (aplican a TODOS los loops)

- No existen errores "pre-existentes": lint, typecheck y build deben terminar en CERO errores. Si algo falla, se corrige en el mismo loop.
- Las garantías de seguridad (RLS, privilegios, FKs) se prueban contra la base local real (`supabase start`), no solo con mocks.
- Ninguna migración se da por buena sin `supabase db reset` exitoso.
- Las rutas protegidas viven en el grupo `(protected)` sin prefijo `/app`.

## Reglas de seguridad y esquema

- `supabase/migrations` (SQL) es la UNICA fuente de verdad del esquema. Prisma solo via `npm run db:sync` (db pull + generate). PROHIBIDO `prisma migrate` y `prisma db push`.
- ENABLE + FORCE ROW LEVEL SECURITY en toda tabla nueva. Sin politica DELETE para `authenticated` (solo soft delete).
- GRANT EXECUTE al hook solo a `supabase_auth_admin`; REVOKE a PUBLIC, anon y authenticated.
- `service_role` y conexiones privilegiadas nunca en codigo cliente.
- Toda entrada externa se valida con Zod.
- Trabaja SOLO contra el entorno local (`supabase start`). Nunca ejecutes nada contra un proyecto Supabase remoto sin confirmacion explicita del usuario.

## Estructura del proyecto

- Turborepo monorepo: `apps/*`, `packages/*`
- Web app: Next.js 15 App Router en `apps/web`
- Rutas protegidas: `apps/web/src/app/(protected)/`
- Tests: Vitest en `apps/web/__tests__/`
- Migraciones: `supabase/migrations/` (orden cronologico en el nombre)
