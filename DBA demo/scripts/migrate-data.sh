#!/usr/bin/env bash
# =============================================================================
# Data Migration: SQL Server → PostgreSQL
# Transfers schema + data from WideWorldImporters to PostgreSQL.
#
# Usage: ./scripts/migrate-data.sh
#
# Prerequisites: Both containers must be running (./scripts/setup-local-env.sh)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env
if [ -f "$REPO_ROOT/.env" ]; then
    set -a; source "$REPO_ROOT/.env"; set +a
elif [ -f "$REPO_ROOT/.env.example" ]; then
    set -a; source "$REPO_ROOT/.env.example"; set +a
fi

SA_PASSWORD="${SA_PASSWORD:-Str0ngP@ssw0rd!}"
PG_PASSWORD="${PG_PASSWORD:-Str0ngP@ssw0rd!}"
PG_USER="${PG_USER:-wwi_user}"
PG_DB="${PG_DB:-wide_world_importers}"

# Helpers
sqlcmd_exec() {
    docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" -C -d WideWorldImporters \
        -W -h -1 "$@"
}

psql_exec() {
    docker exec wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -q "$@"
}

echo ""
echo "============================================="
echo "  SQL Server → PostgreSQL Data Migration"
echo "============================================="
echo ""

# ------------------------------------------------------------------
# Step 1: Verify containers
# ------------------------------------------------------------------
echo "[1/5] Checking containers..."

if ! docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" -b &>/dev/null; then
    echo "  ERROR: SQL Server is not reachable. Run setup-local-env first."
    exit 1
fi
echo "  SQL Server: OK"

if ! docker exec wwi-postgres pg_isready -U "$PG_USER" -d "$PG_DB" &>/dev/null; then
    echo "  ERROR: PostgreSQL is not reachable. Run setup-local-env first."
    exit 1
fi
echo "  PostgreSQL: OK"

# ------------------------------------------------------------------
# Step 2: Create PostgreSQL tables
# ------------------------------------------------------------------
echo "[2/5] Creating PostgreSQL tables..."

docker exec -i wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -q \
    < "$REPO_ROOT/scripts/docker/postgres-create-tables.sql"

