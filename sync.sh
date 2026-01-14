#!/bin/bash
set -e

# 引入公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

# 解析命令行参数
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

# 统计变量
SYNCED_CONFIGS=0
SYNCED_EXTENSIONS=0
DELETED_TEMPLATES=0

# ============================================================================
# 主流程函数
# ============================================================================

print_header() {
    echo -e "${BLUE}Claude Code 配置同步脚本${NC}"
    echo "======================================"
    echo ""
}

# 检查前置条件
check_prerequisites() {
    echo -e "${BLUE}检查前置条件...${NC}"

    if [ ! -d "$CLAUDE_DIR" ]; then
        echo -e "${RED}错误: Claude 配置目录不存在: $CLAUDE_DIR${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Claude 配置目录存在"

    if has_jq; then
        echo -e "  ${GREEN}✓${NC} jq 已安装"
    else
        echo -e "  ${YELLOW}⚠${NC} 未安装 jq，将使用 sed 进行简单替换"
    fi

    if [ ! -d "$CONFIG_TEMPLATE_DIR" ]; then
        mkdir -p "$CONFIG_TEMPLATE_DIR"
        echo -e "  ${GREEN}✓${NC} 创建 config 模板目录"
    else
        echo -e "  ${GREEN}✓${NC} 项目目录结构正确"
    fi

    echo ""
}

