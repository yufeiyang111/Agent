#!/bin/bash
# ============================================
# 一键部署脚本 - Linux/macOS Shell
# 使用方法:
#   chmod +x deploy.sh
#   ./deploy.sh [root密码]
# 示例:
#   ./deploy.sh mypassword
# ============================================
set -e

PASSWORD="${1}"
if [ -z "$PASSWORD" ]; then
    read -s -p "请输入root密码: " PASSWORD
    echo ""
fi

MYSQL="mysql -u root -p${PASSWORD}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  电商平台数据库初始化开始"
echo "  数据库: 23个分片库"
echo "  表总数: 160个业务表 + 6个视图"
echo "========================================"
echo ""

# 第一步: 创建数据库
echo "[1/5] 创建23个分片数据库..."
$MYSQL < "${SCRIPT_DIR}/01_databases.sql"
echo "[OK] 数据库创建完成"
echo ""

# 第二步: 创建各业务域表
echo "[2/5] 创建业务域表..."
$MYSQL user_db_0 < "${SCRIPT_DIR}/02_user_center.sql"
$MYSQL product_db_0 < "${SCRIPT_DIR}/03_product_center.sql"
$MYSQL order_db_0 < "${SCRIPT_DIR}/04_order_center.sql"
$MYSQL review_db_0 < "${SCRIPT_DIR}/05_review_center.sql"
$MYSQL marketing_db_0 < "${SCRIPT_DIR}/06_marketing_center.sql"
$MYSQL common_db < "${SCRIPT_DIR}/07_common_db.sql"
echo "[OK] 所有业务表创建完成"
echo ""

# 第三步: 复制模板表到所有分片
echo "[3/5] 复制模板表到所有分片数据库..."
$MYSQL < "${SCRIPT_DIR}/08_shard_replicas.sql"
echo "[OK] 分片复制完成"
echo ""

# 第四步: 创建视图
echo "[4/5] 创建视图..."
$MYSQL common_db < "${SCRIPT_DIR}/09_views.sql"
echo "[OK] 视图创建完成"
echo ""

# 第五步: 验证
echo "[5/5] 验证初始化结果..."
$MYSQL -e "SELECT TABLE_SCHEMA, COUNT(*) AS tables FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE '%db%' AND TABLE_TYPE='BASE TABLE' GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA;"
echo ""
$MYSQL -e "SELECT TABLE_SCHEMA, TABLE_NAME AS views FROM information_schema.VIEWS WHERE TABLE_SCHEMA='common_db';"
echo ""
$MYSQL common_db -e "SELECT config_key, config_value FROM system_config;"
echo "[OK] 验证完成"
echo ""

echo "========================================"
echo "  ✅ 数据库初始化全部完成！"
echo "  数据库: 23个 | 表: 160+张 | 视图: 6个"
echo "========================================"
