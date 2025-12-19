# MCP Server Usage Guide

The Perhaps MCP (Model Context Protocol) server provides financial data access for AI applications and local LLMs. This guide explains how to access and use the MCP server in different deployment scenarios.

## Overview

The MCP server exposes financial data through a JSON-RPC API that supports:
- Account listing and details with balance history
- Transaction queries with advanced filtering (merchants, tags, categories, amounts, dates)
- Financial summaries (net worth, cash flow, spending analysis)

**Endpoint:** `POST /api/v1/mcp`
**Authentication:** OAuth 2.0 Bearer Token (OpenID Connect)
**Protocol:** JSON-RPC 2.0

**BREAKING CHANGE (as of 2025-12-19):** API keys are no longer supported for MCP access. All clients must use OAuth 2.0 with OpenID Connect.

## OIDC Endpoints

The Perhaps MCP server supports OpenID Connect (OIDC) for user authentication and identity management.

### Discovery Endpoint

**Request:**
```bash
curl http://localhost:3000/.well-known/openid-configuration
```

**Response:**
Returns OIDC provider metadata including:
- `issuer`: The base URL of the Perhaps server
- `authorization_endpoint`: OAuth 2.0 authorization endpoint
- `token_endpoint`: OAuth 2.0 token endpoint
- `userinfo_endpoint`: User information endpoint
- `jwks_uri`: JSON Web Key Set URI for token validation
- `scopes_supported`: ["read", "read_write", "openid", "profile", "email"]
- `response_types_supported`: ["code", "token"]
- `subject_types_supported`: ["public"]
- `id_token_signing_alg_values_supported`: ["RS256"]

### UserInfo Endpoint

**Request:**
```bash
curl http://localhost:3000/oauth/userinfo \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Response:**
Returns user claims based on token scopes:
- `openid` scope: Returns `sub` (user ID)
- `profile` scope: Returns `name`, `given_name`, `family_name`, `family_id`, `role`
- `email` scope: Returns `email`, `email_verified`

**Example Response:**
```json
{
  "sub": "12345",
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "email": "john@example.com",
  "email_verified": true,
  "family_id": "family-uuid",
  "role": "admin"
}
```

### OIDC Scopes

For MCP access, tokens must include both OIDC scopes and data scopes:

- `openid` - Required for OIDC authentication
- `profile` - User profile information (name, family_id, role)
- `email` - User email and verification status
- `read` - Read access to financial data
- `read_write` - Read and write access to financial data

**Example:** A token with scopes `openid profile email read` can authenticate via OIDC and read financial data.

## OIDC Authentication Flow

The Perhaps MCP server uses OAuth 2.0 with OpenID Connect for authentication. This provides secure, user-authorized access to financial data.

### Prerequisites

1. **OAuth Application**: Use the generic "MCP Client" application or create your own
2. **Client Credentials**: Get the Client ID from the seed output or OAuth applications page
3. **Redirect URI**: Configure a redirect URI that your application can handle

### Step 1: Get OAuth Application Credentials

Run the seed to create or view the MCP OAuth application:

```bash
bin/rails runner "load Rails.root.join('db/seeds/mcp_oauth_client.rb')"
```

Output includes:
```
MCP OAuth Application configured:
  Name: MCP Client
  Client ID: [your-client-id]
  Redirect URIs:
    - claude://oauth/callback
    - http://localhost:8080/callback
    - http://localhost:3000/oauth/callback
    - urn:ietf:wg:oauth:2.0:oob
```

### Step 2: Generate PKCE Challenge (Required)

PKCE (Proof Key for Code Exchange) is required for public clients:

```bash
# Generate code verifier (43-128 character random string)
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d '+/' | tr '=' '_' | cut -c1-43)
echo "Code Verifier: $CODE_VERIFIER"

# Generate code challenge (SHA256 hash, base64url encoded)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
echo "Code Challenge: $CODE_CHALLENGE"
```

### Step 3: Authorization Request

Direct the user to the authorization endpoint with required parameters:

```
http://localhost:3000/oauth/authorize?
  client_id=YOUR_CLIENT_ID&
  redirect_uri=http://localhost:3000/oauth/callback&
  response_type=code&
  scope=openid+profile+email+read&
  code_challenge=YOUR_CODE_CHALLENGE&
  code_challenge_method=S256
