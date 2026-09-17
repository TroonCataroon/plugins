# Cursor plugins

Official Cursor plugins for popular developer tools, frameworks, and SaaS products. Each plugin is a standalone directory at the repository root with its own `.cursor-plugin/plugin.json` manifest.

## Plugins

| `name` | Plugin | Author | Category | `description` (from marketplace) |
|:-------|:-------|:-------|:---------|:-------------------------------------|
| `continual-learning` | [Continual Learning](continual-learning/) | Cursor | Developer Tools | Incremental transcript-driven memory updates for AGENTS.md using high-signal bullet points only. |
| `cursor-team-kit` | [Cursor Team Kit](cursor-team-kit/) | Cursor | Developer Tools | Internal team workflows used by Cursor developers for CI, code review, and shipping. |
| `create-plugin` | [Create Plugin](create-plugin/) | Cursor | Developer Tools | Scaffold and validate new Cursor plugins. |
| `agent-compatibility` | [Agent Compatibility](agent-compatibility/) | Cursor | Developer Tools | CLI-backed repo compatibility scans plus Cursor agents that audit startup, validation, and docs against reality. |
| `cli-for-agent` | [CLI for Agents](cli-for-agent/) | Cursor | Developer Tools | Patterns for designing CLIs that coding agents can run reliably: flags, help with examples, pipelines, errors, idempotency, dry-run. |

## OpenAI / Codex integrations

The repository also carries portable OpenAI Agent Plugin integrations under `.agents/plugins/marketplace.json`. These coexist with the Cursor marketplace and keep host-specific metadata separate.

| `name` | Integration | Upstream | Surfaces | Status |
|:-------|:------------|:---------|:---------|:-------|
| `blender-agent-studio` | [Blender Agent Studio](blender-agent-studio/) | [ifBars/blender-agent-studio](https://github.com/ifBars/blender-agent-studio) | Codex + ChatGPT via MCP | Adapter added, ChatGPT runtime acceptance pending |

Author values in the Cursor section match each plugin’s `plugin.json` `author.name` (Cursor lists `plugins@cursor.com` in the manifest). OpenAI adapter ownership and upstream provenance are recorded inside each integration directory.

## Repository structure

This is a multi-plugin marketplace repository. The root `.cursor-plugin/marketplace.json` lists Cursor plugins. The root `.agents/plugins/marketplace.json` lists portable OpenAI Agent Plugin integrations.

```text
plugins/
├── .cursor-plugin/
│   └── marketplace.json       # Cursor marketplace manifest
├── .agents/
│   └── plugins/
│       └── marketplace.json   # OpenAI Agent Plugin marketplace manifest
├── plugin-name/
│   ├── .cursor-plugin/
│   │   └── plugin.json        # Per-Cursor-plugin manifest
│   ├── skills/                # Agent skills (SKILL.md with frontmatter)
│   ├── rules/                 # Cursor rules (.mdc files)
│   ├── mcp.json               # MCP server definitions
│   ├── README.md
│   ├── CHANGELOG.md
│   └── LICENSE
└── blender-agent-studio/
    ├── plugin.json             # Portable Agent Plugin manifest
    ├── upstream.json           # Pinned upstream provenance
    ├── skills/                 # Host routing skill
    ├── scripts/                # Upstream bootstrap and MCP launchers
    └── chatgpt/                # ChatGPT tunnel setup
```

## License

MIT
