#!/usr/bin/env bash
#
# Hermetic helper script to transform and duplicate files in a directory tree.
#
# This script is used by Bazel repository rules to create file transformations
# for cross-platform compatibility (case-insensitive Windows vs case-sensitive Unix).
#
# Usage:
#     bash transform_helper.sh <directory_path> [--transform <src>:<dst>]...
#
# Supports:
#     - Exact file duplication: --transform "include/file.h:include/copy.h"
#     - Pattern-based transforms: --transform "include/*.inl:include/*.h"
#     - Lowercase duplicates: --transform "include/*.h:lowercase"
#
# Requirements:
#     - POSIX utilities: find, cp, mv, mkdir, stat, basename, dirname

set -euo pipefail

# Global error counter
ERROR_COUNT=0

#
# Print error message to stderr
#
error() {
    echo "Error: $*" >&2
    ((ERROR_COUNT++)) || true
}

#
# Print warning message to stderr
#
warn() {
    echo "Warning: $*" >&2
}

#
# Check if a string contains glob pattern characters (*, ?, [)
#
has_glob_pattern() {
    local path="$1"
    [[ "$path" == *\** || "$path" == *\?* || "$path" == *\[* ]]
}

#
# Find files matching a glob pattern using find command
#
# Args:
#     $1: Root directory path
#     $2: Glob pattern (e.g., "include/*.inl" or "**/*.h")
#
# Returns:
#     List of matching file paths relative to root (one per line)
#
find_files_by_pattern() {
    local root="$1"
    local pattern="$2"

    # Parse the pattern to extract directory and filename parts
    local dir_part=""
    local name_part="$pattern"

    if [[ "$pattern" == */* ]]; then
        dir_part="${pattern%/*}"
        name_part="${pattern##*/}"
    fi

    # Execute find and convert absolute paths to relative (without eval)
    local search_dir="$root"
    local max_depth_args=()

    if [[ "$dir_part" == "**" || "$dir_part" == "" && "$name_part" == "**/"* ]]; then
        # Recursive search from root: **/*.ext or **.ext
        name_part="${name_part#\*\*/}"
        search_dir="$root"
        # No maxdepth - recursive
    elif [[ "$dir_part" == *"**"* ]]; then
        # Recursive search with prefix: prefix/**/*.ext
        local prefix="${dir_part%%/**}"
        search_dir="$root/$prefix"
        if [[ ! -d "$search_dir" ]]; then
            return 0
        fi
        # No maxdepth - recursive
    elif [[ "$dir_part" != "" ]]; then
        # Non-recursive search: dir/*.ext
        search_dir="$root/$dir_part"
        if [[ ! -d "$search_dir" ]]; then
            return 0
        fi
        max_depth_args=("-maxdepth" "1")
    else
        # No directory part: *.ext (search root only)
        search_dir="$root"
        max_depth_args=("-maxdepth" "1")
    fi

    # Execute find directly without eval (no sort to match Python glob behavior)
    if ((${#max_depth_args[@]} > 0)); then
        find "$search_dir" "${max_depth_args[@]}" -type f -name "$name_part" 2>/dev/null | \
            while IFS= read -r filepath; do
                # Convert to relative path
                echo "${filepath#$root/}"
            done
    else
        find "$search_dir" -type f -name "$name_part" 2>/dev/null | \
            while IFS= read -r filepath; do
                # Convert to relative path
                echo "${filepath#$root/}"
            done
    fi
}

#
# Compute destination path from source path and patterns
#
# Args:
#     $1: Source file path (e.g., "include/winbase.inl")
#     $2: Source pattern (e.g., "include/*.inl")
#     $3: Destination pattern (e.g., "include/*.h")
#
# Returns:
#     Computed destination path or empty on error
#
compute_destination() {
    local src_path="$1"
    local src_pattern="$2"
    local dst_pattern="$3"

    # Extract directory and filename patterns
    local src_dir="${src_pattern%/*}"
    local src_name="${src_pattern##*/}"
    local dst_dir="${dst_pattern%/*}"
    local dst_name="${dst_pattern##*/}"

    # Handle case where pattern has no directory part
    if [[ "$src_pattern" == "$src_name" ]]; then
        src_dir=""
    fi
    if [[ "$dst_pattern" == "$dst_name" ]]; then
        dst_dir=""
    fi

    # Extract the actual filename from source path
    local actual_dir="${src_path%/*}"
    local actual_name="${src_path##*/}"
    if [[ "$src_path" == "$actual_name" ]]; then
        actual_dir=""
    fi

    # Simple pattern matching for *.ext -> *.newext
    if [[ "$src_name" == "*."* && "$dst_name" == "*."* ]]; then
        # Both patterns have wildcard with extension
        local src_ext="${src_name#*.}"
        local dst_ext="${dst_name#*.}"
        local base_name="${actual_name%.$src_ext}"

        # Compute destination directory (handle ** patterns)
        local result_dir="$actual_dir"
        if [[ "$src_dir" == "**" ]]; then
            result_dir="$actual_dir"
        elif [[ "$src_dir" != "" ]]; then
            # Replace src_dir with dst_dir in actual path
            result_dir="${actual_dir/$src_dir/$dst_dir}"
        else
            result_dir="$dst_dir"
        fi

        # Construct result path
        if [[ -n "$result_dir" ]]; then
            echo "$result_dir/$base_name.$dst_ext"
        else
            echo "$base_name.$dst_ext"
        fi
    else
        # Fallback: just replace directory part
        local result_dir="$dst_dir"
        if [[ -n "$result_dir" ]]; then
            echo "$result_dir/$actual_name"
        else
            echo "$actual_name"
        fi
    fi
}

#
# Check if two paths point to the same file (case-only difference)
#
# Args:
#     $1: First path
#     $2: Second path
#
# Returns:
#     0 if same file, 1 otherwise
#
is_same_file() {
    local path1="$1"
    local path2="$2"

    [[ -e "$path1" && -e "$path2" ]] || return 1

    # Get inode numbers (portable across Linux/macOS)
    local inode1 inode2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        inode1=$(stat -f "%i" "$path1" 2>/dev/null || echo "")
        inode2=$(stat -f "%i" "$path2" 2>/dev/null || echo "")
    else
        inode1=$(stat -c "%i" "$path1" 2>/dev/null || echo "")
        inode2=$(stat -c "%i" "$path2" 2>/dev/null || echo "")
    fi

    [[ -n "$inode1" && "$inode1" == "$inode2" ]]
}

#
# Check if two files have identical content
#
# Args:
#     $1: First file path
#     $2: Second file path
#
# Returns:
#     0 if identical, 1 otherwise
#
files_identical() {
    local file1="$1"
    local file2="$2"

    [[ -f "$file1" && -f "$file2" ]] || return 1

    # Use cmp for binary-safe comparison
    cmp -s "$file1" "$file2"
}

#
# Copy file from source to destination, handling case-only changes
#
# Args:
#     $1: Source file path
#     $2: Destination file path
#     $3: Whether destination exists (true/false)
#
copy_file() {
    local src_path="$1"
    local dst_path="$2"
    local dst_exists="$3"

    # Handle case-only change on case-insensitive filesystem
    if [[ "$dst_exists" == "true" ]] && is_same_file "$src_path" "$dst_path"; then
        local temp_path="${dst_path}.tmp_duplicate"

        # Copy via temp file to handle case-only rename
        if ! cp -p "$src_path" "$temp_path" 2>/dev/null; then
            error "Failed to copy via temp file: $src_path -> $temp_path"
            return 1
        fi

        if ! mv "$temp_path" "$dst_path" 2>/dev/null; then
            # Clean up temp file on failure
            rm -f "$temp_path" 2>/dev/null || true
            error "Failed to rename temp file: $temp_path -> $dst_path"
            return 1
        fi

        return 0
    fi

    # Regular copy
    if ! cp -p "$src_path" "$dst_path" 2>/dev/null; then
        error "Failed to copy: $src_path -> $dst_path"
        return 1
    fi

    return 0
}

#
# Duplicate a single file from source to destination
#
# Args:
#     $1: Root directory path
#     $2: Source relative path
#     $3: Destination relative path
#
# Returns:
#     0 on success, 1 on error
#
duplicate_single_file() {
    local root="$1"
    local src_rel="$2"
    local dst_rel="$3"

    # Skip if source and destination are the same
    if [[ "$src_rel" == "$dst_rel" ]]; then
        return 0
    fi

    local src_path="$root/$src_rel"
    local dst_path="$root/$dst_rel"

    # Validate source
    if [[ ! -e "$src_path" ]]; then
        warn "Source '$src_rel' does not exist"
        return 1
    fi

    if [[ ! -f "$src_path" ]]; then
        warn "Source '$src_rel' is not a file"
        return 1
    fi

    # Create parent directory if needed
    local dst_dir
    dst_dir=$(dirname "$dst_path")
    if [[ -n "$dst_dir" && ! -d "$dst_dir" ]]; then
        if ! mkdir -p "$dst_dir" 2>/dev/null; then
            error "Failed to create directory: ${dst_dir#$root/}"
            return 1
        fi
        echo "Created directory: ${dst_dir#$root/}"
    fi

    # Handle existing destination
    if [[ -e "$dst_path" ]]; then
        local msg_type=""

        # Check if files are the same (case-only or identical content)
        if is_same_file "$src_path" "$dst_path"; then
            msg_type="case-only"
            if ! copy_file "$src_path" "$dst_path" "true"; then
                return 1
            fi
        elif files_identical "$src_path" "$dst_path"; then
            msg_type="same content"
            if ! copy_file "$src_path" "$dst_path" "true"; then
                return 1
            fi
        else
            # Different content - skip with warning
            warn "Destination '$dst_rel' already exists with different content, skipping"
            return 0
        fi

        echo "Duplicated ($msg_type): $src_rel -> $dst_rel"
        return 0
    fi

    # Copy file (destination doesn't exist)
    if ! copy_file "$src_path" "$dst_path" "false"; then
        return 1
    fi

    echo "Duplicated: $src_rel -> $dst_rel"
    return 0
}

#
# Duplicate files matching a glob pattern
#
# Args:
#     $1: Root directory path
#     $2: Source glob pattern (e.g., "include/*.inl")
#     $3: Destination pattern or "lowercase"
#
# Returns:
#     Number of errors
#
duplicate_by_pattern() {
    local root="$1"
    local src_pattern="$2"
    local dst_pattern="$3"

    # Find matching files using find command
    local -a matched_files
    local file
    while IFS= read -r file; do
        matched_files+=("$file")
    done < <(find_files_by_pattern "$root" "$src_pattern")

    if ((${#matched_files[@]} == 0)); then
        warn "No files match pattern '$src_pattern'"
        return 1
    fi

    echo "Found ${#matched_files[@]} file(s) matching pattern '$src_pattern'"

    local file_error_count=0
    for src_path in "${matched_files[@]}"; do
        [[ -n "$src_path" ]] || continue

        # Compute destination
        local dst_rel
        if [[ "$dst_pattern" == "lowercase" ]]; then
            # Convert entire path to lowercase
            dst_rel=$(echo "$src_path" | tr '[:upper:]' '[:lower:]')
        else
            # Compute destination using pattern matching
            dst_rel=$(compute_destination "$src_path" "$src_pattern" "$dst_pattern")
            if [[ -z "$dst_rel" ]]; then
                warn "Could not compute destination for '$src_path'"
                ((file_error_count++)) || true
                continue
            fi
        fi

        if ! duplicate_single_file "$root" "$src_path" "$dst_rel"; then
            ((file_error_count++)) || true
        fi
    done

    return "$file_error_count"
}

#
# Apply file transformations according to the mapping
#
# Args:
#     $1: Root directory path
#     $2+: Transformation specifications (src:dst pairs)
#
# Returns:
#     Number of errors
#
apply_transformations() {
    local root="$1"
    shift

    local -a transformations=("$@")

    if ((${#transformations[@]} == 0)); then
        return 0
    fi

    local total_errors=0
    for transform in "${transformations[@]}"; do
        # Parse "src:dst" format
        local src_pattern="${transform%%:*}"
        local dst_pattern="${transform#*:}"

        # Normalize paths (convert backslashes to forward slashes)
        src_pattern="${src_pattern//\\//}"
        dst_pattern="${dst_pattern//\\//}"

        # Normalize "lowercase" marker (case-insensitive)
        local dst_lower
        dst_lower=$(echo "$dst_pattern" | tr '[:upper:]' '[:lower:]')
        if [[ "$dst_lower" == "lowercase" ]]; then
            dst_pattern="lowercase"
        fi

        # Apply transformation
        local transform_errors=0
        if has_glob_pattern "$src_pattern"; then
            duplicate_by_pattern "$root" "$src_pattern" "$dst_pattern" || transform_errors=$?
        else
            # Exact file transformation
            local dst_actual="$dst_pattern"
            if [[ "$dst_pattern" == "lowercase" ]]; then
                dst_actual=$(echo "$src_pattern" | tr '[:upper:]' '[:lower:]')
            fi
            duplicate_single_file "$root" "$src_pattern" "$dst_actual" || transform_errors=$?
        fi

        ((total_errors += transform_errors)) || true
    done

    return "$total_errors"
}

#
# Parse command-line arguments
#
# Args:
#     $@: Command-line arguments
#
# Sets globals:
#     DIRECTORY: Root directory path
#     TRANSFORMATIONS: Array of transformation specs
#
parse_args() {
    DIRECTORY=""
    TRANSFORMATIONS=()

    while (($# > 0)); do
        case "$1" in
            --transform)
                shift
                if (($# == 0)); then
                    error "Missing argument for --transform"
                    return 1
                fi
                TRANSFORMATIONS+=("$1")
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                if [[ -z "$DIRECTORY" ]]; then
                    DIRECTORY="$1"
                else
                    error "Multiple directory arguments provided"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$DIRECTORY" ]]; then
        error "Missing required directory argument"
        echo "Usage: $0 <directory> [--transform <src>:<dst>]..." >&2
        return 1
    fi

    return 0
}

#
# Main entry point
#
main() {
    # Parse arguments
    if ! parse_args "$@"; then
        return 1
    fi

    # Validate directory
    if [[ ! -d "$DIRECTORY" ]]; then
        error "'$DIRECTORY' is not a directory"
        return 1
    fi

    # Apply transformations
    if ((${#TRANSFORMATIONS[@]} > 0)); then
        echo "Applying ${#TRANSFORMATIONS[@]} transformation(s) in: $DIRECTORY"

        local error_count=0
        apply_transformations "$DIRECTORY" "${TRANSFORMATIONS[@]}" || error_count=$?

        if ((error_count > 0)); then
            warn "$error_count transformation error(s) occurred"
            return 1
        fi
    else
        echo "No transformations specified for: $DIRECTORY"
    fi

    return 0
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
