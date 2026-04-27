-- ===================== 用户中心 DDL =====================
-- 分片: 4库 x 32表 | 分片键: user_id
-- 算法: db_idx = (user_id>>4)%4, tb_idx = (user_id>>4)%32
-- 使用: mysql -u root -p user_db_0 < 02_user_center.sql

USE user_db_0;

CREATE TABLE IF NOT EXISTS user_0 (
    user_id          BIGINT       NOT NULL COMMENT '用户ID(雪花算法)',
    username         VARCHAR(64)  NOT NULL COMMENT '用户名',
    password_hash    VARCHAR(128) NOT NULL COMMENT '密码哈希(BCrypt)',
    phone            VARCHAR(20)  DEFAULT NULL COMMENT '手机号',
    email            VARCHAR(128) DEFAULT NULL COMMENT '邮箱',
    avatar_url       VARCHAR(256) DEFAULT NULL COMMENT '头像URL',
    nickname         VARCHAR(64)  DEFAULT NULL COMMENT '昵称',
    gender           TINYINT      DEFAULT 0 COMMENT '性别: 0未知/1男/2女',
    birthday         DATE         DEFAULT NULL COMMENT '生日',
    user_status      TINYINT      DEFAULT 1 COMMENT '状态: 1正常/2禁用/3冻结',
    register_type    TINYINT      DEFAULT 0 COMMENT '注册方式: 1手机/2邮箱/3微信/4QQ',
    register_time    DATETIME     NOT NULL COMMENT '注册时间',
    last_login_time  DATETIME     DEFAULT NULL COMMENT '最后登录时间',
    last_login_ip    VARCHAR(45)  DEFAULT NULL COMMENT '最后登录IP',
    user_level       TINYINT      DEFAULT 0 COMMENT '用户等级: 0普通/1银卡/2金卡/3钻石',
    total_points     INT          DEFAULT 0 COMMENT '总积分',
    is_deleted       TINYINT      DEFAULT 0 COMMENT '逻辑删除: 0未删/1已删',
    create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_email (email),
    INDEX idx_register_time (register_time),
    INDEX idx_user_level (user_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

CREATE TABLE IF NOT EXISTS user_address_0 (
    address_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '地址ID',
    user_id        BIGINT       NOT NULL COMMENT '用户ID',
    receiver_name  VARCHAR(64)  NOT NULL COMMENT '收货人姓名',
    receiver_phone VARCHAR(20)  NOT NULL COMMENT '收货人手机号',
    province       VARCHAR(32)  NOT NULL COMMENT '省份',
    city           VARCHAR(32)  NOT NULL COMMENT '城市',
    district       VARCHAR(32)  NOT NULL COMMENT '区县',
    street         VARCHAR(128) NOT NULL COMMENT '详细街道地址',
    zip_code       VARCHAR(10)  DEFAULT NULL COMMENT '邮编',
    address_label  VARCHAR(16)  DEFAULT NULL COMMENT '标签: 家/公司/学校',
    is_default     TINYINT      DEFAULT 0 COMMENT '是否默认地址: 0否/1是',
    create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id),
    INDEX idx_user_id (user_id),
    INDEX idx_is_default (user_id, is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收货地址表';

CREATE TABLE IF NOT EXISTS user_collection_0 (
    collect_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
    user_id      BIGINT       NOT NULL COMMENT '用户ID',
    spu_id       BIGINT       NOT NULL COMMENT '商品SPU ID',
    folder_id    BIGINT       DEFAULT NULL COMMENT '收藏夹ID',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (collect_id),
    UNIQUE KEY uk_user_spu (user_id, spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_create_time (user_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收藏表';

CREATE TABLE IF NOT EXISTS user_browsing_history_0 (
    id            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id       BIGINT       NOT NULL COMMENT '用户ID',
    spu_id        BIGINT       NOT NULL COMMENT '商品SPU ID',
    sku_id        BIGINT       DEFAULT NULL COMMENT 'SKU ID',
    stay_seconds  INT          DEFAULT 0 COMMENT '停留时长(秒)',
    source        VARCHAR(32)  DEFAULT NULL COMMENT '来源: search/recommend/直接访问',
    browse_time   DATETIME     NOT NULL COMMENT '浏览时间',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_user_time (user_id, browse_time),
    INDEX idx_create_time (create_time),
    INDEX idx_spu_id (spu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户浏览历史表';

CREATE TABLE IF NOT EXISTS user_points_log_0 (
    log_id        BIGINT       NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    user_id       BIGINT       NOT NULL COMMENT '用户ID',
    change_type   TINYINT      NOT NULL COMMENT '变动类型: 1购物获得/2签到/3优惠券兑换/4退款退还/5赠送',
    change_points INT          NOT NULL COMMENT '变动积分(正=获得, 负=消耗)',
    before_points INT          NOT NULL COMMENT '变动前积分',
    after_points  INT          NOT NULL COMMENT '变动后积分',
    order_no      VARCHAR(32)  DEFAULT NULL COMMENT '关联订单号',
    remark        VARCHAR(256) DEFAULT NULL COMMENT '备注',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_user_id (user_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户积分流水表';

CREATE TABLE IF NOT EXISTS user_login_log_0 (
    log_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    user_id      BIGINT       NOT NULL COMMENT '用户ID',
    login_type   TINYINT      NOT NULL COMMENT '登录方式: 1密码/2验证码/3扫码/4第三方',
    login_ip     VARCHAR(45)  DEFAULT NULL COMMENT '登录IP',
    device_info  VARCHAR(256) DEFAULT NULL COMMENT '设备信息(User-Agent)',
    login_result TINYINT      NOT NULL COMMENT '结果: 1成功/2密码错误/3账号禁用/4验证码错误',
    fail_reason  VARCHAR(128) DEFAULT NULL COMMENT '失败原因',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_user_time (user_id, create_time),
    INDEX idx_create_time (create_time),
    INDEX idx_login_result (login_result)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户登录记录表';

SELECT '用户中心表创建完成 (user_db_0)' AS result;
