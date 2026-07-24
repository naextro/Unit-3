#!/usr/bin/env python3
import sys
import os
import json
import re
import urllib.request
import urllib.parse
import subprocess
import argparse

# ── DuckDuckGo Web Search Tool ──
def web_search(query):
    try:
        url = "https://html.duckduckgo.com/html/?q=" + urllib.parse.quote(query)
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            }
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')

        results = []
        cards = re.findall(r'<div class="result__body">(.*?)</div>\s*</div>', html, re.DOTALL)
        for card in cards[:4]:
            title_match = re.search(r'<a class="result__url"[^>]*>(.*?)</a>', card, re.DOTALL)
            snippet_match = re.search(r'<a class="result__snippet"[^>]*>(.*?)</a>', card, re.DOTALL)
            if title_match and snippet_match:
                title = re.sub(r'<[^>]*>', '', title_match.group(1)).strip()
                snippet = re.sub(r'<[^>]*>', '', snippet_match.group(1)).strip()
                results.append(f"Title: {title}\nSnippet: {snippet}")

        if not results:
            return "No search results found."
        return "\n\n".join(results)
    except Exception as e:
        return f"Error performing search: {e}"

# ── Command Execution Tools ──
def run_command(cmd):
    """Always runs as the current (non-root) user. sudo/pkexec are stripped
    if a model tries to sneak them in here - that's what run_command_sudo is for."""
    stripped = re.sub(r'\b(sudo|pkexec)\b\s*', '', cmd).strip()
    try:
        res = subprocess.run(stripped, shell=True, capture_output=True, text=True, timeout=30)
        return f"Exit code: {res.returncode}\nStdout:\n{res.stdout}\nStderr:\n{res.stderr}"
    except subprocess.TimeoutExpired:
        return "ERROR: Command timed out after 30 seconds."
    except Exception as e:
        return f"ERROR running command: {e}"


def run_command_sudo(cmd, allow_root):
    """Runs a command with sudo - but only if allow_root is True (the WARN
    toggle in the panel). If root isn't allowed, this transparently falls
    back to run_command instead of failing outright."""
    if not allow_root:
        note = "NOTE: Root access is disabled (WARN toggle is off) - ran as a normal user instead.\n\n"
        return note + run_command(cmd)

    # Strip any sudo/pkexec the model may have already included, then apply once cleanly.
    stripped = re.sub(r'\b(sudo|pkexec)\b\s*', '', cmd).strip()
    full_cmd = f"sudo -n {stripped}"
    try:
        res = subprocess.run(full_cmd, shell=True, capture_output=True, text=True, timeout=30)
        if res.returncode != 0 and "password is required" in (res.stderr or "").lower():
            return (
                "ERROR: sudo requires a password (passwordless sudo isn't configured "
                "for this command). Configure NOPASSWD in sudoers for this to work "
                "non-interactively, or run it manually."
            )
        return f"Exit code: {res.returncode}\nStdout:\n{res.stdout}\nStderr:\n{res.stderr}"
    except subprocess.TimeoutExpired:
        return "ERROR: Command timed out after 30 seconds."
    except Exception as e:
        return f"ERROR running command: {e}"

