#!/bin/bash

# BluejayLinux - Package Building & Creation System
# Professional build tools and package management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
BUILD_CONFIG_DIR="$CONFIG_DIR/package-builder"
PROJECTS_DIR="$BUILD_CONFIG_DIR/projects"
BUILD_DIR="/tmp/bluejay-builds"
PACKAGES_DIR="$BUILD_CONFIG_DIR/packages"

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Package formats and build systems
PACKAGE_FORMATS="deb rpm tar.xz appimage flatpak snap"
BUILD_SYSTEMS="make cmake autotools meson ninja npm yarn cargo go"
LANGUAGES="c cpp python javascript typescript rust go java kotlin"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$BUILD_CONFIG_DIR" "$PROJECTS_DIR" "$BUILD_DIR" "$PACKAGES_DIR"
    
    # Create default build configuration
    if [ ! -f "$BUILD_CONFIG_DIR/settings.conf" ]; then
        cat > "$BUILD_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Package Builder Settings
DEFAULT_PACKAGE_FORMAT=deb
BUILD_ARCHITECTURE=amd64
BUILD_PARALLEL_JOBS=auto
ENABLE_DEBUG_SYMBOLS=true
STRIP_BINARIES=false
COMPRESS_PACKAGES=true
SIGN_PACKAGES=false
GPG_KEY_ID=""
BUILD_DEPENDENCIES_AUTO=true
CLEAN_BUILD_DIR=true
ENABLE_TESTS=true
ENABLE_LINTING=true
ENABLE_STATIC_ANALYSIS=false
BUILD_TIMEOUT=3600
PACKAGE_MAINTAINER=""
PACKAGE_HOMEPAGE=""
DEFAULT_LICENSE=GPL-3.0
ENABLE_DOCUMENTATION=true
GENERATE_CHANGELOG=true
VERSION_AUTO_INCREMENT=true
CROSS_COMPILE_SUPPORT=false
CONTAINERIZED_BUILDS=false
CACHE_DEPENDENCIES=true
EOF
    fi
    
    # Create build tools database
    touch "$BUILD_CONFIG_DIR/build_tools.db"
    
    # Initialize projects database
    touch "$PROJECTS_DIR/projects.db"
}

# Load settings
load_settings() {
    if [ -f "$BUILD_CONFIG_DIR/settings.conf" ]; then
        source "$BUILD_CONFIG_DIR/settings.conf"
    fi
}

