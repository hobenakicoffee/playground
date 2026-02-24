import type { ReactNode } from "react";

import { cn } from "@/lib/cn";

function Preview({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex min-h-15 items-center rounded-xl border border-border bg-background p-4",
        className,
      )}
    >
      {children}
    </div>
  );
}

export { Preview };
