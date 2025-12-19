# Changes Log

This file documents modifications made to this fork of the original Maybe Finance project, as required by AGPLv3 Section 5(a).

## 2025-12-19
- **Made MCP server accessible via Docker Compose for local LLM integration**
  - Added development API key seed file that creates a test API key (`pk_dev_mcp_test_key_12345678901234567890123456789012`) for immediate MCP server access
  - Configured Active Record encryption keys for development environment to support encrypted API key storage
  - Created comprehensive MCP Server Usage Guide (docs/MCP_SERVER.md) with Docker Compose setup instructions, authentication, and usage examples
  - MCP server endpoint (`POST /api/v1/mcp`) now fully functional with demo data in Docker containers
  - Documented all 6 MCP tools: ping, list_accounts, get_account, list_transactions, query_transactions, financial_summary
  - Fixed Sync model callback error when destroying records during data cleaning (added guard for destroyed records)
- Enhanced demo seed data with comprehensive merchant, tag, and transaction notes for robust MCP server testing
  - Added 32 merchant records (grocery stores, restaurants, gas stations, utilities, entertainment, etc.)
  - Added 10 tag types (business, personal, tax deductible, reimbursable, subscription, recurring, vacation, etc.)
  - Enhanced ~1,500+ transactions with merchant associations for query_transactions merchant filtering
  - Enhanced ~2,300+ transactions with tag associations for query_transactions tag filtering
  - Added contextual notes to ~100+ transaction entries for richer financial context
- Implemented FinancialSummary MCP tool for aggregate financial analytics including net worth, cash flow, and category/merchant spending analysis
- Implemented ListTransactions MCP tool for listing transactions with date range and account filtering, pagination support
- Implemented GetAccount MCP tool for retrieving detailed account information including balance history
- MCP server now provides get_account tool with balance history summaries (30/90/365 day periods)

## 2025-12-13
- **Optimized Docker production image size from 927MB to 507MB (45.3% reduction)**
  - First optimization: 927MB → 724MB (22% reduction) by excluding development/test gems
  - Second optimization: 724MB → 643MB (11% reduction) by cleaning build artifacts before copying
  - Third optimization: 643MB → 531MB (17% reduction) by removing tailwindcss-ruby gem after asset precompilation
  - Fourth optimization: 531MB → 507MB (5% reduction) by switching from Debian Bookworm to Debian Trixie base image
- Upgraded Ruby version from 3.4.4 to 3.4.7 and switched to Debian Trixie (testing) base image
- Moved development-only gems (lookbook, rack-mini-profiler, vernier) to development group in Gemfile
- Changed BUNDLE_WITHOUT from "development" to "development:test" to exclude test gems (selenium-webdriver, capybara, etc.)
- Added conditional loading for lookbook configuration and routes to prevent production errors
- Enhanced .dockerignore to exclude test files, documentation, and development tools from Docker build context
- Implemented pre-copy cleanup in build stage to remove gem documentation, build artifacts (ext/ dirs), and rdoc gem
- Removed tailwindcss-ruby gem (107MB) after asset precompilation as it's only needed during build
- Removed unnecessary Rails files (compose files, Makefile, LICENSE, etc.) before final stage copy
- Final bundle size: 146MB (down from 352MB = 59% reduction), final /rails size: 14MB (down from 76MB = 82% reduction)
- Added Trufflehog secret scanning to CI workflow to detect committed credentials in PRs
- Fixed CI system test failures: added PERHAPS_AI_ENABLED env for ChatsTest and wait for form submission in TradesTest
- Fixed GoCardless provider tests by adding Content-Type headers to WebMock stubs for proper JSON parsing
- Updated GitHub workflows for forked repository (andreaswachs/perhaps) with release-drafter SEMVER tagging and container publishing

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