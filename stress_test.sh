#!/bin/bash

# === Configuration ===
GPU_BURN_DIR="./gpu-burn"
GPU_BURN_DURATION=60
CPU_DURATION=60
RAM_DURATION=60

# === Functions ===

function run_gpu_stress() {
    echo "[INFO] Running GPU stress test with gpu-burn for $GPU_BURN_DURATION seconds..."
    if [ ! -f "$GPU_BURN_DIR/gpu_burn" ]; then
        echo "[INFO] gpu_burn binary not found. Cloning and building..."
        git clone https://github.com/wilicc/gpu-burn.git "$GPU_BURN_DIR"
        cd "$GPU_BURN_DIR" || exit 1
        make || { echo "[ERROR] Failed to build gpu-burn"; exit 1; }
        cd - >/dev/null
    fi

    # Run the test from within the correct directory
    pushd "$GPU_BURN_DIR" >/dev/null
    ./gpu_burn "$GPU_BURN_DURATION"
    popd >/dev/null
}

function run_cpu_stress() {
    echo "[INFO] Running CPU stress test with stress-ng for $CPU_DURATION seconds..."
    stress-ng --cpu 0 --cpu-method matrixprod --verify --timeout "${CPU_DURATION}s" --metrics-brief
}

function run_ram_stress() {
    echo "[INFO] Running RAM stress test with stress-ng for $RAM_DURATION seconds..."
    stress-ng --vm 1 --vm-bytes 95% --timeout "${RAM_DURATION}s" --metrics-brief
}

# === Main Logic ===

case "$1" in
    gpu)
        run_gpu_stress
        ;;
    cpu)
        run_cpu_stress
        ;;
    ram)
        run_ram_stress
        ;;
    *)
        echo "[INFO] No valid argument provided. Running all stress tests in parallel for 60s..."
        run_gpu_stress &
        run_cpu_stress &
        run_ram_stress &
        wait
        ;;
esac
