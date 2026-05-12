# Shell Hooks Framework

This framework provides a robust set of **Shell Hooks** for **Claude Code** (Anthropic's CLI-based AI coding assistant). It is designed to add a layer of safety, monitoring, and automation to your AI-driven development workflow by intercepting actions before they occur and managing side effects after they complete.

## 🚀 System Overview
The framework operates across three critical lifecycle stages of an AI session:
1.  **PreToolUse**: Executes before the AI runs a command (e.g., a Bash script) and can **block** dangerous actions.
2.  **PostToolUse**: Executes after the AI edits or writes files, handling backups and syntax validation.
3.  **Stop**: Executes when the session ends to generate a comprehensive activity report.

---

## 🛠️ The Hooks

### 🛡️ Safety & Guardrail Hooks (Pre-Tool)
* **Command Firewall (`pre_command_firewall.sh`)**: Intercepts shell commands and blocks those matching dangerous patterns (e.g., `rm -rf /`) based on regex rules defined in your configuration.
* **Rate Limiter (`pre_rate_limiter.sh`)**: Tracks command usage per session and blocks the AI if it exceeds a defined threshold, preventing costly runaway automation loops.
* **Commit Validator (`pre_commit_validator.sh`)**: Enforces the Conventional Commits format. If a prefix is missing, it analyzes staged changes and suggests the most appropriate one (e.g., `feat:`, `fix:`, `docs:`).

### 🔄 Automation & Monitoring Hooks (Post-Tool & Stop)
* **Auto-Backup (`post_auto_backup.sh`)**: Creates a timestamped backup of every file edited by the AI. It includes automatic rotation to keep only the most recent versions.
* **Syntax Checker (`post_syntax_checker.sh`)**: Runs an immediate syntax check on Bash, Python, or C/H files after an edit to catch errors before they are committed.
* **Session Summary (`post_session_summary.sh`)**: Analyzes session logs to produce a visual report detailing total actions, backups made, most edited files, and any syntax errors encountered.

---

## ⚙️ Claude Code Integration
To use these hooks in a real project, copy the `.claude` directory to your project root. The included `settings.json` is pre-configured to wire the scripts to the correct events:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre_secrets_guard.sh" },
          { "type": "command", "command": ".claude/hooks/pre_command_firewall.sh" },
          { "type": "command", "command": ".claude/hooks/pre_rate_limiter.sh" },
          { "type": "command", "command": ".claude/hooks/pre_commit_validator.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post_auto_backup.sh" },
          { "type": "command", "command": ".claude/hooks/post_syntax_checker.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post_session_summary.sh" }
        ]
      }
    ]
  }
}

```

## 💻 Installation & Testing

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/shell-hooks-automation.git
cd shell-hooks-automation
```

### 2. Run the Simulator

You can test the hooks without a Claude Code subscription using the included `hook_runner.sh`.  
It simulates the tool execution environment:

```bash
# Test the Firewall (should block dangerous command)
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | ./hook_runner.sh PreToolUse Bash

# Test the Syntax Checker (provide a path to a file)
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/main.c"}}' | ./hook_runner.sh PostToolUse Edit
```

### 3. Configuration

Customize behavior by editing the files in `.claude/hooks/config/`:

- `dangerous_patterns.txt` — Define forbidden regex patterns for shell commands.
- `hooks.conf` — Set `MAX_COMMANDS` and `MAX_BACKUPS` limits.
- `commit_prefixes.txt` — List of allowed Conventional Commit prefixes.

---

## 📝 Requirements

- **Environment:** Linux, macOS, or WSL (Windows Subsystem for Linux)
- **Shell:** Bash 4.0+
- **Dependencies:** Standard Unix utilities such as `grep`, `sed`, `awk`, `cut`, and `date`  
  *(No `jq` required)*

## 🌐 Connect with me:
* **GitHub:** [github.com/eranmal](https://github.com/eranmal)
* **LinkedIn:** [LinkedIn](https://il.linkedin.com/in/eran-malachi-6797a5393)
