import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TalentGo — Enterprise HCM",
  description: "SAP SuccessFactors-class Human Capital Management",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-slate-950 text-slate-100 antialiased">
        {children}
      </body>
    </html>
  );
}
