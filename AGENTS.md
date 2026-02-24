# Agent Guidelines for This Project

This document provides guidelines for AI agents working in this repository.

## Project Overview

This is a Next.js documentation site using Fumadocs. It includes:
- Next.js 16.1.6 with App Router
- TypeScript with strict mode
- Biome for linting and formatting
- Tailwind CSS 4 for styling
- Fumadocs (core + MDX + UI) for documentation
- Additional libraries:
  - `@hugeicons/react` for icons
  - `lucide-react` for icons
  - `recharts` for charts
  - `radix-ui` for UI primitives
  - `mermaid` for diagrams
  - `class-variance-authority` for component variants

## Commands

### Development
```bash
npm run dev          # Start development server
npm run build        # Build for production
npm start           # Start production server
```

### Linting & Formatting
```bash
npm run lint        # Run Biome linter
npm run format      # Format code with Biome
npm run types:check # Run TypeScript type checking (includes Fumadocs MDX processing)
```

### Running a Single Test
**No test framework is currently configured.** If you need to add tests, consider:
- Vitest for unit tests
- Playwright for e2e tests

## Code Style Guidelines

### General Principles
- Use TypeScript with strict mode enabled
- Prefer explicit types over `any`
- Use functional components with hooks
- Keep components small and focused
- Use absolute imports with `@/` path alias

### Imports
- Use absolute imports with `@/` prefix (e.g., `import { source } from "@/lib/source"`)
- Group imports in this order: external, internal, relative
- Let Biome organize imports automatically with `npm run format`

### Formatting (Biome)
- 2-space indentation
- Single quotes for strings
- Trailing commas where valid
- Run `npm run format` before committing

### TypeScript
- Always enable strict mode
- Avoid `any`, use `unknown` when type is uncertain
- Use type inference when obvious
- Explicitly type function parameters and return types
- Use interfaces for object shapes, types for unions/aliases

### Naming Conventions
- **Files**: kebab-case for config files (e.g., `source.config.ts`), camelCase for TypeScript files
- **Components**: PascalCase (e.g., `SearchDialog`)
- **Functions/variables**: camelCase
- **Constants**: SCREAMING_SCASE for global constants, PascalCase for component names
- **Types/interfaces**: PascalCase with `Type` suffix for types (optional), or simple nouns

### React/Next.js Patterns
- Use Server Components by default, add `"use client"` only when needed
- Use async/await for server-side data fetching
- Handle loading and error states appropriately
- Use proper Next.js caching strategies when needed

### Error Handling
- Use try/catch for async operations
- Create custom error types/classes for domain-specific errors
- Return proper HTTP status codes in API routes
- Use Next.js error boundaries for client-side errors

### Tailwind CSS
- Use utility classes for styling
- Use `cn()` from `@/lib/cn` for conditional class merging
- Keep custom CSS minimal; prefer Tailwind utilities

### Documentation (Fumadocs)
- MDX files go in `content/docs/`
- Use frontmatter for metadata (title, description, etc.)
- Reference the Fumadocs documentation at https://fumadocs.dev

## File Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── api/               # API routes
│   ├── docs/              # Documentation pages
│   ├── (home)/            # Home page routes
│   └── *.tsx              # Page components
├── components/            # React components
│   ├── ai/               # AI-related components
│   └── mdx/              # MDX components
├── constants/            # Global constants
├── lib/                   # Utility functions
│   ├── cn.ts             # Class name merging
│   ├── source.ts         # Fumadocs source config
│   ├── utils.ts          # General utilities
│   └── layout.shared.tsx # Shared layout components
├── mdx-components.tsx    # MDX component mappings
└── app/global.css        # Global styles
content/
└── docs/                 # MDX documentation files
    ├── index.mdx         # Home documentation page
    ├── schemas/          # Schema documentation
    └── components/       # Component documentation
```

## Common Tasks

### Adding a New API Route
1. Create file in `src/app/api/[route-name]/route.ts`
2. Export named handlers: `GET`, `POST`, etc.
3. Use proper HTTP status codes

### Adding a New Page
1. Create file in `src/app/[page-name]/page.tsx`
2. Use Server Component by default
3. Add `"use client"` directive if client-side interactivity is needed

### Adding Documentation
1. Create MDX file in `content/docs/`
2. Add frontmatter with title and description
3. Optionally add to a `meta.json` in the same folder for navigation

## Configuration Files

- `biome.json` - Linting and formatting rules
- `tsconfig.json` - TypeScript configuration
- `src/lib/source.ts` - Fumadocs source configuration
- `.vscode/settings.json` - VS Code workspace settings

## Notes for AI Agents

- Always run `npm run lint` and `npm run types:check` before completing a task
- Use `npm run format` to fix formatting issues
- Do not commit secrets or API keys to the repository
- Follow the existing code patterns in the codebase