# Detect build tools and dependencies
detect_build_tools() {
    echo -e "${BLUE}Detecting build tools...${NC}"
    
    local build_tools=()
    local missing_tools=()
    
    # Essential build tools
    local essential_tools="gcc g++ make cmake autotools-dev pkg-config"
    for tool in $essential_tools; do
        case "$tool" in
            gcc)
                if command -v gcc >/dev/null; then
                    local gcc_version=$(gcc --version | head -1 | cut -d' ' -f4)
                    build_tools+=("gcc:$gcc_version")
                    echo -e "${GREEN}✓${NC} GCC: $gcc_version"
                else
                    missing_tools+=("gcc")
                fi
                ;;
            g++)
                if command -v g++ >/dev/null; then
                    local gpp_version=$(g++ --version | head -1 | cut -d' ' -f4)
                    build_tools+=("g++:$gpp_version")
                    echo -e "${GREEN}✓${NC} G++: $gpp_version"
                else
                    missing_tools+=("g++")
                fi
                ;;
            make)
                if command -v make >/dev/null; then
                    local make_version=$(make --version | head -1 | cut -d' ' -f3)
                    build_tools+=("make:$make_version")
                    echo -e "${GREEN}✓${NC} Make: $make_version"
                else
                    missing_tools+=("make")
                fi
                ;;
            cmake)
                if command -v cmake >/dev/null; then
                    local cmake_version=$(cmake --version | head -1 | cut -d' ' -f3)
                    build_tools+=("cmake:$cmake_version")
                    echo -e "${GREEN}✓${NC} CMake: $cmake_version"
                else
                    missing_tools+=("cmake")
                fi
                ;;
        esac
    done
    
    # Language-specific tools
    echo -e "\n${CYAN}Language Tools:${NC}"
    
    # Python
    if command -v python3 >/dev/null; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        build_tools+=("python3:$python_version")
        echo -e "${GREEN}✓${NC} Python: $python_version"
        
        # pip
        if command -v pip3 >/dev/null; then
            build_tools+=("pip3:$(pip3 --version | cut -d' ' -f2)")
            echo -e "${GREEN}✓${NC} pip3 available"
        fi
    fi
    
    # Node.js
    if command -v node >/dev/null; then
        local node_version=$(node --version)
        build_tools+=("node:$node_version")
        echo -e "${GREEN}✓${NC} Node.js: $node_version"
        
        # npm
        if command -v npm >/dev/null; then
            build_tools+=("npm:$(npm --version)")
            echo -e "${GREEN}✓${NC} npm available"
        fi
        
        # yarn
        if command -v yarn >/dev/null; then
            build_tools+=("yarn:$(yarn --version)")
            echo -e "${GREEN}✓${NC} Yarn available"
        fi
    fi
    
    # Rust
    if command -v rustc >/dev/null; then
        local rust_version=$(rustc --version | cut -d' ' -f2)
        build_tools+=("rustc:$rust_version")
        echo -e "${GREEN}✓${NC} Rust: $rust_version"
        
        if command -v cargo >/dev/null; then
            build_tools+=("cargo:$(cargo --version | cut -d' ' -f2)")
            echo -e "${GREEN}✓${NC} Cargo available"
        fi
    fi
    
    # Go
    if command -v go >/dev/null; then
        local go_version=$(go version | cut -d' ' -f3)
        build_tools+=("go:$go_version")
        echo -e "${GREEN}✓${NC} Go: $go_version"
    fi
    
    # Package building tools
    echo -e "\n${CYAN}Package Tools:${NC}"
    
    if command -v dpkg-deb >/dev/null; then
        build_tools+=("dpkg-deb:available")
        echo -e "${GREEN}✓${NC} dpkg-deb (Debian packages)"
    fi
    
    if command -v rpmbuild >/dev/null; then
        build_tools+=("rpmbuild:available")
        echo -e "${GREEN}✓${NC} rpmbuild (RPM packages)"
    fi
    
    if command -v flatpak-builder >/dev/null; then
        build_tools+=("flatpak-builder:available")
        echo -e "${GREEN}✓${NC} flatpak-builder"
    fi
    
    if command -v snapcraft >/dev/null; then
        build_tools+=("snapcraft:available")
        echo -e "${GREEN}✓${NC} snapcraft"
    fi
    
    # Show missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Missing essential tools:${NC} ${missing_tools[*]}"
        echo -e "${CYAN}Install with: sudo apt install build-essential cmake${NC}"
    fi
    
    echo "${build_tools[@]}"
}

# Create new project
create_project() {
    local project_name="$1"
    local project_type="$2"
    local language="$3"
    
    if [ -z "$project_name" ]; then
        echo -ne "${CYAN}Enter project name:${NC} "
        read -r project_name
    fi
    
    if [ -z "$project_type" ]; then
        echo -e "${CYAN}Project types: application library daemon service${NC}"
        echo -ne "${CYAN}Enter project type (application):${NC} "
        read -r project_type
        project_type="${project_type:-application}"
    fi
    
    if [ -z "$language" ]; then
        echo -e "${CYAN}Languages: c cpp python javascript rust go${NC}"
        echo -ne "${CYAN}Enter language (c):${NC} "
        read -r language
        language="${language:-c}"
    fi
    
    local project_dir="$PROJECTS_DIR/$project_name"
    
    if [ -d "$project_dir" ]; then
        echo -e "${RED}✗${NC} Project already exists: $project_name"
        return 1
    fi
    
    echo -e "${BLUE}Creating project: $project_name${NC}"
    echo -e "${CYAN}Type: $project_type${NC}"
    echo -e "${CYAN}Language: $language${NC}"
    
    mkdir -p "$project_dir"/{src,include,tests,docs,build,dist}
    
    # Create project configuration
    cat > "$project_dir/bluejay-project.conf" << EOF
# BluejayLinux Project Configuration
PROJECT_NAME=$project_name
PROJECT_TYPE=$project_type
LANGUAGE=$language
VERSION=1.0.0
DESCRIPTION=""
AUTHOR=""
LICENSE=$DEFAULT_LICENSE
HOMEPAGE=$PACKAGE_HOMEPAGE
BUILD_SYSTEM=make
DEPENDENCIES=""
BUILD_FLAGS=""
INSTALL_PREFIX=/usr/local
PACKAGE_FORMAT=$DEFAULT_PACKAGE_FORMAT
CREATED=$(date +%s)
EOF
    
    # Create language-specific files
    case "$language" in
        c)
            create_c_project "$project_dir" "$project_name"
            ;;
        cpp)
            create_cpp_project "$project_dir" "$project_name"
            ;;
        python)
            create_python_project "$project_dir" "$project_name"
            ;;
        javascript)
            create_javascript_project "$project_dir" "$project_name"
            ;;
        rust)
            create_rust_project "$project_dir" "$project_name"
            ;;
        go)
            create_go_project "$project_dir" "$project_name"
            ;;
    esac
    
    # Save to projects database
    echo "$project_name|$project_dir|$project_type|$language|$(date +%s)" >> "$PROJECTS_DIR/projects.db"
    
    echo -e "${GREEN}✓${NC} Project created: $project_dir"
}

