#!/bin/bash

# bad:  a7491b1e81557d3d5a0ddda7070e0a692e43d971
# good: a2f31c66e110a157ca5269db6d4ce7a05fe7e9e9
# first bad commit: 95b7f1953be51ae994640ddfbc16565041149df0

service=$1
good_commit=$2
bad_commit=$3

function build_service() {
    echo -e "\nBuilding the service: $service..."
    nx build $service
    echo -e "$service has been built successfully!\n"
}

function get_build_size() {
    # for local testing: local size=`du -b --max-depth=0  ./$service/main.js | cut -f1`
    local size=`du -b --max-depth=0  ./dist/apps/$service/main.js | cut -f1`
    echo "$size"
}

function print_commit_info() {
    echo $(git show --oneline -s)
}

function print_separator_start() {
    echo -e "\n\n================================================"
}

function print_separator_end() {
    echo -e "================================================\n\n"
}

git bisect start
echo -e "\n[USING GIT BISECT TO FIND THE BUG]\n"
echo "Started bisecting"

echo "Good Commit: $good_commit"
git bisect good $good_commit

build_service

# standard_deviation_percentage(%): a small jitter on bundle size because it can slowly grow over time
# feel free to experiment with this value to get better results
# (optionally) we can add the ability to compare current_bundle_size to previous_bundle_size (so we only compare two adjacent values)
standard_deviation_percentage=20
original_bundle_size=$(get_build_size)
acceptable_bundle_size=$((original_bundle_size + (original_bundle_size * standard_deviation_percentage / 100)))

print_separator_start
echo -e "\n\nOriginal bundle size $original_bundle_size"
echo -e "Acceptable size $acceptable_bundle_size\n\n"
print_separator_end

echo "Bad Commit: $bad_commit"
git bisect bad $bad_commit
echo -e "...\n\n"

while true; do
    output="$(cat ./animals.txt)"
    current_commit=$(git show --format="%h" --no-patch)

    echo -e "\nCurrently bisecting commit sha: $current_commit"
    
    # Build the service
    build_service

    current_bundle_size=$(get_build_size)
    echo "($current_commit) Current bundle size: $current_bundle_size"
    echo "($current_commit) Acceptable bundle size: $acceptable_bundle_size"

    # Run the logic to verify if the bundle size is exceeded
    if [ "$current_bundle_size" -gt "$acceptable_bundle_size" ]; then
        echo -e "Commit \"$(print_commit_info)\" is a bad commit"

        # Check if bisect is finished
        if git bisect bad | grep -q "is the first bad commit"; then
            print_separator_start
            echo "Found the first bad commit. SHA: $current_commit"
            print_commit_info
            print_separator_end
            break
        fi
    else
        echo -e "Commit \"$(print_commit_info)\" is a good commit"
        
        # Check if bisect is finished
        if git bisect good | grep -q "is the first bad commit"; then
            print_separator_start
            echo "Couldn't find the bad commit. Ended at SHA: $current_commit"
            print_commit_info
            print_separator_end
            break
        fi
    fi

    # sleep 5
done

git bisect reset
echo "Bisecting completed!"