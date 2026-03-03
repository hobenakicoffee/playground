# Agent Guidelines

## Stack
- Next.js 16.1.6 + App Router
- TypeScript (strict)
- Tailwind CSS 4
- Fumadocs (MDX docs)
- Biome (lint/format)

## Commands
```bash
npm run dev        # dev server
npm run build      # production build
npm run lint       # biome check
npm run format     # biome format --write
npm run types:check # tsc + fumadocs
```

## Rules
- Use `@/` for absolute imports
- Server Components by default; add `"use client"` only when needed
- Use `cn()` from `@/lib/cn` for conditional classes
- Avoid `any`; use `unknown` if uncertain
- Run `npm run lint && npm run types:check` before completing tasks

## Structure
```
src/app/         # pages, api routes
src/components/  # React components
src/lib/         # utilities (cn.ts, utils.ts, source.ts)
content/docs/    # MDX documentation
```

## Docs
- MDX in `content/docs/` with frontmatter (title, description)
- Add `meta.json` in folder for navigation
