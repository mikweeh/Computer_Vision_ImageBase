#!/bin/bash
# Installation verification test for docker_cv_baseimage
# Run from the host: ssh Haddock "cd Projects/docker_cv_baseimage/repo && bash tests/test_installation.sh"

echo "════════════════════════════════════════════════════════════════"
echo "   DOCKER CV BASEIMAGE INSTALLATION VERIFICATION TEST"
echo "   (Python 3.11 + PyTorch + CUDA 12.4)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

section() {
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  $1"
    echo "────────────────────────────────────────────────────────────────"
}

# ============================================================================
section "1. CONTAINER STATUS"
# ============================================================================

if docker compose ps | grep -q "dev_service.*Up"; then
    pass "Container is running"
else
    # Try alternative match (container name varies)
    if docker compose ps | grep -q "dev.*running\|dev.*Up"; then
        pass "Container is running"
    else
        fail "Container is not running"
        info "Run: docker compose up -d"
        exit 1
    fi
fi

# ============================================================================
section "2. PYTHON ENVIRONMENT"
# ============================================================================

echo "Testing Python version..."
PY_VERSION=$(docker compose exec -T dev_service python --version 2>&1)
if echo "$PY_VERSION" | grep -q "3.11"; then
    pass "Python 3.11 detected: $PY_VERSION"
else
    fail "Python 3.11 not found: $PY_VERSION"
fi

# ============================================================================
section "3. PYTORCH AND CUDA"
# ============================================================================

echo "Testing PyTorch..."
TORCH_VERSION=$(docker compose exec -T dev_service python -c "import torch; print(torch.__version__)" 2>/dev/null)
if [ -n "$TORCH_VERSION" ]; then
    pass "PyTorch installed: $TORCH_VERSION"
else
    fail "PyTorch not found"
fi

echo ""
echo "Testing CUDA availability..."
CUDA_AVAILABLE=$(docker compose exec -T dev_service python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
if [ "$CUDA_AVAILABLE" = "True" ]; then
    pass "CUDA is available"
    GPU_NAME=$(docker compose exec -T dev_service python -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null)
    info "GPU: $GPU_NAME"
else
    fail "CUDA is NOT available"
fi

echo ""
echo "Testing nvidia-smi..."
if docker compose exec -T dev_service nvidia-smi --query-gpu=name --format=csv,noheader &>/dev/null; then
    GPU=$(docker compose exec -T dev_service nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
    pass "nvidia-smi accessible: $GPU"
else
    fail "nvidia-smi not accessible"
fi

# ============================================================================
section "4. KEY PYTHON LIBRARIES"
# ============================================================================

echo "Testing library imports..."
docker compose exec -T dev_service python -c "import cv2" 2>/dev/null && pass "OpenCV installed" || fail "OpenCV not found"
docker compose exec -T dev_service python -c "import matplotlib" 2>/dev/null && pass "Matplotlib installed" || fail "Matplotlib not found"
docker compose exec -T dev_service python -c "import numpy" 2>/dev/null && pass "NumPy installed" || fail "NumPy not found"
docker compose exec -T dev_service python -c "import pandas" 2>/dev/null && pass "Pandas installed" || fail "Pandas not found"
docker compose exec -T dev_service python -c "import sklearn" 2>/dev/null && pass "scikit-learn installed" || fail "scikit-learn not found"
docker compose exec -T dev_service python -c "import scipy" 2>/dev/null && pass "SciPy installed" || fail "SciPy not found"
docker compose exec -T dev_service python -c "import transformers" 2>/dev/null && pass "Transformers installed" || fail "Transformers not found"
docker compose exec -T dev_service python -c "import ultralytics" 2>/dev/null && pass "Ultralytics installed" || fail "Ultralytics not found"
docker compose exec -T dev_service python -c "import albumentations" 2>/dev/null && pass "Albumentations installed" || fail "Albumentations not found"
docker compose exec -T dev_service python -c "import tqdm" 2>/dev/null && pass "tqdm installed" || fail "tqdm not found"

# ============================================================================
section "5. JUPYTER KERNEL"
# ============================================================================

echo "Checking Jupyter kernel..."
KERNELS=$(docker compose exec -T dev_service jupyter kernelspec list 2>/dev/null)
if echo "$KERNELS" | grep -q "python3"; then
    pass "Jupyter Python 3 kernel installed"
else
    fail "Jupyter Python 3 kernel NOT found"
fi

# ============================================================================
section "6. WORKDIR AND WORKSPACE"
# ============================================================================

echo "Checking WORKDIR..."
PWD_OUTPUT=$(docker compose exec -T dev_service bash -c "pwd" 2>/dev/null | tr -d '\r')
if [ "$PWD_OUTPUT" = "/home/rosuser/repo_out" ]; then
    pass "WORKDIR is /home/rosuser/repo_out"
else
    fail "WORKDIR is '$PWD_OUTPUT', expected '/home/rosuser/repo_out'"
fi

echo ""
echo "Checking WORKSPACE env var..."
WS=$(docker compose exec -T dev_service bash -c "echo \$WORKSPACE" 2>/dev/null | tr -d '\r')
if [ "$WS" = "/home/rosuser/repo_out" ]; then
    pass "WORKSPACE set to /home/rosuser/repo_out"
else
    fail "WORKSPACE is '$WS', expected '/home/rosuser/repo_out'"
fi

# ============================================================================
section "7. MOUNT POINT DIRECTORIES"
# ============================================================================

echo "Checking pre-created mount point directories..."
if docker compose exec -T dev_service test -d /home/rosuser/repo_out; then
    pass "repo_out directory exists"
else
    fail "repo_out directory NOT found"
fi

if docker compose exec -T dev_service test -d /home/rosuser/catkin_ws/src/repo_ros; then
    pass "catkin_ws/src/repo_ros directory exists"
else
    fail "catkin_ws/src/repo_ros directory NOT found"
fi

if docker compose exec -T dev_service test -d /home/rosuser/dataset; then
    pass "dataset directory exists"
else
    fail "dataset directory NOT found"
fi

echo ""
echo "Checking no stale /home/rosuser/repo directory..."
if docker compose exec -T dev_service test -d /home/rosuser/repo 2>/dev/null; then
    fail "Stale /home/rosuser/repo directory still exists"
else
    pass "No stale /home/rosuser/repo directory"
fi

# ============================================================================
section "8. TEST CODE"
# ============================================================================

echo "Checking test code is accessible..."
if docker compose exec -T dev_service test -f /home/rosuser/repo_out/src/main.py; then
    pass "src/main.py exists at /home/rosuser/repo_out/src/main.py"
else
    fail "src/main.py NOT found at expected location"
fi

# ============================================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    TEST SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "  ${RED}Failed: $FAIL_COUNT${NC}"
echo ""
echo "Key success indicators:"
echo "  - Python 3.11 with PyTorch and CUDA working"
echo "  - All key libraries importable"
echo "  - WORKDIR is /home/rosuser/repo_out"
echo "  - Mount point directories (repo_out, catkin_ws/src/repo_ros, dataset) exist"
echo "  - No stale /home/rosuser/repo directory"
echo "  - Jupyter kernel installed"
echo ""
echo "════════════════════════════════════════════════════════════════"

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
