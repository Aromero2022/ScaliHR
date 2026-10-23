import { z } from "zod";

const RFC_PATTERN = /^[A-Z&Ñ]{3,4}\d{6}[A-Z\d]{3}$/;

export const createTenantSchema = z.object({
  name: z
    .string()
    .min(2, "El nombre debe tener al menos 2 caracteres")
    .max(100, "El nombre no puede exceder 100 caracteres")
    .trim(),
  slug: z
    .string()
    .min(3, "El slug debe tener al menos 3 caracteres")
    .max(50, "El slug no puede exceder 50 caracteres")
    .regex(
      /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      "Solo letras minúsculas, números y guiones"
    ),
  rfc: z
    .string()
    .regex(RFC_PATTERN, "RFC inválido")
    .optional()
    .or(z.literal("")),
  modules: z.object({
    employee_central: z.boolean().default(true),
    recruiting: z.boolean().default(false),
    performance: z.boolean().default(false),
    lms: z.boolean().default(false),
  }),
});

export type CreateTenantInput = z.infer<typeof createTenantSchema>;
