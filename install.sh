#!/bin/bash
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$HOME/.claude.backup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

        # 备份用户现有的 .claude.json（官方安装脚本会重置此文件）
        local claude_json_backup="$HOME/.claude.json.install-backup"
        if [ -f "$HOME/.claude.json" ]; then
            cp "$HOME/.claude.json" "$claude_json_backup"
            echo -e "${YELLOW}已备份现有 .claude.json${NC}"
        fi

        # 确保 curl 已安装
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
            # 恢复用户原有的 .claude.json 配置
            if [ -f "$claude_json_backup" ]; then
                # 合并原配置和新安装的配置
                if command -v jq &> /dev/null; then
                    # 将官方安装脚本生成的配置与用户原有配置合并
                    # 用户配置优先，保留官方脚本新增的字段
                    jq -s '.[1] as $official | .[0] + $official | with_entries(.value = ($official[.key] // .value))' \
                        "$claude_json_backup" "$HOME/.claude.json" > "$HOME/.claude.json.tmp" 2>/dev/null || \
                        jq -s '.[0] * .[1]' "$claude_json_backup" "$HOME/.claude.json" > "$HOME/.claude.json.tmp"
                    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
                    rm -f "$claude_json_backup"
                    echo -e "${GREEN}✓ 已恢复原有配置${NC}"
                else
                    # jq 不可用时，直接恢复原配置
                    mv "$claude_json_backup" "$HOME/.claude.json"
                    echo -e "${YELLOW}⚠ 已恢复原有配置（建议安装 jq 以获得更好的合并效果）${NC}"
                fi
            fi

            if command -v claude &> /dev/null; then
                echo -e "${GREEN}✓ Claude Code 安装成功${NC}"
            else
                echo -e "${YELLOW}⚠ 安装脚本已执行，请重新打开终端后再运行此脚本${NC}"
                exit 0
            fi
        else
            # 安装失败时清理备份
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
    if [ -d "$CLAUDE_DIR" ]; then
        echo -e "${YELLOW}正在备份现有配置到 $BACKUP_DIR${NC}"

        # 删除旧备份
        if [ -d "$BACKUP_DIR" ]; then
            rm -rf "$BACKUP_DIR"
        fi

        # 创建新备份
        cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}✓ 备份完成${NC}"
    else
        echo -e "${YELLOW}未找到现有配置，跳过备份${NC}"
    fi
}

# 处理模板文件 - 交互式输入敏感信息
process_template() {
    local template_file="$1"
    local output_file="$2"

    # 读取模板文件内容
    local content
    content=$(cat "$template_file")

    # 替换 YOUR_API_KEY_HERE
    if [[ "$content" == *"YOUR_API_KEY_HERE"* ]]; then
        echo -n "请输入您的 ANTHROPIC_API_KEY: "
        read -s API_KEY
        echo
        content="${content//YOUR_API_KEY_HERE/$API_KEY}"
    fi

    # 替换 YOUR_CUSTOM_ENDPOINT
    if [[ "$content" == *"YOUR_CUSTOM_ENDPOINT"* ]]; then
        echo -n "请输入您的自定义 API endpoint (留空使用默认): "
        read -r CUSTOM_ENDPOINT
        if [ -n "$CUSTOM_ENDPOINT" ]; then
            content="${content//YOUR_CUSTOM_ENDPOINT/$CUSTOM_ENDPOINT}"
        else
            # 移除包含 YOUR_CUSTOM_ENDPOINT 的行，使用默认值
            content=$(echo "$content" | sed '/YOUR_CUSTOM_ENDPOINT/d')
        fi
    fi

    # 写入输出文件
    echo "$content" > "$output_file"
}

