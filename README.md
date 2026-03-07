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
- **@hugeicons/core-free-icons** for icons
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
- **react-day-picker** for date picking

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
│   │   ├── [[...slug]]/    # Catch-all route for docs
│   │   └── layout.tsx      # Docs layout
│   ├── api/                # API routes
│   │   └── search/         # Search API
│   ├── llms.txt/           # LLMs routes
│   ├── llms-full.txt/      # LLMs full routes
│   ├── llms.mdx/           # LLMs MDX routes
│   ├── og/                 # Open Graph image generation
│   └── *.tsx               # Page components
├── components/             # React components
│   ├── ai/                 # AI-related components
│   ├── mdx/                # MDX custom components
│   └── preview.tsx         # Preview component
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

## @hobenakicoffee/libraries

This project uses `@hobenakicoffee/libraries` (v1.12.0) which provides:

### Entry Points

| Entrypoint | Description |
| ---------- | ------------ |
| `@hobenakicoffee/libraries` | Main entry (constants) |
| `@hobenakicoffee/libraries/constants` | Constants and types |
| `@hobenakicoffee/libraries/utils` | Utility functions |
| `@hobenakicoffee/libraries/types` | TypeScript types |
| `@hobenakicoffee/libraries/moderation` | Content moderation |
| `@hobenakicoffee/libraries/providers/theme-provider` | Theme provider |
| `@hobenakicoffee/libraries/lib/utils` | Class merging utilities |
| `@hobenakicoffee/libraries/components/*` | UI components |

### UI Components

Accessible components built on Radix UI: alert, alert-dialog, avatar, badge, breadcrumb, button, button-group, calendar, card, chart, checkbox, dialog, drawer, dropdown-menu, empty, empty-minimal, field, input, input-group, input-otp, item, label, popover, radio-group, select, separator, sheet, sidebar, skeleton, sonner, spinner, table, tabs, textarea, toggle, toggle-group, tooltip.

### Constants

`Visibility`, `productInfo`, `companyInfo`, `PaymentTypes`, `PaymentStatuses`, `PaymentProviders`, `PaymentDirections`, `SupporterPlatforms`, `ServiceTypes`

### Utilities

`checkModeration`, `formatAmount`, `formatSignedAmount`, `formatDate`, `formatNumber`, `formatToPlainText`, `getSocialHandle`, `getSocialUrl`, `getUserNameInitials`, `getUserPageLink`, `openInNewWindow`, `shareToFacebook`, `shareToInstagram`, `shareToLinkedIn`, `shareToX`, `printQrSvg`, `toHumanReadable`, `validatePhoneNumber`

## Learn More

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API
- [Fumadocs](https://fumadocs.dev) - learn about Fumadocs
