# Claude Code 配置项目说明

本文档记录此配置仓库的关键信息和重要注意事项，作为项目维护的知识库。

## 项目概述

这是一个 Claude Code 配置模板仓库，用于在不同设备间快速同步和恢复工作环境。

## 核心脚本

### sync.sh - 配置同步脚本

将 `~/.claude` 的实际配置同步回项目模板，自动处理敏感信息。

### install.sh - 配置安装脚本

将模板配置安装到 `~/.claude`，交互式输入敏感信息。

## 重要配置说明

### .claude.json 过滤规则

`.claude.json` 文件包含大量运行时数据，同步时必须过滤，只保留以下配置项：

```json
{
  "autoConnectIde": true,
  "hasCompletedOnboarding": true,
  "hasIdeAutoConnectDialogBeenShown": true,
  "sonnet45MigrationComplete": true,
  "opus45MigrationComplete": true,
  "thinkingMigrationComplete": true
}
```

**过滤掉的字段包括**：
- `userID` - 用户特定哈希
- `projects` - 项目统计数据（成本、token、session ID）
- `tipsHistory` - 提示历史记录
- `skillUsage` - 技能使用统计
- `lastPlanModeUse` - 最后使用时间
- `cachedStatsigGates` / `cachedDynamicConfigs` / `cachedGrowthBookFeatures` - 缓存数据
- `githubRepoPaths` - 用户特定的仓库路径

### 敏感信息脱敏规则

| 字段 | 脱敏后值 |
|------|---------|
| `env.ANTHROPIC_AUTH_TOKEN` | `"YOUR_API_KEY_HERE"` |
| `env.ANTHROPIC_BASE_URL` (非官方) | `"YOUR_CUSTOM_ENDPOINT"` |

## 工作流程

### 更新配置模板

```bash
# 1. 修改 ~/.claude 中的配置

# 2. 同步到项目模板
./sync.sh

# 3. 检查模板文件确认脱敏正确
cat config/settings.json.template

# 4. 提交变更
git add .
git commit -m "chore: update config templates"
git push
```

### 新设备安装

```bash
./install.sh
```

## 文件结构

```
claude-code-config-template/
├── sync.sh              # 配置同步脚本
├── install.sh           # 配置安装脚本
├── uninstall.sh         # 配置卸载脚本
├── config/              # 配置模板目录
│   ├── *.template       # 配置模板文件（提交到 git）
│   └── *.json           # 实际配置（不提交）
├── commands/            # 自定义命令
├── agents/              # 自定义代理
├── skills/              # 自定义技能
└── .gitignore           # 忽略敏感配置和备份文件
```

## .gitignore 配置

```
# 敏感配置（实际使用的配置，非模板）
config/settings.json
config/config.json
config/.claude.json

# 但保留模板文件
!config/*.template

# 备份目录
.template_backup/
```

## 注意事项

1. **验证脱敏结果** - 同步后检查模板文件，确保 API 密钥已替换为占位符
2. **JSON 格式验证** - 脚本会自动验证，确保 JSON 格式正确
3. **备份机制** - 每次同步会自动备份旧模板到 `.template_backup/`
4. **跨平台差异** - macOS 特定的音效配置（afplay）在非 macOS 系统上会被 install.sh 自动移除
