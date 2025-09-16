#!/bin/sh

echo "Checking for potentially vulnerable packages..."
echo "------------------------------------------------"

# Initialize counters
vulnerable_count=0
vulnerable_packages=""
error_count=0
error_packages=""

check_package() {
    package=$1
    vulnerable_version=$2
    
    echo "Package: $package"
    echo "Vulnerable version: $vulnerable_version"
    
    # Escape special characters in package name for grep/sed
    escaped_package=$(echo "$package" | sed 's/[[\.*^$()+?{|\/]/\\&/g' 2>&1)
    
    # Check if escaping failed
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Failed to process package name"
        error_count=$((error_count + 1))
        error_packages="${error_packages}  - $package (failed to process name)\n"
        echo "------------------------------------------------"
        return
    fi
    
    # Use npm ls to find installed versions
    npm_output=$(npm ls "$package" --all --depth=Infinity 2>&1)
    npm_exit_code=$?
    
    # Extract versions from npm output (use | as delimiter to avoid conflicts with / in package names)
    installed_versions=$(echo "$npm_output" | grep -E "($escaped_package@[^ ]+)" 2>&1 | sed -E "s|^.*($escaped_package@[^ ]+).*$|\1|" 2>&1 | sed "s|^$escaped_package@||" 2>&1 | sort -u 2>&1)
    
    # Check if any of the commands failed with actual errors (not just no matches)
    if [ $? -ne 0 ] && [ -n "$(echo "$npm_output" | grep -i error)" ]; then
        echo "❌ ERROR: Failed to check package"
        error_count=$((error_count + 1))
        error_packages="${error_packages}  - $package (check failed)\n"
        echo "------------------------------------------------"
        return
    fi
    
    if [ -z "$installed_versions" ]; then
        echo "Installed version: Not found"
    else
        echo "Installed version(s):"
        echo "$installed_versions" | sed 's/^/  - /'
        
        # Check if vulnerable version is installed
        if echo "$installed_versions" | grep -q "^$vulnerable_version$"; then
            echo "⚠️  VULNERABLE VERSION DETECTED!"
            vulnerable_count=$((vulnerable_count + 1))
            vulnerable_packages="${vulnerable_packages}  - $package@$vulnerable_version\n"
        fi
    fi
    
    echo "------------------------------------------------"
}

check_package "backslash" "0.2.1"
check_package "chalk" "5.6.1"
check_package "chalk-template" "1.1.1"
check_package "color-convert" "3.1.1"
check_package "color-name" "2.0.1"
check_package "color-string" "2.1.1"
check_package "@ctrl/tinycolor" "2.1.1"
check_package "wrap-ansi" "9.0.1"
check_package "supports-hyperlinks" "4.1.1"
check_package "strip-ansi" "7.1.1"
check_package "slice-ansi" "7.1.1"
check_package "simple-swizzle" "0.2.3"
check_package "is-arrayish" "0.3.3"
check_package "error-ex" "1.3.3"
check_package "ansi-regex" "6.2.1"
check_package "ansi-styles" "6.2.2"
check_package "supports-color" "10.2.1"
check_package "debug" "4.4.2"
check_package "debug" "4.2.2"
check_package "color" "5.0.1"
check_package "has-ansi" "6.0.1"

# Print summary
echo "\n🔍 VULNERABILITY SCAN SUMMARY"
echo "=================================================="

# Report vulnerabilities
if [ $vulnerable_count -eq 0 ]; then
    echo "✅ No vulnerable packages detected!"
else
    echo "⚠️  Found $vulnerable_count vulnerable package(s):"
    printf "$vulnerable_packages"
    echo "\nRecommendation: Add overrides to package.json to fix these vulnerabilities."
fi

# Report errors
if [ $error_count -gt 0 ]; then
    echo ""
    echo "❌ Encountered $error_count error(s) during scan:"
    printf "$error_packages"
    echo "\nNote: Some packages could not be checked properly."
fi

echo "=================================================="