```

**Required Parameters:**
- `client_id`: Your OAuth application's Client ID
- `redirect_uri`: One of your registered redirect URIs (must match exactly)
- `response_type`: `code` (authorization code flow)
- `scope`: Space-separated scopes (minimum: `openid profile email read`)
- `code_challenge`: PKCE challenge from Step 2
- `code_challenge_method`: `S256` (SHA256)

The user will be prompted to log in (if not already) and authorize your application. Upon approval, they'll be redirected to your redirect_uri with an authorization code:

```
http://localhost:3000/oauth/callback?code=AUTHORIZATION_CODE
```

### Step 4: Exchange Code for Token

Exchange the authorization code for an access token:

```bash
curl -X POST http://localhost:3000/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=AUTHORIZATION_CODE" \
  -d "redirect_uri=http://localhost:3000/oauth/callback" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "code_verifier=$CODE_VERIFIER"
```

**Response:**
```json
{
  "access_token": "<token>",
  "token_type": "Bearer",
  "expires_in": 31536000,
  "refresh_token": "refresh_token_here",
  "scope": "openid profile email read",
  "created_at": 1640000000,
  "id_token": "<token>"
}
```

**Important Fields:**
- `access_token`: Use this for API authentication
- `expires_in`: Token lifetime in seconds (1 year = 31536000)
- `refresh_token`: Use to obtain new access tokens without re-authorization
- `id_token`: JWT containing user claims (can be decoded)

### Step 5: Use Access Token for MCP Requests

Include the access token in the Authorization header:

```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

### Token Refresh

When your access token expires, use the refresh token to get a new one:

```bash
curl -X POST http://localhost:3000/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=YOUR_REFRESH_TOKEN" \
  -d "client_id=YOUR_CLIENT_ID"
```

### Decoding the ID Token

The ID token is a JWT containing user claims. Decode it to access user information:

```bash
# Decode JWT (requires jq and base64)
echo "YOUR_ID_TOKEN" | cut -d. -f2 | base64 -d | jq
```

**Example Claims:**
```json
{
  "sub": "123",
  "email": "user@example.com",
  "email_verified": true,
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "family_id": 456,
  "role": "admin",
  "iss": "http://localhost:3000",
  "aud": "client-id-here",
  "exp": 1672531200,
  "iat": 1640995200
}
```

### Required Scopes

All MCP requests require these scopes:

| Scope | Purpose | Required |
|-------|---------|----------|
| `openid` | Enable OpenID Connect authentication | Yes |
| `profile` | Access to user profile information | Yes |
| `email` | Access to user email and verification status | Yes |
| `read` | Read access to financial data | Yes |
| `read_write` | Write access to financial data | Optional |

**Minimum Scope Request:** `openid profile email read`

## Migration Guide: API Keys to OAuth

If you were using API keys for MCP access, follow these steps to migrate to OAuth 2.0:

### Why the Change?

- **Security**: OAuth provides user-authorized, scoped access instead of long-lived keys
- **Standards Compliance**: OIDC is the industry standard for authentication
- **Multi-tenancy**: OAuth properly handles family-based access control
- **Audit Trail**: Better tracking of which applications access user data

### Migration Steps

#### 1. Update Your Client Configuration

**Before (API Key):**
```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "X-Api-Key: pk_dev_mcp_test_key_..." \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

**After (OAuth):**
```bash
# First, obtain access token via OAuth flow (see above)
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

#### 2. Implement OAuth Flow

Choose an OAuth library for your platform:

**Python:**
```bash
pip install requests-oauthlib
```

**JavaScript/Node:**
```bash
npm install openid-client
```

**Ruby:**
```bash
gem install oauth2
```

**Go:**
```bash
go get golang.org/x/oauth2
```

#### 3. Handle Token Storage

