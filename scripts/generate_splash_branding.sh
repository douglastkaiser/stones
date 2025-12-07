#!/bin/bash
# Generate the splash screen branding image with "Stones" text

set -e

OUTPUT_DIR="assets/splash"
OUTPUT_FILE="$OUTPUT_DIR/branding.png"

mkdir -p "$OUTPUT_DIR"

# Check if ImageMagick is available
if command -v convert &> /dev/null; then
    echo "Using ImageMagick to generate branding image..."
    convert -size 400x80 xc:transparent \
        -font DejaVu-Sans -pointsize 48 -fill white \
        -gravity center -annotate 0 "Stones" \
        "$OUTPUT_FILE"
    echo "Generated $OUTPUT_FILE"
else
    echo "ImageMagick not found, using pre-generated fallback..."
    # Base64-encoded PNG with "STONES" text (white on transparent, 400x80)
    base64 -d > "$OUTPUT_FILE" << 'ENDOFPNG'
iVBORw0KGgoAAAANSUhEUgAAAZAAAABQCAYAAAA3ICPMAAABt0lEQVR42u3cQRaEIAxEQe5/aT2E
Bjqhaj1vRA38nWsBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABfPMXS1vPXOqvXX72etP/3
3vesEwREQAREQEBAHCQC4r0LCALiIBEQ711AEBABERAQEAEREAGB5IPktvuaejCnrdO8gcEXEAER
EHDQui8BERABQUAEREAExD4CAREQAbGPwOALiIAICBh8AckMyKnfCwg4aAVEQAREQBAQ9yUgAiIg
ICACIiD2ERh8AREQAQGDLyACIiBwT1i6fOxNQM7+T5ePKdpHYPAFREAEBAREQAREQAQEAREQARGQ
AUFABERABERAQEAEREAEBPqGyHVnBKT7Ou0jMPgCYp32ERh81xUQB6fnAAIiIAIiIOAgdzALiICA
gAiIddpHYPAFREDsIzD4risgDk7PAQREQAREQMBBvmAWEAEBAREQ67SPwOALiIDYRwJC5mD6mGLm
cxa6PewjEBABERABAQEREAEREBAQAREQAREQBERABERABAQBERABERABAQAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAACAiV5wm48+U12t0wAAAABJRU5ErkJggg==
ENDOFPNG
    echo "Created fallback $OUTPUT_FILE"
fi
