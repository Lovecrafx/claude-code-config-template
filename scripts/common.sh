#!/bin/bash
# Claude Code 配置管理公共库
# 提供通用的工具函数和常量定义

# ============================================================================
# 颜色变量常量
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# 路径变量常量
# ============================================================================
readonly CLAUDE_DIR="$HOME/.claude"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_TEMPLATE_DIR="$PROJECT_ROOT/config"
readonly BACKUP_DIR="$HOME/.claude.backup"
readonly TEMPLATE_BACKUP_DIR="$PROJECT_ROOT/.template_backup"

# ============================================================================
# 模板文件路径常量
# ============================================================================
readonly SETTINGS_TEMPLATE="$CONFIG_TEMPLATE_DIR/settings.json.template"
readonly CONFIG_TEMPLATE="$CONFIG_TEMPLATE_DIR/config.json.template"
readonly CLAUDE_JSON_TEMPLATE="$CONFIG_TEMPLATE_DIR/.claude.json.template"
readonly CLAUDE_MD_TEMPLATE="$CONFIG_TEMPLATE_DIR/CLAUDE.md.template"

# ============================================================================
# 敏感信息占位符常量
# ============================================================================
readonly PLACEHOLDER_API_KEY="YOUR_API_KEY_HERE"
readonly PLACEHOLDER_ENDPOINT="YOUR_CUSTOM_ENDPOINT"

# ============================================================================
# 扩展目录定义
# ============================================================================
readonly EXTENSIONS=("commands" "agents" "skills")

# ============================================================================
# 工具检测函数
# ============================================================================

# 检查 jq 是否可用
has_jq() {
    command -v jq &> /dev/null
}

# 如果需要 jq 但未安装，输出警告
require_jq() {
    if ! has_jq; then
        echo -e "${YELLOW}⚠ 未安装 jq，建议安装以获得完整功能${NC}"
        return 1
    fi
    return 0
}

# ============================================================================
# 备份函数
# ============================================================================

# 创建备份
# 参数: $1=源目录, $2=目标目录, $3=描述信息
create_backup() {
    local source_dir="$1"
    local target_dir="$2"
    local description="${3:-配置}"

    if [ ! -d "$source_dir" ]; then
        echo -e "${YELLOW}未找到 ${description}，跳过备份${NC}"
        return 1
    fi

    echo -e "${YELLOW}正在备份${description}到 $target_dir${NC}"

    # 删除旧备份
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi

    # 创建新备份
    cp -r "$source_dir" "$target_dir"
    echo -e "${GREEN}✓ 备份完成${NC}"
    return 0
}

# ============================================================================
# JSON 验证函数
# ============================================================================

# 验证 JSON 文件格式
# 参数: $@=JSON 文件路径列表
validate_json_files() {
    if ! has_jq; then
        echo -e "${YELLOW}未安装 jq，跳过 JSON 验证${NC}"
        return 0
    fi

    echo -e "${BLUE}验证 JSON 格式...${NC}"
    local has_error=false

    for json_file in "$@"; do
        if [ -f "$json_file" ]; then
            if jq empty "$json_file" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $(basename "$json_file")"
            else
                echo -e "  ${RED}✗${NC} $(basename "$json_file") 格式错误"
                has_error=true
            fi
        fi
    done

    if [ "$has_error" = false ]; then
        echo -e "  ${GREEN}✓ 所有 JSON 文件格式正确${NC}"
    fi

    return 0
}

# ============================================================================
# 配置合并函数
# ============================================================================

# 合并用户配置和官方配置，用户配置优先
# 参数: $1=用户配置, $2=官方配置, $3=输出文件
merge_configs() {
    local user_config="$1"
    local official_config="$2"
    local output="$3"

    if ! has_jq; then
        # jq 不可用时的降级方案：直接使用官方配置
        cp "$official_config" "$output"
        return 0
    fi

    # 策略1: 深度合并，官方配置的新字段会被保留
    jq -s '
        .[1] as $official |
        .[0] + $official |
        with_entries(.value = ($official[.key] // .value))
    ' "$user_config" "$official_config" > "$output" 2>/dev/null

    # 如果策略1失败，使用简单的浅合并
    if [ $? -ne 0 ]; then
        jq -s '.[0] * .[1]' "$user_config" "$official_config" > "$output"
    fi
}

# ============================================================================
# 跨平台 sed 替换函数
# ============================================================================

# 跨平台 sed 替换（处理 macOS 和 Linux 差异）
# 参数: $1=替换表达式, $2=目标文件
sed_replace() {
    local expression="$1"
    local file="$2"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$expression" "$file"
    else
        sed -i "$expression" "$file"
    fi
}

# ============================================================================
# 扩展目录同步函数
# ============================================================================

# 同步单个扩展目录
# 参数: $1=源目录, $2=目标目录, $3=扩展名称
sync_extension_dir() {
    local source_dir="$1"
    local target_dir="$2"
    local ext_name="$3"

    if [ ! -d "$source_dir" ]; then
        return 0
    fi

    # 创建目标目录
    mkdir -p "$target_dir"

    # 同步文件
    local file_count=0
    for file in "$source_dir"/*; do
        if [ -f "$file" ]; then
            cp "$file" "$target_dir/"
            ((file_count++))
            echo -e "    - $(basename "$file")"
        fi
    done

    if [ $file_count -gt 0 ]; then
        echo -e "    ${GREEN}✓ 已同步 $file_count 个文件${NC}"
    else
        echo -e "    ${YELLOW}无文件${NC}"
    fi
}

# ============================================================================
# 确认函数
# ============================================================================

# 请求用户确认
# 参数: $1=提示信息
confirm_action() {
    local prompt="$1"
    read -p "$prompt (yes/no): " confirm
    [[ "$confirm" == "yes" || "$confirm" == "y" ]]
}
