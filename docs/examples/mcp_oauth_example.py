#!/usr/bin/env python3
"""
Example OAuth 2.0 + OIDC client for Perhaps MCP Server

This script demonstrates the complete OAuth flow including:
- PKCE challenge generation
- Authorization request
- Token exchange
- MCP API request with access token

Requirements:
    pip install requests oauthlib
"""

import base64
import hashlib
import json
import secrets
import urllib.parse
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler

import requests
from oauthlib.oauth2 import WebApplicationClient

# Configuration
BASE_URL = "http://localhost:3000"
CLIENT_ID = "YOUR_CLIENT_ID_HERE"  # Get from seed output
REDIRECT_URI = "http://localhost:8080/callback"
SCOPES = ["openid", "profile", "email", "read"]

# OAuth endpoints
AUTH_ENDPOINT = f"{BASE_URL}/oauth/authorize"
TOKEN_ENDPOINT = f"{BASE_URL}/oauth/token"
MCP_ENDPOINT = f"{BASE_URL}/api/v1/mcp"


class CallbackHandler(BaseHTTPRequestHandler):
    """Handle OAuth callback"""

    def do_GET(self):
        # Parse query parameters
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)

        if "code" in params:
            self.server.authorization_code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"<html><body><h1>Authorization successful!</h1><p>You can close this window.</p></body></html>")
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Authorization failed")

    def log_message(self, format, *args):
        pass  # Suppress log messages


def generate_pkce_pair():
    """Generate PKCE code verifier and challenge"""
    # Generate random code verifier (43-128 chars)
    code_verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode('utf-8').rstrip('=')

    # Generate code challenge (SHA256 of verifier)
    challenge = hashlib.sha256(code_verifier.encode('utf-8')).digest()
    code_challenge = base64.urlsafe_b64encode(challenge).decode('utf-8').rstrip('=')

    return code_verifier, code_challenge


def get_authorization_code(client_id, redirect_uri, scopes, code_challenge):
    """Step 1: Get authorization code"""
    client = WebApplicationClient(client_id)

    # Build authorization URL
    auth_url = client.prepare_request_uri(
        AUTH_ENDPOINT,
        redirect_uri=redirect_uri,
        scope=scopes,
        code_challenge=code_challenge,
        code_challenge_method="S256"
    )

    print(f"Opening browser for authorization...")
    print(f"URL: {auth_url}")
    webbrowser.open(auth_url)

    # Start local server to receive callback
    server = HTTPServer(("localhost", 8080), CallbackHandler)
    server.authorization_code = None

    print("Waiting for authorization callback...")
    while server.authorization_code is None:
        server.handle_request()

    return server.authorization_code


def exchange_code_for_token(client_id, code, code_verifier, redirect_uri):
    """Step 2: Exchange authorization code for access token"""
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "code_verifier": code_verifier
    }

    response = requests.post(TOKEN_ENDPOINT, data=data)
    response.raise_for_status()

    return response.json()


def call_mcp_api(access_token, method, params=None):
    """Make MCP JSON-RPC request"""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "id": 1
    }

    if params:
        payload["params"] = params

    response = requests.post(MCP_ENDPOINT, headers=headers, json=payload)
    response.raise_for_status()

    return response.json()


def main():
    """Main OAuth flow"""
    print("Perhaps MCP Server OAuth Example")
    print("=" * 50)

    # Generate PKCE pair
    print("\n1. Generating PKCE challenge...")
    code_verifier, code_challenge = generate_pkce_pair()
    print(f"   Code Challenge: {code_challenge}")

    # Get authorization code
    print("\n2. Requesting authorization...")
    auth_code = get_authorization_code(CLIENT_ID, REDIRECT_URI, SCOPES, code_challenge)
    print(f"   Authorization Code: {auth_code[:20]}...")

    # Exchange for token
    print("\n3. Exchanging code for token...")
    token_response = exchange_code_for_token(CLIENT_ID, auth_code, code_verifier, REDIRECT_URI)
    access_token = token_response["access_token"]
    print(f"   Access Token: {access_token[:20]}...")
    print(f"   Expires In: {token_response['expires_in']} seconds")

    # Decode ID token (optional - just for display)
    if "id_token" in token_response:
        # Simple JWT decode (don't use in production without verification)
        id_token_payload = token_response["id_token"].split(".")[1]
        # Add padding if needed
        id_token_payload += "=" * (4 - len(id_token_payload) % 4)
        id_claims = json.loads(base64.urlsafe_b64decode(id_token_payload))
        print(f"\n   User Claims:")
        print(f"     Email: {id_claims.get('email')}")
        print(f"     Name: {id_claims.get('name')}")
        print(f"     Family ID: {id_claims.get('family_id')}")

    # Test MCP API
    print("\n4. Testing MCP API...")
    result = call_mcp_api(access_token, "tools/list")
    print(f"   Available Tools: {len(result.get('result', {}).get('tools', []))}")

    # List some tools
    if "result" in result and "tools" in result["result"]:
        print("\n   Tools:")
        for tool in result["result"]["tools"][:3]:
            print(f"     - {tool['name']}: {tool['description'][:60]}...")

    print("\n" + "=" * 50)
    print("OAuth flow completed successfully!")
    print(f"\nAccess Token (save this): {access_token}")
    print(f"Refresh Token: {token_response.get('refresh_token', 'N/A')}")


if __name__ == "__main__":
    main()
