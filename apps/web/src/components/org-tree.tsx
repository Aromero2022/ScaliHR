"use client";

export interface OrgNode {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  manager_id: string | null;
  status: string;
  job_title: string | null;
  department_name: string | null;
}

interface TreeProps {
  nodes: OrgNode[];
}

export default function OrgTree({ nodes }: TreeProps) {
  const childrenMap = new Map<string | null, OrgNode[]>();
  for (const n of nodes) {
    const key = n.manager_id;
    if (!childrenMap.has(key)) childrenMap.set(key, []);
    childrenMap.get(key)!.push(n);
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
  node: OrgNode;
  childrenMap: Map<string | null, OrgNode[]>;
  depth: number;
}) {
  const children = childrenMap.get(node.id) ?? [];

  return (
    <div className="flex flex-col items-center">
      <PersonCard node={node} depth={depth} />

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

function PersonCard({ node, depth }: { node: OrgNode; depth: number }) {
  const initials = `${node.first_name[0]}${node.last_name[0]}`;

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
        {node.first_name} {node.last_name}
      </p>
      <p className="text-xs text-slate-400">{node.job_title ?? "—"}</p>
      <p className="text-xs text-slate-600">{node.department_name ?? ""}</p>
    </div>
  );
}
