# Changes Log

This file documents modifications made to this fork of the original Maybe Finance project, as required by AGPLv3 Section 5(a).

## 2025-12-06
- Added release-drafter GitHub Action for automated release notes and version tagging via PR labels

## 2025-12-03
- Replaced OpenAI with Anthropic Claude for all AI-powered features (chat, auto-categorization, merchant detection)
- Added model selection toggle between "Fast" (Haiku 4.5) and "Intelligent" (Sonnet 4.5) modes in chat interface
- Updated README with proper attribution to original Maybe Finance authors (AGPLv3 compliance)
- Added "Source Code" link to application footer (AGPLv3 Section 13 compliance)
- Added SOURCE_CODE_URL environment variable for configurable source code link
- Updated footer copyright to attribute Perhaps contributors and original Maybe Finance
- Fixed rules page crash when compound conditions have no sub-conditions
- Added validation to prevent creating compound conditions without sub-conditions
- Fixed rule form to preserve state (conditions, actions) when validation fails
- Fixed GoCardless callback crash by adding error handling for missing requisitions
- Fixed Docker Compose database credentials mismatch issue
- Added full containerized development mode with hot reloading via Docker Compose profiles
- Added Makefile with convenient Docker development commands
- Fixed GoCardless callback session loss by using Redis cache instead of session storage for cross-site OAuth flows
- Added CACHE_REDIS_URL configuration to Docker Compose for Redis-based caching
- Fixed Docker development environment conflicts by masking host .env file in containers
- Fixed development environment caching to use Redis when available (required for GoCardless OAuth)
- Fixed GoCardless sync failure by removing strict balance validation (accounts can sync without immediate balance data)

## 2025-12-01
- Fixed GoCardless bank filtering functionality using existing list-filter Stimulus controller
- Fixed GoCardless bank selection form parameter namespacing (400 error)
- Enabled hotwire-livereload for automatic browser refresh during development
- Fixed Rails credentials handling to be optional in development environment
- Added compose.dev.yml for running PostgreSQL and Redis in Docker for local development

## 2025-11-30
- Added GoCardless Bank Account Data integration for European bank account syncing
- Renamed maybe-design-system directory to perhaps-design-system (completing rename)
- Refactored compose.yml and compose.example.yml to build from local Dockerfile
- Added GoCardless UI improvements: loading state, reconnect flow for expired connections

## 2025-08-06
- Forked from Maybe Finance (github.com/maybe-finance/maybe) after project abandonment
- Renamed all occurrences of "maybe" to "perhaps" in filenames and code to avoid trademark issues