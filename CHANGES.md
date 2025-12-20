# Changes Log

This file documents modifications made to this fork of the original Maybe Finance project, as required by AGPLv3 Section 5(a).

## 2025-12-20 (Current)
- **Fixed CI test failure: Removed unnecessary LookbooksController**
  - LookbooksController was causing Zeitwerk eager loader errors in test environment because Lookbook gem is only in development group
  - Lookbook provides its own default preview controller, so custom controller is unnecessary
  - Deleted app/controllers/lookbooks_controller.rb and removed preview_controller configuration from application.rb
  - Tests now pass cleanly without Zeitwerk NameError
- **Completed kubernetes-separation feature: Added Helm PDB, HPA, and anti-affinity configuration (Task 06)**
  - Created PodDisruptionBudget templates for web and worker deployments to ensure minimum availability during cluster maintenance
  - Created HorizontalPodAutoscaler templates for automatic scaling based on CPU and memory utilization
  - Added pod anti-affinity helper functions to spread pods across nodes for improved resilience
  - Updated deployment templates to support custom affinity or default pod anti-affinity rules
  - Enhanced values.yaml with complete PDB and HPA configuration for both web and worker components
  - Created production-ready example values file (values-production.yaml) with 3 replicas and HPA enabled
  - Created minimal example values file (values-minimal.yaml) for testing/development deployments
  - Enhanced NOTES.txt with autoscaling and PDB status information and monitoring commands
  - Created comprehensive Chart README with installation, configuration, and troubleshooting documentation
  - All Helm chart validations pass: linting clean, templates render correctly, all configurations work as expected
  - All project tests pass (1084 tests), rubocop clean, ERB linting clean, security scan clean (0 warnings)
- **Fixed Docker image build and test compatibility issues**
  - Updated Ruby version from 3.4.4 to 3.4.7 to match available Docker base image (ruby:3.4.7-slim-trixie)
  - Updated Gemfile.lock to Ruby 3.4.7 with compatible gem versions
  - Pinned Pagy to version 9.3.5 (instead of latest 43.2.2) to ensure overflow and array extras availability
  - Fixed Minitest 6.0.0 incompatibility with Rails 7.2.3 by pinning to Minitest 5.25.5
  - Removed redundant `require "minitest/mock"` from test_helper.rb (provided by rails/test_help in Ruby 3.4+)
  - Docker image builds successfully (520MB) and all 1064 tests can now run
  - All CI checks pass: Rubocop linting, ERB linting, and Brakeman security scan (0 warnings)
- **Added OIDC signing key documentation to Docker hosting guide**
  - Documents how to generate and configure `OPENID_SIGNING_KEY` for production deployments
  - Explains `APP_HOST` environment variable requirement for OIDC issuer URL
  - Includes security considerations for key management, rotation, and backup
- **Fixed TypeError in OIDC token generation (signing_key configuration)**
  - The `signing_key` configuration in doorkeeper-openid_connect expects a string value, not a block
  - Changed from `signing_key do ... end` to `signing_key(...)` to evaluate and pass the key string directly
  - Added logic to persist generated development keys to `config/openid_key.pem`
  - Added `config/openid_key.pem` to .gitignore
- **Fixed OAuth flow not returning to client after login**
  - OAuth authorization URL is now stored in session before redirecting to login
  - After login, user is redirected back to OAuth authorization flow instead of dashboard
  - Handles both regular login (SessionsController) and MFA verification (MfaController)
  - Added `redirect_to_after_login` helper to Authentication concern for shared behavior
- **Fixed DoubleRenderError when OAuth clients use prompt=consent (OIDC)**
  - Created monkey-patch in `config/initializers/doorkeeper_openid_connect_patch.rb`
  - The doorkeeper-openid_connect gem's `handle_oidc_prompt_param!` method calls `render :new` when `prompt=consent` is passed, but doesn't clear any existing response body first
  - Patch clears `response_body` and `@_response_body` before rendering (same approach the gem uses in `handle_oidc_error!`)
  - Also created custom `Oauth::AuthorizationsController` as additional safety check
  - Updated routes.rb to use `controllers authorizations: "oauth/authorizations"`
- **Fixed OIDC configuration error that prevented MCP OAuth token exchange**
  - Added missing `auth_time_from_resource_owner` block to doorkeeper_openid_connect.rb initializer
  - The OIDC spec requires this configuration for ID token generation; without it, `/oauth/token` would fail with `InvalidConfiguration` error
  - Uses `resource_owner.created_at` as the auth_time claim value
  - Fixed 2 MCP controller tests that were missing the required `email` scope
  - All 17 MCP controller tests and 10 OAuth dynamic registration tests now pass
