#!/bin/bash
set -e

# 引入公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

echo -e "${GREEN}Claude Code 配置安装脚本${NC}"
echo "======================================"

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        echo "检测到操作系统: macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        echo "检测到操作系统: Linux"
    else
        echo -e "${RED}错误: 不支持的操作系统 $OSTYPE${NC}"
        exit 1
    fi
}

# 检测并安装 Claude Code
check_claude_code() {
    echo "检查 Claude Code 安装..."

    if ! command -v claude &> /dev/null; then
        echo -e "${YELLOW}未检测到 Claude Code CLI${NC}"

        local claude_json_backup="$HOME/.claude.json.install-backup"
        if [ -f "$HOME/.claude.json" ]; then
            cp "$HOME/.claude.json" "$claude_json_backup"
            echo -e "${YELLOW}已备份现有 .claude.json${NC}"
        fi

        if ! command -v curl &> /dev/null; then
            echo "正在安装 curl..."
            if [ "$OS" = "macos" ]; then
                if command -v brew &> /dev/null; then
                    brew install curl
                else
                    echo -e "${RED}未检测到 Homebrew，请先安装: https://brew.sh${NC}"
                    exit 1
                fi
            else
                if command -v apt-get &> /dev/null; then
                    apt-get update -qq && apt-get install -y curl
                elif command -v yum &> /dev/null; then
                    yum install -y curl
                else
                    echo -e "${RED}无法自动安装 curl，请手动安装${NC}"
                    exit 1
                fi
            fi
        fi

        echo "正在自动安装 Claude Code..."
        echo ""

        if curl -fsSL https://claude.ai/install.sh | bash; then
            echo ""
            if [ -f "$claude_json_backup" ]; then
                if has_jq; then
                    merge_configs "$claude_json_backup" "$HOME/.claude.json" "$HOME/.claude.json.tmp"
                    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
                    rm -f "$claude_json_backup"
                    echo -e "${GREEN}✓ 已恢复原有配置${NC}"
                else
                    mv "$claude_json_backup" "$HOME/.claude.json"
                    echo -e "${YELLOW}⚠ 已恢复原有配置（建议安装 jq 以获得更好的合并效果）${NC}"
                fi
            fi

            export PATH="$HOME/.local/bin:$PATH"

            if command -v claude &> /dev/null; then
                echo -e "${GREEN}✓ Claude Code 安装成功${NC}"
            else
                echo -e "${YELLOW}⚠ Claude Code 安装完成，但当前会话中无法检测到命令${NC}"
                echo -e "${YELLOW}⚠ 继续执行配置安装流程...${NC}"
            fi
        else
            rm -f "$claude_json_backup"
            echo -e "${RED}✗ Claude Code 安装失败${NC}"
            echo "请手动安装后重试: curl -fsSL https://claude.ai/install.sh | bash"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Claude Code 已安装${NC}"
    fi
    echo ""
}

# 备份现有配置
backup_existing_config() {
    create_backup "$CLAUDE_DIR" "$BACKUP_DIR" "现有配置"
}

