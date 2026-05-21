#!/bin/bash
# HammerDB TPC-C benchmark for PostgreSQL (target)
# Usage: hammerdbcli auto postgres-tpcc.tcl

echo "HammerDB TPC-C Benchmark - PostgreSQL Target"
echo "=============================================="
echo ""
echo "Parameters:"
echo "  Virtual Users: 50"
echo "  Ramp-up: 30 seconds"
echo "  Duration: 5 minutes"
echo "  Metrics: TPS, avg response time, 95th percentile"
echo ""
echo "Run with: hammerdbcli auto benchmarks/hammerdb/postgres-tpcc.tcl"
echo ""
echo "Compare results with: benchmarks/hammerdb/sqlserver-tpcc.tcl"
echo "See HammerDB docs: https://www.hammerdb.com/docs/"
