#!/bin/bash
set -e

# 引入公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

echo -e "${RED}Claude Code 配置卸载脚本${NC}"
echo "======================================"
echo ""
echo -e "${YELLOW}警告: 此操作将删除以下配置文件:${NC}"
echo "  - $CLAUDE_DIR/CLAUDE.md"
echo "  - $CLAUDE_DIR/settings.json"
echo "  - $CLAUDE_DIR/config.json"
echo "  - $CLAUDE_DIR/commands/"
echo "  - $CLAUDE_DIR/agents/"
echo "  - $CLAUDE_DIR/skills/"
echo ""

# 确认操作
if ! confirm_action "确定要继续吗"; then
    echo "操作已取消"
    exit 0
fi

# 备份当前配置
backup_current_config() {
    create_backup "$CLAUDE_DIR" "$BACKUP_DIR" "当前配置"
}

# 删除配置文件
remove_configs() {
    echo "删除配置文件..."

    for file in "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/config.json"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo -e "${GREEN}✓ 已删除 $(basename $file)${NC}"
        fi
    done

    for dir in "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo -e "${GREEN}✓ 已删除 $(basename $dir)${NC}"
        fi
    done
}

# 恢复选项
restore_option() {
    echo ""
    if confirm_action "是否要从备份恢复配置"; then
        if [ -d "$BACKUP_DIR" ]; then
            echo "从备份恢复配置..."
            cp -r "$BACKUP_DIR"/* "$CLAUDE_DIR/"
            echo -e "${GREEN}✓ 配置已恢复${NC}"
        else
            echo -e "${RED}未找到备份文件${NC}"
        fi
    fi
}

# 显示完成信息
print_uninstall_summary() {
    echo ""
    echo "======================================"
    echo -e "${GREEN}✓ 卸载完成！${NC}"
    echo ""
    echo "备份位置: $BACKUP_DIR"
    echo ""
    echo "如需恢复配置，请运行:"
    echo "  cp -r $BACKUP_DIR/* $CLAUDE_DIR/"
    echo ""
}

# 主流程
main() {
    backup_current_config
    remove_configs
    print_uninstall_summary
    restore_option
}

# 执行主流程
main
