"use client";

import { useState, useTransition } from "react";
import { clsx } from "clsx";
import { updateSelfAssessment } from "@/app/(protected)/skills-hub/actions";

interface OntologySkill {
  id: string;
  code: string;
  name: string;
  description: string | null;
  category: string;
  is_active: boolean;
}

interface MySkill {
  id: string;
  skill_id: string;
  self_assessed_level: number;
  manager_assessed_level: number | null;
  verified: boolean;
  skill_name: string;
  skill_code: string;
  skill_category: string;
}

interface RoleSkill {
  id: string;
  skill_id: string;
  required_level: number;
  importance: string;
  skill_name: string;
  skill_code: string;
  skill_category: string;
}

interface Props {
  ontology: OntologySkill[];
  mySkills: MySkill[];
  roleSkills: RoleSkill[];
}

const CATEGORY_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  TECHNICAL: { label: "Técnica", color: "text-blue-400", bg: "bg-blue-500/10 border-blue-500/20" },
  LEADERSHIP: { label: "Liderazgo", color: "text-amber-400", bg: "bg-amber-500/10 border-amber-500/20" },
  FUNCTIONAL: { label: "Funcional", color: "text-emerald-400", bg: "bg-emerald-500/10 border-emerald-500/20" },
  INTERPERSONAL: { label: "Interpersonal", color: "text-purple-400", bg: "bg-purple-500/10 border-purple-500/20" },
  LANGUAGE: { label: "Idioma", color: "text-cyan-400", bg: "bg-cyan-500/10 border-cyan-500/20" },
  CERTIFICATION: { label: "Certificación", color: "text-rose-400", bg: "bg-rose-500/10 border-rose-500/20" },
};

const IMPORTANCE_CONFIG: Record<string, { label: string; color: string }> = {
  CRITICAL: { label: "Crítica", color: "text-red-400" },
  REQUIRED: { label: "Requerida", color: "text-amber-400" },
  PREFERRED: { label: "Preferida", color: "text-blue-400" },
  NICE_TO_HAVE: { label: "Deseable", color: "text-slate-400" },
};

export default function SkillsHubDashboard({ ontology, mySkills, roleSkills }: Props) {
  const [activeTab, setActiveTab] = useState<"radar" | "catalog">("radar");

  const assessedCount = mySkills.length;
  const verifiedCount = mySkills.filter((s) => s.verified).length;
  const gapCount = roleSkills.filter(
    (rs) => {
      const mine = mySkills.find((ms) => ms.skill_id === rs.skill_id);
      return !mine || mine.self_assessed_level < rs.required_level;
    }
  ).length;
  const avgLevel =
    assessedCount > 0
      ? (mySkills.reduce((sum, s) => sum + s.self_assessed_level, 0) / assessedCount).toFixed(1)
      : "—";

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatTile label="Habilidades Evaluadas" value={assessedCount} />
        <StatTile label="Verificadas" value={verifiedCount} accent="emerald" />
        <StatTile label="Brechas Detectadas" value={gapCount} accent="amber" />
        <StatTile label="Nivel Promedio" value={avgLevel} accent="indigo" />
      </div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-lg bg-slate-800/50 p-1">
        {(["radar", "catalog"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={clsx(
              "flex-1 rounded-md px-4 py-2 text-sm font-medium transition",
              activeTab === tab
                ? "bg-indigo-600 text-white shadow"
                : "text-slate-400 hover:text-slate-200"
            )}
          >
            {tab === "radar" ? "Radar de Competencias" : "Catálogo de Habilidades"}
          </button>
        ))}
      </div>

      {activeTab === "radar" ? (
        <SkillRadar mySkills={mySkills} roleSkills={roleSkills} />
      ) : (
        <SkillCatalog ontology={ontology} mySkills={mySkills} />
      )}
    </div>
  );
}

/* ─── Stat Tile ──────────────────────────────────────────────────── */