# 备份现有模板
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
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_dir="$TEMPLATE_BACKUP_DIR/$timestamp"
        mkdir -p "$backup_dir"
        cp -r "$CONFIG_TEMPLATE_DIR"/*.template "$backup_dir/" 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} 备份至 $backup_dir"
    else
        echo -e "  ${YELLOW}⚠${NC} 无现有模板文件，跳过备份"
    fi

    echo ""
}

# 检测需要删除的扩展文件
detect_extension_deletions() {
    local ext_type="$1"
    local source_dir="$CLAUDE_DIR/$ext_type"
    local target_dir="$PROJECT_ROOT/$ext_type"

    [ ! -d "$target_dir" ] && return 0

    for template_file in "$target_dir"/*.md; do
        [ -f "$template_file" ] || continue

        local basename
        basename=$(basename "$template_file")
        [[ "$basename" == ".gitkeep" ]] && continue

        local source_file="$source_dir/$basename"
        [ ! -f "$source_file" ] && echo "$template_file"
    done
}

# 执行删除同步
sync_deletions() {
    echo -e "${BLUE}检查需要删除的模板文件...${NC}"

    local all_deletions=()

    # 收集扩展文件删除（只保留 commands/agents/skills）
    for ext in "${EXTENSIONS[@]}"; do
        while IFS= read -r file; do
            [ -n "$file" ] && all_deletions+=("$file")
        done < <(detect_extension_deletions "$ext")
    done

    # 无需删除
    if [ ${#all_deletions[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} 无需删除的文件"
        echo ""
        return 0
    fi

    # 显示待删除文件
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] 将要删除 ${#all_deletions[@]} 个文件:${NC}"
    else
        echo -e "${YELLOW}将删除 ${#all_deletions[@]} 个过时模板:${NC}"
    fi

    for file in "${all_deletions[@]}"; do
        echo -e "  ${RED}✗${NC} ${file#$PROJECT_ROOT/}"
    done
    echo ""

    # Dry-run 模式不执行删除
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] 未执行实际删除${NC}"
        echo ""
        return 0
    fi

    # 执行删除
    local deleted_count=0
    for file in "${all_deletions[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            echo -e "  ${GREEN}✓${NC} 已删除: $(basename "$file")"
            ((deleted_count++))
        fi
    done

    [ $deleted_count -gt 0 ] && echo ""
    DELETED_TEMPLATES=$deleted_count
}

# 脱敏 settings.json
sanitize_settings() {
    local input_file="$CLAUDE_DIR/settings.json"
    local output_file="$SETTINGS_TEMPLATE"

    [ ! -f "$input_file" ] && return 1

    if has_jq; then
        if ! jq empty "$input_file" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} 源文件 JSON 格式错误: $(basename "$input_file")"
            return 1
        fi

        jq '
            if .env and .env.ANTHROPIC_AUTH_TOKEN then
                .env.ANTHROPIC_AUTH_TOKEN = "'"$PLACEHOLDER_API_KEY"'"
            else . end |
            if .env and .env.ANTHROPIC_BASE_URL and
               (.env.ANTHROPIC_BASE_URL | test("api\\.anthropic\\.com") | not) then
                .env.ANTHROPIC_BASE_URL = "'"$PLACEHOLDER_ENDPOINT"'"
            else . end |
            if .hooks then del(.hooks) else . end
        ' "$input_file" > "$output_file"
    else
        sed 's/"ANTHROPIC_AUTH_TOKEN": "[^"]*"/"ANTHROPIC_AUTH_TOKEN": "'"$PLACEHOLDER_API_KEY"'"/' \
            "$input_file" > "$output_file"
        sed_replace 's|"ANTHROPIC_BASE_URL": "https://[^"]*"|"ANTHROPIC_BASE_URL": "'"$PLACEHOLDER_ENDPOINT"'"|g' "$output_file"
    fi

    return 0
}

# 过滤 .claude.json 配置
sanitize_claude_json() {
    local input="$HOME/.claude.json"
    local output="$CLAUDE_JSON_TEMPLATE"

    [ ! -f "$input" ] && return 1

    if ! has_jq; then
        echo -e "  ${YELLOW}⚠${NC} jq 未安装，跳过 .claude.json 同步"
        return 1
    fi

    if ! jq empty "$input" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} 源文件 JSON 格式错误: .claude.json"
        return 1
    fi

    jq '{
        autoConnectIde: .autoConnectIde,
        hasCompletedOnboarding: .hasCompletedOnboarding,
        hasIdeAutoConnectDialogBeenShown: .hasIdeAutoConnectDialogBeenShown,
        sonnet45MigrationComplete: .sonnet45MigrationComplete,
        opus45MigrationComplete: .opus45MigrationComplete,
        thinkingMigrationComplete: .thinkingMigrationComplete
    }' "$input" > "$output"

    return 0
}

# 同步配置文件
sync_config_files() {
    echo -e "${BLUE}同步配置文件...${NC}"

    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        if sanitize_settings; then
            echo -e "  ${GREEN}✓${NC} settings.json.template 已更新"
            ((SYNCED_CONFIGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} settings.json 不存在，跳过"
    fi

    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_MD_TEMPLATE"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md.template 已更新"
        ((SYNCED_CONFIGS++))
    else
        echo -e "  ${YELLOW}⚠${NC} CLAUDE.md 不存在，跳过"
    fi

    if [ -f "$CLAUDE_DIR/config.json" ]; then
        cp "$CLAUDE_DIR/config.json" "$CONFIG_TEMPLATE"
        echo -e "  ${GREEN}✓${NC} config.json.template 已更新"
        ((SYNCED_CONFIGS++))
    else
        echo -e "  ${YELLOW}⚠${NC} config.json 不存在，跳过"
    fi

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

# 同步自定义扩展
sync_extensions() {
    echo -e "${BLUE}同步自定义扩展...${NC}"

    for ext in "${EXTENSIONS[@]}"; do
        echo -e "  ${ext}/"
        sync_extension_dir "$CLAUDE_DIR/$ext" "$PROJECT_ROOT/$ext" "$ext"
    done

    echo ""
}

# 验证脱敏结果
verify_sanitization() {
    echo -e "${BLUE}验证脱敏结果...${NC}"

    local has_issue=false
    local sensitive_patterns=(
        "sk-ant-[a-zA-Z0-9_-]{40,}"
        "[a-zA-Z0-9_-]{32,}\\.[a-zA-Z0-9_-]{20,}"
    )

    for template_file in "$CONFIG_TEMPLATE_DIR"/*.template; do
        [ -f "$template_file" ] || continue

        for pattern in "${sensitive_patterns[@]}"; do
            if grep -qE "$pattern" "$template_file" 2>/dev/null; then
                echo -e "  ${RED}✗${NC} $(basename "$template_file") 可能包含敏感信息"
                has_issue=true
            fi
        done
    done

    if [ "$has_issue" = false ]; then
        echo -e "  ${GREEN}✓${NC} 未检测到敏感信息"
    else
        echo -e "  ${YELLOW}⚠${NC} 请手动检查上述文件"
    fi

    if has_jq; then
        echo ""
        validate_json_files \
            "$SETTINGS_TEMPLATE" \
            "$CONFIG_TEMPLATE" \
            "$CLAUDE_JSON_TEMPLATE"
    else
        echo ""
    fi
}

# 显示同步摘要
print_sync_summary() {
    echo "======================================"
    echo -e "${GREEN}✓ 同步完成！${NC}"
    echo ""
    echo "配置文件: $SYNCED_CONFIGS 个已更新"
    echo "自定义扩展: $SYNCED_EXTENSIONS 个文件"
    if [ $DELETED_TEMPLATES -gt 0 ]; then
        echo -e "${YELLOW}已删除: $DELETED_TEMPLATES 个过时模板${NC}"
    fi
    if [ -d "$TEMPLATE_BACKUP_DIR" ]; then
        echo "备份位置: $TEMPLATE_BACKUP_DIR"
    fi
    echo ""
    echo "下一步:"
    echo "1. 检查模板文件确认脱敏正确"
    echo "2. 使用 git 提交变更: git add . && git commit -m 'chore: sync config templates'"
    echo ""
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    print_header
    check_prerequisites
    backup_templates
    sync_deletions
    sync_config_files
    sync_extensions
    verify_sanitization
    print_sync_summary
}

# 执行主流程
main

