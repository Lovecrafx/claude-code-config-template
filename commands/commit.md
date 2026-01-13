---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit
---

## Conventional Commits 格式

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Type 类型

| type | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 仅文档变更 |
| `style` | 代码格式（不影响含义的修改） |
| `refactor` | 重构（既不是新功能也不是 Bug 修复） |
| `perf` | 性能优化 |
| `test` | 添加或修改测试 |
| `chore` | 构建过程或辅助工具的变更 |
| `ci` | CI 配置变更 |
| `build` | 构建系统变更 |
| `revert` | 回滚提交 |

## 示例

**简单提交：**
```
feat: 添加用户登录功能
```

**带 Scope：**
```
feat(auth): 添加用户登录功能
fix(api): 修复用户查询接口的空指针问题
```

**带 Body：**
```
feat: 添加用户登录功能

实现完整的用户认证流程：
- 集成 JWT 令牌机制
- 添加登录/登出接口
- 支持记住密码功能
```

**带 Footer（Breaking Change）：**
```
feat: 重构用户认证模块

BREAKING CHANGE: 认证 API 路径从 /api/login 变更为 /api/auth/login
```

## 任务

1. 分析 diff 内容，理解变更的性质和目的
2. 生成 3 个 commit 消息候选
3. 选择最合适的消息并说明理由
4. **预览 commit message，等待用户确认**
5. 用户确认后，使用 git add 暂存变更
6. 执行 git commit

## 约束

- 禁止添加 Claude 共同作者 footer
- Breaking Change 必须用 `BREAKING CHANGE:` 或 `!:` 标注
