import { Slot } from "expo-router";
import { AuthProvider } from "../src/providers/auth-provider";

export default function RootLayout() {
  return (
    <AuthProvider>
      <Slot />
    </AuthProvider>
  );
}
