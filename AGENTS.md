# AGENTS.md

This file guides agentic coding agents working in the Perhaps Finance codebase.

## Build / Lint / Test Commands

### Ruby / Rails
- `bin/rails test` - Run all tests
- `bin/rails test test/models/user_test.rb` - Run specific test file
- `bin/rails test test/models/user_test.rb:42` - Run specific test at line
- `bin/rails test:db` - Run tests with database reset
- `bin/rails test:system` - Run system tests (use sparingly - they take longer)
- `bin/rails console` - Open Rails console
- `bin/dev` - Start development server with automatic browser reload

### Linting & Formatting
- `bin/rubocop` - Run Ruby linter
- `bin/rubocop -f github -a` - Ruby linting with auto-correct
- `bundle exec erb_lint ./app/**/*.erb -a` - ERB linting with auto-correct
- `bin/brakeman` - Run security analysis
- `npm run lint` - Check JavaScript/TypeScript code
- `npm run lint:fix` - Fix JavaScript/TypeScript issues
- `npm run format` - Format JavaScript/TypeScript code

### Docker (alternative)
- `make test` - Run all tests in container
- `make lint` - Run rubocop and erb_lint in container
- `make security` - Run brakeman security scan in container

## Code Style Guidelines

### Ruby / Rails
- **Indentation:** 2 spaces (inherited from rubocop-rails-omakase)
- **Style:** Follow rubocop-rails-omakase conventions
- **Authentication:** Use `Current.user`, NOT `current_user`. Use `Current.family`, NOT `current_family`
- **Business Logic:** Place in `app/models/`, avoid `app/services/` unless necessary
- **Models:** Models should answer questions about themselves: `account.balance_series` not `AccountSeries.new(account).call`
- **State Machines:** Use AASM for state management
- **ActiveStorage:** For file uploads, always use webp variants with quality 80

### JavaScript / Stimulus
- **Formatter:** Biome (double quotes)
- **Linter:** Biome recommended rules enabled
- **Framework:** Stimulus for interactivity, Hotwire (Turbo) for page updates
- **Style:** Use declarative actions in HTML: `data-action="click->toggle#toggle"`
- **Controllers:** Keep lightweight (< 7 targets), use private methods, single responsibility

### Frontend (HTML/ERB)
- **Hotwire-First:** Prefer native HTML over JS components
  - Use `<dialog>` for modals, `<details><summary>` for disclosures
- **Turbo Frames:** For page sections over client-side solutions
- **State Management:** Query params over localStorage/sessions
- **Formatting:** Server-side for currencies, numbers, dates

### TailwindCSS Design System
- **Always reference:** `app/assets/tailwind/perhaps-design-system.css`
- **Use functional tokens:** `text-primary` instead of `text-white`, `bg-container` instead of `bg-white`
- **NEVER create new styles** in design system files without permission
- **Icons:** Always use `icon` helper from `application_helper.rb`, NEVER `lucide_icon` directly

### Components (ViewComponent vs Partials)
- **Use ViewComponent when:** Complex logic/styling, reusable across contexts, variants/sizes needed, interactive behavior, accessibility features
- **Use Partial when:** Static HTML with minimal logic, used in few contexts, simple template content

### Testing
- **Framework:** Minitest + fixtures (NEVER RSpec or factories)
- **Fixtures:** Keep minimal (2-3 per model for base cases), create edge cases on-the-fly
- **Coverage:** Test only critical code paths, system tests sparingly
- **Test boundaries correctly:**
  - Commands: test they were called with correct params
  - Queries: test output
  - Don't test implementation details of other classes
- **Stubs/Mocks:** Use `mocha` gem, prefer `OpenStruct` for mock instances

### Naming Conventions
- **Classes:** PascalCase (e.g., `User`, `AccountBalance`)
- **Methods:** snake_case (e.g., `current_balance`, `update_user`)
- **Variables:** snake_case (e.g., `current_user`, `account_balance`)
- **Constants:** SCREAMING_SNAKE_CASE (e.g., `RATE_LIMITS`, `DEFAULT_TIER`)

### Error Handling
- **Validations:** Simple validations (null checks, unique indexes) in DB, ActiveRecord validations for convenience
- **Complex validations:** Business logic in ActiveRecord
- **Exceptions:** Use `rescue => e` with specific exceptions when possible, always re-raise or handle appropriately

### Import Organization (JavaScript)
- Biome organizes imports automatically
- Order: external libraries first, then internal modules

### Database
- **Migrations:** Run with `bin/rails db:migrate` (never run automatically)
- **Validations:** Prefer database-level for simple constraints, ActiveRecord for form validation convenience
- **Queries:** Optimize to avoid N+1, use `includes`/`joins` when loading associations

## Pre-Commit Requirements
Before committing or creating PRs, run:
1. `bin/rails test` - All tests must pass
2. `bin/rubocop -f github -a` - Auto-fix lint issues
3. `bundle exec erb_lint ./app/**/*.erb -a` - Auto-fix ERB issues
4. `bin/brakeman --no-pager` - Security scan must pass

## Project Conventions

1. **Minimize Dependencies:** Push Rails to its limits before adding new gems. Strong technical reason required for new dependencies.
2. **Skinny Controllers, Fat Models:** Business logic in models, not controllers. Use concerns and POROs for organization.
3. **Hotwire-First Frontend:** Leverage native HTML, Turbo frames, server-side formatting.
4. **Optimize for Simplicity:** Prioritize good OOP design over performance, focus on critical/global areas (avoid N+1).
5. **No Comments:** Unless explicitly requested, do NOT add comments to code.
6. **No i18n:** Ignore i18n methods and files. Hardcode strings in English for speed.
7. **No Rails Server:** Do NOT run `rails server` in responses.
