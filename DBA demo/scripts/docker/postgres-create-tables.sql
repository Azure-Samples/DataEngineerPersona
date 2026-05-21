-- PostgreSQL CREATE TABLE definitions for WideWorldImporters
-- Generated from SQL Server INFORMATION_SCHEMA with type mapping:
--   nvarchar/varchar/ntext → TEXT
--   int → INTEGER, bigint → BIGINT, smallint → SMALLINT, tinyint → SMALLINT
--   bit → BOOLEAN
--   decimal/numeric → NUMERIC(p,s), money → NUMERIC(19,4)
--   datetime/datetime2/datetimeoffset → TIMESTAMPTZ
--   date → DATE
--   uniqueidentifier → UUID
--   varbinary/image → BYTEA
--   hierarchyid → TEXT, geography → TEXT
-- PascalCase → snake_case for all identifiers
-- Computed columns excluded; no FKs (added post-migration if needed)

BEGIN;

-- ============================================================
-- Application schema
-- ============================================================

DROP TABLE IF EXISTS application.cities CASCADE;
CREATE TABLE application.cities (
    city_id              INTEGER      NOT NULL,
    city_name            TEXT         NOT NULL,
    state_province_id    INTEGER      NOT NULL,
    location             TEXT,
    latest_recorded_population BIGINT,
    last_edited_by       INTEGER      NOT NULL,
    valid_from           TIMESTAMPTZ  NOT NULL,
    valid_to             TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.countries CASCADE;
CREATE TABLE application.countries (
    country_id                INTEGER      NOT NULL,
    country_name              TEXT         NOT NULL,
    formal_name               TEXT         NOT NULL,
    iso_alpha3_code           TEXT,
    iso_numeric_code          INTEGER,
    country_type              TEXT,
    latest_recorded_population BIGINT,
    continent                 TEXT         NOT NULL,
    region                    TEXT         NOT NULL,
    subregion                 TEXT         NOT NULL,
    border                    TEXT,
    last_edited_by            INTEGER      NOT NULL,
    valid_from                TIMESTAMPTZ  NOT NULL,
    valid_to                  TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.delivery_methods CASCADE;
CREATE TABLE application.delivery_methods (
    delivery_method_id   INTEGER      NOT NULL,
    delivery_method_name TEXT         NOT NULL,
    last_edited_by       INTEGER      NOT NULL,
    valid_from           TIMESTAMPTZ  NOT NULL,
    valid_to             TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.payment_methods CASCADE;
CREATE TABLE application.payment_methods (
    payment_method_id    INTEGER      NOT NULL,
    payment_method_name  TEXT         NOT NULL,
    last_edited_by       INTEGER      NOT NULL,
    valid_from           TIMESTAMPTZ  NOT NULL,
    valid_to             TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.people CASCADE;
CREATE TABLE application.people (
    person_id                  INTEGER      NOT NULL,
    full_name                  TEXT         NOT NULL,
    preferred_name             TEXT         NOT NULL,
    search_name                TEXT         NOT NULL,
    is_permitted_to_logon      BOOLEAN      NOT NULL,
    logon_name                 TEXT,
    is_external_logon_provider BOOLEAN      NOT NULL,
    hashed_password            BYTEA,
    is_system_user             BOOLEAN      NOT NULL,
    is_employee                BOOLEAN      NOT NULL,
    is_salesperson             BOOLEAN      NOT NULL,
    user_preferences           TEXT,
    phone_number               TEXT,
    fax_number                 TEXT,
    email_address              TEXT,
    photo                      BYTEA,
    custom_fields              TEXT,
    other_languages            TEXT,
    last_edited_by             INTEGER      NOT NULL,
    valid_from                 TIMESTAMPTZ  NOT NULL,
    valid_to                   TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.state_provinces CASCADE;
CREATE TABLE application.state_provinces (
    state_province_id          INTEGER      NOT NULL,
    state_province_code        TEXT         NOT NULL,
    state_province_name        TEXT         NOT NULL,
    country_id                 INTEGER      NOT NULL,
    sales_territory            TEXT         NOT NULL,
    border                     TEXT,
    latest_recorded_population BIGINT,
    last_edited_by             INTEGER      NOT NULL,
    valid_from                 TIMESTAMPTZ  NOT NULL,
    valid_to                   TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.system_parameters CASCADE;
CREATE TABLE application.system_parameters (
    system_parameter_id      INTEGER      NOT NULL,
    delivery_address_line1   TEXT         NOT NULL,
    delivery_address_line2   TEXT,
    delivery_city_id         INTEGER      NOT NULL,
    delivery_postal_code     TEXT         NOT NULL,
    delivery_location        TEXT         NOT NULL,
    postal_address_line1     TEXT         NOT NULL,
    postal_address_line2     TEXT,
    postal_city_id           INTEGER      NOT NULL,
    postal_postal_code       TEXT         NOT NULL,
    application_settings     TEXT         NOT NULL,
    last_edited_by           INTEGER      NOT NULL,
    last_edited_when         TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS application.transaction_types CASCADE;
CREATE TABLE application.transaction_types (
    transaction_type_id      INTEGER      NOT NULL,
    transaction_type_name    TEXT         NOT NULL,
    last_edited_by           INTEGER      NOT NULL,
    valid_from               TIMESTAMPTZ  NOT NULL,
    valid_to                 TIMESTAMPTZ  NOT NULL
);

-- ============================================================
-- Purchasing schema
-- ============================================================

DROP TABLE IF EXISTS purchasing.purchase_order_lines CASCADE;
CREATE TABLE purchasing.purchase_order_lines (
    purchase_order_line_id       INTEGER      NOT NULL,
    purchase_order_id            INTEGER      NOT NULL,
    stock_item_id                INTEGER      NOT NULL,
    ordered_outers               INTEGER      NOT NULL,
    description                  TEXT         NOT NULL,
    received_outers              INTEGER      NOT NULL,
    package_type_id              INTEGER      NOT NULL,
    expected_unit_price_per_outer NUMERIC(18,2),
    last_receipt_date            DATE,
    is_order_line_finalized      BOOLEAN      NOT NULL,
    last_edited_by               INTEGER      NOT NULL,
    last_edited_when             TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS purchasing.purchase_orders CASCADE;
CREATE TABLE purchasing.purchase_orders (
    purchase_order_id    INTEGER      NOT NULL,
    supplier_id          INTEGER      NOT NULL,
    order_date           DATE         NOT NULL,
    delivery_method_id   INTEGER      NOT NULL,
    contact_person_id    INTEGER      NOT NULL,
    expected_delivery_date DATE,
    supplier_reference   TEXT,
    is_order_finalized   BOOLEAN      NOT NULL,
    comments             TEXT,
    internal_comments    TEXT,
    last_edited_by       INTEGER      NOT NULL,
    last_edited_when     TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS purchasing.supplier_categories CASCADE;
CREATE TABLE purchasing.supplier_categories (
    supplier_category_id   INTEGER      NOT NULL,
    supplier_category_name TEXT         NOT NULL,
    last_edited_by         INTEGER      NOT NULL,
    valid_from             TIMESTAMPTZ  NOT NULL,
    valid_to               TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS purchasing.suppliers CASCADE;
CREATE TABLE purchasing.suppliers (
    supplier_id                INTEGER      NOT NULL,
    supplier_name              TEXT         NOT NULL,
    supplier_category_id       INTEGER      NOT NULL,
    primary_contact_person_id  INTEGER      NOT NULL,
    alternate_contact_person_id INTEGER     NOT NULL,
    delivery_method_id         INTEGER,
    delivery_city_id           INTEGER      NOT NULL,
    postal_city_id             INTEGER      NOT NULL,
    supplier_reference         TEXT,
    bank_account_name          TEXT,
    bank_account_branch        TEXT,
    bank_account_code          TEXT,
    bank_account_number        TEXT,
    bank_international_code    TEXT,
    payment_days               INTEGER      NOT NULL,
    internal_comments          TEXT,
    phone_number               TEXT         NOT NULL,
    fax_number                 TEXT         NOT NULL,
    website_url                TEXT         NOT NULL,
    delivery_address_line1     TEXT         NOT NULL,
    delivery_address_line2     TEXT,
    delivery_postal_code       TEXT         NOT NULL,
    delivery_location          TEXT,
    postal_address_line1       TEXT         NOT NULL,
    postal_address_line2       TEXT,
    postal_postal_code         TEXT         NOT NULL,
    last_edited_by             INTEGER      NOT NULL,
    valid_from                 TIMESTAMPTZ  NOT NULL,
    valid_to                   TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS purchasing.supplier_transactions CASCADE;
CREATE TABLE purchasing.supplier_transactions (
    supplier_transaction_id  INTEGER        NOT NULL,
    supplier_id              INTEGER        NOT NULL,
    transaction_type_id      INTEGER        NOT NULL,
    purchase_order_id        INTEGER,
    payment_method_id        INTEGER,
    supplier_invoice_number  TEXT,
    transaction_date         DATE           NOT NULL,
    amount_excluding_tax     NUMERIC(18,2)  NOT NULL,
    tax_amount               NUMERIC(18,2)  NOT NULL,
    transaction_amount       NUMERIC(18,2)  NOT NULL,
    outstanding_balance      NUMERIC(18,2)  NOT NULL,
    finalization_date        DATE,
    is_finalized             BOOLEAN,
    last_edited_by           INTEGER        NOT NULL,
    last_edited_when         TIMESTAMPTZ    NOT NULL
);

-- ============================================================
-- Sales schema
-- ============================================================

DROP TABLE IF EXISTS sales.buying_groups CASCADE;
CREATE TABLE sales.buying_groups (
    buying_group_id    INTEGER      NOT NULL,
    buying_group_name  TEXT         NOT NULL,
    last_edited_by     INTEGER      NOT NULL,
    valid_from         TIMESTAMPTZ  NOT NULL,
    valid_to           TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS sales.customer_categories CASCADE;
CREATE TABLE sales.customer_categories (
    customer_category_id   INTEGER      NOT NULL,
    customer_category_name TEXT         NOT NULL,
    last_edited_by         INTEGER      NOT NULL,
    valid_from             TIMESTAMPTZ  NOT NULL,
    valid_to               TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS sales.customers CASCADE;
CREATE TABLE sales.customers (
    customer_id                  INTEGER        NOT NULL,
    customer_name                TEXT           NOT NULL,
    bill_to_customer_id          INTEGER        NOT NULL,
    customer_category_id         INTEGER        NOT NULL,
    buying_group_id              INTEGER,
    primary_contact_person_id    INTEGER        NOT NULL,
    alternate_contact_person_id  INTEGER,
    delivery_method_id           INTEGER        NOT NULL,
    delivery_city_id             INTEGER        NOT NULL,
    postal_city_id               INTEGER        NOT NULL,
    credit_limit                 NUMERIC(18,2),
    account_opened_date          DATE           NOT NULL,
    standard_discount_percentage NUMERIC(18,3)  NOT NULL,
    is_statement_sent            BOOLEAN        NOT NULL,
    is_on_credit_hold            BOOLEAN        NOT NULL,
    payment_days                 INTEGER        NOT NULL,
    phone_number                 TEXT           NOT NULL,
    fax_number                   TEXT           NOT NULL,
    delivery_run                 TEXT,
    run_position                 TEXT,
    website_url                  TEXT           NOT NULL,
    delivery_address_line1       TEXT           NOT NULL,
    delivery_address_line2       TEXT,
    delivery_postal_code         TEXT           NOT NULL,
    delivery_location            TEXT,
    postal_address_line1         TEXT           NOT NULL,
    postal_address_line2         TEXT,
    postal_postal_code           TEXT           NOT NULL,
    last_edited_by               INTEGER        NOT NULL,
    valid_from                   TIMESTAMPTZ    NOT NULL,
    valid_to                     TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS sales.customer_transactions CASCADE;
CREATE TABLE sales.customer_transactions (
    customer_transaction_id  INTEGER        NOT NULL,
    customer_id              INTEGER        NOT NULL,
    transaction_type_id      INTEGER        NOT NULL,
    invoice_id               INTEGER,
    payment_method_id        INTEGER,
    transaction_date         DATE           NOT NULL,
    amount_excluding_tax     NUMERIC(18,2)  NOT NULL,
    tax_amount               NUMERIC(18,2)  NOT NULL,
    transaction_amount       NUMERIC(18,2)  NOT NULL,
    outstanding_balance      NUMERIC(18,2)  NOT NULL,
    finalization_date        DATE,
    is_finalized             BOOLEAN,
    last_edited_by           INTEGER        NOT NULL,
    last_edited_when         TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS sales.invoice_lines CASCADE;
CREATE TABLE sales.invoice_lines (
    invoice_line_id    INTEGER        NOT NULL,
    invoice_id         INTEGER        NOT NULL,
    stock_item_id      INTEGER        NOT NULL,
    description        TEXT           NOT NULL,
    package_type_id    INTEGER        NOT NULL,
    quantity           INTEGER        NOT NULL,
    unit_price         NUMERIC(18,2),
    tax_rate           NUMERIC(18,3)  NOT NULL,
    tax_amount         NUMERIC(18,2)  NOT NULL,
    line_profit        NUMERIC(18,2)  NOT NULL,
    extended_price     NUMERIC(18,2)  NOT NULL,
    last_edited_by     INTEGER        NOT NULL,
    last_edited_when   TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS sales.invoices CASCADE;
CREATE TABLE sales.invoices (
    invoice_id                     INTEGER      NOT NULL,
    customer_id                    INTEGER      NOT NULL,
    bill_to_customer_id            INTEGER      NOT NULL,
    order_id                       INTEGER,
    delivery_method_id             INTEGER      NOT NULL,
    contact_person_id              INTEGER      NOT NULL,
    accounts_person_id             INTEGER      NOT NULL,
    salesperson_person_id          INTEGER      NOT NULL,
    packed_by_person_id            INTEGER      NOT NULL,
    invoice_date                   DATE         NOT NULL,
    customer_purchase_order_number TEXT,
    is_credit_note                 BOOLEAN      NOT NULL,
    credit_note_reason             TEXT,
    comments                       TEXT,
    delivery_instructions          TEXT,
    internal_comments              TEXT,
    total_dry_items                INTEGER      NOT NULL,
    total_chiller_items            INTEGER      NOT NULL,
    delivery_run                   TEXT,
    run_position                   TEXT,
    returned_delivery_data         TEXT,
    confirmed_delivery_time        TIMESTAMPTZ,
    confirmed_received_by          TEXT,
    last_edited_by                 INTEGER      NOT NULL,
    last_edited_when               TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS sales.order_lines CASCADE;
CREATE TABLE sales.order_lines (
    order_line_id          INTEGER        NOT NULL,
    order_id               INTEGER        NOT NULL,
    stock_item_id          INTEGER        NOT NULL,
    description            TEXT           NOT NULL,
    package_type_id        INTEGER        NOT NULL,
    quantity               INTEGER        NOT NULL,
    unit_price             NUMERIC(18,2),
    tax_rate               NUMERIC(18,3)  NOT NULL,
    picked_quantity        INTEGER        NOT NULL,
    picking_completed_when TIMESTAMPTZ,
    last_edited_by         INTEGER        NOT NULL,
    last_edited_when       TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS sales.orders CASCADE;
CREATE TABLE sales.orders (
    order_id                       INTEGER      NOT NULL,
    customer_id                    INTEGER      NOT NULL,
    salesperson_person_id          INTEGER      NOT NULL,
    picked_by_person_id            INTEGER,
    contact_person_id              INTEGER      NOT NULL,
    backorder_order_id             INTEGER,
    order_date                     DATE         NOT NULL,
    expected_delivery_date         DATE         NOT NULL,
    customer_purchase_order_number TEXT,
    is_undersupply_backordered     BOOLEAN      NOT NULL,
    comments                       TEXT,
    delivery_instructions          TEXT,
    internal_comments              TEXT,
    picking_completed_when         TIMESTAMPTZ,
    last_edited_by                 INTEGER      NOT NULL,
    last_edited_when               TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS sales.special_deals CASCADE;
CREATE TABLE sales.special_deals (
    special_deal_id       INTEGER        NOT NULL,
    stock_item_id         INTEGER,
    customer_id           INTEGER,
    buying_group_id       INTEGER,
    customer_category_id  INTEGER,
    stock_group_id        INTEGER,
    deal_description      TEXT           NOT NULL,
    start_date            DATE           NOT NULL,
    end_date              DATE           NOT NULL,
    discount_amount       NUMERIC(18,2),
    discount_percentage   NUMERIC(18,3),
    unit_price            NUMERIC(18,2),
    last_edited_by        INTEGER        NOT NULL,
    last_edited_when      TIMESTAMPTZ    NOT NULL
);

-- ============================================================
-- Warehouse schema
-- ============================================================

DROP TABLE IF EXISTS warehouse.cold_room_temperatures CASCADE;
CREATE TABLE warehouse.cold_room_temperatures (
    cold_room_temperature_id BIGINT       NOT NULL,
    cold_room_sensor_number  INTEGER      NOT NULL,
    recorded_when            TIMESTAMPTZ  NOT NULL,
    temperature              NUMERIC(10,2) NOT NULL,
    valid_from               TIMESTAMPTZ  NOT NULL,
    valid_to                 TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS warehouse.colors CASCADE;
CREATE TABLE warehouse.colors (
    color_id        INTEGER      NOT NULL,
    color_name      TEXT         NOT NULL,
    last_edited_by  INTEGER      NOT NULL,
    valid_from      TIMESTAMPTZ  NOT NULL,
    valid_to        TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS warehouse.package_types CASCADE;
CREATE TABLE warehouse.package_types (
    package_type_id   INTEGER      NOT NULL,
    package_type_name TEXT         NOT NULL,
    last_edited_by    INTEGER      NOT NULL,
    valid_from        TIMESTAMPTZ  NOT NULL,
    valid_to          TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS warehouse.stock_groups CASCADE;
CREATE TABLE warehouse.stock_groups (
    stock_group_id    INTEGER      NOT NULL,
    stock_group_name  TEXT         NOT NULL,
    last_edited_by    INTEGER      NOT NULL,
    valid_from        TIMESTAMPTZ  NOT NULL,
    valid_to          TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS warehouse.stock_item_holdings CASCADE;
CREATE TABLE warehouse.stock_item_holdings (
    stock_item_id             INTEGER        NOT NULL,
    quantity_on_hand          INTEGER        NOT NULL,
    bin_location              TEXT           NOT NULL,
    last_stocktake_quantity   INTEGER        NOT NULL,
    last_cost_price           NUMERIC(18,2)  NOT NULL,
    reorder_level             INTEGER        NOT NULL,
    target_stock_level        INTEGER        NOT NULL,
    last_edited_by            INTEGER        NOT NULL,
    last_edited_when          TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS warehouse.stock_items CASCADE;
CREATE TABLE warehouse.stock_items (
    stock_item_id              INTEGER        NOT NULL,
    stock_item_name            TEXT           NOT NULL,
    supplier_id                INTEGER        NOT NULL,
    color_id                   INTEGER,
    unit_package_id            INTEGER        NOT NULL,
    outer_package_id           INTEGER        NOT NULL,
    brand                      TEXT,
    size                       TEXT,
    lead_time_days             INTEGER        NOT NULL,
    quantity_per_outer         INTEGER        NOT NULL,
    is_chiller_stock           BOOLEAN        NOT NULL,
    barcode                    TEXT,
    tax_rate                   NUMERIC(18,3)  NOT NULL,
    unit_price                 NUMERIC(18,2)  NOT NULL,
    recommended_retail_price   NUMERIC(18,2),
    typical_weight_per_unit    NUMERIC(18,3)  NOT NULL,
    marketing_comments         TEXT,
    internal_comments          TEXT,
    photo                      BYTEA,
    custom_fields              TEXT,
    tags                       TEXT,
    search_details             TEXT           NOT NULL,
    last_edited_by             INTEGER        NOT NULL,
    valid_from                 TIMESTAMPTZ    NOT NULL,
    valid_to                   TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS warehouse.stock_item_stock_groups CASCADE;
CREATE TABLE warehouse.stock_item_stock_groups (
    stock_item_stock_group_id INTEGER      NOT NULL,
    stock_item_id             INTEGER      NOT NULL,
    stock_group_id            INTEGER      NOT NULL,
    last_edited_by            INTEGER      NOT NULL,
    last_edited_when          TIMESTAMPTZ  NOT NULL
);

DROP TABLE IF EXISTS warehouse.stock_item_transactions CASCADE;
CREATE TABLE warehouse.stock_item_transactions (
    stock_item_transaction_id INTEGER        NOT NULL,
    stock_item_id             INTEGER        NOT NULL,
    transaction_type_id       INTEGER        NOT NULL,
    customer_id               INTEGER,
    invoice_id                INTEGER,
    supplier_id               INTEGER,
    purchase_order_id         INTEGER,
    transaction_occurred_when TIMESTAMPTZ    NOT NULL,
    quantity                  NUMERIC(18,3)  NOT NULL,
    last_edited_by            INTEGER        NOT NULL,
    last_edited_when          TIMESTAMPTZ    NOT NULL
);

DROP TABLE IF EXISTS warehouse.vehicle_temperatures CASCADE;
CREATE TABLE warehouse.vehicle_temperatures (
    vehicle_temperature_id BIGINT       NOT NULL,
    vehicle_registration   TEXT         NOT NULL,
    chiller_sensor_number  INTEGER      NOT NULL,
    recorded_when          TIMESTAMPTZ  NOT NULL,
    temperature            NUMERIC(10,2) NOT NULL,
    full_sensor_data       TEXT,
    is_compressed          BOOLEAN      NOT NULL,
    compressed_sensor_data BYTEA
);

COMMIT;