TABLE_COUNT=$(docker exec wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('application','purchasing','sales','warehouse') AND table_type='BASE TABLE'")
echo "  Created $TABLE_COUNT tables"

# ------------------------------------------------------------------
# Step 3: Export data from SQL Server via BCP
# ------------------------------------------------------------------
echo "[3/5] Exporting data from SQL Server..."

# Create export directory (mounted as /backup/export in sqlserver, /data/export in postgres)
EXPORT_DIR="$REPO_ROOT/data/export"
mkdir -p "$EXPORT_DIR"

# Table mapping: MSSQL_Schema.MSSQL_Table → pg_schema.pg_table
# Format: "MSSQLSchema|MSSQLTable|pg_schema|pg_table|SELECT columns (excluding binary/computed)"
declare -a TABLES=(
    "Application|Cities|application|cities|CityID,CityName,StateProvinceID,CAST(Location AS NVARCHAR(MAX)),LatestRecordedPopulation,LastEditedBy,ValidFrom,ValidTo"
    "Application|Countries|application|countries|CountryID,CountryName,FormalName,IsoAlpha3Code,IsoNumericCode,CountryType,LatestRecordedPopulation,Continent,Region,Subregion,CAST(Border AS NVARCHAR(MAX)),LastEditedBy,ValidFrom,ValidTo"
    "Application|DeliveryMethods|application|delivery_methods|DeliveryMethodID,DeliveryMethodName,LastEditedBy,ValidFrom,ValidTo"
    "Application|PaymentMethods|application|payment_methods|PaymentMethodID,PaymentMethodName,LastEditedBy,ValidFrom,ValidTo"
    "Application|People|application|people|PersonID,FullName,PreferredName,SearchName,IsPermittedToLogon,LogonName,IsExternalLogonProvider,HashedPassword,IsSystemUser,IsEmployee,IsSalesperson,UserPreferences,PhoneNumber,FaxNumber,EmailAddress,Photo,CustomFields,OtherLanguages,LastEditedBy,ValidFrom,ValidTo"
    "Application|StateProvinces|application|state_provinces|StateProvinceID,StateProvinceCode,StateProvinceName,CountryID,SalesTerritory,CAST(Border AS NVARCHAR(MAX)),LatestRecordedPopulation,LastEditedBy,ValidFrom,ValidTo"
    "Application|SystemParameters|application|system_parameters|SystemParameterID,DeliveryAddressLine1,DeliveryAddressLine2,DeliveryCityID,DeliveryPostalCode,CAST(DeliveryLocation AS NVARCHAR(MAX)),PostalAddressLine1,PostalAddressLine2,PostalCityID,PostalPostalCode,REPLACE(REPLACE(REPLACE(ApplicationSettings,CHAR(9),' '),CHAR(13),''),CHAR(10),' '),LastEditedBy,LastEditedWhen"
    "Application|TransactionTypes|application|transaction_types|TransactionTypeID,TransactionTypeName,LastEditedBy,ValidFrom,ValidTo"
    "Purchasing|PurchaseOrderLines|purchasing|purchase_order_lines|PurchaseOrderLineID,PurchaseOrderID,StockItemID,OrderedOuters,Description,ReceivedOuters,PackageTypeID,ExpectedUnitPricePerOuter,LastReceiptDate,IsOrderLineFinalized,LastEditedBy,LastEditedWhen"
    "Purchasing|PurchaseOrders|purchasing|purchase_orders|PurchaseOrderID,SupplierID,OrderDate,DeliveryMethodID,ContactPersonID,ExpectedDeliveryDate,SupplierReference,IsOrderFinalized,Comments,InternalComments,LastEditedBy,LastEditedWhen"
    "Purchasing|SupplierCategories|purchasing|supplier_categories|SupplierCategoryID,SupplierCategoryName,LastEditedBy,ValidFrom,ValidTo"
    "Purchasing|Suppliers|purchasing|suppliers|SupplierID,SupplierName,SupplierCategoryID,PrimaryContactPersonID,AlternateContactPersonID,DeliveryMethodID,DeliveryCityID,PostalCityID,SupplierReference,BankAccountName,BankAccountBranch,BankAccountCode,BankAccountNumber,BankInternationalCode,PaymentDays,InternalComments,PhoneNumber,FaxNumber,WebsiteURL,DeliveryAddressLine1,DeliveryAddressLine2,DeliveryPostalCode,CAST(DeliveryLocation AS NVARCHAR(MAX)),PostalAddressLine1,PostalAddressLine2,PostalPostalCode,LastEditedBy,ValidFrom,ValidTo"
    "Purchasing|SupplierTransactions|purchasing|supplier_transactions|SupplierTransactionID,SupplierID,TransactionTypeID,PurchaseOrderID,PaymentMethodID,SupplierInvoiceNumber,TransactionDate,AmountExcludingTax,TaxAmount,TransactionAmount,OutstandingBalance,FinalizationDate,IsFinalized,LastEditedBy,LastEditedWhen"
    "Sales|BuyingGroups|sales|buying_groups|BuyingGroupID,BuyingGroupName,LastEditedBy,ValidFrom,ValidTo"
    "Sales|CustomerCategories|sales|customer_categories|CustomerCategoryID,CustomerCategoryName,LastEditedBy,ValidFrom,ValidTo"
    "Sales|Customers|sales|customers|CustomerID,CustomerName,BillToCustomerID,CustomerCategoryID,BuyingGroupID,PrimaryContactPersonID,AlternateContactPersonID,DeliveryMethodID,DeliveryCityID,PostalCityID,CreditLimit,AccountOpenedDate,StandardDiscountPercentage,IsStatementSent,IsOnCreditHold,PaymentDays,PhoneNumber,FaxNumber,DeliveryRun,RunPosition,WebsiteURL,DeliveryAddressLine1,DeliveryAddressLine2,DeliveryPostalCode,CAST(DeliveryLocation AS NVARCHAR(MAX)),PostalAddressLine1,PostalAddressLine2,PostalPostalCode,LastEditedBy,ValidFrom,ValidTo"
    "Sales|CustomerTransactions|sales|customer_transactions|CustomerTransactionID,CustomerID,TransactionTypeID,InvoiceID,PaymentMethodID,TransactionDate,AmountExcludingTax,TaxAmount,TransactionAmount,OutstandingBalance,FinalizationDate,IsFinalized,LastEditedBy,LastEditedWhen"
    "Sales|InvoiceLines|sales|invoice_lines|InvoiceLineID,InvoiceID,StockItemID,Description,PackageTypeID,Quantity,UnitPrice,TaxRate,TaxAmount,LineProfit,ExtendedPrice,LastEditedBy,LastEditedWhen"
    "Sales|Invoices|sales|invoices|InvoiceID,CustomerID,BillToCustomerID,OrderID,DeliveryMethodID,ContactPersonID,AccountsPersonID,SalespersonPersonID,PackedByPersonID,InvoiceDate,CustomerPurchaseOrderNumber,IsCreditNote,CreditNoteReason,Comments,DeliveryInstructions,InternalComments,TotalDryItems,TotalChillerItems,DeliveryRun,RunPosition,ReturnedDeliveryData,ConfirmedDeliveryTime,ConfirmedReceivedBy,LastEditedBy,LastEditedWhen"
    "Sales|OrderLines|sales|order_lines|OrderLineID,OrderID,StockItemID,Description,PackageTypeID,Quantity,UnitPrice,TaxRate,PickedQuantity,PickingCompletedWhen,LastEditedBy,LastEditedWhen"
    "Sales|Orders|sales|orders|OrderID,CustomerID,SalespersonPersonID,PickedByPersonID,ContactPersonID,BackorderOrderID,OrderDate,ExpectedDeliveryDate,CustomerPurchaseOrderNumber,IsUndersupplyBackordered,Comments,DeliveryInstructions,InternalComments,PickingCompletedWhen,LastEditedBy,LastEditedWhen"
    "Sales|SpecialDeals|sales|special_deals|SpecialDealID,StockItemID,CustomerID,BuyingGroupID,CustomerCategoryID,StockGroupID,DealDescription,StartDate,EndDate,DiscountAmount,DiscountPercentage,UnitPrice,LastEditedBy,LastEditedWhen"
    "Warehouse|ColdRoomTemperatures|warehouse|cold_room_temperatures|ColdRoomTemperatureID,ColdRoomSensorNumber,RecordedWhen,Temperature,ValidFrom,ValidTo"
    "Warehouse|Colors|warehouse|colors|ColorID,ColorName,LastEditedBy,ValidFrom,ValidTo"
    "Warehouse|PackageTypes|warehouse|package_types|PackageTypeID,PackageTypeName,LastEditedBy,ValidFrom,ValidTo"
    "Warehouse|StockGroups|warehouse|stock_groups|StockGroupID,StockGroupName,LastEditedBy,ValidFrom,ValidTo"
    "Warehouse|StockItemHoldings|warehouse|stock_item_holdings|StockItemID,QuantityOnHand,BinLocation,LastStocktakeQuantity,LastCostPrice,ReorderLevel,TargetStockLevel,LastEditedBy,LastEditedWhen"
    "Warehouse|StockItems|warehouse|stock_items|StockItemID,StockItemName,SupplierID,ColorID,UnitPackageID,OuterPackageID,Brand,Size,LeadTimeDays,QuantityPerOuter,IsChillerStock,Barcode,TaxRate,UnitPrice,RecommendedRetailPrice,TypicalWeightPerUnit,MarketingComments,InternalComments,NULL AS Photo,CustomFields,Tags,SearchDetails,LastEditedBy,ValidFrom,ValidTo"
    "Warehouse|StockItemStockGroups|warehouse|stock_item_stock_groups|StockItemStockGroupID,StockItemID,StockGroupID,LastEditedBy,LastEditedWhen"
    "Warehouse|StockItemTransactions|warehouse|stock_item_transactions|StockItemTransactionID,StockItemID,TransactionTypeID,CustomerID,InvoiceID,SupplierID,PurchaseOrderID,TransactionOccurredWhen,Quantity,LastEditedBy,LastEditedWhen"
    "Warehouse|VehicleTemperatures|warehouse|vehicle_temperatures|VehicleTemperatureID,VehicleRegistration,ChillerSensorNumber,RecordedWhen,Temperature,FullSensorData,IsCompressed,NULL AS CompressedSensorData"
)

TOTAL=${#TABLES[@]}
SUCCESS=0
FAILED=0
FAIL_LIST=""

for i in "${!TABLES[@]}"; do
    IFS='|' read -r MS_SCHEMA MS_TABLE PG_SCHEMA PG_TABLE COLUMNS <<< "${TABLES[$i]}"
    IDX=$((i + 1))
    LABEL="$PG_SCHEMA.$PG_TABLE"
    CSV_FILE="export/${MS_SCHEMA}_${MS_TABLE}.csv"

    printf "  [%2d/%d] %-45s" "$IDX" "$TOTAL" "$LABEL"

    # Export: sqlcmd SELECT → tab-delimited file in shared volume
    if docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" -C -d WideWorldImporters \
        -W -s"	" -h -1 -Q \
        "SET NOCOUNT ON; SELECT $COLUMNS FROM [$MS_SCHEMA].[$MS_TABLE]" \
        > "$EXPORT_DIR/${MS_SCHEMA}_${MS_TABLE}.csv" 2>/dev/null; then

        # Count exported rows
        ROW_COUNT=$(wc -l < "$EXPORT_DIR/${MS_SCHEMA}_${MS_TABLE}.csv" | tr -d '[:space:]')

        # Remove trailing blank lines (sqlcmd sometimes adds them)
        sed -i'' '/^[[:space:]]*$/d' "$EXPORT_DIR/${MS_SCHEMA}_${MS_TABLE}.csv" 2>/dev/null || \
        sed -i '' '/^[[:space:]]*$/d' "$EXPORT_DIR/${MS_SCHEMA}_${MS_TABLE}.csv" 2>/dev/null || true

        ROW_COUNT=$(wc -l < "$EXPORT_DIR/${MS_SCHEMA}_${MS_TABLE}.csv" | tr -d '[:space:]')

        # Import: COPY from file in shared volume (/data/export/...)
        if docker exec wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -q -c \
            "COPY $PG_SCHEMA.$PG_TABLE FROM '/data/$CSV_FILE' WITH (FORMAT text, DELIMITER E'\t', NULL 'NULL')" \
            2>/dev/null; then
            printf "%6s rows  ✓\n" "$ROW_COUNT"
            SUCCESS=$((SUCCESS + 1))
        else
            printf "%6s IMPORT FAILED  ✗\n" ""
            FAILED=$((FAILED + 1))
            FAIL_LIST="$FAIL_LIST  - $LABEL\n"
        fi
    else
        printf "%6s EXPORT FAILED  ✗\n" ""
        FAILED=$((FAILED + 1))
        FAIL_LIST="$FAIL_LIST  - $LABEL\n"
    fi
done

echo ""
echo "  Export/Import: $SUCCESS/$TOTAL succeeded, $FAILED failed"
if [ -n "$FAIL_LIST" ]; then
    echo -e "  Failed tables:\n$FAIL_LIST"
fi

# ------------------------------------------------------------------
# Step 4: Install PL/pgSQL functions
# ------------------------------------------------------------------
echo "[4/5] Installing PL/pgSQL functions..."

docker exec -i wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -q \
    < "$REPO_ROOT/scripts/docker/install-functions.sql"

FUNC_COUNT=$(docker exec wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema IN ('warehouse','sales','integration','sequences') AND routine_type='FUNCTION'")
echo "  Installed $FUNC_COUNT functions"

# ------------------------------------------------------------------
# Step 5: Validate row counts
# ------------------------------------------------------------------
echo "[5/5] Validating row counts..."

echo ""
printf "  %-45s %10s %10s %s\n" "Table" "SQL Server" "PostgreSQL" "Match"
printf "  %-45s %10s %10s %s\n" "-----" "----------" "----------" "-----"

MATCH=0
MISMATCH=0

for entry in "${TABLES[@]}"; do
    IFS='|' read -r MS_SCHEMA MS_TABLE PG_SCHEMA PG_TABLE _ <<< "$entry"

    MS_COUNT=$(sqlcmd_exec -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM [$MS_SCHEMA].[$MS_TABLE]" 2>/dev/null | tr -d '[:space:]')
    PG_COUNT=$(docker exec wwi-postgres psql -U "$PG_USER" -d "$PG_DB" -tAc \
        "SELECT COUNT(*) FROM $PG_SCHEMA.$PG_TABLE" 2>/dev/null | tr -d '[:space:]')

    if [ "$MS_COUNT" = "$PG_COUNT" ]; then
        STATUS="✓"
        MATCH=$((MATCH + 1))
    else
        STATUS="✗"
        MISMATCH=$((MISMATCH + 1))
    fi

    printf "  %-45s %10s %10s %s\n" "$PG_SCHEMA.$PG_TABLE" "$MS_COUNT" "$PG_COUNT" "$STATUS"
done

echo ""
echo "  Row count validation: $MATCH matched, $MISMATCH mismatched out of $TOTAL tables"

# ------------------------------------------------------------------
# Cleanup + Summary
# ------------------------------------------------------------------
rm -rf "$EXPORT_DIR"

echo ""
echo "============================================="
echo "  Migration Complete!"
echo "============================================="
echo ""
echo "  Tables created:    $TABLE_COUNT"
echo "  Data transferred:  $SUCCESS/$TOTAL tables"
echo "  Functions:         $FUNC_COUNT PL/pgSQL functions"
echo "  Row validation:    $MATCH/$TOTAL matched"
echo ""
echo "  Next steps:"
echo "    1. Run side-by-side queries to verify data"
echo "    2. Run: ./scripts/validate-migration.sh"
echo "    3. Or use Copilot: /db-migrate samples/wide-world-importers"
echo ""
