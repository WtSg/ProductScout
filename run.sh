#\!/bin/bash

echo "🚀 Starting ProductScout (Swift Native App)"
echo "=============================================="

cd "$(dirname "$0")"
swift run --configuration release