- **Implemented OAuth 2.0 Dynamic Client Registration (RFC 7591) for MCP clients**
  - Added `/oauth/register` endpoint for automatic OAuth application registration
  - MCP clients like Claude Code can now self-register without manual OAuth setup
  - Custom discovery endpoints include `registration_endpoint`:
    - `/.well-known/openid-configuration` (OIDC Discovery)
    - `/.well-known/oauth-authorization-server` (RFC 8414)
  - Added `/.well-known/oauth-protected-resource` endpoint (RFC 9728) for protected resource metadata
  - Supports RFC 7591 client metadata: redirect_uris, client_name, token_endpoint_auth_method, scope
  - Public clients (token_endpoint_auth_method: "none") supported for mobile/CLI apps
  - Default scopes for MCP clients: openid, profile, email, read
  - Created comprehensive integration tests (10 tests covering registration, all discovery endpoints)
  - All tests passing, rubocop clean

## 2025-12-19
- **Updated MCP Server documentation and migration guide (Task 06)**
  - Completely updated docs/MCP_SERVER.md with comprehensive OAuth 2.0 + OIDC authentication guide
  - Added step-by-step OIDC Authentication Flow section covering authorization, PKCE, token exchange, and refresh
  - Created detailed Migration Guide from API keys to OAuth with common issues and testing tools
  - Updated all curl examples to use Bearer tokens instead of API keys
  - Enhanced troubleshooting section with OAuth-specific errors and solutions
  - Updated security notes for OAuth token handling and storage best practices
  - Created example Python OAuth client script (docs/examples/mcp_oauth_example.py) demonstrating complete flow
- **Implemented OIDC Scope Validation for MCP endpoint (Task 05)**
  - Added two new scope validation methods to BaseController: `require_oidc_scopes!` and `require_full_oidc_scopes!`
  - MCP endpoint now validates that tokens include both OIDC scopes (openid, profile, email) AND data scopes (read/read_write)
  - Comprehensive error responses indicate which scopes are missing and what's required
  - Tokens with only OIDC scopes are rejected (even with valid authentication)
  - Tokens with only data scopes are rejected (missing OpenID Connect identity verification)
  - Error messages provide documentation links and clear guidance for scope configuration
  - Added 11 new OIDC scope validation tests covering all scope combinations and error cases
  - Rubocop clean with space formatting fixes
  - See docs/MCP_SERVER.md for detailed scope requirements
- **BREAKING CHANGE: MCP Endpoint Now Requires OAuth 2.0 + OIDC (Task 04)**
  - MCP endpoint (`POST /api/v1/mcp`) now requires OAuth 2.0 Bearer token authentication
  - API keys are no longer accepted for MCP access (other API endpoints unaffected)
  - Helpful error messages guide users to OAuth 2.0 authorization flow with PKCE
  - Required scopes: `openid profile email read`
  - Deprecation error includes migration guide with step-by-step OAuth setup instructions
  - OAuth endpoints: /oauth/authorize, /oauth/token, /oauth/userinfo, /.well-known/openid-configuration
  - Updated BaseController comments to clarify OAuth rate limiting behavior
  - Created comprehensive tests for OAuth-only authentication (10 tests covering OAuth acceptance, API key rejection, scope validation)
  - All 1040 tests passing, rubocop clean
  - See docs/MCP_SERVER.md for OAuth authentication guide
- **Implemented MCP OAuth application configuration with OIDC scopes (Task 03)**
  - Created dedicated "MCP Client" OAuth application for LLM clients (Claude Desktop, ChatGPT, etc.)
  - Configured 4 redirect URIs: claude://oauth/callback, http://localhost:8080/callback, http://localhost:3000/oauth/callback, urn:ietf:wg:oauth:2.0:oob
  - Scopes configured: openid, profile, email, read, read_write (OIDC + data access)
  - Marked as public client (confidential: false) with PKCE enforcement
  - Updated existing iOS OAuth app with new OIDC-compatible scopes (openid profile email read)
  - Created comprehensive integration tests for MCP OAuth flow (5 tests covering app configuration, scopes, and token creation)
  - All 1043 tests passing, no rubocop or erb_lint violations
- **Implemented OIDC Discovery and UserInfo endpoints for MCP authentication (Task 02)**
  - Added 8 OIDC claim methods to User model (oidc_sub, oidc_email, oidc_email_verified, oidc_name, oidc_given_name, oidc_family_name, oidc_family_id, oidc_role)
  - Configured OIDC claims in doorkeeper_openid_connect initializer with scope-aware claim inclusion
  - Profile scope includes name, given_name, family_name, family_id, role; email scope includes email, email_verified
  - Added comprehensive unit tests for all OIDC claim methods (9 new tests)
  - Added integration tests for UserInfo endpoint with scope validation (3 new tests)
  - Updated docs/MCP_SERVER.md with OIDC endpoint documentation and usage examples
  - All 1038 existing tests continue to pass, rubocop/erb_lint/brakeman all pass
- **Implemented OpenID Connect (OIDC) foundation for MCP authentication (Task 01)**
  - Added doorkeeper-openid_connect gem (v1.8.11) to enable OIDC authentication
  - Created OIDC initializer configuration for ID token generation and claims
  - Added OIDC scopes (openid, profile, email) to optional_scopes
  - Discovery endpoint (/.well-known/openid-configuration) now functional
  - All tests passing (1026 tests), no rubocop violations
  - Lays groundwork for replacing API key authentication with OAuth 2.0 + OIDC on MCP endpoint

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