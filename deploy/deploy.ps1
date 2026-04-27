<#
=============================================
电商平台数据库初始化脚本 — PowerShell
版本: v1.0 | MySQL 8.0
使用方法:
  .\deploy.ps1                          # 交互式输入密码
  .\deploy.ps1 -Password "mypass"       # 直接传密码
  .\deploy.ps1 -AllInOne "mypass"       # 使用 all_in_one.sql 快速部署
=============================================
#>

param(
    [string]$Password = "",
    [switch]$AllInOne = $false
)

$ErrorActionPreference = "Stop"

# ---------- 辅助函数 ----------
function Write-Step($msg) {
    Write-Host "`n[$($script:step)/5] $msg" -ForegroundColor Cyan
    $script:step++
}

function Exec-Sql($db, $file) {
    $dbFlag = if ($db) { "-D $db" } else { "" }
    if ($env:OS -eq "Windows_NT") {
        cmd /c "chcp 65001 >nul 2>&1"
    }
    $cmd = "mysql -u root -p$Password $dbFlag"
    $result = cmd /c "$cmd < `"$file`" 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ 失败: $file" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ $file" -ForegroundColor Green
}

# ---------- 入口 ----------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:step = 1

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  高并发电商平台 — 数据库部署脚本" -ForegroundColor Yellow
Write-Host "  MySQL 8.0 | 23个分片库 | 160+张表" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# 密码输入
if (-not $Password) {
    $securePwd = Read-Host -Prompt "请输入 root 密码" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

# 测试连接
Write-Host "`n[0/5] 测试 MySQL 连接..." -ForegroundColor Cyan
try {
    $test = cmd /c "mysql -u root -p$Password -e `"SELECT 1 AS ping;`" 2>&1"
    if ($LASTEXITCODE -ne 0) { throw $test }
    Write-Host "  ✓ MySQL 连接成功" -ForegroundColor Green
} catch {
    Write-Host "  ✗ MySQL 连接失败，请检查密码或服务是否运行" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---------- AllInOne 模式 ----------
if ($AllInOne) {
    Write-Step "使用 all_in_one.sql 一键部署..."
    Exec-Sql "" (Join-Path $scriptDir "all_in_one.sql")
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  ✅ 一键部署完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Yellow
    exit 0
}

# ---------- 分步模式 ----------

# Step 1: 创建数据库
Write-Step "创建 23 个分片数据库..."
Exec-Sql "" (Join-Path $scriptDir "01_databases.sql")

# Step 2: 创建各业务域表
Write-Step "创建各业务域表..."
Exec-Sql "user_db_0"     (Join-Path $scriptDir "02_user_center.sql")
Exec-Sql "product_db_0"  (Join-Path $scriptDir "03_product_center.sql")
Exec-Sql "order_db_0"    (Join-Path $scriptDir "04_order_center.sql")
Exec-Sql "review_db_0"   (Join-Path $scriptDir "05_review_center.sql")
Exec-Sql "marketing_db_0" (Join-Path $scriptDir "06_marketing_center.sql")
Exec-Sql "common_db"     (Join-Path $scriptDir "07_common_db.sql")

# Step 3: 复制模板表到全部分片
Write-Step "复制模板表到所有分片数据库..."
Exec-Sql "" (Join-Path $scriptDir "08_shard_replicas.sql")

# Step 4: 创建视图
Write-Step "创建 6 个分析视图..."
Exec-Sql "common_db" (Join-Path $scriptDir "09_views.sql")

# Step 5: 验证
Write-Step "验证初始化结果..."
$verify = cmd /c "mysql -u root -p$Password -e `"SELECT TABLE_SCHEMA, COUNT(*) AS tables FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE '%%db%%' AND TABLE_TYPE='BASE TABLE' GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA;`" 2>&1 | findstr /V Warning"
Write-Host "$verify" -ForegroundColor Gray

$views = cmd /c "mysql -u root -p$Password -e `"SELECT TABLE_NAME AS views FROM information_schema.VIEWS WHERE TABLE_SCHEMA='common_db';`" 2>&1 | findstr /V Warning"
Write-Host "视图: $views" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  ✅ 数据库初始化全部完成！" -ForegroundColor Green
Write-Host "  数据库: 23个 | 表: 160+张 | 视图: 6个" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Yellow
