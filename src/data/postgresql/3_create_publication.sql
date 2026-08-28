SHOW wal_level;

CREATE PUBLICATION airbyte_retail_publication
FOR TABLE
    public.customers,
    public.stores,
    public.categories,
    public.suppliers,
    public.products,
    public.orders,
    public.order_items;

SELECT pg_create_logical_replication_slot(
    'airbyte_retail_slot',
    'pgoutput'
);