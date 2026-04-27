-- =================================================================
-- 海量数据电商购物平台 — 数据库 DDL (第一期)
-- =================================================================
-- 版本: v1.0
-- 引擎: InnoDB
-- 字符集: utf8mb4 / utf8mb4_unicode_ci
-- 分库分表: ShardingSphere-JDBC 5.x
-- 分布式ID: 雪花算法 (Snowflake BIGINT)
-- =================================================================

-- =================================================================
-- 第一节: 创建数据库 (分库)
-- =================================================================

-- 用户库 (4 个实例: user_db_0 ~ user_db_3)
CREATE DATABASE IF NOT EXISTS user_db_0 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS user_db_1 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS user_db_2 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS user_db_3 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 商品库 (4 个实例: product_db_0 ~ product_db_3)
CREATE DATABASE IF NOT EXISTS product_db_0 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS product_db_1 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS product_db_2 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS product_db_3 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 订单库 (8 个实例: order_db_0 ~ order_db_7)
CREATE DATABASE IF NOT EXISTS order_db_0 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_1 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_2 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_3 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_4 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_5 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_6 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db_7 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 评价库 (4 个实例: review_db_0 ~ review_db_3)
CREATE DATABASE IF NOT EXISTS review_db_0 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS review_db_1 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS review_db_2 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS review_db_3 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 营销库 (2 个实例: marketing_db_0 ~ marketing_db_1)
CREATE DATABASE IF NOT EXISTS marketing_db_0 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS marketing_db_1 DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 全局公共库 (不分片, 存储映射表/广播表/配置表)
CREATE DATABASE IF NOT EXISTS common_db DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;


-- =================================================================
-- 第二节: 用户中心 — DDL
-- 分片: 4库 × 32表, 分片键 user_id
-- 片键算法: db_idx = (user_id >> 4) % 4, tb_idx = (user_id >> 4) % 32
-- =================================================================