# 处理 hooks 配置（根据操作系统调整）
process_hooks_config() {
    local settings_file="$1"
    local content

    content=$(cat "$settings_file")

    # 如果不是 macOS，移除 afplay 相关的 hooks
    if [ "$OS" != "macos" ]; then
        echo -e "${YELLOW}检测到非 macOS 系统，移除 macOS 特定的通知音效配置${NC}"
        # 使用 jq 移除 hooks（如果安装了 jq）
        if command -v jq &> /dev/null; then
            content=$(echo "$content" | jq 'del(.hooks)')
        fi
    fi

    echo "$content" > "$settings_file"
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

    # 处理 settings.json
    if [ -f "$SCRIPT_DIR/config/settings.json.template" ]; then
        process_template "$SCRIPT_DIR/config/settings.json.template" "$CLAUDE_DIR/settings.json"
        process_hooks_config "$CLAUDE_DIR/settings.json"
        echo -e "${GREEN}✓ settings.json 安装完成${NC}"
    fi

    # 处理 config.json
    if [ -f "$SCRIPT_DIR/config/config.json.template" ]; then
        cp "$SCRIPT_DIR/config/config.json.template" "$CLAUDE_DIR/config.json"
        echo -e "${GREEN}✓ config.json 安装完成${NC}"
    fi

    # 处理 .claude.json（追加模式，保留现有配置）
    if [ -f "$SCRIPT_DIR/config/.claude.json.template" ]; then
        if [ -f "$HOME/.claude.json" ]; then
            echo -e "${YELLOW}合并 .claude.json 配置...${NC}"
            # 如果 jq 可用，合并配置
            if command -v jq &> /dev/null; then
                jq -s '.[0] * .[1]' "$HOME/.claude.json" "$SCRIPT_DIR/config/.claude.json.template" > "$HOME/.claude.json.tmp"
                mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
            else
                # 否则直接追加（可能会产生无效 JSON，仅作为后备）
                cp "$SCRIPT_DIR/config/.claude.json.template" "$HOME/.claude.json"
            fi
        else
            cp "$SCRIPT_DIR/config/.claude.json.template" "$HOME/.claude.json"
        fi
        echo -e "${GREEN}✓ .claude.json 更新完成${NC}"
    fi

    # 复制 CLAUDE.md
    if [ -f "$SCRIPT_DIR/config/CLAUDE.md.template" ]; then
        cp "$SCRIPT_DIR/config/CLAUDE.md.template" "$CLAUDE_DIR/CLAUDE.md"
        echo -e "${GREEN}✓ CLAUDE.md 安装完成${NC}"
    fi
}

# 复制自定义扩展
install_extensions() {
    echo "安装自定义扩展..."

    # 复制 commands
    if [ -d "$SCRIPT_DIR/commands" ] && [ -n "$(ls -A $SCRIPT_DIR/commands 2>/dev/null)" ]; then
        cp -r "$SCRIPT_DIR/commands"/* "$CLAUDE_DIR/commands/"
        echo -e "${GREEN}✓ commands 安装完成${NC}"
    fi

    # 复制 agents
    if [ -d "$SCRIPT_DIR/agents" ] && [ -n "$(ls -A $SCRIPT_DIR/agents 2>/dev/null)" ]; then
        cp -r "$SCRIPT_DIR/agents"/* "$CLAUDE_DIR/agents/"
        echo -e "${GREEN}✓ agents 安装完成${NC}"
    fi

    # 复制 skills
    if [ -d "$SCRIPT_DIR/skills" ] && [ -n "$(ls -A $SCRIPT_DIR/skills 2>/dev/null)" ]; then
        cp -r "$SCRIPT_DIR/skills"/* "$CLAUDE_DIR/skills/" 2>/dev/null || true
        echo -e "${GREEN}✓ skills 安装完成${NC}"
    fi
}

# 验证 JSON 格式
validate_json() {
    echo "验证 JSON 格式..."

    if command -v jq &> /dev/null; then
        for json_file in "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/config.json" "$HOME/.claude.json"; do
            if [ -f "$json_file" ]; then
                if jq empty "$json_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ $(basename $json_file) 格式正确${NC}"
                else
                    echo -e "${RED}✗ $(basename $json_file) 格式错误${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}未安装 jq，跳过 JSON 验证${NC}"
    fi
}

# 显示安装摘要
show_summary() {
    echo ""
    echo "======================================"
    echo -e "${GREEN}安装完成！${NC}"
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
    show_summary
}

# 执行主流程
main