Store tokens securely:
- **Desktop apps**: OS keychain/credential manager
- **CLI tools**: Encrypted config file
- **Web apps**: Encrypted session storage
- **Mobile apps**: Secure storage (iOS Keychain, Android Keystore)

Never store tokens in:
- Plain text files
- Environment variables (in production)
- Version control
- Logs

#### 4. Implement Token Refresh

Access tokens expire after 1 year. Implement refresh logic:

```python
# Python example
from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session

def refresh_token_if_needed(session, token):
    if token['expires_at'] < time.time():
        # Token expired, refresh it
        token = session.refresh_token(
            'http://localhost:3000/oauth/token',
            refresh_token=token['refresh_token'],
            client_id='YOUR_CLIENT_ID'
        )
        # Save new token
        save_token(token)
    return token
```

#### 5. Update Error Handling

OAuth errors differ from API key errors:

```json
// API Key Error (old)
{
  "error": "unauthorized",
  "message": "Invalid API key"
}

// OAuth Error (new)
{
  "error": "invalid_token",
  "error_description": "The access token expired"
}
```

Handle these OAuth error types:
- `invalid_token`: Token is invalid or expired
- `insufficient_scope`: Token lacks required scopes
- `invalid_request`: Malformed request

#### 6. Test Your Implementation

Verify your OAuth implementation:

1. **Authorization Flow**: User can authorize your app
2. **Token Storage**: Tokens are securely stored
3. **Token Usage**: Access token works for MCP requests
4. **Token Refresh**: Refresh token obtains new access token
5. **Error Handling**: Gracefully handles OAuth errors

### Common Issues

#### "insufficient_scope" Error

**Problem:** Token missing required scopes

**Solution:** Request all required scopes in authorization:
```
scope=openid+profile+email+read
```

#### "invalid_token" Error

**Problem:** Token expired or invalid

**Solution:** Check token expiration and refresh if needed:
```bash
# Check token expiration from token response
# "expires_in": 31536000 (seconds until expiration)
# "created_at": 1640000000 (unix timestamp)
```

#### PKCE Errors

**Problem:** PKCE challenge/verifier mismatch

**Solution:** Ensure code_verifier matches the one used to generate code_challenge

#### Redirect URI Mismatch

**Problem:** redirect_uri doesn't match registered URI

**Solution:** Use exact redirect_uri from OAuth application configuration

### Testing Tools

Test OAuth flow manually:

**Postman:**
1. Create new request
2. Authorization tab → Type: OAuth 2.0
3. Configure endpoints and scopes
4. Click "Get New Access Token"

**curl + jq:**
```bash
# Get authorization code (manual step in browser)
# Then exchange for token:
curl -X POST http://localhost:3000/oauth/token \
  -d "grant_type=authorization_code" \
  -d "code=AUTHORIZATION_CODE" \
  -d "redirect_uri=urn:ietf:wg:oauth:2.0:oob" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "code_verifier=YOUR_CODE_VERIFIER" | jq
```

### Support

If you encounter issues migrating to OAuth:

