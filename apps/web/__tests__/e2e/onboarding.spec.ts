import { test, expect } from "@playwright/test";

const UNIQUE = Date.now().toString(36);
const TEST_EMAIL = `e2e-${UNIQUE}@test.local`;
const TEST_PASSWORD = "Test1234!";
const TEST_TENANT_NAME = `E2E Corp ${UNIQUE}`;
const TEST_TENANT_SLUG = `e2e-corp-${UNIQUE}`;

test.describe("Full onboarding flow", () => {
  test("signup → create tenant → enroll MFA → access admin-center", async ({
    page,
  }) => {
    // --- 1. Signup ---
    await page.goto("/signup");
    await page.getByLabel("Email").fill(TEST_EMAIL);
    await page.getByLabel("Password").fill(TEST_PASSWORD);
    await page.getByRole("button", { name: /registr|sign up|crear/i }).click();

    await expect(page).toHaveURL(/\/(app|onboarding|verify)/, {
      timeout: 15_000,
    });

    // --- 2. Create tenant ---
    await page.goto("/app/onboarding");
    await page.getByLabel(/nombre/i).fill(TEST_TENANT_NAME);
    await page.getByLabel(/slug/i).fill(TEST_TENANT_SLUG);

    const moduleCheckbox = page.getByLabel(/employee.central/i);
    if (await moduleCheckbox.isVisible()) {
      await moduleCheckbox.check();
    }

    await page.getByRole("button", { name: /crear|create/i }).click();
    await expect(page.getByText(/tenant.*cread|organización.*cread/i)).toBeVisible({
      timeout: 10_000,
    });

    // --- 3. Forced MFA enrollment (owner role) ---
    await page.goto("/app/dashboard");
    // Owner with no TOTP should be redirected to /mfa/enroll
    await expect(page).toHaveURL(/\/mfa\/enroll/);

    // Verify enrollment page shows QR code
    await expect(
      page.locator("img[src*='data:image'], canvas, [data-testid='qr-code']")
    ).toBeVisible({ timeout: 5_000 });

    // --- 4. Verify admin-center requires aal2 ---
    await page.goto("/admin-center");
    // Without completing MFA verify, should redirect to /mfa/verify or /mfa/enroll
    await expect(page).toHaveURL(/\/mfa\/(verify|enroll)/);
  });
});