# ── API Providers Handlers ──
def call_ollama(endpoint, model, messages):
    url = f"{endpoint}/api/chat"
    body = json.dumps({"model": model, "messages": messages, "stream": False})
    req = urllib.request.Request(url, data=body.encode('utf-8'), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as response:
        res = json.loads(response.read().decode('utf-8'))
        return res["message"]["content"]

def call_openai_compatible(url, api_key, model, messages):
    body = json.dumps({"model": model, "messages": messages, "stream": False})
    req = urllib.request.Request(
        url,
        data=body.encode('utf-8'),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            res = json.loads(response.read().decode('utf-8'))
            return res["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='replace')
        e.body_text = error_body   # cache it, .read() only works once
        try:
            err_json = json.loads(error_body)
            err_obj = err_json.get("error", {})
            if err_obj.get("code") == "tool_use_failed" and "failed_generation" in err_obj:
                gen = json.loads(err_obj["failed_generation"])
                tool_name = gen.get("name", "")
                tool_args = gen.get("arguments", {})
                arg_name = "query" if "query" in tool_args else "cmd"
                arg_val = tool_args.get(arg_name, "")
                return f'<tool_call name="{tool_name}" {arg_name}="{arg_val}" />'
        except Exception:
            pass
        raise
def call_gemini(api_key, model, messages, system_prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    contents = []
    for m in messages:
        if m["role"] in ["user", "assistant"]:
            contents.append({
                "role": "model" if m["role"] == "assistant" else "user",
                "parts": [{"text": m["content"]}]
            })

    req_body = {"contents": contents}
    if system_prompt:
        req_body["systemInstruction"] = {"parts": [{"text": system_prompt}]}

    req = urllib.request.Request(url, data=json.dumps(req_body).encode('utf-8'), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as response:
        res = json.loads(response.read().decode('utf-8'))
        parts = res["candidates"][0]["content"]["parts"]
        text_parts = [p["text"] for p in parts if "text" in p and not p.get("thought", False)]
        return "".join(text_parts).strip() or "(empty response from model)"
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--api-key", default="")
    parser.add_argument("--endpoint", default="http://localhost:11434")
    parser.add_argument("--system-prompt", default="")
    parser.add_argument("--history", required=True)
    parser.add_argument("--allow-root", action="store_true")
    args = parser.parse_args()

    messages = json.loads(args.history)

    # Impose tool guidelines on system prompt
    root_status = "ENABLED" if args.allow_root else "DISABLED (WARN toggle is off)"
    tool_instructions = (
        "\n\nYou are equipped with tool-calling capabilities. You MUST use them to perform actions requested by the operator.\n"
        "Available tools:\n"
        "1. Web Search:\n"
        "   Call this to search the internet for information.\n"
        "   Syntax: <tool_call name=\"web_search\" query=\"search query\" />\n"
        "2. Run Command:\n"
        "   Call this to execute a bash/shell command as a normal (non-root) user.\n"
        "   Syntax: <tool_call name=\"run_command\" cmd=\"command string\" />\n"
        "3. Run Command (Sudo):\n"
        "   Call this ONLY when the operator explicitly needs root/administrative privileges "
        "(e.g. package installs, systemctl, editing system files).\n"
        "   Syntax: <tool_call name=\"run_command_sudo\" cmd=\"command string\" />\n"
        f"   Root access is currently {root_status}. If disabled, this tool will silently run "
        "the command as a normal user instead of failing - so only use it when root is actually needed, "
        "and tell the operator if the result suggests it ran without root.\n"
        "When calling a tool, you MUST output ONLY the tool call tag (e.g. <tool_call name=\"...\" ... />) and STOP generating immediately. "
        "The system will execute the tool and provide the response in a <tool_response> block. Do not write anything else or output markdown code blocks around the tool call tag."
    )

    # Inject tool instructions into system prompt or history
    system_prompt = args.system_prompt + tool_instructions

    # Prepare history for non-Gemini providers (which require system message in messages array)
    if args.provider != "gemini":
        messages.insert(0, {"role": "system", "content": system_prompt})

    # Agent Loop (max 5 turns)
    for turn in range(5):
        try:
            if args.provider == "ollama":
                content = call_ollama(args.endpoint, args.model, messages)
            elif args.provider == "groq":
                content = call_openai_compatible("https://api.groq.com/openai/v1/chat/completions", args.api_key, args.model, messages)
            elif args.provider == "openrouter":
                content = call_openai_compatible("https://openrouter.ai/api/v1/chat/completions", args.api_key, args.model, messages)
            elif args.provider == "cerebras":
                content = call_openai_compatible("https://api.cerebras.ai/v1/chat/completions", args.api_key, args.model, messages)
            elif args.provider == "gemini":
                content = call_gemini(args.api_key, args.model, messages, system_prompt)
            else:
                print(f"Error: Unknown provider {args.provider}")
                sys.exit(1)
        except urllib.error.HTTPError as e:
            error_body = getattr(e, 'body_text', None)
            if error_body is None:
                try:
                    error_body = e.read().decode('utf-8', errors='replace')
                except Exception:
                    error_body = "<no response body available>"

            detail = error_body
            try:
                err_json = json.loads(error_body)
                err_obj = err_json.get("error", err_json)
                if isinstance(err_obj, dict):
                    parts = []
                    for key in ("message", "type", "code", "status", "param"):
                        if err_obj.get(key):
                            parts.append(f"{key}={err_obj[key]}")
                    if parts:
                        detail = " | ".join(parts)
            except Exception:
                pass

            headers_str = ""
            try:
                retry_after = e.headers.get("Retry-After") if e.headers else None
                if retry_after:
                    headers_str = f" | Retry-After: {retry_after}s"
            except Exception:
                pass

            print(f"Connection failed: HTTP {e.code} ({e.reason}){headers_str}\n{detail}")
            sys.exit(1)
        except urllib.error.URLError as e:
            print(f"Connection failed: could not reach server - {e.reason}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Connection failed: server returned invalid JSON - {e}")
            sys.exit(1)
        except KeyError as e:
            print(f"Connection failed: unexpected response format - missing key {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Connection failed: {type(e).__name__}: {e}")
            sys.exit(1)
        # Strip reasoning blocks some models (e.g. Qwen3) emit inline
        content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()

        # Parse tool call if any
        # Format: <tool_call name="tool_name" attr="val" />
        tool_call_match = re.search(r'<tool_call\s+name="([^"]+)"\s+(query|cmd)="([^"]+)"\s*/?>', content)
        if tool_call_match:
            tool_name = tool_call_match.group(1)
            arg_name = tool_call_match.group(2)
            arg_val = tool_call_match.group(3)

            # Print execution info so user/GUI knows what's happening
            print(f"```🤖 Calling tool: {tool_name} with {arg_name}={arg_val}``` \n")

            if tool_name == "web_search":
                res = web_search(arg_val)
            elif tool_name == "run_command":
                res = run_command(arg_val)
            elif tool_name == "run_command_sudo":
                res = run_command_sudo(arg_val, allow_root=args.allow_root)
            else:
                res = f"ERROR: Unknown tool {tool_name}"

            messages.append({"role": "assistant", "content": f'<tool_call name="{tool_name}" {arg_name}="{arg_val}" />'})
            messages.append({"role": "user", "content": f"<tool_response>\n{res}\n</tool_response>"})
        else:
            # Final output, return it
            print(content)
            break
    else:
        print("Error: Max tool call turns exceeded.")

if __name__ == "__main__":
    main()