1. Check the [OIDC Discovery Endpoint](http://localhost:3000/.well-known/openid-configuration)
2. Review OAuth error responses for details
3. Verify your redirect URI is registered
4. Ensure all required scopes are requested
5. Check server logs for detailed error messages

## Quick Start with Docker Compose

### 1. Start the Application

```bash
docker compose up -d
```

This starts:
- Web server on `http://localhost:3000`
- PostgreSQL database
- Redis cache
- Sidekiq background worker

### 2. Set Up Demo Data

```bash
# Create and seed the database with demo data
docker compose exec web bin/rails db:prepare
docker compose exec web bin/rails demo_data:default
docker compose exec web bin/rails db:seed
```

This creates:
- Demo user account (`user@perhaps.local`)
- ~8,000 transactions with realistic data
- 32 merchants (grocery stores, restaurants, gas stations, etc.)
- 10 transaction tags (business, personal, vacation, etc.)
- API key for MCP access

### 3. Set Up OAuth Application

The seed command creates an OAuth application for MCP access:

```bash
docker compose exec web bin/rails runner "load Rails.root.join('db/seeds/mcp_oauth_client.rb')"
```

This creates the "MCP Client" OAuth application with:
- Client ID for authorization requests
- OIDC scopes: `openid`, `profile`, `email`
- Data scopes: `read`, `read_write`
- Redirect URIs for common MCP clients

**Save the Client ID** from the output - you'll need it for OAuth authorization.

### 4. Authenticate via OAuth

Follow the [OIDC Authentication Flow](#oidc-authentication-flow) to obtain an access token.

**Quick test with manual token creation (development only):**

```bash
# Create a test token
docker compose exec web bin/rails runner "
  user = User.find_by(email: 'user@perhaps.local')
  app = Doorkeeper::Application.find_by(name: 'MCP Client')
  token = Doorkeeper::AccessToken.create!(
    resource_owner_id: user.id,
    application: app,
    scopes: 'openid profile email read',
    expires_in: 1.hour
  )
  puts token.token
"
```

**Use the token for MCP requests:**
```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## MCP Server Endpoints

### List Available Tools

**Request:**
```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "ping",
        "description": "Simple health check tool that returns a pong response"
      },
      {
        "name": "list_accounts",
        "description": "List all financial accounts for the user's family..."
      },
      {
        "name": "get_account",
        "description": "Get detailed information about a specific account..."
      },
      {
        "name": "list_transactions",
        "description": "List transactions with date range and account filtering..."
      },
      {
        "name": "query_transactions",
        "description": "Advanced transaction search with filters..."
      },
      {
        "name": "financial_summary",
        "description": "Get aggregate financial analytics..."
      }
    ]
  },
  "id": 1
}
```

### Example: List Accounts

```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "list_accounts",
      "arguments": {}
    },
    "id": 2
  }'
```

### Example: Query Transactions by Merchant

```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "query_transactions",
      "arguments": {
        "merchant_names": ["Whole Foods", "Trader Joes"],
        "start_date": "2024-01-01",
        "end_date": "2024-12-31",
        "include_summary": true
      }
    },
    "id": 3
  }'
```

### Example: Get Financial Summary

```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "financial_summary",
      "arguments": {
        "period": "month",
        "compare_previous": true,
        "include_net_worth": true,
        "include_cash_flow": true,
        "include_top_categories": true,
        "include_top_merchants": true
      }
    },
    "id": 4
  }'
```

## Using with Local Development (Non-Docker)

### 1. Start Dependencies

```bash
# Start PostgreSQL and Redis via Docker
docker compose -f compose.dev.yml up -d

# Start Rails server
bin/dev
```

### 2. Set Up Demo Data

```bash
bin/rails db:prepare
bin/rails demo_data:default
bin/rails db:seed
```

### 3. Access MCP Server

The MCP server is now available at `http://localhost:3000/api/v1/mcp` with the same API key from the seed output.

## Available MCP Tools

### 1. **ping**
Health check tool that returns a pong response.

### 2. **list_accounts**
List all financial accounts with optional filters:
- `account_type`: Filter by type (depository, investment, credit_card, etc.)
- `classification`: Filter by asset or liability
- `include_inactive`: Include disabled accounts

### 3. **get_account**
Get detailed account information including:
- Current balance and balance history
- 30/90/365 day balance summaries
- Transaction and holdings counts
- Institution information

### 4. **list_transactions**
List transactions with basic filtering:
- `account_id`: Filter by account
- `start_date` / `end_date`: Date range filter
- `limit` / `offset`: Pagination

### 5. **query_transactions**
Advanced transaction search with comprehensive filters:
- **Accounts**: `account_id`, `account_ids`
- **Dates**: `start_date`, `end_date`
- **Categories**: `category_id`, `category_ids`, `category_names`, `uncategorized`
- **Merchants**: `merchant_id`, `merchant_ids`, `merchant_names`
- **Amounts**: `min_amount`, `max_amount`, `exact_amount`
- **Types**: `classification` (income/expense), `kind`, `exclude_transfers`
- **Search**: `search` (text search in name, notes, merchant)
- **Tags**: `tag_ids`, `tag_names`
- **Pagination**: `limit`, `offset`
- **Summary**: `include_summary` (aggregate statistics)

