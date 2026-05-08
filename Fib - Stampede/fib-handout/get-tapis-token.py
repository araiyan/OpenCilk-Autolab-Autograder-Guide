#!/usr/bin/env python3
"""
get-tapis-token.py - Fetch a fresh TAPIS access token using TACC credentials.

Usage:
    python3 get-tapis-token.py
    
Environment Variables:
    TAPIS_USERNAME: Your TACC username (prompted if not set)
    TAPIS_PASSWORD: Your TACC password (prompted if not set)
    TAPIS_BASE_URL: TAPIS tenant URL (default: https://tacc.tapis.io)

Output:
    Prints "access_token: <token>" on success
    Exits with non-zero on failure
"""

import os
import sys
import json
import getpass
import subprocess

try:
    from tapipy.tapis import Tapis
except ImportError:
    print("Error: tapipy not installed. Install with: pip install tapipy", file=sys.stderr)
    # Try to auto-install tapipy
    print("Attempting to install tapipy...", file=sys.stderr)
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "tapipy", "-q"])
        from tapipy.tapis import Tapis
        print("Successfully installed tapipy", file=sys.stderr)
    except Exception as install_err:
        print(f"Failed to auto-install tapipy: {install_err}", file=sys.stderr)
        sys.exit(1)


def main():
    tenant_url = os.environ.get("TAPIS_BASE_URL", "https://tacc.tapis.io")
    
    # Get credentials from environment or prompt
    username = os.environ.get("TAPIS_USERNAME", "").strip()
    if not username:
        try:
            username = input("TACC Username: ").strip()
        except EOFError:
            print("Error: No username provided (stdin not available)", file=sys.stderr)
            return 1
    
    password = os.environ.get("TAPIS_PASSWORD", "").strip()
    if not password:
        try:
            password = getpass.getpass("TACC Password: ")
        except EOFError:
            print("Error: No password provided (stdin not available)", file=sys.stderr)
            return 1
    
    if not username or not password:
        print("Error: Username and password are required", file=sys.stderr)
        return 1
    
    try:
        print(f"Authenticating to {tenant_url}...", file=sys.stderr)
        t = Tapis(base_url=tenant_url, username=username, password=password)
        t.get_tokens()
        token = t.access_token.access_token
        print(f"access_token: {token}")
        return 0
    except Exception as e:
        print(f"Error: Authentication failed: {e}", file=sys.stderr)
        print(f"  Verify your TACC username and password", file=sys.stderr)
        print(f"  Check your MFA token (if enabled on your account)", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
