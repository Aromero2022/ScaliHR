import { useEffect, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, FlatList, ActivityIndicator } from "react-native";
import { useAuth } from "../../src/providers/auth-provider";
import { supabase } from "../../src/lib/supabase";
import type { User } from "@talentgo/shared";
import { router } from "expo-router";

export default function DashboardScreen() {
  const { user, tenantId, signOut } = useAuth();
  const [employees, setEmployees] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadEmployees();
  }, []);

  async function loadEmployees() {
    const { data, error } = await supabase
      .from("users")
      .select("id, first_name, last_name, email, status, performance_score, potential_score")
      .order("created_at", { ascending: false })
      .limit(20);

    if (!error && data) setEmployees(data as User[]);
    setLoading(false);
  }

  async function handleSignOut() {
    await signOut();
    router.replace("/(auth)/login");
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>Dashboard</Text>
          <Text style={styles.tenantBadge}>Tenant: {tenantId?.slice(0, 8) ?? "—"}</Text>
        </View>
        <TouchableOpacity onPress={handleSignOut} style={styles.signOutBtn}>
          <Text style={styles.signOutText}>Sign Out</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.sectionTitle}>Employees</Text>

      {loading ? (
        <ActivityIndicator size="large" color="#4f46e5" style={{ marginTop: 32 }} />
      ) : (
        <FlatList
          data={employees}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <View style={styles.card}>
              <Text style={styles.cardName}>{item.first_name} {item.last_name}</Text>
              <Text style={styles.cardEmail}>{item.email}</Text>
              <View style={styles.cardFooter}>
                <Text style={styles.badge}>{item.status}</Text>
                {item.performance_score != null && (
                  <Text style={styles.score}>Perf: {item.performance_score}</Text>
                )}
                {item.potential_score != null && (
                  <Text style={styles.score}>Pot: {item.potential_score}</Text>
                )}
              </View>
            </View>
          )}
          ListEmptyComponent={
            <Text style={styles.empty}>No employees found for this tenant.</Text>
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0f0f23", padding: 16, paddingTop: 60 },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 20 },
  title: { fontSize: 24, fontWeight: "700", color: "#fff" },
  tenantBadge: { fontSize: 12, color: "#4f46e5", marginTop: 2 },
  signOutBtn: { backgroundColor: "#2a2a4a", paddingHorizontal: 16, paddingVertical: 8, borderRadius: 8 },
  signOutText: { color: "#e5e5e5", fontSize: 14 },
  sectionTitle: { fontSize: 18, fontWeight: "600", color: "#ccc", marginBottom: 12 },
  card: { backgroundColor: "#1a1a2e", borderRadius: 12, padding: 16, marginBottom: 10 },
  cardName: { fontSize: 16, fontWeight: "600", color: "#fff" },
  cardEmail: { fontSize: 13, color: "#888", marginTop: 2 },
  cardFooter: { flexDirection: "row", gap: 12, marginTop: 8 },
  badge: { fontSize: 11, color: "#4f46e5", backgroundColor: "#1e1e3f", paddingHorizontal: 8, paddingVertical: 2, borderRadius: 4, overflow: "hidden" },
  score: { fontSize: 11, color: "#aaa" },
  empty: { color: "#666", textAlign: "center", marginTop: 40 },
});
