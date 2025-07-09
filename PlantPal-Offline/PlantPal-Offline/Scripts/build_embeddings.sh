#!/bin/bash

#
# build_embeddings.sh
# PlantPal-Offline
#
# Created by Pulkit Midha on 07/07/24.
#

set -e

echo "🌱 Starting build-time embedding generation..."

# Check if we're in a build environment
if [ -z "$BUILT_PRODUCTS_DIR" ]; then
    echo "❌ This script should be run as part of Xcode build process"
    exit 1
fi

# Paths
SCRIPT_DIR="$PROJECT_DIR/BuildScripts"
EMBEDDINGS_SCRIPT="$SCRIPT_DIR/generate_embeddings.swift"
OUTPUT_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH"

echo "📁 Script directory: $SCRIPT_DIR"
echo "📁 Output directory: $OUTPUT_DIR"

# Check if the Swift script exists
if [ ! -f "$EMBEDDINGS_SCRIPT" ]; then
    echo "❌ Embedding generation script not found at: $EMBEDDINGS_SCRIPT"
    echo "💡 Make sure generate_embeddings.swift is in the Scripts folder"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if we have plant data
PLANT_DATA="$PROJECT_DIR/$PRODUCT_NAME/demo-data.json"
if [ ! -f "$PLANT_DATA" ]; then
    echo "❌ Plant data file not found at: $PLANT_DATA"
    exit 1
fi

# Check if we need to regenerate embeddings
EMBEDDINGS_FILE="$OUTPUT_DIR/plant_embeddings.json"
SHOULD_GENERATE=false

if [ ! -f "$EMBEDDINGS_FILE" ]; then
    echo "📝 Embeddings file doesn't exist, generating..."
    SHOULD_GENERATE=true
elif [ "$PLANT_DATA" -nt "$EMBEDDINGS_FILE" ]; then
    echo "📝 Plant data is newer than embeddings, regenerating..."
    SHOULD_GENERATE=true
elif [ "$EMBEDDINGS_SCRIPT" -nt "$EMBEDDINGS_FILE" ]; then
    echo "📝 Embedding script is newer than embeddings, regenerating..."
    SHOULD_GENERATE=true
else
    echo "✅ Embeddings are up to date, skipping generation"
    exit 0
fi

if [ "$SHOULD_GENERATE" = true ]; then
    echo "🔄 Generating embeddings..."
    
    # Execute the Swift script from the correct directory
    cd "$PROJECT_DIR"
    
    # Run the Swift embedding generation script
    if swift "$EMBEDDINGS_SCRIPT"; then
        echo "✅ Embeddings generated successfully"
        
        # Move the generated files to the bundle
        if [ -f "plant_embeddings.json" ]; then
            mv "plant_embeddings.json" "$OUTPUT_DIR/"
            echo "📦 Moved embeddings to bundle"
        fi
        
        if [ -f "embedding_metadata.json" ]; then
            mv "embedding_metadata.json" "$OUTPUT_DIR/"
            echo "📦 Moved metadata to bundle"
        fi
        
        # Calculate size savings
        EMBEDDING_SIZE=$(stat -f%z "$OUTPUT_DIR/plant_embeddings.json" 2>/dev/null || echo "0")
        IMAGES_DIR="$PROJECT_DIR/$PRODUCT_NAME/Assets.xcassets/demo-images"
        
        if [ -d "$IMAGES_DIR" ]; then
            IMAGE_SIZE=$(find "$IMAGES_DIR" -name "*.jpg" -o -name "*.png" | xargs stat -f%z | awk '{sum += $1} END {print sum}')
            SAVINGS=$((100 - (EMBEDDING_SIZE * 100 / IMAGE_SIZE)))
            echo "📊 Size comparison:"
            echo "   Images: $(echo $IMAGE_SIZE | awk '{printf "%.1fMB", $1/1024/1024}')"
            echo "   Embeddings: $(echo $EMBEDDING_SIZE | awk '{printf "%.1fKB", $1/1024}')"
            echo "   Savings: ${SAVINGS}%"
        fi
        
    else
        echo "❌ Embedding generation failed"
        exit 1
    fi
fi

echo "🎉 Build-time embedding generation complete!" 