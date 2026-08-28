-- ============================================================
-- CUSTOMERS
-- ============================================================

INSERT INTO customers
    (first_name, last_name, email, phone, city, country)
VALUES
    ('Andi', 'Pratama', 'andi.pratama@example.com', '081234567001', 'Bandung', 'Indonesia'),
    ('Budi', 'Santoso', 'budi.santoso@example.com', '081234567002', 'Jakarta', 'Indonesia'),
    ('Citra', 'Lestari', 'citra.lestari@example.com', '081234567003', 'Surabaya', 'Indonesia'),
    ('Dewi', 'Anggraini', 'dewi.anggraini@example.com', '081234567004', 'Bandung', 'Indonesia'),
    ('Eko', 'Wijaya', 'eko.wijaya@example.com', '081234567005', 'Jakarta', 'Indonesia'),
    ('Fajar', 'Hidayat', 'fajar.hidayat@example.com', '081234567006', 'Yogyakarta', 'Indonesia'),
    ('Gita', 'Permata', 'gita.permata@example.com', '081234567007', 'Surabaya', 'Indonesia'),
    ('Hendra', 'Kurniawan', 'hendra.kurniawan@example.com', '081234567008', 'Semarang', 'Indonesia'),
    ('Intan', 'Sari', 'intan.sari@example.com', '081234567009', 'Bandung', 'Indonesia'),
    ('Joko', 'Susanto', 'joko.susanto@example.com', '081234567010', 'Jakarta', 'Indonesia');


-- ============================================================
-- STORES
-- ============================================================

INSERT INTO stores
    (store_name, city, province, country, opened_date)
VALUES
    ('Bandung Central', 'Bandung', 'West Java', 'Indonesia', '2022-01-15'),
    ('Jakarta Mall', 'Jakarta', 'DKI Jakarta', 'Indonesia', '2021-06-20'),
    ('Surabaya Plaza', 'Surabaya', 'East Java', 'Indonesia', '2023-03-10'),
    ('Yogyakarta Point', 'Yogyakarta', 'DI Yogyakarta', 'Indonesia', '2024-01-05');


-- ============================================================
-- CATEGORIES
-- ============================================================

INSERT INTO categories
    (category_name, description)
VALUES
    ('Beverages', 'Drinks and beverages'),
    ('Snacks', 'Packaged snacks and light food'),
    ('Household', 'Household and cleaning products'),
    ('Personal Care', 'Personal hygiene and care products'),
    ('Dairy', 'Milk and dairy products');


-- ============================================================
-- SUPPLIERS
-- ============================================================

INSERT INTO suppliers
    (supplier_name, contact_name, email, country)
VALUES
    ('Indo Beverage Supply', 'Rudi Hartono', 'rudi@indobeverage.com', 'Indonesia'),
    ('Nusantara Foods', 'Sari Dewi', 'sari@nusantarafoods.com', 'Indonesia'),
    ('Clean Home Indonesia', 'Agus Setiawan', 'agus@cleanhome.com', 'Indonesia'),
    ('Beauty Care Supply', 'Maya Putri', 'maya@beautycare.com', 'Indonesia'),
    ('Fresh Dairy Co', 'Dimas Saputra', 'dimas@freshdairy.com', 'Indonesia');


-- ============================================================
-- PRODUCTS
-- ============================================================

INSERT INTO products
    (category_id, supplier_id, product_name, sku, cost_price, selling_price)
VALUES
    (1, 1, 'Coca Cola 330ml',       'BEV-001', 5000,  7500),
    (1, 1, 'Pepsi 330ml',           'BEV-002', 4800,  7000),
    (1, 1, 'Mineral Water 600ml',   'BEV-003', 2500,  4000),

    (2, 2, 'Potato Chips Original', 'SNK-001', 7000, 10000),
    (2, 2, 'Chocolate Bar',         'SNK-002', 6000,  9000),
    (2, 2, 'Cheese Crackers',       'SNK-003', 5500,  8500),

    (3, 3, 'Dishwashing Liquid',    'HOU-001', 11000, 16000),
    (3, 3, 'Laundry Detergent',     'HOU-002', 18000, 25000),
    (3, 3, 'Floor Cleaner',         'HOU-003', 12000, 18000),

    (4, 4, 'Shampoo 250ml',         'PER-001', 17000, 24000),
    (4, 4, 'Body Wash 250ml',       'PER-002', 16000, 23000),
    (4, 4, 'Toothpaste 120g',       'PER-003', 9000,  14000),

    (5, 5, 'Fresh Milk 1L',          'DAI-001', 15000, 21000),
    (5, 5, 'Yogurt 500ml',           'DAI-002', 10000, 15000),
    (5, 5, 'Cheese 200g',             'DAI-003', 22000, 30000);


