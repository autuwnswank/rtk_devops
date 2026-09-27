#!/bin/bash

stop_all() {
    echo "Stopping jobs..."
    nomad job stop -purge nginx-vault-demo
    nomad job stop -purge nginx-frontend
    nomad job stop -purge nginx-backend
    nomad system gc
    echo "Done"
}

run_all() {
    echo "Running jobs..."
    nomad job run nginx-service1.nomad
    nomad job run nginx-service2.nomad
}

check_all() {
    echo "=== Nomad servers ==="
    nomad server members
    echo ""
    echo "=== Nomad nodes ==="
    nomad node status
    echo ""
    echo "=== Jobs ==="
    nomad job status
    echo ""
    echo "=== Allocs ==="
    nomad job status nginx-service1 2>/dev/null | grep -A10 "Allocations"
    nomad job status nginx-service2 2>/dev/null | grep -A10 "Allocations"
}

case "$1" in
    --stop)
        stop_all
        ;;
    --restart)
        stop_all
        run_all
        ;;
    --check)
        check_all
        ;;
    *)
        run_all
        ;;
esac
