#!/usr/bin/env bash
# save-report.sh — 自动归档 Deep Research 报告到 VitePress 知识库
#
# 用法:
#   save-report.sh <output_file> <slug> <title> [tags]
#
# 参数:
#   output_file  - workflow output JSON 文件路径
#   slug         - 报告文件名（不含 .md），如 china-son-preference
#   title        - 报告标题
#   tags         - 可选，逗号分隔的标签，如 "人口学,性别研究,中国"
#
# 示例:
#   save-report.sh /tmp/wf-output.json china-son-preference "中国重男轻女观念变迁" "人口学,性别研究,中国"

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/deep-research}"
OUTPUT_FILE="${1:?Usage: save-report.sh <output_file> <slug> <title> [tags]}"
SLUG="${2:?Missing slug}"
TITLE="${3:?Missing title}"
TAGS="${4:-}"

# 从 output 文件提取元数据（简单 grep/sed，适用于 workflow output 格式）
EXTRACT_FIELD() {
  grep -o "\"$1\":[^,}]*" "$OUTPUT_FILE" 2>/dev/null | head -1 | sed "s/\"$1\"://;s/^[[:space:]]*//;s/[[:space:]]*$//" | tr -d '"' || echo "0"
}

AGENTS=$(EXTRACT_FIELD "agentCount")
TOKENS=$(EXTRACT_FIELD "totalTokens")
TOOL_CALLS=$(EXTRACT_FIELD "totalToolCalls")
CONFIRMED=$(EXTRACT_FIELD "confirmed")
KILLED=$(EXTRACT_FIELD "killed")
DURATION=$(EXTRACT_FIELD "durationMs")

# 计算验证总数
TOTAL_CLAIMS=$((CONFIRMED + KILLED))

# 当前日期
DATE=$(date +%Y-%m-%d)
YEAR=$(date +%Y)

# 目标目录
TARGET_DIR="$REPO_DIR/reports/$YEAR"
TARGET_FILE="$TARGET_DIR/$SLUG.md"

mkdir -p "$TARGET_DIR"

# 如果文件已存在，提示并退出
if [[ -f "$TARGET_FILE" ]]; then
  echo "⚠️  报告已存在: $TARGET_FILE"
  echo "   如需覆盖，请先删除该文件"
  exit 1
fi

echo "📝 生成报告: $TARGET_FILE"

# 生成 frontmatter + 元数据
cat > "$TARGET_FILE" << FRONTMATTER
---
title: "$TITLE"
date: $DATE
tags: [$TAGS]
status: completed
confidence: high
workflow:
  agents: $AGENTS
  tokens: $TOKENS
  tool_calls: $TOOL_CALLS
  verified_claims: $CONFIRMED
  killed_claims: $KILLED
  total_claims: $TOTAL_CLAIMS
  duration_ms: $DURATION
---

# $TITLE

> **深度研究报告** | $DATE | 对抗性验证流程

::: tip 研究概要
- **Agent数量**: $AGENTS
- **Token消耗**: $TOKENS
- **工具调用**: $TOOL_CALLS
- **验证通过**: $CONFIRMED / $TOTAL_CLAIMS (${CONFIRMED}00 / $TOTAL_CLAIMS%)
- **耗时**: $((DURATION / 60000)) 分钟
:::

<!-- 报告正文由 Claude Code 在归档时插入 -->
<!-- 完整验证日志请参考 workflow transcript -->

FRONTMATTER

echo "✅ 报告已生成: $TARGET_FILE"
echo ""
echo "📋 下一步:"
echo "   1. 将报告正文插入到 $TARGET_FILE"
echo "   2. cd $REPO_DIR && git add . && git commit -m 'add: $TITLE' && git push"
