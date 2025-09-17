#!/bin/sh

echo "📦 Checking for potentially vulnerable packages"
echo "------------------------------------------------"

# Try local text file first, fallback to remote
local_txt="vulnerable.txt"
remote_txt="https://raw.githubusercontent.com/pepo-fun/npm-security/refs/heads/main/vulnerable.txt"

if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in $(pwd)"
    echo "This script must be run from the root of a Node project so npm ls can inspect dependencies."
    [ -f "$temp_txt" ] && rm -f "$temp_txt"
    exit 1
fi

# Check if local text file exists
if [ -f "$local_txt" ]; then
    packages_file="$local_txt"
    echo "Using local vulnerable packages list: $local_txt"
else
    # Download remote text file to temp file
    temp_txt=$(mktemp)
    echo "Local file not found, downloading from remote..."
    if curl -s -o "$temp_txt" "$remote_txt"; then
        packages_file="$temp_txt"
        echo "Using remote vulnerable packages list"
    else
        echo "❌ Failed to download vulnerable packages list from $remote_txt"
        rm -f "$temp_txt"
        exit 1
    fi
fi


# Create temp directory for parallel job results
results_dir=$(mktemp -d)

# Cleanup function
cleanup() {
    # Kill spinner first if it exists
    if [ -n "$spinner_pid" ]; then
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
    fi

    # Kill all background jobs
    jobs -p | xargs -r kill 2>/dev/null

    # Remove temp directory
    rm -rf "$results_dir"

    # Remove temp file if it exists
    [ -f "$temp_txt" ] && rm -f "$temp_txt"

    printf "\n\n❌ Script interrupted by user\n"
    exit 130
}

# Set up trap for cleanup on exit or interrupt
trap cleanup EXIT INT TERM

# Create files for accumulating results
vuln_file="$results_dir/vulnerable"
error_file="$results_dir/errors"
progress_file="$results_dir/progress"
touch "$vuln_file" "$error_file" "$progress_file"

check_package() {
    package=$1
    vulnerable_version=$2
    output_file=$3

    {
        echo "PACKAGE_START"
        # Escape special characters in package name for grep/sed
        escaped_package=$(echo "$package" | sed 's/[[\.*^$()+?{|\/]/\\&/g' 2>&1)

        # Check if escaping failed
        if [ $? -ne 0 ]; then
            echo "\n🔍 $package@$vulnerable_version"
            echo "❌ ERROR: Failed to process package name"
            echo "$package (failed to process name)" >> "$error_file"
        else
            # Use npm ls to find installed versions
            npm_output=$(npm ls "$package" --all --depth=Infinity 2>&1)
            npm_exit_code=$?

            # Extract versions from npm output
            installed_versions=$(echo "$npm_output" | grep -E "($escaped_package@[^ ]+)" 2>&1 | sed -E "s|^.*($escaped_package@[^ ]+).*$|\1|" 2>&1 | sed "s|^$escaped_package@||" 2>&1 | sort -u 2>&1)

            # Check if any of the commands failed with actual errors
            if [ $? -ne 0 ] && [ -n "$(echo "$npm_output" | grep -i error)" ]; then
                echo "\n🔍 $package@$vulnerable_version"
                echo "❌ ERROR: Failed to check package"
                echo "$package (check failed)" >> "$error_file"
            elif [ -z "$installed_versions" ]; then
                # Package not found - don't output anything
                :
            else
                echo "\n🔍 $package@$vulnerable_version"
                # echo "Installed version(s):"
                # Check if vulnerable version is installed
                vulnerable_found=0
                while IFS= read -r version; do
                    if [ "$version" = "$vulnerable_version" ]; then
                        printf "  - \033[31m%s (VULNERABLE!)\033[0m\n" "$version"
                        vulnerable_found=1
                        echo "$package@$vulnerable_version" >> "$vuln_file"
                    else
                        printf "  - \033[32m%s (safe)\033[0m\n" "$version"
                    fi
                done <<< "$installed_versions"

                if [ $vulnerable_found -eq 1 ]; then
                    printf "\033[31m⚠️  VULNERABLE VERSION DETECTED!\033[0m\n"
                fi
            fi
        fi
        echo "PACKAGE_END"

        # Mark this package as completed
        echo "done" >> "$progress_file"
    } > "$output_file"
}

load_packages_from_text() {
    text_file=$1

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        case "$line" in
            \#*|"")
                continue
                ;;
        esac

        # Split on @ to get package and version
        if echo "$line" | grep -q '@'; then
            # Use sed to split since we can't rely on IFS with @ in package names
            package=$(echo "$line" | sed 's/@[^@]*$//')
            version=$(echo "$line" | sed 's/.*@//')

            if [ -n "$package" ] && [ -n "$version" ]; then
                echo "$package|$version"
            fi
        fi
    done < "$text_file"
}

if [ ! -f "$packages_file" ]; then
    echo "❌ Vulnerable package list not found at $packages_file"
    exit 1
fi

