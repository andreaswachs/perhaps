# MCP Server Usage Guide

The Perhaps MCP (Model Context Protocol) server provides financial data access for AI applications and local LLMs. This guide explains how to access and use the MCP server in different deployment scenarios.

## Overview

The MCP server exposes financial data through a JSON-RPC API that supports:
- Account listing and details with balance history
- Transaction queries with advanced filtering (merchants, tags, categories, amounts, dates)
- Financial summaries (net worth, cash flow, spending analysis)

**Endpoint:** `POST /api/v1/mcp`
**Authentication:** API Key (via `X-Api-Key` header)
**Protocol:** JSON-RPC 2.0

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

### 3. Get Your API Key

The seed command outputs your API key:

```
Created MCP API Key for demo user:
  API Key: pk_dev_mcp_test_key_12345678901234567890123456789012
  User: user@perhaps.local
  Scopes: read
```

**Save this API key** - you'll need it for all MCP requests.

## MCP Server Endpoints

### List Available Tools

**Request:**
```bash
curl -X POST http://localhost:3000/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY_HERE" \
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
  -H "X-Api-Key: YOUR_API_KEY_HERE" \
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
  -H "X-Api-Key: YOUR_API_KEY_HERE" \
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
  -H "X-Api-Key: YOUR_API_KEY_HERE" \
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

### "Unauthorized" Error

- **Check API Key**: Ensure you're using the correct API key from the seed output
- **Check Header**: API key must be sent in `X-Api-Key` header (not Authorization)
- **Check Scope**: API key must have at least `read` scope

### "Connection Refused" Error

- **Check Server**: Ensure Rails server is running (`docker compose ps` or check port 3000)
- **Check Port**: Default is 3000, verify in `compose.yml`

### "Missing Family" Error

- **Run Seeds**: Ensure you've run both `demo_data:default` and `db:seed`
- **Check User**: API key must belong to a user with a family

### Empty Results

- **Check Data**: Verify demo data was created: `docker compose exec web bin/rails runner "puts Transaction.count"`
- **Check Filters**: Try removing filters to see if data exists
- **Check Dates**: Demo data spans last 3 years, adjust date filters accordingly

## Security Notes

- The development API key (`pk_dev_mcp_test_key_12345678901234567890123456789012`) is **only for local testing**
- In production, generate unique API keys per user/application
- API keys should never be committed to version control
- Consider implementing IP whitelisting for production deployments

## Rate Limits

- Default: 1000 requests per hour per API key
- Headers returned: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Exceeded: HTTP 429 with `Retry-After` header

## Further Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Perhaps API Documentation](../README.md#api)
- [Docker Compose Guide](./hosting/docker.md)
