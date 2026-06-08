#!/usr/bin/env python3
import argparse
import json
import os
import sys
import subprocess
from pathlib import Path

LLM_DOMAINS = [
    'chat.openai.com',
    'api.openai.com',
    'chatgpt.com',
    'gemini.google.com',
    'claude.ai',
    'api.anthropic.com',
    'grok.com',
    'x.ai',
    'grok.x.com',
    'api.x.ai',
    'perplexity.ai',
    'chat.deepseek.com',
    'api.deepseek.com'
]

HOSTS_FILE = '/etc/hosts'
REDIRECT_IP = '127.0.0.1'

STATUS_FILE = Path("/tmp/llm_status.json")

def read_hosts():
    """Read the current hosts file"""
    try:
        with open(HOSTS_FILE, 'r') as f:
            return f.read().splitlines()
    except FileNotFoundError:
        return []

def write_hosts(lines):
    """Write to hosts file with sudo"""
    try:
        content = '\n'.join(lines) + '\n'
        # Use sudo tee to write to /etc/hosts
        os.system(f'echo "{content}" | sudo tee {HOSTS_FILE} > /dev/null')
        return True
    except Exception as e:
        print(f"Error writing hosts file: {e}", file=sys.stderr)
        return False

def is_llm_blocked():
    """Check if LLM domains are blocked in hosts file"""
    hosts_lines = read_hosts()
    blocked_count = 0
    
    for domain in LLM_DOMAINS:
        for line in hosts_lines:
            if line.strip().startswith('#'):
                continue
            if f"{REDIRECT_IP} {domain}" in line:
                blocked_count += 1
                break
    
    return blocked_count > len(LLM_DOMAINS) // 2  # Consider blocked if >50% are blocked

def toggle_llm():
    """Toggle LLM blocking in hosts file"""
    hosts_lines = read_hosts()
    new_lines = []
    currently_blocked = is_llm_blocked()
    
    for line in hosts_lines:
        # Remove existing LLM entries
        is_llm_entry = False
        if not line.strip().startswith('#') and REDIRECT_IP in line:
            parts = line.split()
            if len(parts) >= 2 and parts[1] in LLM_DOMAINS:
                is_llm_entry = True
        
        if not is_llm_entry:
            new_lines.append(line)
    
    # Add or remove LLM entries
    if not currently_blocked:
        # Block LLMs
        for domain in LLM_DOMAINS:
            new_lines.append(f"{REDIRECT_IP} {domain}")
        print("LLM access blocked")
        status = "blocked"
    else:
        # Unblock LLMs
        print("LLM access unblocked")
        status = "unblocked"
    
    # Write back to hosts
    if write_hosts(new_lines):
        return status
    else:
        print("Failed to update hosts file", file=sys.stderr)
        return None

def get_status():
    """Get current status in JSON format for Waybar, print only if changed globally."""
    blocked = is_llm_blocked()
    
    status_data = {
        "text": "󰚩" if not blocked else "󱚧",
        "class": "ai-active" if not blocked else "ai-blocked",
        "tooltip": "LLM Access: Active" if not blocked else "LLM Access: Blocked",
        "percentage": 100 if not blocked else 0
    }

    status_json = json.dumps(status_data)

    # Read previous status from file
    if STATUS_FILE.exists():
        last_status = STATUS_FILE.read_text()
    else:
        last_status = None

    # Compare and update if changed
    if last_status != status_json:
        STATUS_FILE.write_text(status_json)
        os.system(f"swayosd-client --custom-message='AI: {"Blocked" if blocked else "Unblocked"}'")

    # No change
    return status_json

def main():
    parser = argparse.ArgumentParser(description='Toggle LLM access via hosts file')
    parser.add_argument('--toggle', action='store_true', help='Toggle LLM blocking')
    parser.add_argument('--status', action='store_true', help='Show current status')
    
    args = parser.parse_args()
    
    if args.toggle:
        toggle_llm()
    elif args.status:
        print(get_status())
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