-- 2.1 用户表 (user)
CREATE TABLE user_0 (
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
    create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_email (email),
    INDEX idx_register_time (register_time),
    INDEX idx_user_level (user_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 2.2 收货地址表 (user_address)
CREATE TABLE user_address_0 (
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
    create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (address_id),
    INDEX idx_user_id (user_id),
    INDEX idx_is_default (user_id, is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收货地址表';

-- 2.3 用户收藏表 (user_collection)
CREATE TABLE user_collection_0 (
    collect_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
    user_id      BIGINT       NOT NULL COMMENT '用户ID',
    spu_id       BIGINT       NOT NULL COMMENT '商品SPU ID',
    folder_id    BIGINT       DEFAULT NULL COMMENT '收藏夹ID',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (collect_id),
    UNIQUE KEY uk_user_spu (user_id, spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_create_time (user_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收藏表';

-- 2.4 浏览历史表 (user_browsing_history)
-- 注意: MySQL 仅存储最近30天记录, 历史数据迁移至 MongoDB
CREATE TABLE user_browsing_history_0 (
    id            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id       BIGINT       NOT NULL COMMENT '用户ID',
    spu_id        BIGINT       NOT NULL COMMENT '商品SPU ID',
    sku_id        BIGINT       DEFAULT NULL COMMENT 'SKU ID',
    stay_seconds  INT          DEFAULT 0 COMMENT '停留时长(秒)',
    source        VARCHAR(32)  DEFAULT NULL COMMENT '来源: search/recommend/直接访问',
    browse_time   DATETIME     NOT NULL COMMENT '浏览时间',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_user_time (user_id, browse_time),
    INDEX idx_create_time (create_time),
    INDEX idx_spu_id (spu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户浏览历史表';

-- 2.5 用户积分流水表 (user_points_log)
CREATE TABLE user_points_log_0 (
    log_id        BIGINT       NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    user_id       BIGINT       NOT NULL COMMENT '用户ID',
    change_type   TINYINT      NOT NULL COMMENT '变动类型: 1购物获得/2签到获得/3优惠券兑换/4订单退款退还/5平台赠送',
    change_points INT          NOT NULL COMMENT '变动积分(正=获得, 负=消耗)',
    before_points INT          NOT NULL COMMENT '变动前积分',
    after_points  INT          NOT NULL COMMENT '变动后积分',
    order_no      VARCHAR(32)  DEFAULT NULL COMMENT '关联订单号',
    remark        VARCHAR(256) DEFAULT NULL COMMENT '备注',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (log_id),
    INDEX idx_user_id (user_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户积分流水表';

-- 2.6 用户登录记录表 (user_login_log)
CREATE TABLE user_login_log_0 (
    log_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    user_id      BIGINT       NOT NULL COMMENT '用户ID',
    login_type   TINYINT      NOT NULL COMMENT '登录方式: 1密码/2验证码/3扫码/4第三方',
    login_ip     VARCHAR(45)  DEFAULT NULL COMMENT '登录IP',
    device_info  VARCHAR(256) DEFAULT NULL COMMENT '设备信息(User-Agent)',
    login_result TINYINT      NOT NULL COMMENT '结果: 1成功/2密码错误/3账号禁用/4验证码错误',
    fail_reason  VARCHAR(128) DEFAULT NULL COMMENT '失败原因',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (log_id),
    INDEX idx_user_time (user_id, create_time),
    INDEX idx_create_time (create_time),
    INDEX idx_login_result (login_result)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户登录记录表';


-- =================================================================
-- 第三节: 商品中心 — DDL
-- 分片: 4库 × 32表, 分片键 spu_id
-- 片键算法: db_idx = spu_id % 4, tb_idx = (spu_id >> 4) % 32
-- =================================================================

-- 3.1 商品SPU表 (spu)
CREATE TABLE spu_0 (
    spu_id            BIGINT        NOT NULL COMMENT 'SPU ID(雪花算法)',
    spu_name          VARCHAR(256)  NOT NULL COMMENT '商品名称',
    subtitle          VARCHAR(512)  DEFAULT NULL COMMENT '副标题',
    category_id       BIGINT        NOT NULL COMMENT '三级类目ID',
    brand_id          BIGINT        DEFAULT NULL COMMENT '品牌ID',
    main_image        VARCHAR(256)  NOT NULL COMMENT '主图URL',
    images            JSON          DEFAULT NULL COMMENT '商品轮播图列表(JSON数组)',
    video_url         VARCHAR(256)  DEFAULT NULL COMMENT '商品视频URL',
    description       LONGTEXT      COMMENT '商品详细描述(富文本HTML)',
    service_guarantee VARCHAR(512)  DEFAULT NULL COMMENT '服务承诺(JSON数组: 正品保障/7天退换等)',
    spu_status        TINYINT       DEFAULT 0 COMMENT '状态: 0草稿/1待审核/2审核通过/3已上架/4已下架/5审核驳回',
    audit_reason      VARCHAR(512)  DEFAULT NULL COMMENT '审核驳回原因',
    sale_count        INT           DEFAULT 0 COMMENT '累计销量',
    review_count      INT           DEFAULT 0 COMMENT '累计评价数',
    avg_rating        DECIMAL(2,1)  DEFAULT 0.0 COMMENT '平均评分',
    min_price         DECIMAL(12,2) DEFAULT 0.00 COMMENT '最低销售价(冗余, 用于列表展示)',
    max_price         DECIMAL(12,2) DEFAULT 0.00 COMMENT '最高销售价(冗余, 用于列表展示)',
    is_new            TINYINT       DEFAULT 0 COMMENT '是否新品',
    is_hot            TINYINT       DEFAULT 0 COMMENT '是否热销',
    is_recommend      TINYINT       DEFAULT 0 COMMENT '是否推荐',
    shelf_time        DATETIME      DEFAULT NULL COMMENT '上架时间',
    is_deleted        TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (spu_id),
    INDEX idx_category_id (category_id),
    INDEX idx_brand_id (brand_id),
    INDEX idx_spu_status (spu_status),
    INDEX idx_create_time (create_time),
    INDEX idx_sale_count (sale_count),
    INDEX idx_recommend (is_recommend, spu_status),
    INDEX idx_category_status (category_id, spu_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SPU表';

-- 3.2 商品SKU表 (sku)
CREATE TABLE sku_0 (
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID(雪花算法)',
    spu_id         BIGINT        NOT NULL COMMENT '关联SPU ID',
    sku_code       VARCHAR(64)   NOT NULL COMMENT 'SKU编码(商家自定义)',
    sku_name       VARCHAR(256)  DEFAULT NULL COMMENT 'SKU名称(如"iPhone 15 Pro Max 钛金属原色 256GB")',
    sku_image      VARCHAR(256)  DEFAULT NULL COMMENT 'SKU图URL',
    sale_price     DECIMAL(12,2) NOT NULL COMMENT '售价',
    market_price   DECIMAL(12,2) DEFAULT NULL COMMENT '划线价(市场价)',
    cost_price     DECIMAL(12,2) DEFAULT NULL COMMENT '成本价',
    attrs          JSON          NOT NULL COMMENT '销售属性组合(JSON, 如{"颜色":"钛金属原色","容量":"256GB"})',
    weight         DECIMAL(10,2) DEFAULT 0.00 COMMENT '重量(kg)',
    volume         DECIMAL(10,2) DEFAULT 0.00 COMMENT '体积(m³)',
    is_deleted     TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (sku_id),
    UNIQUE KEY uk_sku_code (sku_code),
    INDEX idx_spu_id (spu_id),
    INDEX idx_sale_price (sale_price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SKU表';

-- 3.3 SKU库存表 (sku_stock)
CREATE TABLE sku_stock_0 (
    stock_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库存ID',
    sku_id          BIGINT        NOT NULL COMMENT 'SKU ID',
    spu_id          BIGINT        NOT NULL COMMENT 'SPU ID',
    total_stock     INT           NOT NULL DEFAULT 0 COMMENT '总库存',
    locked_stock    INT           NOT NULL DEFAULT 0 COMMENT '预扣库存(已下单未支付)',
    available_stock INT           NOT NULL DEFAULT 0 COMMENT '可用库存 = 总库存 - 预扣库存',
    safety_stock    INT           DEFAULT 0 COMMENT '安全库存(低于此值触发预警)',
    version         INT           NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    warehouse_id    BIGINT        DEFAULT NULL COMMENT '仓库ID',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (stock_id),
    UNIQUE KEY uk_sku_id (sku_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_available (available_stock),
    INDEX idx_safety (available_stock, safety_stock)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU库存表';

-- 3.4 库存流水表 (stock_flow)
CREATE TABLE stock_flow_0 (
    flow_id         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    sku_id          BIGINT        NOT NULL COMMENT 'SKU ID',
    change_type     TINYINT       NOT NULL COMMENT '变动类型: 1下单预扣/2支付确认/3取消释放/4入库/5出库/6人工调整',
    change_quantity INT           NOT NULL COMMENT '变动数量(负数为减少)',
    before_stock    INT           NOT NULL COMMENT '变动前可用库存',
    after_stock     INT           NOT NULL COMMENT '变动后可用库存',
    order_no        VARCHAR(32)   DEFAULT NULL COMMENT '关联订单号',
    operator        VARCHAR(64)   DEFAULT NULL COMMENT '操作人(系统/管理员)',
    remark          VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (flow_id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存流水表';

-- 3.5 SKU价格历史表 (sku_price_history)
CREATE TABLE sku_price_history_0 (
    id            BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    sku_id        BIGINT        NOT NULL COMMENT 'SKU ID',
    old_price     DECIMAL(12,2) NOT NULL COMMENT '原价',
    new_price     DECIMAL(12,2) NOT NULL COMMENT '新价',
    change_type   TINYINT       DEFAULT 1 COMMENT '变动类型: 1调价/2促销/3秒杀/4恢复原价',
    operator      VARCHAR(64)   DEFAULT NULL COMMENT '操作人',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU价格历史表';

-- 3.6 商品分类表 (category) — 广播表, 每分片存全量
CREATE TABLE category_broadcast (
    category_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '分类ID',
    category_name VARCHAR(64)  NOT NULL COMMENT '分类名称',
    parent_id     BIGINT       DEFAULT 0 COMMENT '父分类ID(0=顶级)',
    level         TINYINT      NOT NULL COMMENT '层级: 1一级/2二级/3三级',
    sort_order    INT          DEFAULT 0 COMMENT '排序值(越小越前)',
    icon_url      VARCHAR(256) DEFAULT NULL COMMENT '分类图标',
    banner_url    VARCHAR(256) DEFAULT NULL COMMENT '分类Banner图',
    is_show       TINYINT      DEFAULT 1 COMMENT '是否显示: 0隐藏/1显示',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (category_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_sort_order (sort_order),
    INDEX idx_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品分类表(广播表)';

-- 3.7 品牌表 (brand) — 广播表, 每分片存全量
CREATE TABLE brand_broadcast (
    brand_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '品牌ID',
    brand_name   VARCHAR(128) NOT NULL COMMENT '品牌名称',
    brand_logo   VARCHAR(256) DEFAULT NULL COMMENT '品牌Logo URL',
    brand_desc   TEXT         COMMENT '品牌描述',
    country      VARCHAR(64)  DEFAULT NULL COMMENT '品牌产地',
    sort_order   INT          DEFAULT 0 COMMENT '排序',
    is_show      TINYINT      DEFAULT 1 COMMENT '是否显示: 0隐藏/1显示',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (brand_id),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='品牌表(广播表)';

-- 3.8 商品属性模板表 (product_attr) — 公共表
CREATE TABLE product_attr (
    attr_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '属性ID',
    category_id   BIGINT       NOT NULL COMMENT '关联分类ID',
    attr_name     VARCHAR(64)  NOT NULL COMMENT '属性名称(如"电池容量")',
    input_type    TINYINT      DEFAULT 1 COMMENT '录入方式: 1手动输入/2从列表选择',
    attr_values   JSON         DEFAULT NULL COMMENT '可选值列表(JSON数组)',
    sort_order    INT          DEFAULT 0 COMMENT '排序',
    is_required   TINYINT      DEFAULT 0 COMMENT '是否必填: 0非必填/1必填',
    attr_type     TINYINT      DEFAULT 1 COMMENT '1销售属性(如颜色)/2非销售属性(如电池容量)',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (attr_id),
    INDEX idx_category_id (category_id),
    INDEX idx_attr_type (attr_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品属性模板表';


-- =================================================================
-- 第四节: 订单中心 — DDL
-- 分片: 8库 × 64表, 分片键 user_id
-- 片键算法: db_idx = user_id % 8, tb_idx = (user_id >> 4) % 64
-- =================================================================

-- 4.1 订单表 (order)
CREATE TABLE order_0 (
    order_no          VARCHAR(32)   NOT NULL COMMENT '订单号(雪花算法+业务编码, 18-32位)',
    user_id           BIGINT        NOT NULL COMMENT '买家用户ID',
    seller_id         BIGINT        DEFAULT NULL COMMENT '卖家ID(平台模式多卖家场景)',
    order_status      TINYINT       NOT NULL DEFAULT 0 COMMENT '订单状态: 0待支付/10已支付/20已发货/30已收货/40已完成/50已取消/60已退款',
    payment_status    TINYINT       DEFAULT 0 COMMENT '支付状态: 0未支付/1已支付/2已退款/3部分退款',
    delivery_status   TINYINT       DEFAULT 0 COMMENT '物流状态: 0未发货/1已发货/2已揽收/3运输中/4派件中/5已签收',
    order_type        TINYINT       DEFAULT 1 COMMENT '订单类型: 1普通/2秒杀/3拼团/4砍价/5预售',
    source            VARCHAR(32)   DEFAULT 'APP' COMMENT '来源: APP/H5/PC/MINI_PROGRAM',
    product_amount    DECIMAL(12,2) NOT NULL COMMENT '商品总金额',
    discount_amount   DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠金额',
    freight_amount    DECIMAL(12,2) DEFAULT 0.00 COMMENT '运费金额',
    pay_amount        DECIMAL(12,2) NOT NULL COMMENT '实付金额',
    coupon_id         BIGINT        DEFAULT NULL COMMENT '使用的优惠券ID',
    coupon_amount     DECIMAL(12,2) DEFAULT 0.00 COMMENT '优惠券减免金额',
    points_deduction  INT           DEFAULT 0 COMMENT '积分抵扣数量',
    invoice_type      TINYINT       DEFAULT 0 COMMENT '发票类型: 0不开发票/1电子发票/2纸质发票',
    buyer_remark      VARCHAR(512)  DEFAULT NULL COMMENT '买家备注',
    seller_remark     VARCHAR(512)  DEFAULT NULL COMMENT '卖家备注(仅后台可见)',
    payment_time      DATETIME      DEFAULT NULL COMMENT '支付时间',
    delivery_time     DATETIME      DEFAULT NULL COMMENT '发货时间',
    receive_time      DATETIME      DEFAULT NULL COMMENT '收货时间',
    finish_time       DATETIME      DEFAULT NULL COMMENT '完成时间',
    cancel_time       DATETIME      DEFAULT NULL COMMENT '取消时间',
    cancel_reason     VARCHAR(256)  DEFAULT NULL COMMENT '取消原因',
    auto_confirm_days INT           DEFAULT 15 COMMENT '自动确认收货天数',
    is_archived       TINYINT       DEFAULT 0 COMMENT '是否已归档(冷数据): 0否/1是',
    consignee_name    VARCHAR(64)   NOT NULL COMMENT '收货人姓名(地址快照)',
    consignee_phone   VARCHAR(20)   NOT NULL COMMENT '收货人手机号(地址快照)',
    province          VARCHAR(32)   NOT NULL COMMENT '省份(地址快照)',
    city              VARCHAR(32)   NOT NULL COMMENT '城市(地址快照)',
    district          VARCHAR(32)   NOT NULL COMMENT '区县(地址快照)',
    street_address    VARCHAR(256)  NOT NULL COMMENT '详细地址(地址快照)',
    create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_order_status (order_status),
    INDEX idx_create_time (create_time),
    INDEX idx_payment_time (payment_time),
    INDEX idx_user_status (user_id, order_status),
    INDEX idx_user_time (user_id, create_time DESC),
    INDEX idx_archived_status (is_archived, order_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表';

-- 4.2 订单明细表 (order_item)
CREATE TABLE order_item_0 (
    item_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '明细ID',
    order_no       VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id        BIGINT        NOT NULL COMMENT '买家ID',
    spu_id         BIGINT        NOT NULL COMMENT 'SPU ID',
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID',
    sku_name       VARCHAR(256)  NOT NULL COMMENT 'SKU名称(商品快照)',
    sku_image      VARCHAR(256)  DEFAULT NULL COMMENT 'SKU图片(商品快照)',
    attrs_snapshot JSON          DEFAULT NULL COMMENT '销售属性快照(JSON)',
    price          DECIMAL(12,2) NOT NULL COMMENT '成交单价',
    quantity       INT           NOT NULL COMMENT '购买数量',
    subtotal       DECIMAL(12,2) NOT NULL COMMENT '小计金额 = price × quantity',
    is_evaluated   TINYINT       DEFAULT 0 COMMENT '是否已评价: 0未评/1已评',
    is_refunded    TINYINT       DEFAULT 0 COMMENT '是否已退款: 0否/1退款中/2已退款',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (item_id),
    INDEX idx_order_no (order_no),
    INDEX idx_sku_id (sku_id),
    INDEX idx_user_id (user_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_evaluated (is_evaluated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单明细表';

-- 4.3 订单操作日志表 (order_log)
CREATE TABLE order_log_0 (
    log_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    order_no      VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id       BIGINT        NOT NULL COMMENT '操作人ID(用户/系统/客服)',
    operator_type TINYINT       DEFAULT 1 COMMENT '操作人类型: 1用户/2商家/3系统/4客服',
    action        VARCHAR(64)   NOT NULL COMMENT '操作动作: CREATE/PAY/CANCEL/DELIVER/RECEIVE/FINISH/REFUND/ARCHIVE',
    from_status   TINYINT       DEFAULT NULL COMMENT '变更前状态',
    to_status     TINYINT       DEFAULT NULL COMMENT '变更后状态',
    remark        VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (log_id),
    INDEX idx_order_no (order_no),
    INDEX idx_create_time (create_time),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单操作日志表';

-- 4.4 购物车表 (cart)
CREATE TABLE cart_0 (
    cart_id      BIGINT    NOT NULL AUTO_INCREMENT COMMENT '购物车ID',
    user_id      BIGINT    NOT NULL COMMENT '用户ID',
    sku_id       BIGINT    NOT NULL COMMENT 'SKU ID',
    quantity     INT       NOT NULL DEFAULT 1 COMMENT '数量',
    checked      TINYINT   DEFAULT 1 COMMENT '是否选中: 0否/1是',
    is_deleted   TINYINT   DEFAULT 0 COMMENT '软删除: 0未删/1已删',
    create_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (cart_id),
    UNIQUE KEY uk_user_sku (user_id, sku_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='购物车表';

-- 4.5 支付记录表 (order_payment)
CREATE TABLE order_payment_0 (
    payment_id      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '支付记录ID',
    order_no        VARCHAR(32)   NOT NULL COMMENT '订单号',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    pay_amount      DECIMAL(12,2) NOT NULL COMMENT '支付金额',
    pay_type        TINYINT       NOT NULL COMMENT '支付方式: 1微信支付/2支付宝/3平台余额/4组合支付',
    pay_status      TINYINT       DEFAULT 0 COMMENT '状态: 0待支付/1支付成功/2支付失败/3已退款',
    trade_no        VARCHAR(128)  DEFAULT NULL COMMENT '第三方支付流水号',
    notify_url      VARCHAR(256)  DEFAULT NULL COMMENT '回调通知URL',
    notify_status   TINYINT       DEFAULT 0 COMMENT '回调处理状态: 0待处理/1处理成功/2处理失败',
    notify_count    TINYINT       DEFAULT 0 COMMENT '回调通知次数(重试上限10次)',
    notify_time     DATETIME      DEFAULT NULL COMMENT '最后通知时间',
    bank_type       VARCHAR(32)   DEFAULT NULL COMMENT '银行类型(微信返回)',
    pay_time        DATETIME      DEFAULT NULL COMMENT '支付时间',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (payment_id),
    UNIQUE KEY uk_trade_no (trade_no),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_pay_status (pay_status),
    INDEX idx_pay_time (pay_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付记录表';

-- 4.6 退款表 (refund)
CREATE TABLE refund_0 (
    refund_id       BIGINT        NOT NULL AUTO_INCREMENT COMMENT '退款ID',
    order_no        VARCHAR(32)   NOT NULL COMMENT '原订单号',
    order_item_id   BIGINT        DEFAULT NULL COMMENT '退款的明细ID(部分退款时指定, 全额退款为空)',
    user_id         BIGINT        NOT NULL COMMENT '用户ID',
    refund_amount   DECIMAL(12,2) NOT NULL COMMENT '退款金额',
    refund_type     TINYINT       NOT NULL COMMENT '退款类型: 1仅退款(未发货)/2退货退款(已发货)',
    refund_reason   VARCHAR(256)  NOT NULL COMMENT '退款原因',
    refund_status   TINYINT       DEFAULT 0 COMMENT '状态: 0待审核/1同意/2驳回/3退款中/4已完成/5退款失败',
    audit_remark    VARCHAR(256)  DEFAULT NULL COMMENT '审核意见',
    express_company VARCHAR(64)   DEFAULT NULL COMMENT '退货快递公司',
    express_no      VARCHAR(64)   DEFAULT NULL COMMENT '退货快递单号',
    audit_time      DATETIME      DEFAULT NULL COMMENT '审核时间',
    finish_time     DATETIME      DEFAULT NULL COMMENT '退款完成时间',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (refund_id),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_refund_status (refund_status),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='退款表';

-- 4.7 物流信息表 (order_delivery)
CREATE TABLE order_delivery_0 (
    delivery_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '物流记录ID',
    order_no          VARCHAR(32)  NOT NULL COMMENT '订单号',
    express_company   VARCHAR(64)  NOT NULL COMMENT '快递公司名称',
    express_no        VARCHAR(64)  NOT NULL COMMENT '快递单号',
    delivery_status   TINYINT      DEFAULT 0 COMMENT '状态: 0待揽收/1运输中/2派件中/3已签收/4退回',
    estimated_arrival DATETIME     DEFAULT NULL COMMENT '预计送达时间',
    sign_time         DATETIME     DEFAULT NULL COMMENT '签收时间',
    create_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (delivery_id),
    INDEX idx_order_no (order_no),
    INDEX idx_express_no (express_no),
    INDEX idx_delivery_status (delivery_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='发货物流表';

-- 4.8 物流轨迹表 (delivery_track)
-- 存储快递路由节点，一个包裹多条轨迹记录
CREATE TABLE delivery_track_0 (
    track_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '轨迹ID',
    delivery_id    BIGINT       NOT NULL COMMENT '关联物流记录ID',
    order_no       VARCHAR(32)  NOT NULL COMMENT '订单号',
    track_status   VARCHAR(64)  NOT NULL COMMENT '物流节点描述(如"快件已揽收""到达转运中心")',
    track_desc     VARCHAR(256) DEFAULT NULL COMMENT '详细描述',
    track_location VARCHAR(128) DEFAULT NULL COMMENT '发生地点',
    track_time     DATETIME     NOT NULL COMMENT '物流节点时间',
    create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (track_id),
    INDEX idx_delivery_id (delivery_id),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物流轨迹表';


-- =================================================================
-- 第五节: 评价中心 — DDL
-- 分片: 4库 × 32表, 分片键 spu_id
-- =================================================================

-- 5.1 评价表 (review)
CREATE TABLE review_0 (
    review_id    BIGINT         NOT NULL AUTO_INCREMENT COMMENT '评价ID',
    order_no     VARCHAR(32)    NOT NULL COMMENT '关联订单号',
    user_id      BIGINT         NOT NULL COMMENT '用户ID',
    spu_id       BIGINT         NOT NULL COMMENT 'SPU ID',
    sku_id       BIGINT         NOT NULL COMMENT 'SKU ID',
    rating       TINYINT        NOT NULL COMMENT '评分(1~5星)',
    content      VARCHAR(2000)  DEFAULT NULL COMMENT '评价内容',
    tags         JSON           DEFAULT NULL COMMENT '评价标签(如["质量很好","物流快"])',
    review_type  TINYINT        DEFAULT 0 COMMENT '评价类型: 0好评(4-5星)/1中评(3星)/2差评(1-2星)',
    is_anonymous TINYINT        DEFAULT 0 COMMENT '是否匿名: 0否/1是',
    is_top       TINYINT        DEFAULT 0 COMMENT '是否置顶: 0否/1是',
    helpful_count INT           DEFAULT 0 COMMENT '有帮助数(点赞)',
    is_archived  TINYINT        DEFAULT 0 COMMENT '是否归档(冷数据): 0否/1是',
    is_deleted   TINYINT        DEFAULT 0 COMMENT '逻辑删除: 0未删/1已删',
    create_time  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (review_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_user_id (user_id),
    INDEX idx_order_no (order_no),
    INDEX idx_rating (spu_id, rating),
    INDEX idx_create_time (create_time),
    INDEX idx_spu_type (spu_id, review_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价表';

-- 5.2 评价图片表 (review_image)
CREATE TABLE review_image_0 (
    image_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '图片ID',
    review_id   BIGINT       NOT NULL COMMENT '关联评价ID',
    image_url   VARCHAR(256) NOT NULL COMMENT '图片URL',
    image_order INT          DEFAULT 0 COMMENT '图片排序(越小越前)',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (image_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价图片表';

-- 5.3 评价回复表 (review_reply)
CREATE TABLE review_reply_0 (
    reply_id    BIGINT         NOT NULL AUTO_INCREMENT COMMENT '回复ID',
    review_id   BIGINT         NOT NULL COMMENT '关联评价ID',
    reply_type  TINYINT        DEFAULT 1 COMMENT '回复类型: 1商家回复/2用户追评',
    content     VARCHAR(2000)  NOT NULL COMMENT '回复内容',
    user_id     BIGINT         DEFAULT NULL COMMENT '回复人ID',
    is_deleted  TINYINT        DEFAULT 0 COMMENT '逻辑删除: 0未删/1已删',
    create_time DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (reply_id),
    INDEX idx_review_id (review_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价回复表';


-- =================================================================
-- 第六节: 营销中心 — DDL
-- 分片: 2库 × 16表
-- =================================================================

-- 6.1 优惠券定义表 (coupon)
CREATE TABLE coupon_0 (
    coupon_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '优惠券ID',
    coupon_name      VARCHAR(128)  NOT NULL COMMENT '优惠券名称',
    coupon_type      TINYINT       NOT NULL COMMENT '类型: 1满减券/2折扣券/3无门槛券/4新人券',
    discount_value   DECIMAL(12,2) NOT NULL COMMENT '优惠值(满减金额/折扣折数)',
    min_order_amount DECIMAL(12,2) DEFAULT 0.00 COMMENT '最低订单金额(满减门槛, 0=无门槛)',
    total_limit      INT           NOT NULL DEFAULT 0 COMMENT '发放总量(0=不限)',
    received_count   INT           DEFAULT 0 COMMENT '已领取数量',
    used_count       INT           DEFAULT 0 COMMENT '已使用数量',
    per_user_limit   INT           DEFAULT 1 COMMENT '每人限领数量',
    use_scope        TINYINT       DEFAULT 1 COMMENT '使用范围: 1全平台/2指定分类/3指定SPU',
    scope_values     JSON          DEFAULT NULL COMMENT '范围值(如分类ID列表/SPU ID列表)',
    valid_start_time DATETIME      NOT NULL COMMENT '有效期开始',
    valid_end_time   DATETIME      NOT NULL COMMENT '有效期结束',
    status           TINYINT       DEFAULT 1 COMMENT '状态: 1启用/2停用/3过期',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (coupon_id),
    INDEX idx_coupon_type (coupon_type),
    INDEX idx_valid_time (valid_start_time, valid_end_time),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券定义表';

-- 6.2 用户领券表 (user_coupon)
CREATE TABLE user_coupon_0 (
    uc_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id      BIGINT        NOT NULL COMMENT '用户ID',
    coupon_id    BIGINT        NOT NULL COMMENT '优惠券ID',
    use_status   TINYINT       DEFAULT 0 COMMENT '使用状态: 0未使用/1已使用/2已过期',
    order_no     VARCHAR(32)   DEFAULT NULL COMMENT '使用的订单号',
    use_time     DATETIME      DEFAULT NULL COMMENT '使用时间',
    create_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (uc_id),
    INDEX idx_user_id (user_id),
    INDEX idx_coupon_id (coupon_id),
    INDEX idx_use_status (user_id, use_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户领券表';

-- 6.3 秒杀活动表 (seckill_activity)
CREATE TABLE seckill_activity_0 (
    activity_id        BIGINT       NOT NULL AUTO_INCREMENT COMMENT '活动ID',
    activity_name      VARCHAR(128) NOT NULL COMMENT '活动名称',
    start_time         DATETIME     NOT NULL COMMENT '开始时间',
    end_time           DATETIME     NOT NULL COMMENT '结束时间',
    status             TINYINT      DEFAULT 0 COMMENT '状态: 0待开始/1进行中/2已结束/3已取消',
    seckill_strategy   TINYINT      DEFAULT 1 COMMENT '秒杀策略: 1先到先得/2排队抽签',
    per_user_limit     INT          DEFAULT 1 COMMENT '每人限购件数',
    create_time        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (activity_id),
    INDEX idx_status (status),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀活动表';

-- 6.4 秒杀商品表 (seckill_product)
CREATE TABLE seckill_product_0 (
    id               BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    activity_id      BIGINT        NOT NULL COMMENT '活动ID',
    sku_id           BIGINT        NOT NULL COMMENT 'SKU ID',
    spu_id           BIGINT        NOT NULL COMMENT 'SPU ID',
    seckill_price    DECIMAL(12,2) NOT NULL COMMENT '秒杀价',
    seckill_stock    INT           NOT NULL COMMENT '秒杀库存(独立于普通库存)',
    seckill_sold     INT           DEFAULT 0 COMMENT '已售数量',
    seckill_limit    INT           DEFAULT 1 COMMENT '每单限购件数',
    qps_limit        INT           DEFAULT 1000 COMMENT '接口限流QPS',
    create_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_activity_sku (activity_id, sku_id),
    INDEX idx_activity_id (activity_id),
    INDEX idx_sku_id (sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀商品表';

-- 6.5 秒杀订单记录表 (seckill_order)
CREATE TABLE seckill_order_0 (
    id             BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    activity_id    BIGINT        NOT NULL COMMENT '活动ID',
    user_id        BIGINT        NOT NULL COMMENT '用户ID',
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID',
    order_no       VARCHAR(32)   DEFAULT NULL COMMENT '关联正式订单号',
    seckill_status TINYINT       DEFAULT 0 COMMENT '状态: 0抢购成功(待支付)/1已支付/2已取消(超时)',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_activity_user (activity_id, user_id),
    INDEX idx_order_no (order_no),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='秒杀订单记录表';

-- 6.6 满减活动表 (promotion_activity)
CREATE TABLE promotion_activity_0 (
    activity_id   BIGINT        NOT NULL AUTO_INCREMENT COMMENT '活动ID',
    activity_name VARCHAR(128)  NOT NULL COMMENT '活动名称',
    rule_type     TINYINT       NOT NULL COMMENT '规则类型: 1满减/2满折/3满赠',
    threshold     DECIMAL(12,2) NOT NULL COMMENT '满足条件(满X元)',
    discount      DECIMAL(12,2) NOT NULL COMMENT '优惠值(减Y元/打Z折)',
    scope_type    TINYINT       DEFAULT 1 COMMENT '适用范围: 1全平台/2指定分类/3指定SPU',
    scope_values  JSON          DEFAULT NULL COMMENT '范围值',
    start_time    DATETIME      NOT NULL COMMENT '开始时间',
    end_time      DATETIME      NOT NULL COMMENT '结束时间',
    priority      INT           DEFAULT 0 COMMENT '优先级(多个活动同时命中时, 数值越大越优先)',
    status        TINYINT       DEFAULT 1 COMMENT '状态: 1启用/2停用',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (activity_id),
    INDEX idx_time (start_time, end_time),
    INDEX idx_status (status),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='满减活动表';


-- =================================================================
-- 第七节: 全局公共表 (common_db, 不分区)
-- =================================================================

-- 7.1 订单号→用户ID映射表 (order_no_mapping)
-- 解决只知订单号而不知user_id时无法定位分片的问题
CREATE TABLE common_db.order_no_mapping (
    id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    order_no    VARCHAR(32)  NOT NULL COMMENT '订单号',
    user_id     BIGINT       NOT NULL COMMENT '用户ID(分片键)',
    is_archived TINYINT      DEFAULT 0 COMMENT '是否已归档',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_user_id (user_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单号→用户ID映射表(全局)';

-- 7.2 短信验证码记录表 (sms_log)
CREATE TABLE common_db.sms_log (
    id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    phone       VARCHAR(20)  NOT NULL COMMENT '手机号',
    code        VARCHAR(10)  NOT NULL COMMENT '验证码',
    biz_type    TINYINT      NOT NULL COMMENT '业务类型: 1注册/2登录/3找回密码/4绑定手机',
    send_ip     VARCHAR(45)  DEFAULT NULL COMMENT '发送IP',
    is_used     TINYINT      DEFAULT 0 COMMENT '是否已使用: 0未用/1已用',
    expire_time DATETIME     NOT NULL COMMENT '过期时间',
    send_result TINYINT      DEFAULT 1 COMMENT '发送结果: 1成功/2失败',
    fail_reason VARCHAR(128) DEFAULT NULL COMMENT '失败原因描述',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_phone (phone),
    INDEX idx_phone_time (phone, create_time),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短信验证码记录表';

-- 7.3 系统配置表 (system_config)
CREATE TABLE common_db.system_config (
    config_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '配置ID',
    config_key   VARCHAR(64)  NOT NULL COMMENT '配置键(如"order.auto_cancel_minutes")',
    config_value VARCHAR(512) NOT NULL COMMENT '配置值',
    config_desc  VARCHAR(256) DEFAULT NULL COMMENT '配置说明',
    config_group VARCHAR(64)  DEFAULT 'DEFAULT' COMMENT '配置分组: ORDER/PAY/SECKILL/COMMON',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (config_id),
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- 7.4 后台管理员表 (admin_user)
CREATE TABLE common_db.admin_user (
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
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (admin_id),
    UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台管理员表';

-- 7.5 后台角色表 (admin_role)
CREATE TABLE common_db.admin_role (
    role_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '角色ID',
    role_name   VARCHAR(64)  NOT NULL COMMENT '角色名称',
    role_code   VARCHAR(64)  NOT NULL COMMENT '角色标识(如"SUPER_ADMIN","CSR")',
    permissions JSON         DEFAULT NULL COMMENT '权限列表(JSON: 菜单+操作权限)',
    role_desc   VARCHAR(256) DEFAULT NULL COMMENT '角色描述',
    status      TINYINT      DEFAULT 1 COMMENT '状态: 1启用/2禁用',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (role_id),
    UNIQUE KEY uk_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台角色表';

-- 7.6 管理员角色关联表 (admin_role_rel)
CREATE TABLE common_db.admin_role_rel (
    rel_id    BIGINT   NOT NULL AUTO_INCREMENT COMMENT '关联ID',
    admin_id  BIGINT   NOT NULL COMMENT '管理员ID',
    role_id   BIGINT   NOT NULL COMMENT '角色ID',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (rel_id),
    UNIQUE KEY uk_admin_role (admin_id, role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理员角色关联表';

-- 7.7 系统操作日志表 (admin_operation_log)
CREATE TABLE common_db.admin_operation_log (
    log_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    admin_id      BIGINT        NOT NULL COMMENT '操作管理员ID',
    admin_name    VARCHAR(64)   DEFAULT NULL COMMENT '操作管理员名(冗余)',
    module        VARCHAR(64)   NOT NULL COMMENT '操作模块(如"商品管理""订单管理")',
    action        VARCHAR(64)   NOT NULL COMMENT '操作动作(如"上架商品""审核退款")',
    target_id     VARCHAR(128)  DEFAULT NULL COMMENT '操作目标ID(如商品ID/订单号)',
    request_ip    VARCHAR(45)   DEFAULT NULL COMMENT '请求IP',
    request_params JSON         DEFAULT NULL COMMENT '请求参数(JSON, 敏感数据脱敏)',
    result        TINYINT       DEFAULT 1 COMMENT '执行结果: 1成功/2失败',
    fail_reason   VARCHAR(512)  DEFAULT NULL COMMENT '失败原因',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (log_id),
    INDEX idx_admin_id (admin_id),
    INDEX idx_create_time (create_time),
    INDEX idx_module (module)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统操作日志表';

-- 7.8 首页轮播图表 (banner)
CREATE TABLE common_db.banner (
    banner_id    BIGINT       NOT NULL AUTO_INCREMENT COMMENT 'Banner ID',
    title        VARCHAR(128) NOT NULL COMMENT '标题',
    image_url    VARCHAR(256) NOT NULL COMMENT '图片URL',
    link_url     VARCHAR(256) DEFAULT NULL COMMENT '跳转链接',
    banner_type  TINYINT      DEFAULT 1 COMMENT '类型: 1首页轮播/2分类Banner/3活动推广',
    sort_order   INT          DEFAULT 0 COMMENT '排序值',
    start_time   DATETIME     DEFAULT NULL COMMENT '投放开始时间',
    end_time     DATETIME     DEFAULT NULL COMMENT '投放结束时间',
    status       TINYINT      DEFAULT 1 COMMENT '状态: 1启用/2禁用',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (banner_id),
    INDEX idx_status_time (status, start_time, end_time),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='首页轮播图表';

-- 7.9 消息通知记录表 (notification)
CREATE TABLE common_db.notification (
    notif_id      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '通知ID',
    user_id       BIGINT        NOT NULL COMMENT '用户ID',
    notif_type    TINYINT       NOT NULL COMMENT '类型: 1系统通知/2订单通知/3促销通知/4物流通知',
    title         VARCHAR(128)  NOT NULL COMMENT '通知标题',
    content       VARCHAR(1024) DEFAULT NULL COMMENT '通知内容',
    is_read       TINYINT       DEFAULT 0 COMMENT '是否已读: 0未读/1已读',
    read_time     DATETIME      DEFAULT NULL COMMENT '阅读时间',
    biz_id        VARCHAR(64)   DEFAULT NULL COMMENT '关联业务ID(如订单号)',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (notif_id),
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息通知记录表';


-- =================================================================
-- 第八节: 视图(View) 设计
-- 用于数据分析、运营后台等场景
-- 注: 在分库分表场景下, 视图建议在 ClickHouse/ES 中创建用于OLAP
-- 以下是逻辑视图定义, 实际通过数据同步在分析层实现
-- =================================================================

-- 8.1 商品销售概况视图 (逻辑定义)
-- 用途: 运营后台商品分析 - 近30天销量排行
CREATE VIEW common_db.v_product_sales_30d AS
SELECT
    item.spu_id,
    COUNT(DISTINCT item.order_no) AS order_count,
    SUM(item.quantity)            AS sold_quantity,
    SUM(item.subtotal)            AS total_gmv,
    AVG(item.price)               AS avg_price
FROM order_item_0 item
JOIN order_0 ord ON item.order_no = ord.order_no
WHERE ord.order_status IN (10, 20, 30, 40)   -- 已支付及之后状态
  AND ord.create_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND ord.is_archived = 0
GROUP BY item.spu_id;


-- 8.2 用户订单汇总视图 (逻辑定义)
-- 用途: 用户画像 - 用户消费统计
CREATE VIEW common_db.v_user_order_summary AS
SELECT
    user_id,
    COUNT(order_no)       AS total_orders,
    SUM(pay_amount)       AS total_amount,
    AVG(pay_amount)       AS avg_order_amount,
    MAX(create_time)      AS last_order_time,
    COUNT(CASE WHEN order_status = 40 THEN 1 END) AS finished_orders,
    COUNT(CASE WHEN order_status IN (50, 60) THEN 1 END) AS cancelled_refund_orders
FROM order_0
WHERE is_archived = 0
GROUP BY user_id;


-- 8.3 分类销售统计视图 (逻辑定义)
-- 用途: 品类分析
CREATE VIEW common_db.v_category_sales AS
SELECT
    cat.category_id,
    cat.category_name,
    cat.parent_id,
    cat.level,
    COUNT(DISTINCT spu.spu_id) AS spu_count,
    SUM(spu.sale_count)        AS total_sales,
    AVG(spu.avg_rating)        AS avg_rating
FROM category_broadcast cat
LEFT JOIN spu_0 spu ON cat.category_id = spu.category_id AND spu.is_deleted = 0
WHERE cat.is_show = 1
GROUP BY cat.category_id, cat.category_name, cat.parent_id, cat.level;


-- 8.4 订单待办视图 (逻辑定义)
-- 用途: 运营后台首页 - 待处理数量统计
CREATE VIEW common_db.v_pending_tasks AS
SELECT
    '待支付'  AS task_type, COUNT(order_no) AS task_count FROM order_0 WHERE order_status = 0
UNION ALL
SELECT
    '待发货'  AS task_type, COUNT(order_no) AS task_count FROM order_0 WHERE order_status = 10
UNION ALL
SELECT
    '已发货'  AS task_type, COUNT(order_no) AS task_count FROM order_0 WHERE order_status = 20
UNION ALL
SELECT
    '待审核退款' AS task_type, COUNT(refund_id) AS task_count FROM refund_0 WHERE refund_status = 0
UNION ALL
SELECT
    '待审核商品' AS task_type, COUNT(spu_id) AS task_count FROM spu_0 WHERE spu_status = 1;


-- 8.5 优惠券使用统计视图 (逻辑定义)
CREATE VIEW common_db.v_coupon_usage_stats AS
SELECT
    c.coupon_id,
    c.coupon_name,
    c.coupon_type,
    c.total_limit,
    c.received_count,
    c.used_count,
    ROUND(c.used_count / NULLIF(c.received_count, 0) * 100, 2) AS usage_rate,
    c.status
FROM coupon_0 c;


-- 8.6 每日经营数据视图 (逻辑定义)
-- 用途: Dashboard 核心指标
CREATE VIEW common_db.v_daily_business_metrics AS
SELECT
    DATE(ord.create_time)                                  AS biz_date,
    COUNT(DISTINCT ord.order_no)                           AS order_count,
    COUNT(DISTINCT ord.user_id)                            AS buyer_count,
    SUM(ord.product_amount)                                AS product_amount,
    SUM(ord.discount_amount)                               AS discount_amount,
    SUM(ord.pay_amount)                                    AS gmv,
    AVG(ord.pay_amount)                                    AS avg_order_value,
    COUNT(DISTINCT CASE WHEN ord.order_type = 2 THEN ord.order_no END) AS seckill_order_count
FROM order_0 ord
WHERE ord.pay_time IS NOT NULL
  AND ord.is_archived = 0
GROUP BY DATE(ord.create_time);


-- =================================================================
-- 第九节: 预置核心配置数据
-- =================================================================

-- 系统默认配置项
INSERT INTO common_db.system_config (config_key, config_value, config_desc, config_group) VALUES
('order.auto_cancel_minutes', '30', '下单后未支付自动取消时间(分钟)', 'ORDER'),
('order.auto_confirm_days', '15', '发货后自动确认收货天数', 'ORDER'),
('order.max_cart_items', '200', '购物车最大商品数量', 'ORDER'),
('review.auto_good_days', '30', '订单完成后自动好评天数', 'REVIEW'),
('seckill.default_qps_limit', '10000', '秒杀接口默认QPS限制', 'SECKILL'),
('sms.max_per_hour_per_ip', '5', '同IP每小时最大短信发送次数', 'SECURITY'),
('user.max_address_count', '20', '用户最大收货地址数', 'USER');


-- =================================================================
-- 第十节: 分布式 ID 生成器表 (可选, 仅备选方案)
-- 雪花算法为主要方案, 此表为退化/兜底方案的号段模式
-- =================================================================

CREATE TABLE common_db.id_generator (
    id              BIGINT  NOT NULL AUTO_INCREMENT COMMENT '主键',
    biz_type        VARCHAR(32) NOT NULL COMMENT '业务类型: ORDER/USER/SPU/SKU',
    max_id          BIGINT  NOT NULL DEFAULT 0 COMMENT '当前最大ID',
    step            INT     NOT NULL DEFAULT 1000 COMMENT '号段步长',
    version         INT     NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    create_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_biz_type (biz_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分布式ID生成器(号段模式-兜底方案)';

-- 预置ID生成业务类型
INSERT INTO common_db.id_generator (biz_type, max_id, step) VALUES
('USER', 1000000, 1000),
('SPU', 1000000, 1000),
('SKU', 1000000, 1000),
('ORDER', 1000000, 5000),
('REVIEW', 1000000, 1000),
('COUPON', 1000000, 500),
('PAYMENT', 1000000, 1000);


-- =================================================================
-- 附录: 分库分表路由规则汇总
-- =================================================================
/*
┌──────────┬──────────┬─────────────────┬────────────┬──────┬────────┐
│ 业务域    │ 表名      │ 分片键            │ 路由算法      │ 库数  │ 每库表数 │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ user_db  │ user     │ user_id          │ ID右移4位取模 │ 4    │ 32     │
│          │ address  │ user_id          │ 同user库     │ 4    │ 32     │
│          │ collection│ user_id          │ 同user库     │ 4    │ 32     │
│          │ history  │ user_id          │ 同user库     │ 4    │ 32     │
│          │ points   │ user_id          │ 同user库     │ 4    │ 32     │
│          │ login_log│ user_id          │ 同user库     │ 4    │ 32     │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ prod_db  │ spu      │ spu_id           │ spu_id%4    │ 4    │ 32     │
│          │ sku      │ spu_id           │ 同spu库     │ 4    │ 32     │
│          │ stock    │ spu_id           │ 同spu库     │ 4    │ 32     │
│          │ stock_flow│ spu_id           │ 同spu库     │ 4    │ 32     │
│          │ price_hist│ spu_id           │ 同spu库     │ 4    │ 32     │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ order_db │ order    │ user_id          │ user_id%8   │ 8    │ 64     │
│          │ order_item│ user_id          │ 同order库   │ 8    │ 64     │
│          │ order_log│ user_id          │ 同order库   │ 8    │ 64     │
│          │ cart     │ user_id          │ user_id%8   │ 8    │ 64     │
│          │ payment  │ user_id          │ user_id%8   │ 8    │ 64     │
│          │ refund   │ user_id          │ user_id%8   │ 8    │ 64     │
│          │ delivery │ user_id          │ user_id%8   │ 8    │ 64     │
│          │ track    │ user_id          │ user_id%8   │ 8    │ 64     │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ review_db│ review   │ spu_id           │ spu_id%4    │ 4    │ 32     │
│          │ img      │ spu_id           │ 同review库  │ 4    │ 32     │
│          │ reply    │ spu_id           │ 同review库  │ 4    │ 32     │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ mkt_db   │ coupon   │ coupon_id        │ coupon_id%2 │ 2    │ 16     │
│          │ user_coupon│ user_id         │ user_id%2   │ 2    │ 16     │
│          │ seckill  │ activity_id      │ act_id%2    │ 2    │ 16     │
│          │ sk_product│ activity_id      │ act_id%2    │ 2    │ 16     │
│          │ sk_order │ user_id          │ user_id%2   │ 2    │ 16     │
│          │ promotion│ activity_id      │ act_id%2    │ 2    │ 16     │
├──────────┼──────────┼─────────────────┼────────────┼──────┼────────┤
│ common_db│ mapping  │ 不分区             │ —          │ 1    │ 1      │
│          │ sms_log  │ 不分区             │ —          │ 1    │ 1      │
│          │ config   │ 不分区             │ —          │ 1    │ 1      │
│          │ admin_*  │ 不分区             │ —          │ 1    │ 1      │
│          │ banner   │ 不分区             │ —          │ 1    │ 1      │
│          │ notif    │ 不分区             │ —          │ 1    │ 1      │
│          │ id_gen   │ 不分区             │ —          │ 1    │ 1      │
└──────────┴──────────┴─────────────────┴────────────┴──────┴────────┘
*/
