// prisma.config.ts  (Prisma 7)
// The `datasource.url` here is used by the Prisma CLI for `db pull` and migrations.
// Use the DIRECT Supabase connection (port 5432) for CLI work.
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: env("DATABASE_URL"),
  },
});
