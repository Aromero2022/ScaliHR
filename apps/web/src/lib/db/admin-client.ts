import { PrismaClient, Prisma } from "@prisma/client";

const globalForAdmin = globalThis as unknown as {
  adminPrisma: PrismaClient | undefined;
};

const adminPrisma =
  globalForAdmin.adminPrisma ??
  new PrismaClient({
    datasourceUrl: process.env.ADMIN_DATABASE_URL,
  });

if (process.env.NODE_ENV !== "production")
  globalForAdmin.adminPrisma = adminPrisma;

export { adminPrisma, Prisma };
