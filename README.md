# Claude Code 配置仓库

这是一个可复现的 Claude Code 配置仓库，用于在重装电脑或切换设备后快速恢复工作环境。

## 功能特性

- **一键安装**: 自动化脚本快速安装所有配置
- **安全备份**: 安装前自动备份现有配置
- **模板化管理**: 敏感信息（如 API 密钥）使用占位符，不会提交到仓库
- **跨平台支持**: 支持 macOS 和 Linux
- **自定义扩展**: 包含自定义命令、代理和技能

## 目录结构

```
claude-code-config-template/
├── README.md                      # 本文件
├── .gitignore                     # 防止敏感信息泄露
├── install.sh                     # 一键安装脚本
├── uninstall.sh                   # 卸载脚本
├── config/                        # 配置文件模板
│   ├── CLAUDE.md.template         # 全局指令模板
│   ├── settings.json.template     # 主配置模板（含占位符）
│   ├── config.json.template       # API 配置模板
│   └── .claude.json.template      # 应用级配置模板
├── commands/                      # 自定义命令
│   └── commit.md                  # Conventional Commits 提交规范
├── agents/                        # 自定义代理
│   └── git-operation-manager.md   # Git 操作管理代理
└── skills/                        # 自定义技能（预留扩展）
    └── .gitkeep
```

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/claude-code-config-template.git
cd claude-code-config-template
```

### 2. 运行安装脚本

```bash
chmod +x install.sh
./install.sh
```

安装脚本会：
1. 检测你的操作系统
2. 备份现有配置到 `~/.claude.backup`
3. 提示输入 API 密钥
4. 安装所有配置文件和自定义扩展

### 3. 重启 Claude Code

重启应用以加载新配置。

## 配置说明

### settings.json

主配置文件，包含：
- **启用的插件**: code-review, code-simplifier, commit-commands, context7, frontend-design
- **LSP 支持**: jdtls-lsp, lua-lsp, pyright-lsp, typescript-lsp
- **语言设置**: 中文
- **通知音效**: macOS 系统音效（非 macOS 系统会自动移除）
- **状态栏**: ccusage 集成

### CLAUDE.md

全局指令配置，定义了：
- 默认使用中文回复
- 自动使用 Context7 MCP 获取文档
- 确认需求后再执行

### 自定义命令

- **/commit**: 使用 Conventional Commits 规范创建提交

### 自定义代理

- **git-operation-manager**: Git 操作管理器，提供安全的 Git 操作

## 自定义配置

### 添加新的自定义命令

1. 在 `commands/` 目录创建 `.md` 文件
2. 添加 YAML frontmatter:

```markdown
---
description: 命令描述
allowed-tools: Bash, Read
---

命令内容...
```

### 添加新的自定义代理

1. 在 `agents/` 目录创建 `.md` 文件
2. 添加 frontmatter:

```markdown
---
name: my-agent
description: "代理描述"
tools: Bash, Read, Grep
model: sonnet
---

代理指令...
```

### 修改 API 配置

编辑 `config/settings.json.template`，修改以下字段：
- `ANTHROPIC_BASE_URL`: 你的自定义 API endpoint
- `ANTHROPIC_DEFAULT_*_MODEL`: 默认模型配置

## 卸载

运行卸载脚本：

```bash
chmod +x uninstall.sh
./uninstall.sh
```

卸载脚本会：
1. 备份当前配置
2. 删除所有配置文件
3. 提供从备份恢复的选项

## 手动恢复备份

如果需要从备份恢复配置：

```bash
cp -r ~/.claude.backup/* ~/.claude/
```

## 常见问题

### Q: 安装后配置没有生效？

A: 请确保重启了 Claude Code 应用。如果仍然无效，检查 `~/.claude/` 目录下的文件是否正确生成。

### Q: 如何验证 JSON 格式是否正确？

A: 安装脚本会自动验证。你也可以手动检查：

```bash
jq empty ~/.claude/settings.json
```

### Q: 我使用的是 Linux，通知音效会报错吗？

A: 不会。安装脚本会自动检测操作系统并移除 macOS 特定的音效配置。

### Q: 可以在不重新安装的情况下更新配置吗？

A: 可以。直接修改 `~/.claude/` 下的配置文件，然后重启 Claude Code。

### Q: 这个仓库会包含我的 API 密钥吗？

A: 不会。所有配置文件使用模板，敏感信息使用占位符。实际配置仅在本地生成。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个配置仓库！

## 许可证

MIT License

---

**注意**: 请勿在仓库中提交包含真实 API 密钥的配置文件。仅提交 `.template` 文件。
