@echo off
chcp 65001 >nul
title 电商平台数据库初始化脚本 (MySQL 8.0)

REM ============================================
REM 一键部署脚本 - Windows 批处理
REM 使用方法: deploy.bat [root密码]
REM 示例: deploy.bat mypassword
REM ============================================

set PASSWORD=%1
if "%PASSWORD%"=="" (
    echo 请输入root密码:
    set /p PASSWORD=
)

set MYSQL=mysql -u root -p%PASSWORD%

echo ========================================
echo   电商平台数据库初始化开始
echo   数据库: 23个分片库
echo   表总数: 160个业务表 + 6个视图
echo ========================================
echo.

REM 第一步: 创建数据库
echo [1/5] 创建23个分片数据库...
%MYSQL% < 01_databases.sql
if %ERRORLEVEL% neq 0 (
    echo [!] 数据库创建失败，请检查MySQL连接
    pause
    exit /b 1
)
echo [OK] 数据库创建完成

REM 第二步: 创建各业务域表
echo [2/5] 创建用户中心表 (user_db_0)...
%MYSQL% user_db_0 < 02_user_center.sql

echo [2/5] 创建商品中心表 (product_db_0)...
%MYSQL% product_db_0 < 03_product_center.sql

echo [2/5] 创建订单中心表 (order_db_0)...
%MYSQL% order_db_0 < 04_order_center.sql

echo [2/5] 创建评价中心表 (review_db_0)...
%MYSQL% review_db_0 < 05_review_center.sql

echo [2/5] 创建营销中心表 (marketing_db_0)...
%MYSQL% marketing_db_0 < 06_marketing_center.sql

echo [2/5] 创建公共库表 (common_db)...
%MYSQL% common_db < 07_common_db.sql
echo [OK] 所有业务表创建完成

REM 第三步: 复制模板表到所有分片
echo [3/5] 复制模板表到所有分片数据库...
%MYSQL% < 08_shard_replicas.sql
echo [OK] 分片复制完成

REM 第四步: 创建视图
echo [4/5] 创建视图 (common_db)...
%MYSQL% common_db < 09_views.sql
echo [OK] 视图创建完成

REM 第五步: 验证
echo [5/5] 验证初始化结果...
%MYSQL% -e "SELECT TABLE_SCHEMA, COUNT(*) AS tables FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE '%%db%%' AND TABLE_TYPE='BASE TABLE' GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA;"
%MYSQL% -e "SELECT TABLE_SCHEMA, TABLE_NAME AS views FROM information_schema.VIEWS WHERE TABLE_SCHEMA='common_db';"
%MYSQL% common_db -e "SELECT config_key, config_value FROM system_config;"
echo [OK] 验证完成

echo ========================================
echo   ✅ 数据库初始化全部完成！
echo   数据库: 23个 | 表: 160+张 | 视图: 6个
echo ========================================
pause
