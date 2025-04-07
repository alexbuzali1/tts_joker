#!/bin/bash

# Set paths
BUILD_DIR="./build"
TTS_LUA_DIR="/var/folders/3s/m9ny9p1s0_5c_3fh4w09jgw40000gn/T/TabletopSimulator/Tabletop Simulator Lua"

echo "🛠️ Building scripts..."
lua build.lua || { echo "❌ Build failed"; exit 1; }

echo "📁 Copying to TTS Lua workspace..."
cp "$BUILD_DIR"/*.lua "$TTS_LUA_DIR/" || { echo "❌ Copy failed"; exit 1; }

echo "✅ Done!"
echo "🧠 Switch to VS Code's TTS Lua Workspace and run 'Put Scripts'"