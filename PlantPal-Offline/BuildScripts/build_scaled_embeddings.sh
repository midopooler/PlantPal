#!/bin/bash

#
# build_scaled_embeddings.sh
# PlantPal-Offline
#
# Created by Pulkit Midha on 07/07/24.
#

set -e

# Configuration
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATASET_PATH="dataset/"
OUTPUT_DIR="$PROJECT_ROOT/PlantPal-Offline"

echo "🚀 PlantPal Scaled Embedding Generation"
echo "======================================="

# Check if dataset exists
if [ ! -d "$DATASET_PATH" ]; then
    echo "❌ Dataset directory not found: $DATASET_PATH"
    echo "📁 Please organize your 15,000 images into 47 plant folders in: $DATASET_PATH"
    echo ""
    echo "Expected structure:"
    echo "dataset/"
    echo "├── ZZ Plant (Zamioculcas zamiifolia)/"
    echo "│   ├── image001.jpg"
    echo "│   ├── image002.jpg"
    echo "│   └── ..."
    echo "├── Snake Plant (Sansevieria)/"
    echo "│   ├── image001.jpg"
    echo "│   └── ..."
    echo "└── ..."
    exit 1
fi

# Count total images
TOTAL_IMAGES=$(find "$DATASET_PATH" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.heic" -o -name "*.heif" \) | wc -l)
PLANT_FOLDERS=$(find "$DATASET_PATH" -type d -mindepth 1 -maxdepth 1 | wc -l)

echo "📊 Dataset Analysis:"
echo "• Plant folders: $PLANT_FOLDERS"
echo "• Total images: $TOTAL_IMAGES"
echo ""

if [ "$TOTAL_IMAGES" -lt 1000 ]; then
    echo "⚠️  Warning: Found only $TOTAL_IMAGES images. Expected ~15,000."
    echo "Continue anyway? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi

# Step 1: Generate representative embeddings
echo "🌱 Step 1: Generating representative embeddings..."
echo "⏱️  This may take 30-60 minutes for 15,000 images..."

chmod +x "$SCRIPT_DIR/generate_representative_embeddings.swift"

if swift "$SCRIPT_DIR/generate_representative_embeddings.swift"; then
    echo "✅ Representative embeddings generated successfully!"
else
    echo "❌ Failed to generate representative embeddings"
    exit 1
fi

# Step 2: Move output files to the correct location
echo ""
echo "📦 Step 2: Moving output files..."

if [ -f "plant_embeddings_representative.json" ]; then
    mv "plant_embeddings_representative.json" "$OUTPUT_DIR/"
    echo "✅ Moved representative embeddings to $OUTPUT_DIR/"
else
    echo "❌ Representative embeddings file not found"
    exit 1
fi

# Step 3: Generate file size report
echo ""
echo "📊 Step 3: Generating size report..."

REP_SIZE=$(stat -f%z "$OUTPUT_DIR/plant_embeddings_representative.json" 2>/dev/null || stat -c%s "$OUTPUT_DIR/plant_embeddings_representative.json" 2>/dev/null || echo "0")
REP_SIZE_KB=$((REP_SIZE / 1024))

echo ""
echo "🎉 Scaled Embedding Generation Complete!"
echo "========================================"
echo ""
echo "📊 Results:"
echo "• Representative embeddings: ${REP_SIZE_KB}KB"
echo "• Expected detailed embeddings: ~46MB (when generated)"
echo "• Total expected app size: ~57MB"
echo "• Size reduction: ~97% from original 15,000 images"
echo ""
echo "🚀 Next Steps:"
echo "1. Update BuildTimeEmbeddingLoader for multi-tier loading"
echo "2. Implement smart search algorithm"
echo "3. Add detailed embedding generation (optional)"
echo "4. Test with representative embeddings first"
echo ""
echo "📱 Integration:"
echo "• Add plant_embeddings_representative.json to Xcode project"
echo "• Update BuildTimeEmbeddingLoader to use new format"
echo "• Test app with representative embeddings"
echo ""

# Optional: Generate detailed embeddings (commented out for now)
echo "💡 Tip: Start with representative embeddings for testing."
echo "   Generate detailed embeddings later if needed for higher accuracy."
echo ""
echo "   To generate detailed embeddings (46MB):"
echo "   swift BuildScripts/generate_detailed_embeddings.swift"
echo "" 