-- ============================================================
-- ORDERS
-- ============================================================

INSERT INTO orders
    (customer_id, store_id, order_date, order_status, payment_method)
VALUES
    (1, 1, '2026-08-01 09:15:00', 'COMPLETED', 'E_WALLET'),
    (2, 2, '2026-08-01 10:30:00', 'COMPLETED', 'CREDIT_CARD'),
    (3, 3, '2026-08-02 13:45:00', 'COMPLETED', 'DEBIT_CARD'),
    (4, 1, '2026-08-02 15:20:00', 'COMPLETED', 'CASH'),
    (5, 2, '2026-08-03 11:10:00', 'COMPLETED', 'E_WALLET'),
    (6, 4, '2026-08-03 16:40:00', 'COMPLETED', 'DEBIT_CARD'),
    (7, 3, '2026-08-04 12:05:00', 'COMPLETED', 'CREDIT_CARD'),
    (8, 1, '2026-08-05 09:50:00', 'COMPLETED', 'CASH'),
    (9, 2, '2026-08-05 14:30:00', 'COMPLETED', 'E_WALLET'),
    (10, 4, '2026-08-06 17:15:00', 'COMPLETED', 'CREDIT_CARD'),

    (1, 1, '2026-08-07 10:20:00', 'COMPLETED', 'E_WALLET'),
    (3, 3, '2026-08-07 13:10:00', 'COMPLETED', 'DEBIT_CARD'),
    (5, 2, '2026-08-08 15:40:00', 'COMPLETED', 'CREDIT_CARD'),
    (7, 3, '2026-08-09 11:30:00', 'COMPLETED', 'CASH'),
    (9, 1, '2026-08-10 16:00:00', 'COMPLETED', 'E_WALLET'),

    -- Include a cancelled order for data quality/business logic testing
    (2, 2, '2026-08-10 18:20:00', 'CANCELLED', 'CREDIT_CARD');


-- ============================================================
-- ORDER ITEMS
-- ============================================================

INSERT INTO order_items
    (order_id, product_id, quantity, unit_price, unit_cost, discount_amount)
VALUES

    -- Order 1
    (1,  1, 2, 7500,  5000, 0),
    (1,  4, 1, 10000, 7000, 0),

    -- Order 2
    (2,  2, 2, 7000,  4800, 0),
    (2,  5, 1, 9000,  6000, 1000),

    -- Order 3
    (3,  3, 3, 4000,  2500, 0),
    (3,  6, 2, 8500,  5500, 0),

    -- Order 4
    (4,  7, 1, 16000, 11000, 0),
    (4,  8, 1, 25000, 18000, 2000),

    -- Order 5
    (5,  10, 1, 24000, 17000, 0),
    (5,  12, 2, 14000, 9000, 0),

    -- Order 6
    (6,  13, 2, 21000, 15000, 2000),
    (6,  14, 1, 15000, 10000, 0),

    -- Order 7
    (7,  1, 3, 7500,  5000, 0),
    (7,  5, 2, 9000,  6000, 1000),

    -- Order 8
    (8,  9, 1, 18000, 12000, 0),
    (8,  11, 2, 23000, 16000, 2000),

    -- Order 9
    (9,  13, 1, 21000, 15000, 0),
    (9,  15, 1, 30000, 22000, 3000),

    -- Order 10
    (10, 3, 4, 4000, 2500, 0),
    (10, 4, 2, 10000, 7000, 0),

    -- Order 11
    (11, 2, 2, 7000, 4800, 0),
    (11, 7, 1, 16000, 11000, 1000),

    -- Order 12
    (12, 6, 3, 8500, 5500, 0),
    (12, 14, 2, 15000, 10000, 0),

    -- Order 13
    (13, 8, 1, 25000, 18000, 0),
    (13, 10, 1, 24000, 17000, 2000),

    -- Order 14
    (14, 1, 2, 7500, 5000, 0),
    (14, 12, 1, 14000, 9000, 0),

    -- Order 15
    (15, 5, 3, 9000, 6000, 1000),
    (15, 15, 1, 30000, 22000, 0),

    -- Order 16 - cancelled
    (16, 1, 2, 7500, 5000, 0),
    (16, 13, 1, 21000, 15000, 0);