# Create C project template
create_c_project() {
    local project_dir="$1"
    local project_name="$2"
    
    # Main source file
    cat > "$project_dir/src/main.c" << EOF
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    printf("Hello from $project_name!\n");
    return 0;
}
EOF
    
    # Makefile
    cat > "$project_dir/Makefile" << EOF
# Makefile for $project_name

CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2
LDFLAGS = 
SRCDIR = src
BUILDDIR = build
SOURCES = \$(wildcard \$(SRCDIR)/*.c)
OBJECTS = \$(SOURCES:\$(SRCDIR)/%.c=\$(BUILDDIR)/%.o)
TARGET = $project_name

.PHONY: all clean install uninstall test

all: \$(TARGET)

\$(TARGET): \$(OBJECTS)
	\$(CC) \$(OBJECTS) -o \$@ \$(LDFLAGS)

\$(BUILDDIR)/%.o: \$(SRCDIR)/%.c
	@mkdir -p \$(BUILDDIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

clean:
	rm -rf \$(BUILDDIR) \$(TARGET)

install: \$(TARGET)
	install -D \$(TARGET) \$(DESTDIR)/usr/local/bin/\$(TARGET)

uninstall:
	rm -f \$(DESTDIR)/usr/local/bin/\$(TARGET)

test:
	@echo "Running tests..."
	@echo "No tests defined yet"

.PHONY: package
package: \$(TARGET)
	@echo "Creating package..."
	mkdir -p dist
	tar -czf dist/\$(TARGET)-1.0.0.tar.gz \$(TARGET) README.md
EOF
    
    # README
    cat > "$project_dir/README.md" << EOF
# $project_name

A C application created with BluejayLinux Package Builder.

## Building

\`\`\`bash
make
\`\`\`

## Installing

\`\`\`bash
make install
\`\`\`

## Usage

\`\`\`bash
./$project_name
\`\`\`
EOF
}

# Create Python project template
create_python_project() {
    local project_dir="$1"
    local project_name="$2"
    
    # Main Python file
    cat > "$project_dir/src/__init__.py" << EOF
"""$project_name - A Python application"""

__version__ = "1.0.0"
__author__ = ""
EOF
    
    cat > "$project_dir/src/main.py" << EOF
#!/usr/bin/env python3
"""Main module for $project_name"""

import sys
import argparse

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='$project_name')
    parser.add_argument('--version', action='version', version='1.0.0')
    args = parser.parse_args()
    
    print(f"Hello from $project_name!")
    return 0

if __name__ == '__main__':
    sys.exit(main())
EOF
    
    # setup.py
    cat > "$project_dir/setup.py" << EOF
#!/usr/bin/env python3
"""Setup script for $project_name"""

from setuptools import setup, find_packages

setup(
    name='$project_name',
    version='1.0.0',
    description='A Python application',
    author='',
    author_email='',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    python_requires='>=3.6',
    install_requires=[
        # Add dependencies here
    ],
    entry_points={
        'console_scripts': [
            '$project_name = main:main',
        ],
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: End Users/Desktop',
        'License :: OSI Approved :: GNU General Public License v3 (GPLv3)',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
    ],
)
EOF
    
    # requirements.txt
    touch "$project_dir/requirements.txt"
    
    # Makefile for Python
    cat > "$project_dir/Makefile" << EOF
# Makefile for $project_name (Python)

PYTHON = python3
PIP = pip3

.PHONY: all install clean test lint package

all: install

install:
	\$(PIP) install -e .

clean:
	rm -rf build/ dist/ *.egg-info/
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete

test:
	\$(PYTHON) -m pytest tests/

lint:
	\$(PYTHON) -m flake8 src/
	\$(PYTHON) -m pylint src/

package:
	\$(PYTHON) setup.py sdist bdist_wheel
EOF
}

# Build project
build_project() {
    local project_path="$1"
    local build_type="${2:-release}"
    local clean_build="${3:-false}"
    
    if [ -z "$project_path" ]; then
        echo -ne "${CYAN}Enter project path:${NC} "
        read -r project_path
    fi
    
    if [ ! -d "$project_path" ]; then
        echo -e "${RED}✗${NC} Project directory not found: $project_path"
        return 1
    fi
    
    if [ ! -f "$project_path/bluejay-project.conf" ]; then
        echo -e "${RED}✗${NC} Not a BluejayLinux project (missing bluejay-project.conf)"
        return 1
    fi
    
    echo -e "${BLUE}Building project: $(basename "$project_path")${NC}"
    cd "$project_path" || return 1
    
    # Load project configuration
    source "./bluejay-project.conf"
    
    echo -e "${CYAN}Language: $LANGUAGE${NC}"
    echo -e "${CYAN}Build type: $build_type${NC}"
    
    # Clean build if requested
    if [ "$clean_build" = "true" ] || [ "$CLEAN_BUILD_DIR" = "true" ]; then
        echo -e "${CYAN}Cleaning build directory...${NC}"
        make clean 2>/dev/null || true
        rm -rf build/ dist/ 2>/dev/null || true
    fi
    
    # Set parallel jobs
    local jobs="$BUILD_PARALLEL_JOBS"
    if [ "$jobs" = "auto" ]; then
        jobs=$(nproc)
    fi
    
    # Build based on build system
    local build_success=false
    
    if [ -f "Makefile" ]; then
        echo -e "${CYAN}Building with Make...${NC}"
        if make -j"$jobs"; then
            build_success=true
        fi
    elif [ -f "CMakeLists.txt" ]; then
        echo -e "${CYAN}Building with CMake...${NC}"
        mkdir -p build
        cd build || return 1
        if cmake .. && make -j"$jobs"; then
            build_success=true
        fi
        cd ..
    elif [ -f "setup.py" ] && [ "$LANGUAGE" = "python" ]; then
        echo -e "${CYAN}Building Python project...${NC}"
        if python3 setup.py build; then
            build_success=true
        fi
    elif [ -f "package.json" ] && [ "$LANGUAGE" = "javascript" ]; then
        echo -e "${CYAN}Building Node.js project...${NC}"
        if npm install && npm run build; then
            build_success=true
        fi
    elif [ -f "Cargo.toml" ] && [ "$LANGUAGE" = "rust" ]; then
        echo -e "${CYAN}Building Rust project...${NC}"
        local cargo_flags=""
        if [ "$build_type" = "release" ]; then
            cargo_flags="--release"
        fi
        if cargo build $cargo_flags; then
            build_success=true
        fi
    elif [ -f "go.mod" ] && [ "$LANGUAGE" = "go" ]; then
        echo -e "${CYAN}Building Go project...${NC}"
        if go build; then
            build_success=true
        fi
    else
        echo -e "${RED}✗${NC} No supported build system found"
        return 1
    fi
    
    if [ "$build_success" = true ]; then
        echo -e "${GREEN}✓${NC} Build completed successfully"
        
        # Run tests if enabled
        if [ "$ENABLE_TESTS" = "true" ]; then
            echo -e "${CYAN}Running tests...${NC}"
            make test 2>/dev/null || python3 -m pytest tests/ 2>/dev/null || npm test 2>/dev/null || cargo test 2>/dev/null || echo "No tests found"
        fi
        
        return 0
    else
        echo -e "${RED}✗${NC} Build failed"
        return 1
    fi
}

# Create package
create_package() {
    local project_path="$1"
    local package_format="${2:-$DEFAULT_PACKAGE_FORMAT}"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${RED}✗${NC} Project directory not found: $project_path"
        return 1
    fi
    
    cd "$project_path" || return 1
    source "./bluejay-project.conf"
    
    echo -e "${BLUE}Creating $package_format package for: $PROJECT_NAME${NC}"
    
    local package_name="${PROJECT_NAME}_${VERSION}_${BUILD_ARCHITECTURE}"
    local package_dir="$BUILD_DIR/${package_name}"
    
    # Clean and create package directory
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    
    case "$package_format" in
        deb)
            create_deb_package "$package_dir" "$project_path"
            ;;
        rpm)
            create_rpm_package "$package_dir" "$project_path"
            ;;
        tar.xz)
            create_tar_package "$package_dir" "$project_path"
            ;;
        appimage)
            create_appimage_package "$package_dir" "$project_path"
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported package format: $package_format"
            return 1
            ;;
    esac
}

# Create Debian package
create_deb_package() {
    local package_dir="$1"
    local project_path="$2"
    
    echo -e "${CYAN}Creating Debian package...${NC}"
    
    # Create package structure
    mkdir -p "$package_dir/DEBIAN"
    mkdir -p "$package_dir/usr/local/bin"
    mkdir -p "$package_dir/usr/share/doc/$PROJECT_NAME"
    
    # Copy binary/files
    if [ -f "$PROJECT_NAME" ]; then
        cp "$PROJECT_NAME" "$package_dir/usr/local/bin/"
        chmod +x "$package_dir/usr/local/bin/$PROJECT_NAME"
    elif [ -f "build/$PROJECT_NAME" ]; then
        cp "build/$PROJECT_NAME" "$package_dir/usr/local/bin/"
        chmod +x "$package_dir/usr/local/bin/$PROJECT_NAME"
    fi
    
    # Copy documentation
    [ -f "README.md" ] && cp "README.md" "$package_dir/usr/share/doc/$PROJECT_NAME/"
    [ -f "LICENSE" ] && cp "LICENSE" "$package_dir/usr/share/doc/$PROJECT_NAME/"
    
    # Create control file
    cat > "$package_dir/DEBIAN/control" << EOF
Package: $PROJECT_NAME
Version: $VERSION
Section: misc
Priority: optional
Architecture: $BUILD_ARCHITECTURE
Maintainer: ${PACKAGE_MAINTAINER:-"Unknown <unknown@bluejaylinux.local>"}
Description: $DESCRIPTION
 ${DESCRIPTION:-"Package created with BluejayLinux Package Builder"}
Homepage: ${HOMEPAGE:-""}
EOF
    
    # Create postinst script if needed
    if [ "$PROJECT_TYPE" = "daemon" ] || [ "$PROJECT_TYPE" = "service" ]; then
        cat > "$package_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "configure" ]; then
    # Enable and start service if systemd is available
    if command -v systemctl >/dev/null; then
        systemctl daemon-reload
        systemctl enable $PROJECT_NAME.service
        systemctl start $PROJECT_NAME.service
    fi
fi
EOF
        chmod +x "$package_dir/DEBIAN/postinst"
    fi
    
    # Build package
    local deb_file="$PACKAGES_DIR/${PROJECT_NAME}_${VERSION}_${BUILD_ARCHITECTURE}.deb"
    if dpkg-deb --build "$package_dir" "$deb_file"; then
        echo -e "${GREEN}✓${NC} Debian package created: $deb_file"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to create Debian package"
        return 1
    fi
}

# Create tar package
create_tar_package() {
    local package_dir="$1"
    local project_path="$2"
    
    echo -e "${CYAN}Creating tar package...${NC}"
    
    # Create directory structure
    mkdir -p "$package_dir/bin"
    mkdir -p "$package_dir/docs"
    
    # Copy files
    if [ -f "$PROJECT_NAME" ]; then
        cp "$PROJECT_NAME" "$package_dir/bin/"
    elif [ -f "build/$PROJECT_NAME" ]; then
        cp "build/$PROJECT_NAME" "$package_dir/bin/"
    fi
    
    [ -f "README.md" ] && cp "README.md" "$package_dir/docs/"
    [ -f "LICENSE" ] && cp "LICENSE" "$package_dir/docs/"
    
    # Create install script
    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
# Installation script

echo "Installing $PROJECT_NAME..."
cp bin/* /usr/local/bin/
chmod +x /usr/local/bin/*
echo "Installation complete"
EOF
    chmod +x "$package_dir/install.sh"
    
    # Create archive
    local tar_file="$PACKAGES_DIR/${PROJECT_NAME}_${VERSION}.tar.xz"
    cd "$BUILD_DIR" || return 1
    
    if tar -cJf "$tar_file" "$(basename "$package_dir")"; then
        echo -e "${GREEN}✓${NC} Tar package created: $tar_file"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to create tar package"
        return 1
    fi
}

# List projects
list_projects() {
    echo -e "\n${BLUE}BluejayLinux Projects:${NC}"
    
    if [ ! -s "$PROJECTS_DIR/projects.db" ]; then
        echo -e "${YELLOW}No projects found${NC}"
        return
    fi
    
    local count=1
    while IFS='|' read -r name path type language created; do
        local date_created=$(date -d "@$created" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        
        echo -e "${WHITE}$count.${NC} $name"
        echo -e "   ${CYAN}Type:${NC} $type"
        echo -e "   ${CYAN}Language:${NC} $language"
        echo -e "   ${CYAN}Path:${NC} $path"
        echo -e "   ${CYAN}Created:${NC} $date_created"
        
        # Check if project directory exists
        if [ -d "$path" ]; then
            if [ -f "$path/bluejay-project.conf" ]; then
                # Load project config to get version
                local version=$(grep "^VERSION=" "$path/bluejay-project.conf" | cut -d'=' -f2)
                echo -e "   ${CYAN}Version:${NC} $version"
            fi
        else
            echo -e "   ${RED}Directory not found${NC}"
        fi
        
        echo
        ((count++))
    done < "$PROJECTS_DIR/projects.db"
}

# Install build dependencies
install_build_dependencies() {
    echo -e "${BLUE}Installing build dependencies...${NC}"
    
    local essential_packages="build-essential cmake pkg-config git"
    local python_packages="python3-dev python3-pip python3-setuptools"
    local node_packages="nodejs npm"
    local rust_packages=""  # Rust is typically installed via rustup
    local debian_packages="dpkg-dev debhelper"
    
    echo -e "${CYAN}Essential build tools...${NC}"
    if sudo apt update && sudo apt install -y $essential_packages; then
        echo -e "${GREEN}✓${NC} Essential tools installed"
    fi
    
    echo -e "${CYAN}Python development tools...${NC}"
    if sudo apt install -y $python_packages; then
        echo -e "${GREEN}✓${NC} Python tools installed"
    fi
    
    echo -e "${CYAN}Node.js development tools...${NC}"
    if sudo apt install -y $node_packages; then
        echo -e "${GREEN}✓${NC} Node.js tools installed"
    fi
    
    echo -e "${CYAN}Package building tools...${NC}"
    if sudo apt install -y $debian_packages; then
        echo -e "${GREEN}✓${NC} Debian packaging tools installed"
    fi
    
    # Offer to install Rust
    if ! command -v rustc >/dev/null; then
        echo -ne "${CYAN}Install Rust toolchain? (y/N):${NC} "
        read -r install_rust
        if [ "$install_rust" = "y" ] || [ "$install_rust" = "Y" ]; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
            source "$HOME/.cargo/env"
            echo -e "${GREEN}✓${NC} Rust installed"
        fi
    fi
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                ${WHITE}BluejayLinux Package Builder${PURPLE}                     ║${NC}"
    echo -e "${PURPLE}║              ${CYAN}Professional Build Tools & Packaging${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local build_tools=($(detect_build_tools))
    echo -e "${WHITE}Build tools available:${NC} ${#build_tools[@]}"
    echo
    
    echo -e "${WHITE}Project Management:${NC}"
    echo -e "${WHITE}1.${NC} Create new project"
    echo -e "${WHITE}2.${NC} List projects"
    echo -e "${WHITE}3.${NC} Build project"
    echo -e "${WHITE}4.${NC} Create package"
    echo
    echo -e "${WHITE}Build Environment:${NC}"
    echo -e "${WHITE}5.${NC} Install build dependencies"
    echo -e "${WHITE}6.${NC} Check build tools"
    echo
    echo -e "${WHITE}Package Management:${NC}"
    echo -e "${WHITE}7.${NC} List packages"
    echo -e "${WHITE}8.${NC} Install package"
    echo
    echo -e "${WHITE}Settings:${NC}"
    echo -e "${WHITE}9.${NC} Build settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --create)
                create_project "$2" "$3" "$4"
                ;;
            --build)
                build_project "$2" "$3" "$4"
                ;;
            --package)
                create_package "$2" "$3"
                ;;
            --list)
                list_projects
                ;;
            --install-deps)
                install_build_dependencies
                ;;
            --help|-h)
                echo "BluejayLinux Package Builder"
                echo "Usage: $0 [options] [parameters]"
                echo "  --create <name> [type] [lang]  Create new project"
                echo "  --build <path> [type] [clean]  Build project"
                echo "  --package <path> [format]      Create package"
                echo "  --list                         List projects"
                echo "  --install-deps                 Install build dependencies"
                ;;
        esac
        return
    fi
    
    # Interactive mode
    while true; do
        main_menu
        echo -ne "${YELLOW}Select option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                create_project
                ;;
            2)
                list_projects
                ;;
            3)
                list_projects
                echo -ne "\n${CYAN}Enter project path:${NC} "
                read -r project_path
                if [ -n "$project_path" ]; then
                    echo -ne "${CYAN}Build type (release/debug):${NC} "
                    read -r build_type
                    build_type="${build_type:-release}"
                    echo -ne "${CYAN}Clean build? (y/N):${NC} "
                    read -r clean_opt
                    local clean="false"
                    [ "$clean_opt" = "y" ] && clean="true"
                    build_project "$project_path" "$build_type" "$clean"
                fi
                ;;
            4)
                list_projects
                echo -ne "\n${CYAN}Enter project path:${NC} "
                read -r project_path
                if [ -n "$project_path" ]; then
                    echo -e "${CYAN}Package formats: deb rpm tar.xz appimage${NC}"
                    echo -ne "${CYAN}Package format ($DEFAULT_PACKAGE_FORMAT):${NC} "
                    read -r package_format
                    package_format="${package_format:-$DEFAULT_PACKAGE_FORMAT}"
                    create_package "$project_path" "$package_format"
                fi
                ;;
            5)
                install_build_dependencies
                ;;
            6)
                detect_build_tools
                ;;
            7)
                echo -e "\n${BLUE}Created Packages:${NC}"
                if [ -d "$PACKAGES_DIR" ] && [ "$(ls -A "$PACKAGES_DIR" 2>/dev/null)" ]; then
                    ls -la "$PACKAGES_DIR"
                else
                    echo -e "${YELLOW}No packages found${NC}"
                fi
                ;;
            8)
                if [ -d "$PACKAGES_DIR" ] && [ "$(ls -A "$PACKAGES_DIR" 2>/dev/null)" ]; then
                    echo -e "\n${BLUE}Available packages:${NC}"
                    ls "$PACKAGES_DIR"
                    echo -ne "\n${CYAN}Enter package name to install:${NC} "
                    read -r package_name
                    if [ -f "$PACKAGES_DIR/$package_name" ]; then
                        if [[ $package_name == *.deb ]]; then
                            sudo dpkg -i "$PACKAGES_DIR/$package_name"
                        elif [[ $package_name == *.tar.* ]]; then
                            echo "Extract and run install script manually"
                        fi
                    fi
                else
                    echo -e "${YELLOW}No packages available${NC}"
                fi
                ;;
            9)
                echo -e "\n${PURPLE}=== Build Settings ===${NC}"
                echo -e "${WHITE}Current settings from: $BUILD_CONFIG_DIR/settings.conf${NC}"
                echo -e "${CYAN}Edit this file to modify build settings${NC}"
                ;;
            q|Q)
                echo -e "${GREEN}Package Builder session saved${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
        echo -ne "${GRAY}Press Enter to continue...${NC}"
        read -r
        clear
    done
}

# Run main function
main "$@"