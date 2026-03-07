# Playground (Docs)

## Stack
Next.js 16.1.6, TypeScript, Tailwind 4, Fumadocs

## Commands
```bash
npm run dev      # dev
npm run build    # prod
npm run lint     # biome
npm run format   # biome format
npm run types:check
```

## Rules
- `@/` for imports
- Server Components by default
- `cn()` from `@/lib/cn`
- No `any`

## Structure
```
src/app/       # pages, api
src/components/
src/lib/
content/docs/  # MDX
```