# 处理模板文件 - 交互式输入敏感信息
process_template() {
    local template_file="$1"
    local output_file="$2"
    local content
    content=$(cat "$template_file")

    if [[ "$content" == *"$PLACEHOLDER_API_KEY"* ]]; then
        if [ -n "$ANTHROPIC_API_KEY" ]; then
            API_KEY="$ANTHROPIC_API_KEY"
        elif [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
            API_KEY="$ANTHROPIC_AUTH_TOKEN"
        else
            echo -n "请输入您的 ANTHROPIC_API_KEY: "
            read -s API_KEY
            echo
        fi
        content="${content//$PLACEHOLDER_API_KEY/$API_KEY}"
    fi

    if [[ "$content" == *"$PLACEHOLDER_ENDPOINT"* ]]; then
        CUSTOM_ENDPOINT=""
        if [ ! -t 0 ]; then
            content=$(echo "$content" | sed "/$PLACEHOLDER_ENDPOINT/d")
        elif [ -n "$ANTHROPIC_BASE_URL" ]; then
            CUSTOM_ENDPOINT="$ANTHROPIC_BASE_URL"
            content="${content//$PLACEHOLDER_ENDPOINT/$CUSTOM_ENDPOINT}"
        else
            echo -n "请输入您的自定义 API endpoint (留空使用默认): "
            read -r CUSTOM_ENDPOINT
            if [ -n "$CUSTOM_ENDPOINT" ]; then
                content="${content//$PLACEHOLDER_ENDPOINT/$CUSTOM_ENDPOINT}"
            else
                content=$(echo "$content" | sed "/$PLACEHOLDER_ENDPOINT/d")
            fi
        fi
    fi

    echo "$content" > "$output_file"
}

# 处理 hooks 配置（预留用于未来扩展）
process_hooks_config() {
    # 未来可能需要根据操作系统调整 hooks 配置
    :
}

# 创建必要的目录结构
create_directories() {
    echo "创建目录结构..."
    mkdir -p "$CLAUDE_DIR"/{commands,agents,skills}
    echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 安装配置文件
install_configs() {
    echo "安装配置文件..."

    if [ -f "$SETTINGS_TEMPLATE" ]; then
        process_template "$SETTINGS_TEMPLATE" "$CLAUDE_DIR/settings.json"
        process_hooks_config "$CLAUDE_DIR/settings.json"
        echo -e "${GREEN}✓ settings.json 安装完成${NC}"
    fi

    if [ -f "$CONFIG_TEMPLATE" ]; then
        cp "$CONFIG_TEMPLATE" "$CLAUDE_DIR/config.json"
        echo -e "${GREEN}✓ config.json 安装完成${NC}"
    fi

    if [ -f "$CLAUDE_JSON_TEMPLATE" ]; then
        if [ -f "$HOME/.claude.json" ]; then
            echo -e "${YELLOW}合并 .claude.json 配置...${NC}"
            if has_jq; then
                merge_configs "$HOME/.claude.json" "$CLAUDE_JSON_TEMPLATE" "$HOME/.claude.json.tmp"
                mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
            else
                cp "$CLAUDE_JSON_TEMPLATE" "$HOME/.claude.json"
            fi
        else
            cp "$CLAUDE_JSON_TEMPLATE" "$HOME/.claude.json"
        fi
        echo -e "${GREEN}✓ .claude.json 更新完成${NC}"
    fi

    if [ -f "$CLAUDE_MD_TEMPLATE" ]; then
        cp "$CLAUDE_MD_TEMPLATE" "$CLAUDE_DIR/CLAUDE.md"
        echo -e "${GREEN}✓ CLAUDE.md 安装完成${NC}"
    fi
}

# 安装自定义扩展
install_extensions() {
    echo "安装自定义扩展..."

    for ext in "${EXTENSIONS[@]}"; do
        local source_dir="$PROJECT_ROOT/$ext"
        if [ -d "$source_dir" ] && [ -n "$(ls -A $source_dir 2>/dev/null)" ]; then
            cp -r "$source_dir"/* "$CLAUDE_DIR/$ext/"
            echo -e "${GREEN}✓ ${ext} 安装完成${NC}"
        fi
    done
}

# 验证 JSON 格式
validate_json() {
    validate_json_files \
        "$CLAUDE_DIR/settings.json" \
        "$CLAUDE_DIR/config.json" \
        "$HOME/.claude.json"
}

# 显示安装摘要
print_install_summary() {
    echo ""
    echo "======================================"
    echo -e "${GREEN}✓ 安装完成！${NC}"
    echo ""
    echo "配置位置: $CLAUDE_DIR"
    echo "备份位置: $BACKUP_DIR"
    echo ""
    echo "下一步:"
    echo "1. 重启 Claude Code 应用"
    echo "2. 检查配置是否正确加载"
    echo "3. 如有问题，可从备份恢复: cp -r $BACKUP_DIR/* $CLAUDE_DIR/"
    echo ""
}

# 主流程
main() {
    detect_os
    check_claude_code
    backup_existing_config
    create_directories
    install_configs
    install_extensions
    validate_json
    print_install_summary
}

# 执行主流程
main

