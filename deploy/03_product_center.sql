-- ===================== 商品中心 + 广播表 DDL =====================
-- 分片: 4库 x 32表 | 分片键: spu_id
-- 算法: db_idx = spu_id%4, tb_idx = (spu_id>>4)%32
-- 使用: mysql -u root -p product_db_0 < 03_product_center.sql

USE product_db_0;

CREATE TABLE IF NOT EXISTS spu_0 (
    spu_id            BIGINT        NOT NULL COMMENT 'SPU ID(雪花算法)',
    spu_name          VARCHAR(256)  NOT NULL COMMENT '商品名称',
    subtitle          VARCHAR(512)  DEFAULT NULL COMMENT '副标题',
    category_id       BIGINT        NOT NULL COMMENT '三级类目ID',
    brand_id          BIGINT        DEFAULT NULL COMMENT '品牌ID',
    main_image        VARCHAR(256)  NOT NULL COMMENT '主图URL',
    images            JSON          DEFAULT NULL COMMENT '商品轮播图列表(JSON数组)',
    video_url         VARCHAR(256)  DEFAULT NULL COMMENT '商品视频URL',
    description       LONGTEXT      COMMENT '商品详细描述(富文本HTML)',
    service_guarantee VARCHAR(512)  DEFAULT NULL COMMENT '服务承诺(JSON数组)',
    spu_status        TINYINT       DEFAULT 0 COMMENT '状态: 0草稿/1待审核/2审核通过/3已上架/4已下架/5审核驳回',
    audit_reason      VARCHAR(512)  DEFAULT NULL COMMENT '审核驳回原因',
    sale_count        INT           DEFAULT 0 COMMENT '累计销量',
    review_count      INT           DEFAULT 0 COMMENT '累计评价数',
    avg_rating        DECIMAL(2,1)  DEFAULT 0.0 COMMENT '平均评分',
    min_price         DECIMAL(12,2) DEFAULT 0.00 COMMENT '最低销售价',
    max_price         DECIMAL(12,2) DEFAULT 0.00 COMMENT '最高销售价',
    is_new            TINYINT       DEFAULT 0 COMMENT '是否新品',
    is_hot            TINYINT       DEFAULT 0 COMMENT '是否热销',
    is_recommend      TINYINT       DEFAULT 0 COMMENT '是否推荐',
    shelf_time        DATETIME      DEFAULT NULL COMMENT '上架时间',
    is_deleted        TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (spu_id),
    INDEX idx_category_id (category_id),
    INDEX idx_brand_id (brand_id),
    INDEX idx_spu_status (spu_status),
    INDEX idx_create_time (create_time),
    INDEX idx_sale_count (sale_count),
    INDEX idx_recommend (is_recommend, spu_status),
    INDEX idx_category_status (category_id, spu_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SPU表';

CREATE TABLE IF NOT EXISTS sku_0 (
    sku_id         BIGINT        NOT NULL COMMENT 'SKU ID(雪花算法)',
    spu_id         BIGINT        NOT NULL COMMENT '关联SPU ID',
    sku_code       VARCHAR(64)   NOT NULL COMMENT 'SKU编码',
    sku_name       VARCHAR(256)  DEFAULT NULL COMMENT 'SKU名称',
    sku_image      VARCHAR(256)  DEFAULT NULL COMMENT 'SKU图URL',
    sale_price     DECIMAL(12,2) NOT NULL COMMENT '售价',
    market_price   DECIMAL(12,2) DEFAULT NULL COMMENT '划线价',
    cost_price     DECIMAL(12,2) DEFAULT NULL COMMENT '成本价',
    attrs          JSON          NOT NULL COMMENT '销售属性组合(JSON)',
    weight         DECIMAL(10,2) DEFAULT 0.00 COMMENT '重量(kg)',
    volume         DECIMAL(10,2) DEFAULT 0.00 COMMENT '体积(m3)',
    is_deleted     TINYINT       DEFAULT 0 COMMENT '逻辑删除',
    create_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (sku_id),
    UNIQUE KEY uk_sku_code (sku_code),
    INDEX idx_spu_id (spu_id),
    INDEX idx_sale_price (sale_price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品SKU表';

CREATE TABLE IF NOT EXISTS sku_stock_0 (
    stock_id        BIGINT        NOT NULL AUTO_INCREMENT COMMENT '库存ID',
    sku_id          BIGINT        NOT NULL COMMENT 'SKU ID',
    spu_id          BIGINT        NOT NULL COMMENT 'SPU ID',
    total_stock     INT           NOT NULL DEFAULT 0 COMMENT '总库存',
    locked_stock    INT           NOT NULL DEFAULT 0 COMMENT '预扣库存',
    available_stock INT           NOT NULL DEFAULT 0 COMMENT '可用库存',
    safety_stock    INT           DEFAULT 0 COMMENT '安全库存',
    version         INT           NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    warehouse_id    BIGINT        DEFAULT NULL COMMENT '仓库ID',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (stock_id),
    UNIQUE KEY uk_sku_id (sku_id),
    INDEX idx_spu_id (spu_id),
    INDEX idx_available (available_stock),
    INDEX idx_safety (available_stock, safety_stock)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU库存表';

CREATE TABLE IF NOT EXISTS stock_flow_0 (
    flow_id         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '流水ID',
    sku_id          BIGINT        NOT NULL COMMENT 'SKU ID',
    change_type     TINYINT       NOT NULL COMMENT '变动类型: 1下单预扣/2支付确认/3取消释放/4入库/5出库/6人工调整',
    change_quantity INT           NOT NULL COMMENT '变动数量(负数为减少)',
    before_stock    INT           NOT NULL COMMENT '变动前可用库存',
    after_stock     INT           NOT NULL COMMENT '变动后可用库存',
    order_no        VARCHAR(32)   DEFAULT NULL COMMENT '关联订单号',
    operator        VARCHAR(64)   DEFAULT NULL COMMENT '操作人',
    remark          VARCHAR(256)  DEFAULT NULL COMMENT '备注',
    create_time     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (flow_id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存流水表';

CREATE TABLE IF NOT EXISTS sku_price_history_0 (
    id            BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键',
    sku_id        BIGINT        NOT NULL COMMENT 'SKU ID',
    old_price     DECIMAL(12,2) NOT NULL COMMENT '原价',
    new_price     DECIMAL(12,2) NOT NULL COMMENT '新价',
    change_type   TINYINT       DEFAULT 1 COMMENT '变动类型: 1调价/2促销/3秒杀/4恢复原价',
    operator      VARCHAR(64)   DEFAULT NULL COMMENT '操作人',
    create_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_sku_id (sku_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SKU价格历史表';

-- 广播表 (每分片存全量)
CREATE TABLE IF NOT EXISTS category_broadcast (
    category_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '分类ID',
    category_name VARCHAR(64)  NOT NULL COMMENT '分类名称',
    parent_id     BIGINT       DEFAULT 0 COMMENT '父分类ID(0=顶级)',
    level         TINYINT      NOT NULL COMMENT '层级: 1一级/2二级/3三级',
    sort_order    INT          DEFAULT 0 COMMENT '排序值',
    icon_url      VARCHAR(256) DEFAULT NULL COMMENT '分类图标',
    banner_url    VARCHAR(256) DEFAULT NULL COMMENT '分类Banner图',
    is_show       TINYINT      DEFAULT 1 COMMENT '是否显示: 0隐藏/1显示',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (category_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_sort_order (sort_order),
    INDEX idx_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品分类表(广播表)';

CREATE TABLE IF NOT EXISTS brand_broadcast (
    brand_id     BIGINT       NOT NULL AUTO_INCREMENT COMMENT '品牌ID',
    brand_name   VARCHAR(128) NOT NULL COMMENT '品牌名称',
    brand_logo   VARCHAR(256) DEFAULT NULL COMMENT '品牌Logo URL',
    brand_desc   TEXT         COMMENT '品牌描述',
    country      VARCHAR(64)  DEFAULT NULL COMMENT '品牌产地',
    sort_order   INT          DEFAULT 0 COMMENT '排序',
    is_show      TINYINT      DEFAULT 1 COMMENT '是否显示: 0隐藏/1显示',
    create_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (brand_id),
    INDEX idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='品牌表(广播表)';

CREATE TABLE IF NOT EXISTS product_attr (
    attr_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '属性ID',
    category_id   BIGINT       NOT NULL COMMENT '关联分类ID',
    attr_name     VARCHAR(64)  NOT NULL COMMENT '属性名称',
    input_type    TINYINT      DEFAULT 1 COMMENT '录入方式: 1手动输入/2从列表选择',
    attr_values   JSON         DEFAULT NULL COMMENT '可选值列表(JSON数组)',
    sort_order    INT          DEFAULT 0 COMMENT '排序',
    is_required   TINYINT      DEFAULT 0 COMMENT '是否必填: 0非必填/1必填',
    attr_type     TINYINT      DEFAULT 1 COMMENT '1销售属性(如颜色)/2非销售属性(如电池容量)',
    create_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (attr_id),
    INDEX idx_category_id (category_id),
    INDEX idx_attr_type (attr_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品属性模板表';

SELECT '商品中心表创建完成 (product_db_0)' AS result;
