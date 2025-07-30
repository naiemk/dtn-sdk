#!/bin/bash

# DTN SDK Documentation Build Script
# This script builds the MkDocs documentation site

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if virtual environment exists
check_venv() {
    if [ -d ".venv" ]; then
        print_status "Virtual environment found at .venv"
        return 0
    else
        print_warning "Virtual environment not found at .venv"
        return 1
    fi
}

# Function to create virtual environment
create_venv() {
    print_status "Creating virtual environment..."
    python3 -m venv .venv
    print_success "Virtual environment created"
}

# Function to activate virtual environment
activate_venv() {
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
        print_status "Virtual environment activated"
    else
        print_error "Virtual environment activation script not found"
        exit 1
    fi
}

# Function to install dependencies
install_deps() {
    print_status "Installing MkDocs and dependencies..."
    pip install mkdocs mkdocs-material
    print_success "Dependencies installed"
}

# Function to check if mkdocs.yml exists
check_config() {
    if [ -f "docs/mkdocs.yml" ]; then
        print_status "MkDocs configuration found at docs/mkdocs.yml"
        return 0
    elif [ -f "mkdocs.yml" ]; then
        print_status "MkDocs configuration found at mkdocs.yml"
        return 0
    else
        print_error "MkDocs configuration file not found"
        print_error "Expected: docs/mkdocs.yml or mkdocs.yml"
        exit 1
    fi
}

# Function to build documentation
build_docs() {
    print_status "Building documentation..."
    
    # Determine config file location
    if [ -f "docs/mkdocs.yml" ]; then
        CONFIG_FILE="docs/mkdocs.yml"
        BUILD_DIR="docs/site"
    elif [ -f "mkdocs.yml" ]; then
        CONFIG_FILE="mkdocs.yml"
        BUILD_DIR="site"
    else
        print_error "No mkdocs.yml found"
        exit 1
    fi
    
    # Build the documentation
    if command_exists "mkdocs"; then
        mkdocs build -f "$CONFIG_FILE" --site-dir "$BUILD_DIR"
    elif [ -f ".venv/bin/mkdocs" ]; then
        .venv/bin/mkdocs build -f "$CONFIG_FILE" --site-dir "$BUILD_DIR"
    else
        print_error "MkDocs not found. Please install it first."
        exit 1
    fi
    
    print_success "Documentation built successfully"
    print_status "Build output: $BUILD_DIR"
}

# Function to serve documentation (optional)
serve_docs() {
    if [ "$1" = "--serve" ]; then
        print_status "Starting documentation server..."
        print_status "Documentation will be available at: http://127.0.0.1:8000"
        print_status "Press Ctrl+C to stop the server"
        
        if command_exists "mkdocs"; then
            mkdocs serve -f "$CONFIG_FILE"
        elif [ -f ".venv/bin/mkdocs" ]; then
            .venv/bin/mkdocs serve -f "$CONFIG_FILE"
        fi
    fi
}

# Main execution
main() {
    print_status "Starting DTN SDK documentation build..."
    
    # Check if we're in the right directory
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check for Python
    if ! command_exists "python3"; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check/create virtual environment
    if ! check_venv; then
        create_venv
    fi
    
    # Activate virtual environment
    activate_venv
    
    # Check if MkDocs is installed
    if ! command_exists "mkdocs" && [ ! -f ".venv/bin/mkdocs" ]; then
        install_deps
    fi
    
    # Check configuration
    check_config
    
    # Build documentation
    build_docs
    
    # Serve if requested
    serve_docs "$1"
    
    print_success "Documentation build completed successfully!"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "DTN SDK Documentation Build Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --serve, -s    Build and serve documentation locally"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0              Build documentation"
        echo "  $0 --serve      Build and serve documentation"
        echo "  $0 -s           Build and serve documentation"
        exit 0
        ;;
    --serve|-s)
        main "--serve"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_error "Use --help for usage information"
        exit 1
        ;;
esac 