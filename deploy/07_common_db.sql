-- ===================== 公共库 DDL + 预置数据 =====================
-- 使用: mysql -u root -p common_db < 07_common_db.sql

USE common_db;

-- 7.1 订单号->用户ID映射表
CREATE TABLE IF NOT EXISTS order_no_mapping (
    id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    order_no    VARCHAR(32)  NOT NULL COMMENT '订单号',
    user_id     BIGINT       NOT NULL COMMENT '用户ID(分片键)',
    is_archived TINYINT      DEFAULT 0 COMMENT '是否已归档',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单号->用户ID映射表(全局)';

-- 7.2 短信验证码记录表
CREATE TABLE IF NOT EXISTS sms_log (
    id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    phone       VARCHAR(20)  NOT NULL COMMENT '手机号',
    code        VARCHAR(10)  NOT NULL COMMENT '验证码',
    biz_type    TINYINT      NOT NULL COMMENT '业务类型: 1注册/2登录/3找回密码/4绑定手机',
    send_ip     VARCHAR(45)  DEFAULT NULL COMMENT '发送IP',
    is_used     TINYINT      DEFAULT 0 COMMENT '是否已使用: 0未用/1已用',
    expire_time DATETIME     NOT NULL COMMENT '过期时间',
    send_result TINYINT      DEFAULT 1 COMMENT '发送结果: 1成功/2失败',
    fail_reason VARCHAR(128) DEFAULT NULL COMMENT '失败原因描述',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_phone (phone),
    INDEX idx_phone_time (phone, create_time),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短信验证码记录表';

-- 7.3 系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    config_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '配置ID',
    config_key   VARCHAR(64)  NOT NULL COMMENT '配置键',
    config_value VARCHAR(512) NOT NULL COMMENT '配置值',
    config_desc  VARCHAR(256) DEFAULT NULL COMMENT '配置说明',
    config_group VARCHAR(64)  DEFAULT 'DEFAULT' COMMENT '配置分组',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (config_id),
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- 7.4 后台管理员表
CREATE TABLE IF NOT EXISTS admin_user (
    admin_id      BIGINT       NOT NULL AUTO_INCREMENT COMMENT '管理员ID',
    username      VARCHAR(64)  NOT NULL COMMENT '用户名',
    password_hash VARCHAR(128) NOT NULL COMMENT '密码哈希(BCrypt)',
    real_name     VARCHAR(64)  DEFAULT NULL COMMENT '真实姓名',
    phone         VARCHAR(20)  DEFAULT NULL COMMENT '手机号',
    email         VARCHAR(128) DEFAULT NULL COMMENT '邮箱',
    admin_status  TINYINT      DEFAULT 1 COMMENT '状态: 1正常/2禁用',
    is_super      TINYINT      DEFAULT 0 COMMENT '是否超级管理员: 0否/1是',
    last_login_ip VARCHAR(45)  DEFAULT NULL COMMENT '最后登录IP',
    last_login_time DATETIME   DEFAULT NULL COMMENT '最后登录时间',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (admin_id),
    UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台管理员表';

-- 7.5 后台角色表
CREATE TABLE IF NOT EXISTS admin_role (
    role_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '角色ID',
    role_name   VARCHAR(64)  NOT NULL COMMENT '角色名称',
    role_code   VARCHAR(64)  NOT NULL COMMENT '角色标识(如"SUPER_ADMIN")',
    permissions JSON         DEFAULT NULL COMMENT '权限列表(JSON)',
    role_desc   VARCHAR(256) DEFAULT NULL COMMENT '角色描述',
    status      TINYINT      DEFAULT 1 COMMENT '状态: 1启用/2禁用',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id),
    UNIQUE KEY uk_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台角色表';

-- 7.6 管理员角色关联表
CREATE TABLE IF NOT EXISTS admin_role_rel (
    rel_id    BIGINT   NOT NULL AUTO_INCREMENT COMMENT '关联ID',
    admin_id  BIGINT   NOT NULL COMMENT '管理员ID',
    role_id   BIGINT   NOT NULL COMMENT '角色ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (rel_id),
    UNIQUE KEY uk_admin_role (admin_id, role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理员角色关联表';

-- 7.7 系统操作日志表
CREATE TABLE IF NOT EXISTS admin_operation_log (
    log_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    admin_id      BIGINT        NOT NULL COMMENT '操作管理员ID',
    admin_name    VARCHAR(64)   DEFAULT NULL COMMENT '操作管理员名(冗余)',
    module        VARCHAR(64)   NOT NULL COMMENT '操作模块(如"商品管理")',
    action        VARCHAR(64)   NOT NULL COMMENT '操作动作(如"上架商品")',
    target_id     VARCHAR(128)  DEFAULT NULL COMMENT '操作目标ID',
    request_ip    VARCHAR(45)   DEFAULT NULL COMMENT '请求IP',
    request_params JSON         DEFAULT NULL COMMENT '请求参数(JSON, 敏感数据脱敏)',
    result        TINYINT       DEFAULT 1 COMMENT '执行结果: 1成功/2失败',
    fail_reason   VARCHAR(512)  DEFAULT NULL COMMENT '失败原因',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_admin_id (admin_id),
    INDEX idx_create_time (create_time),
    INDEX idx_module (module)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统操作日志表';

-- 7.8 首页轮播图表
CREATE TABLE IF NOT EXISTS banner (
    banner_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT 'Banner ID',
    title        VARCHAR(128) NOT NULL COMMENT '标题',
    image_url    VARCHAR(256) NOT NULL COMMENT '图片URL',
    link_url     VARCHAR(256) DEFAULT NULL COMMENT '跳转链接',
    banner_type  TINYINT      DEFAULT 1 COMMENT '类型: 1首页轮播/2分类Banner/3活动推广',
    sort_order   INT          DEFAULT 0 COMMENT '排序值',
    start_time   DATETIME     DEFAULT NULL COMMENT '投放开始时间',
    end_time     DATETIME     DEFAULT NULL COMMENT '投放结束时间',
    status       TINYINT      DEFAULT 1 COMMENT '状态: 1启用/2禁用',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (banner_id),
    INDEX idx_status_time (status, start_time, end_time),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='首页轮播图表';

-- 7.9 消息通知记录表
CREATE TABLE IF NOT EXISTS notification (
    notif_id      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '通知ID',
    user_id       BIGINT        NOT NULL COMMENT '用户ID',
    notif_type    TINYINT       NOT NULL COMMENT '类型: 1系统通知/2订单通知/3促销通知/4物流通知',
    title         VARCHAR(128)  NOT NULL COMMENT '通知标题',
    content       VARCHAR(1024) DEFAULT NULL COMMENT '通知内容',
    is_read       TINYINT       DEFAULT 0 COMMENT '是否已读: 0未读/1已读',
    read_time     DATETIME      DEFAULT NULL COMMENT '阅读时间',
    biz_id        VARCHAR(64)   DEFAULT NULL COMMENT '关联业务ID(如订单号)',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (notif_id),
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息通知记录表';

-- 7.10 ID生成器表(号段模式-兜底方案)
CREATE TABLE IF NOT EXISTS id_generator (
    id              BIGINT  NOT NULL AUTO_INCREMENT COMMENT '主键',
    biz_type        VARCHAR(32) NOT NULL COMMENT '业务类型: ORDER/USER/SPU/SKU',
    max_id          BIGINT  NOT NULL DEFAULT 0 COMMENT '当前最大ID',
    step            INT     NOT NULL DEFAULT 1000 COMMENT '号段步长',
    version         INT     NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    create_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_biz_type (biz_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分布式ID生成器(号段模式-兜底方案)';

-- ===================== 预置数据 =====================

INSERT IGNORE INTO common_db.system_config (config_key, config_value, config_desc, config_group) VALUES
('order.auto_cancel_minutes', '30', '下单后未支付自动取消时间(分钟)', 'ORDER'),
('order.auto_confirm_days', '15', '发货后自动确认收货天数', 'ORDER'),
('order.max_cart_items', '200', '购物车最大商品数量', 'ORDER'),
('review.auto_good_days', '30', '订单完成后自动好评天数', 'REVIEW'),
('seckill.default_qps_limit', '10000', '秒杀接口默认QPS限制', 'SECKILL'),
('sms.max_per_hour_per_ip', '5', '同IP每小时最大短信发送次数', 'SECURITY'),
('user.max_address_count', '20', '用户最大收货地址数', 'USER');

INSERT IGNORE INTO common_db.id_generator (biz_type, max_id, step) VALUES
('USER', 1000000, 1000),
('SPU', 1000000, 1000),
('SKU', 1000000, 1000),
('ORDER', 1000000, 5000),
('REVIEW', 1000000, 1000),
('COUPON', 1000000, 500),
('PAYMENT', 1000000, 1000);

SELECT '公共库表创建完成 + 预置数据插入成功' AS result;
