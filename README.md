# হবে নাকি Coffee? Playground

This is a Next.js 16.1.6 documentation site built with [Fumadocs](https://github.com/fuma-nama/fumadocs) for the **হবে নাকি Coffee?** project.

## Features

- **Next.js 16.1.6** with App Router
- **Fumadocs** for MDX-based documentation
- **Tailwind CSS 4** for styling
- **Biome** for linting and formatting
- **TypeScript** with strict mode
- **Radix UI** components
- **@hugeicons/react** for icons
- **lucide-react** for icons
- **recharts** for charts
- **mermaid** for diagrams
- **class-variance-authority** for component variants
- **@hobenakicoffee/libraries** - Internal library with UI components, utilities, and constants
- **next-themes** for dark/light mode theming
- **shadcn** for UI components
- **sonner** for toast notifications
- **tw-animate-css** for animations
- **vaul** for drawer components

## Getting Started

Install dependencies:

```bash
npm install
```

Run the development server:

```bash
npm run dev
# or
pnpm dev
# or
yarn dev
```

Open http://localhost:3000 with your browser to see the result.

## Available Scripts

| Command | Description |
| ------- | ----------- |
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run start` | Start production server |
| `npm run lint` | Run Biome linter |
| `npm run format` | Format code with Biome |
| `npm run types:check` | Run TypeScript type checking |

## Project Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── (home)/             # Landing page route group
│   ├── docs/               # Documentation layout and pages
│   ├── api/                # API routes
│   ├── llms.txt/           # LLMs routes
│   ├── og/                 # Open Graph image generation
│   └── *.tsx               # Page components
├── components/             # React components
│   ├── ai/                 # AI-related components
│   └── mdx/                # MDX custom components
├── lib/                    # Utility functions
│   ├── cn.ts              # Class name merging
│   ├── source.ts          # Fumadocs source config
│   ├── utils.ts           # Utility functions
│   └── layout.shared.tsx  # Shared layout components
├── constants/              # Global constants
│   └── index.ts
├── mdx-components.tsx     # MDX component mappings
└── app/
    └── global.css         # Global styles
content/
└── docs/                   # MDX documentation files
    ├── components/         # Component documentation
    ├── schemas/            # Schema documentation
    └── supabase/           # Supabase documentation
reference/
├── schemas/                # SQL schema files
└── ui/                     # UI component reference
source.config.ts            # Fumadocs configuration
```

## Documentation

Documentation is written in MDX and stored in `content/docs/`. The site uses Fumadocs to render MDX content with support for:

- Custom components
- Syntax highlighting
- Navigation
- Search
- Mermaid diagrams

## Learn More

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API
- [Fumadocs](https://fumadocs.dev) - learn about Fumadocs
