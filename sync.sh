#!/bin/bash
set -e

# ==================== 配置变量 ====================
CLAUDE_DIR="$HOME/.claude"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TEMPLATE_DIR="$PROJECT_ROOT/config"
BACKUP_DIR="$PROJECT_ROOT/.template_backup/$(date +%Y%m%d_%H%M%S)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 统计变量
SYNCED_CONFIGS=0
SYNCED_EXTENSIONS=0

# ==================== 前置检查 ====================
check_prerequisites() {
    echo -e "${BLUE}检查前置条件...${NC}"

    # 检查 Claude 目录
    if [ ! -d "$CLAUDE_DIR" ]; then
        echo -e "${RED}错误: Claude 配置目录不存在: $CLAUDE_DIR${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Claude 配置目录存在"

    # 检查 jq 是否安装
    if command -v jq &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} jq 已安装"
    else
        echo -e "  ${YELLOW}⚠${NC} 未安装 jq，将使用 sed 进行简单替换"
    fi

    # 检查项目目录结构
    if [ ! -d "$CONFIG_TEMPLATE_DIR" ]; then
        mkdir -p "$CONFIG_TEMPLATE_DIR"
        echo -e "  ${GREEN}✓${NC} 创建 config 模板目录"
    else
        echo -e "  ${GREEN}✓${NC} 项目目录结构正确"
    fi

    echo ""
}