# Load packages from text file
text_entries=$(load_packages_from_text "$packages_file")

if [ -z "$text_entries" ]; then
    echo "❌ No package entries could be read from $packages_file"
    exit 1
fi

# Count total packages for progress display
total_packages=$(echo "$text_entries" | wc -l | tr -d ' ')
echo "Loaded $total_packages vulnerable package definitions from $packages_file"
echo ""

# Set max parallel jobs (adjust based on system capabilities)
max_parallel=20
job_id=0

# Start spinner/progress monitor in background
(
    while [ -d "$results_dir" ]; do
        if [ -f "$progress_file" ]; then
            completed=$(wc -l < "$progress_file" 2>/dev/null | tr -d ' ')
            if [ "$completed" -ge "$total_packages" ] 2>/dev/null; then
                break
            fi
            for s in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
                if [ ! -f "$progress_file" ]; then
                    break
                fi
                completed=$(wc -l < "$progress_file" 2>/dev/null | tr -d ' ')
                if [ "$completed" -ge "$total_packages" ] 2>/dev/null; then
                    break
                fi
                printf " [%s] Scanning packages... (%d/%d completed)\r" "$s" "$completed" "$total_packages"
                sleep 0.1
            done
        else
            break
        fi
    done
    printf "                                                            \r"
) &
spinner_pid=$!

# Function to wait for a job slot to be available
wait_for_job_slot() {
    while [ $(jobs -r | wc -l) -ge $max_parallel ]; do
        sleep 0.05
    done
}

# Process packages in parallel with controlled concurrency
while IFS='|' read -r pkg version; do
    if [ -n "$pkg" ] && [ -n "$version" ]; then
        wait_for_job_slot
        output_file="$results_dir/result_$job_id"
        check_package "$pkg" "$version" "$output_file" &
        ((job_id++))
    fi
done <<EOF
$text_entries
EOF

# Wait for all remaining jobs to complete
wait

# Stop spinner
if [ -n "$spinner_pid" ]; then
    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null
fi
printf "                                                            \r"

echo "✓ Scanning complete. Processing results..."
echo ""

# Display all output in order
for i in $(seq 0 $((job_id - 1))); do
    output_file="$results_dir/result_$i"
    if [ -f "$output_file" ]; then
        in_package=0
        while IFS= read -r line; do
            case "$line" in
                "PACKAGE_START")
                    in_package=1
                    ;;
                "PACKAGE_END")
                    in_package=0
                    ;;
                *)
                    if [ $in_package -eq 1 ]; then
                        echo "$line"
                    fi
                    ;;
            esac
        done < "$output_file"
    fi
done

# Count results
vulnerable_count=$(wc -l < "$vuln_file" | tr -d ' ')
error_count=$(wc -l < "$error_file" | tr -d ' ')

# Print summary
echo "\n------------------------------------------------\n"
echo "\n🔍 VULNERABILITY SCAN SUMMARY"
echo ""
echo "  📊 Checked $total_packages packages"
echo ""

# Report vulnerabilities
if [ $vulnerable_count -eq 0 ]; then
    echo "  ✅ No vulnerable packages detected!"
else
    echo "  ⚠️  Found $vulnerable_count vulnerable package(s):"
    while IFS= read -r vuln; do
        echo "  - $vuln"
    done < "$vuln_file"
    echo "\n  Recommendation: Add version number overrides to package.json to fix these vulnerabilities."
fi

# Report errors
if [ $error_count -gt 0 ]; then
    echo ""
    echo "  ❌ Encountered $error_count error(s) during scan:"
    while IFS= read -r err; do
        echo "  - $err"
    done < "$error_file"
    echo "\n  Note: Some packages could not be checked properly."
fi

echo ""
echo "📦 HARDENING CHECK"
echo ""

package_json="package.json"
min_release_present=0
if [ -f "$package_json" ]; then
    if grep -q '"minimumReleaseAge"' "$package_json" 2>/dev/null; then
        min_release_present=1
    fi
fi

manager_detected=0

if [ -f "yarn.lock" ] || [ -f ".yarnrc.yml" ] || [ -f ".yarn/berry" ] ||  [ -f "package-lock.json" ]; then
    manager_detected=1
    echo "  🚸 Recommendation: Use PNPM and add \"minimumReleaseAge\": 1440 under the config section of package.json."
fi

if [ -f "pnpm-lock.yaml" ]; then
    manager_detected=1
    if [ $min_release_present -eq 0 ]; then
        echo "  🚸 Recommendation: Add \"minimumReleaseAge\": 1440 under the pnpm section of package.json."
    else
        echo "  ✅ minimumReleaseAge already configured in package.json."
    fi
fi

if [ $manager_detected -eq 0 ]; then
    echo "No lockfiles detected in this directory."
fi

echo ""

# Clear trap on normal exit
trap - EXIT INT TERM

# Clean up temp file if it was used
[ -f "$temp_txt" ] && rm -f "$temp_txt"

# Clean up results directory
rm -rf "$results_dir"