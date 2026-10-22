"use client";

export interface PositionNode {
  id: string;
  position_code: string;
  title: string;
  is_vacant: boolean;
  parent_position_id: string | null;
  department_name: string | null;
  occupant_name: string | null;
  occupant_email: string | null;
  job_classification_title: string | null;
}

interface TreeProps {
  positions: PositionNode[];
}

export default function OrgTree({ positions }: TreeProps) {
  const childrenMap = new Map<string | null, PositionNode[]>();
  for (const p of positions) {
    const key = p.parent_position_id;
    if (!childrenMap.has(key)) childrenMap.set(key, []);
    childrenMap.get(key)!.push(p);
  }

  const roots = childrenMap.get(null) ?? [];

  if (roots.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        No hay datos de organigrama disponibles.
      </p>
    );
  }

  return (
    <div className="flex flex-col items-center gap-8 overflow-x-auto pb-8">
      {roots.map((root) => (
        <Branch key={root.id} node={root} childrenMap={childrenMap} depth={0} />
      ))}
    </div>
  );
}

function Branch({
  node,
  childrenMap,
  depth,
}: {
  node: PositionNode;
  childrenMap: Map<string | null, PositionNode[]>;
  depth: number;
}) {
  const children = childrenMap.get(node.id) ?? [];

  return (
    <div className="flex flex-col items-center">
      <PositionCard node={node} depth={depth} />

      {children.length > 0 && (
        <>
          <div className="h-6 w-px bg-slate-700" />
          <div className="relative flex gap-6">
            {children.length > 1 && (
              <div className="absolute top-0 left-[calc(50%-1px)] h-px w-[calc(100%-3rem)] -translate-x-1/2 bg-slate-700" />
            )}
            {children.map((child) => (
              <div key={child.id} className="flex flex-col items-center">
                <div className="h-6 w-px bg-slate-700" />
                <Branch node={child} childrenMap={childrenMap} depth={depth + 1} />
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function PositionCard({ node, depth }: { node: PositionNode; depth: number }) {
  if (node.is_vacant) {
    return (
      <div className="w-52 rounded-xl border border-dashed border-amber-500/50 bg-slate-900/60 p-4 text-center shadow-lg">
        <div className="mx-auto flex h-10 w-10 items-center justify-center rounded-full bg-amber-900/40 text-lg">
          ?
        </div>
        <p className="mt-2 text-sm font-semibold text-amber-400">
          Vacante
        </p>
        <p className="text-xs text-slate-400">{node.title}</p>
        <p className="text-xs text-slate-600">{node.department_name ?? ""}</p>
        <span className="mt-2 inline-block rounded-full bg-amber-500/10 px-2 py-0.5 text-[10px] font-medium text-amber-400">
          To Be Hired
        </span>
      </div>
    );
  }

  const initials = node.occupant_name
    ? node.occupant_name
        .split(" ")
        .map((w) => w[0])
        .join("")
        .slice(0, 2)
    : "??";

  const ringColor =
    depth === 0
      ? "border-indigo-500/50"
      : depth === 1
        ? "border-emerald-500/40"
        : "border-slate-700";

  const avatarBg =
    depth === 0
      ? "bg-indigo-600"
      : depth === 1
        ? "bg-emerald-600"
        : "bg-slate-700";

  return (
    <div
      className={`w-52 rounded-xl border bg-slate-900 p-4 text-center shadow-lg ${ringColor}`}
    >
      <div
        className={`mx-auto flex h-10 w-10 items-center justify-center rounded-full text-sm font-bold text-white ${avatarBg}`}
      >
        {initials}
      </div>
      <p className="mt-2 text-sm font-semibold text-white">
        {node.occupant_name ?? "—"}
      </p>
      <p className="text-xs text-slate-400">{node.title}</p>
      <p className="text-xs text-slate-600">{node.department_name ?? ""}</p>
    </div>
  );
}
