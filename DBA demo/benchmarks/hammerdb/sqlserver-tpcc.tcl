#!/bin/bash
# HammerDB TPC-C benchmark for SQL Server (baseline)
# Usage: hammerdbcli auto sqlserver-tpcc.tcl

# Configure for WideWorldImporters workload simulation
# Adjust connection parameters for your environment

echo "HammerDB TPC-C Benchmark - SQL Server Baseline"
echo "================================================"
echo ""
echo "Parameters:"
echo "  Virtual Users: 50"
echo "  Ramp-up: 30 seconds"
echo "  Duration: 5 minutes"
echo "  Metrics: TPS, avg response time, 95th percentile"
echo ""
echo "Run with: hammerdbcli auto benchmarks/hammerdb/sqlserver-tpcc.tcl"
echo ""
echo "See HammerDB docs: https://www.hammerdb.com/docs/"