### 6. **financial_summary**
Get aggregate financial analytics:
- **Net worth** breakdown by account type
- **Cash flow** analysis (income vs expenses)
- **Top categories** by spending
- **Top merchants** by spending
- **Period comparisons** (month, quarter, year, YTD, all)

## Demo Data Contents

The seed data includes:
- **32 merchants**: Whole Foods, Starbucks, Shell, Netflix, CVS, etc.
- **10 tags**: business, personal, tax_deductible, reimbursable, subscription, recurring, vacation, emergency, gift, one_time
- **~8,000 transactions** spanning 3 years
- **~1,500 transactions** with merchant associations
- **~2,300 transactions** with tag associations
- **~100+ transactions** with contextual notes
- **Multiple account types**: checking, savings, credit cards, investments, property, vehicles, crypto, loans

## Troubleshooting

### "unauthorized" or "invalid_token" Error

**Causes:**
- Access token is expired (tokens last 1 year)
- Access token is invalid or malformed
- Authorization header is missing or incorrect

**Solutions:**
- Check token expiration: decode JWT and check `exp` claim
- Refresh token using refresh_token grant
- Verify Authorization header format: `Authorization: Bearer YOUR_TOKEN`
- Create a new token via OAuth flow

### "insufficient_scope" Error

**Causes:**
- Token missing required OIDC scopes (openid, profile, email)
- Token missing data scope (read or read_write)

**Solutions:**
- Request all required scopes in authorization:
  ```
  scope=openid+profile+email+read
  ```
- Check token scopes: decode ID token and check `scope` claim
- Create a new token with correct scopes

### "authentication_method_not_supported" Error

**Cause:** Attempting to use API key instead of OAuth token

**Solution:** Migrate to OAuth 2.0 authentication (see [Migration Guide](#migration-guide-api-keys-to-oauth))

### "Connection Refused" Error

**Solutions:**
- Ensure Rails server is running: `docker compose ps` or check port 3000
- Verify port in URL matches server port (default: 3000)
- Check firewall settings if accessing remotely

### "Missing Family" Error

**Solutions:**
- Run seeds: `docker compose exec web bin/rails db:seed`
- Verify user has a family: check user.family_id
- Create demo data: `docker compose exec web bin/rails demo_data:default`

### Empty Results

**Solutions:**
- Verify demo data exists: `docker compose exec web bin/rails runner "puts Transaction.count"`
- Check date filters: demo data spans last 3 years
- Remove filters to see if any data exists
- Verify token scopes include `read` access

### OAuth Flow Issues

**Authorization Page Not Loading:**
- Check user is logged in (OAuth requires authentication)
- Verify client_id matches OAuth application
- Ensure redirect_uri is registered in application

**Token Exchange Fails:**
- Verify code_verifier matches code_challenge
- Check authorization code hasn't expired (10 minutes)
- Ensure redirect_uri matches authorization request exactly
- Verify all required parameters are included

**PKCE Errors:**
- Generate code_verifier: 43-128 character random string
- Generate code_challenge: SHA256 hash of verifier, base64url encoded
- Use code_challenge_method=S256 in authorization request

## Security Notes

- OAuth tokens expire after 1 year - implement refresh logic
- Refresh tokens never expire - store them securely
- PKCE is required for all public clients (native apps, SPAs)
- ID tokens contain sensitive user information - don't expose publicly
- Tokens should never be committed to version control or logged
- Consider implementing token revocation in production
- Use HTTPS in production (OAuth requires secure transport)
- Validate redirect URIs to prevent authorization code interception
- Consider IP whitelisting for production deployments

## Rate Limits

- Default: 1000 requests per hour per API key
- Headers returned: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Exceeded: HTTP 429 with `Retry-After` header

## Further Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Perhaps API Documentation](../README.md#api)
- [Docker Compose Guide](./hosting/docker.md)