# ==================== 备份现有模板 ====================
backup_templates() {
    echo -e "${BLUE}备份现有模板文件...${NC}"

    local has_templates=false
    for template in "$CONFIG_TEMPLATE_DIR"/*.template; do
        if [ -f "$template" ]; then
            has_templates=true
            break
        fi
    done

    if [ "$has_templates" = true ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$CONFIG_TEMPLATE_DIR"/*.template "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} 备份至 $BACKUP_DIR"
    else
        echo -e "  ${YELLOW}⚠${NC} 无现有模板文件，跳过备份"
    fi

    echo ""
}

# ==================== 脱敏 JSON 配置 ====================
sanitize_json() {
    local input_file="$1"
    local output_file="$2"

    if [ ! -f "$input_file" ]; then
        return 1
    fi

    # 验证源文件 JSON 格式
    if command -v jq &> /dev/null; then
        if ! jq empty "$input_file" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} 源文件 JSON 格式错误: $(basename $input_file)"
            return 1
        fi

        # 使用 jq 进行安全的 JSON 操作
        jq '
            # 替换 API 密钥
            if .env and .env.ANTHROPIC_AUTH_TOKEN then
                .env.ANTHROPIC_AUTH_TOKEN = "YOUR_API_KEY_HERE"
            else
                .
            end |
            # 检测非官方 endpoint 并替换
            if .env and .env.ANTHROPIC_BASE_URL then
                if (.env.ANTHROPIC_BASE_URL | test("api\\.anthropic\\.com") | not) then
                    .env.ANTHROPIC_BASE_URL = "YOUR_CUSTOM_ENDPOINT"
                else
                    .
                end
            else
                .
            end
        ' "$input_file" > "$output_file"
    else
        # 降级方案：使用 sed 替换已知字段
        sed 's/"ANTHROPIC_AUTH_TOKEN": "[^"]*"/"ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY_HERE"/' \
            "$input_file" > "$output_file"
        # 替换自定义 endpoint（非官方域名）
        sed -i '' 's|"ANTHROPIC_BASE_URL": "https://[^"]*"|"ANTHROPIC_BASE_URL": "YOUR_CUSTOM_ENDPOINT"|g' "$output_file" 2>/dev/null || \
        sed -i 's|"ANTHROPIC_BASE_URL": "https://[^"]*"|"ANTHROPIC_BASE_URL": "YOUR_CUSTOM_ENDPOINT"|g' "$output_file"
    fi

    return 0
}

# ==================== 过滤 .claude.json 配置 ====================
sanitize_claude_json() {
    local input="$HOME/.claude.json"
    local output="$CONFIG_TEMPLATE_DIR/.claude.json.template"

    if [ ! -f "$input" ]; then
        return 1
    fi

    if command -v jq &> /dev/null; then
        if ! jq empty "$input" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} 源文件 JSON 格式错误: .claude.json"
            return 1
        fi

        # 只保留配置项，移除所有运行时数据
        jq '{
            autoConnectIde: .autoConnectIde,
            hasCompletedOnboarding: .hasCompletedOnboarding,
            hasIdeAutoConnectDialogBeenShown: .hasIdeAutoConnectDialogBeenShown,
            sonnet45MigrationComplete: .sonnet45MigrationComplete,
            opus45MigrationComplete: .opus45MigrationComplete,
            thinkingMigrationComplete: .thinkingMigrationComplete
        }' "$input" > "$output"
    else
        echo -e "  ${YELLOW}⚠${NC} jq 未安装，跳过 .claude.json 同步"
        return 1
    fi

    return 0
}

# ==================== 同步配置文件 ====================
sync_config_files() {
    echo -e "${BLUE}同步配置文件...${NC}"

    # 同步 settings.json
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        if sanitize_json "$CLAUDE_DIR/settings.json" "$CONFIG_TEMPLATE_DIR/settings.json.template"; then
            echo -e "  ${GREEN}✓${NC} settings.json.template 已更新"
            ((SYNCED_CONFIGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} settings.json 不存在，跳过"
    fi

    # 同步 CLAUDE.md
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        cp "$CLAUDE_DIR/CLAUDE.md" "$CONFIG_TEMPLATE_DIR/CLAUDE.md.template"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md.template 已更新"
        ((SYNCED_CONFIGS++))
    else
        echo -e "  ${YELLOW}⚠${NC} CLAUDE.md 不存在，跳过"
    fi

    # 同步 config.json
    if [ -f "$CLAUDE_DIR/config.json" ]; then
        cp "$CLAUDE_DIR/config.json" "$CONFIG_TEMPLATE_DIR/config.json.template"
        echo -e "  ${GREEN}✓${NC} config.json.template 已更新"
        ((SYNCED_CONFIGS++))
    else
        echo -e "  ${YELLOW}⚠${NC} config.json 不存在，跳过"
    fi

    # 同步 .claude.json (只保留配置项)
    if [ -f "$HOME/.claude.json" ]; then
        if sanitize_claude_json; then
            echo -e "  ${GREEN}✓${NC} .claude.json.template 已更新"
            ((SYNCED_CONFIGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} .claude.json 不存在，跳过"
    fi

    echo ""
}

# ==================== 同步扩展目录 ====================
sync_extension_dir() {
    local source_dir="$1"
    local target_dir="$2"
    local dir_name="$3"

    if [ ! -d "$source_dir" ]; then
        echo -e "  ${YELLOW}⚠${NC} $dir_name 源目录不存在"
        return
    fi

    # 确保目标目录存在
    mkdir -p "$target_dir"

    # 查找并同步 .md 文件
    local file_count=0
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        local target_file="$target_dir/$filename"

        cp "$file" "$target_file"
        ((file_count++))
        ((SYNCED_EXTENSIONS++))

        echo -e "    ${GREEN}✓${NC} $filename"
    done < <(find "$source_dir" -maxdepth 1 -name "*.md" -print0 2>/dev/null)

    if [ $file_count -eq 0 ]; then
        echo -e "    ${YELLOW}⚠${NC} 未找到 .md 文件"
    fi
}

sync_extensions() {
    echo -e "${BLUE}同步自定义扩展...${NC}"

    # 同步 commands
    echo -e "  commands/"
    sync_extension_dir "$CLAUDE_DIR/commands" "$PROJECT_ROOT/commands" "commands"

    # 同步 agents
    echo -e "  agents/"
    sync_extension_dir "$CLAUDE_DIR/agents" "$PROJECT_ROOT/agents" "agents"

    # 同步 skills
    echo -e "  skills/"
    if [ -d "$CLAUDE_DIR/skills" ]; then
        sync_extension_dir "$CLAUDE_DIR/skills" "$PROJECT_ROOT/skills" "skills"
    else
        echo -e "    ${YELLOW}⚠${NC} skills 目录不存在"
    fi

    echo ""
}

# ==================== 验证脱敏结果 ====================
verify_sanitization() {
    echo -e "${BLUE}验证脱敏结果...${NC}"

    local has_issue=false

    # 检查模板文件中是否包含真实 API 密钥的特征
    local sensitive_patterns=(
        "sk-ant-[a-zA-Z0-9_-]{40,}"
        "[a-zA-Z0-9_-]{32,}\\.[a-zA-Z0-9_-]{20,}"
    )

    for template_file in "$CONFIG_TEMPLATE_DIR"/*.template; do
        if [ -f "$template_file" ]; then
            for pattern in "${sensitive_patterns[@]}"; do
                if grep -qE "$pattern" "$template_file" 2>/dev/null; then
                    echo -e "  ${RED}✗${NC} $(basename $template_file) 可能包含敏感信息"
                    has_issue=true
                fi
            done
        fi
    done

    if [ "$has_issue" = false ]; then
        echo -e "  ${GREEN}✓${NC} 未检测到敏感信息"
    else
        echo -e "  ${YELLOW}⚠${NC} 请手动检查上述文件"
    fi

    # 验证 JSON 格式
    if command -v jq &> /dev/null; then
        echo ""
        echo -e "${BLUE}验证 JSON 格式...${NC}"
        for json_file in "$CONFIG_TEMPLATE_DIR"/settings.json.template \
                         "$CONFIG_TEMPLATE_DIR"/config.json.template \
                         "$CONFIG_TEMPLATE_DIR"/.claude.json.template; do
            if [ -f "$json_file" ]; then
                if jq empty "$json_file" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} $(basename $json_file)"
                else
                    echo -e "  ${RED}✗${NC} $(basename $json_file) 格式错误"
                fi
            fi
        done
    fi

    echo ""
}

# ==================== 显示摘要 ====================
show_summary() {
    echo "======================================"
    echo -e "${GREEN}同步完成！${NC}"
    echo ""
    echo "配置文件: $SYNCED_CONFIGS 个已更新"
    echo "自定义扩展: $SYNCED_EXTENSIONS 个文件"
    if [ -d "$BACKUP_DIR" ]; then
        echo "备份位置: $BACKUP_DIR"
    fi
    echo ""
    echo "下一步:"
    echo "1. 检查模板文件确认脱敏正确"
    echo "2. 使用 git 提交变更: git add . && git commit -m 'chore: sync config templates'"
    echo ""
}

# ==================== 主流程 ====================
main() {
    echo -e "${GREEN}Claude Code 配置同步脚本${NC}"
    echo "======================================"
    echo ""

    check_prerequisites
    backup_templates
    sync_config_files
    sync_extensions
    verify_sanitization
    show_summary
}

# 执行主流程
main