function StatTile({
  label,
  value,
  accent = "slate",
}: {
  label: string;
  value: string | number;
  accent?: string;
}) {
  const ring =
    accent === "emerald"
      ? "border-emerald-500/30"
      : accent === "amber"
        ? "border-amber-500/30"
        : accent === "indigo"
          ? "border-indigo-500/30"
          : "border-slate-700";
  return (
    <div className={clsx("rounded-xl border bg-slate-900 p-4", ring)}>
      <p className="text-xs font-medium uppercase tracking-wider text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-bold text-white">{value}</p>
    </div>
  );
}

/* ─── Skill Radar / Comparison ───────────────────────────────────── */

function SkillRadar({ mySkills, roleSkills }: { mySkills: MySkill[]; roleSkills: RoleSkill[] }) {
  const [editingSkill, setEditingSkill] = useState<string | null>(null);

  const merged = roleSkills.map((rs) => {
    const mine = mySkills.find((ms) => ms.skill_id === rs.skill_id);
    return {
      skill_id: rs.skill_id,
      skill_name: rs.skill_name,
      skill_category: rs.skill_category,
      required_level: rs.required_level,
      importance: rs.importance,
      self_level: mine?.self_assessed_level ?? 0,
      manager_level: mine?.manager_assessed_level ?? null,
      verified: mine?.verified ?? false,
      has_assessment: !!mine,
    };
  });

  const unmatched = mySkills.filter(
    (ms) => !roleSkills.some((rs) => rs.skill_id === ms.skill_id)
  );

  if (roleSkills.length === 0) {
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-900 p-8 text-center">
        <p className="text-slate-400">
          No hay habilidades requeridas asociadas a tu puesto actual.
        </p>
        <p className="mt-2 text-sm text-slate-500">
          Contacta a tu administrador para configurar el perfil de competencias de tu rol.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Visual radar bars */}
      <div className="rounded-xl border border-slate-700 bg-slate-900 p-6">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wider text-slate-400">
          Perfil vs. Requisitos del Puesto
        </h3>
        <div className="space-y-3">
          {merged.map((item) => {
            const gap = item.required_level - item.self_level;
            const isGap = gap > 0;
            return (
              <div key={item.skill_id} className="group">
                <div className="mb-1 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-white">{item.skill_name}</span>
                    <span
                      className={clsx(
                        "text-xs",
                        IMPORTANCE_CONFIG[item.importance]?.color ?? "text-slate-400"
                      )}
                    >
                      {IMPORTANCE_CONFIG[item.importance]?.label ?? item.importance}
                    </span>
                    {item.verified && (
                      <span className="text-xs text-emerald-400">✓</span>
                    )}
                  </div>
                  <div className="flex items-center gap-3 text-xs">
                    {isGap && (
                      <span className="text-amber-400">Brecha: {gap}</span>
                    )}
                    <button
                      onClick={() =>
                        setEditingSkill(
                          editingSkill === item.skill_id ? null : item.skill_id
                        )
                      }
                      className="text-indigo-400 opacity-0 transition group-hover:opacity-100"
                    >
                      Evaluar
                    </button>
                  </div>
                </div>
                {/* Double bar */}
                <div className="relative h-5 overflow-hidden rounded-full bg-slate-800">
                  {/* Required level background */}
                  <div
                    className="absolute inset-y-0 left-0 rounded-full bg-slate-600/50"
                    style={{ width: `${(item.required_level / 5) * 100}%` }}
                  />
                  {/* Self assessed level foreground */}
                  <div
                    className={clsx(
                      "absolute inset-y-0 left-0 rounded-full transition-all",
                      isGap ? "bg-amber-500/80" : "bg-emerald-500/80"
                    )}
                    style={{ width: `${(item.self_level / 5) * 100}%` }}
                  />
                  <div className="absolute inset-0 flex items-center justify-between px-2 text-xs font-medium text-white">
                    <span>Tú: {item.self_level}/5</span>
                    <span className="text-slate-300">Req: {item.required_level}/5</span>
                  </div>
                </div>
                {editingSkill === item.skill_id && (
                  <LevelSelector
                    skillId={item.skill_id}
                    currentLevel={item.self_level}
                    onDone={() => setEditingSkill(null)}
                  />
                )}
              </div>
            );
          })}
        </div>
        <div className="mt-4 flex items-center gap-4 text-xs text-slate-500">
          <span className="flex items-center gap-1">
            <span className="inline-block h-2.5 w-2.5 rounded-full bg-emerald-500/80" /> Tu nivel
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block h-2.5 w-2.5 rounded-full bg-amber-500/80" /> Brecha
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block h-2.5 w-2.5 rounded-full bg-slate-600/50" /> Requerido
          </span>
        </div>
      </div>

      {/* Skills not required by role but self-assessed */}
      {unmatched.length > 0 && (
        <div className="rounded-xl border border-slate-700 bg-slate-900 p-6">
          <h3 className="mb-4 text-sm font-semibold uppercase tracking-wider text-slate-400">
            Habilidades Adicionales (fuera del perfil del puesto)
          </h3>
          <div className="grid gap-3 sm:grid-cols-2">
            {unmatched.map((ms) => (
              <div
                key={ms.id}
                className="flex items-center justify-between rounded-lg border border-slate-700 bg-slate-800/50 px-4 py-3"
              >
                <div>
                  <span className="text-sm font-medium text-white">{ms.skill_name}</span>
                  <span
                    className={clsx(
                      "ml-2 text-xs",
                      CATEGORY_CONFIG[ms.skill_category]?.color ?? "text-slate-400"
                    )}
                  >
                    {CATEGORY_CONFIG[ms.skill_category]?.label ?? ms.skill_category}
                  </span>
                </div>
                <div className="flex items-center gap-1">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <span
                      key={i}
                      className={clsx(
                        "h-2 w-2 rounded-full",
                        i < ms.self_assessed_level ? "bg-indigo-400" : "bg-slate-700"
                      )}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/* ─── Level Selector ─────────────────────────────────────────────── */

function LevelSelector({
  skillId,
  currentLevel,
  onDone,
}: {
  skillId: string;
  currentLevel: number;
  onDone: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function handleSelect(level: number) {
    setError(null);
    startTransition(async () => {
      const result = await updateSelfAssessment(skillId, level);
      if (result.error) {
        setError(result.error);
      } else {
        onDone();
      }
    });
  }

  return (
    <div className="mt-2 flex items-center gap-2 rounded-lg bg-slate-800 p-3">
      <span className="text-xs text-slate-400">Auto-evaluación:</span>
      {[1, 2, 3, 4, 5].map((level) => (
        <button
          key={level}
          disabled={pending}
          onClick={() => handleSelect(level)}
          className={clsx(
            "flex h-8 w-8 items-center justify-center rounded-lg text-sm font-medium transition",
            level === currentLevel
              ? "bg-indigo-600 text-white"
              : "bg-slate-700 text-slate-300 hover:bg-slate-600"
          )}
        >
          {level}
        </button>
      ))}
      <button
        onClick={onDone}
        className="ml-auto text-xs text-slate-500 hover:text-slate-300"
      >
        Cancelar
      </button>
      {error && <span className="text-xs text-red-400">{error}</span>}
    </div>
  );
}

/* ─── Skill Catalog ──────────────────────────────────────────────── */

function SkillCatalog({
  ontology,
  mySkills,
}: {
  ontology: OntologySkill[];
  mySkills: MySkill[];
}) {
  const [filter, setFilter] = useState<string>("ALL");
  const [search, setSearch] = useState("");

  const categories = Array.from(new Set(ontology.map((s) => s.category)));

  const filtered = ontology.filter((s) => {
    if (filter !== "ALL" && s.category !== filter) return false;
    if (search && !s.name.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const grouped = filtered.reduce<Record<string, OntologySkill[]>>((acc, s) => {
    const cat = s.category;
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(s);
    return acc;
  }, {});

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="text"
          placeholder="Buscar habilidad..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white placeholder-slate-500 outline-none focus:border-indigo-500"
        />
        <div className="flex flex-wrap gap-1">
          <button
            onClick={() => setFilter("ALL")}
            className={clsx(
              "rounded-md px-3 py-1 text-xs font-medium transition",
              filter === "ALL"
                ? "bg-indigo-600 text-white"
                : "bg-slate-800 text-slate-400 hover:text-slate-200"
            )}
          >
            Todas
          </button>
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setFilter(cat)}
              className={clsx(
                "rounded-md px-3 py-1 text-xs font-medium transition",
                filter === cat
                  ? "bg-indigo-600 text-white"
                  : "bg-slate-800 text-slate-400 hover:text-slate-200"
              )}
            >
              {CATEGORY_CONFIG[cat]?.label ?? cat}
            </button>
          ))}
        </div>
      </div>

      {/* Grouped Skills */}
      {Object.entries(grouped).map(([cat, skills]) => (
        <div key={cat}>
          <h3
            className={clsx(
              "mb-3 text-sm font-semibold uppercase tracking-wider",
              CATEGORY_CONFIG[cat]?.color ?? "text-slate-400"
            )}
          >
            {CATEGORY_CONFIG[cat]?.label ?? cat} ({skills.length})
          </h3>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {skills.map((skill) => {
              const mine = mySkills.find((ms) => ms.skill_id === skill.id);
              return (
                <SkillCard key={skill.id} skill={skill} myLevel={mine?.self_assessed_level} />
              );
            })}
          </div>
        </div>
      ))}

      {filtered.length === 0 && (
        <div className="rounded-xl border border-slate-700 bg-slate-900 p-8 text-center">
          <p className="text-slate-400">No se encontraron habilidades.</p>
        </div>
      )}
    </div>
  );
}

/* ─── Skill Card (Catalog) ───────────────────────────────────────── */

function SkillCard({
  skill,
  myLevel,
}: {
  skill: OntologySkill;
  myLevel?: number;
}) {
  const [showAssess, setShowAssess] = useState(false);
  const catConf = CATEGORY_CONFIG[skill.category];

  return (
    <div
      className={clsx(
        "rounded-xl border p-4 transition hover:border-slate-600",
        catConf?.bg ?? "bg-slate-900 border-slate-700"
      )}
    >
      <div className="flex items-start justify-between">
        <div>
          <h4 className="text-sm font-semibold text-white">{skill.name}</h4>
          <span className={clsx("text-xs", catConf?.color ?? "text-slate-400")}>
            {catConf?.label ?? skill.category}
          </span>
        </div>
        {myLevel !== undefined && (
          <div className="flex items-center gap-0.5">
            {Array.from({ length: 5 }).map((_, i) => (
              <span
                key={i}
                className={clsx(
                  "h-1.5 w-1.5 rounded-full",
                  i < myLevel ? "bg-indigo-400" : "bg-slate-600"
                )}
              />
            ))}
          </div>
        )}
      </div>
      {skill.description && (
        <p className="mt-2 text-xs leading-relaxed text-slate-400">{skill.description}</p>
      )}
      <div className="mt-3 flex items-center justify-between">
        {myLevel !== undefined ? (
          <span className="text-xs text-slate-500">Tu nivel: {myLevel}/5</span>
        ) : (
          <span className="text-xs text-slate-600">Sin evaluar</span>
        )}
        <button
          onClick={() => setShowAssess(!showAssess)}
          className="text-xs text-indigo-400 hover:text-indigo-300"
        >
          {showAssess ? "Cerrar" : "Evaluar"}
        </button>
      </div>
      {showAssess && (
        <LevelSelector
          skillId={skill.id}
          currentLevel={myLevel ?? 0}
          onDone={() => setShowAssess(false)}
        />
      )}
    </div>
  );
}
