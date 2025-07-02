#!/bin/bash

# Student Name: Shaindy Brandwain
# Student Code: s21
# Class Code: 7736/26
# Lecturer Name: Mrs. Shimrit

#Function to get user input
get_user_input() {
    echo "Enter the path to the file containing 10 .onion websites:"
    read onion_file
    echo "Enter search words for alerts (comma-separated):"
    read search_words
}

#Function to crawl and index websites
crawl_and_index() {
    log_file="crawler_log.txt"
    indexed_links="indexed_links.txt"
    processed_links="processed_links.txt"
    skipped_links="skipped_links.txt"

    # Create the necessary files if they don't exist
    touch "$log_file"
    touch "$indexed_links"
    touch "$processed_links"
    touch "$skipped_links"

    # Check if the script has previously run
    if [ -s "$processed_links" ]; then
        last_processed=$(tail -n 1 "$processed_links")
        echo "Resuming from last processed site: $last_processed"
    else
        last_processed=""
    fi

    # Loop over the list of .onion sites and crawl them
    while read -r url; do
        # Skip sites that have already been processed
        if grep -Fxq "$url" "$processed_links"; then
            echo "Skipping already crawled website: $url"
            continue
        fi

        echo "Crawling: $url"
        response=$(curl -s --socks5-hostname 127.0.0.1:9050 "$url")

        if [ $? -eq 0 ]; then
            title=$(echo "$response" | grep -oP '(?<=<title>).*?(?=</title>)')
            echo "Title: $title"
            echo "Title: $title | URL: $url | Date: $(date)" >> "$log_file"
            echo "$url" >> "$processed_links"
            new_links=$(echo "$response" | grep -oP '(?<=href=")[^"]*\.onion')
            echo "$new_links" >> "$indexed_links"

            # Check for search words and trigger alerts if found
            for word in $(echo "$search_words" | tr "," "\n"); do
                if echo "$response" | grep -iq "$word"; then
                    echo "[ALERT] Found search word '$word' on $url | Date: $(date)" >> "$log_file"
                fi
            done
        else
            echo "[NO ACCESS] $url | Date: $(date)" >> "$log_file"
            echo "$url" >> "$skipped_links"
        fi
    done < "$onion_file"
}

# Function to display the Admin UI
admin_ui() {
    while true; do
        echo "Admin UI"
        echo "1. Display number of sites crawled"
        echo "2. Check Darknet access status"
        echo "3. Add/Manage search words for alerts"
        echo "4. View log file"
        echo "5. Exit"
        read -p "Choose an option: " choice

        case $choice in
            1)
                echo "Number of sites crawled: $(wc -l < "$processed_links")"
                ;;
            2)
                echo "Darknet access: $(curl -s --socks5-hostname 127.0.0.1:9050 http://example.com >/dev/null && echo "Active" || echo "Non-Active")"
                ;;
            3)
                echo "Current search words: $search_words"
                echo "Enter new search words (comma-separated):"
                read search_words
                ;;
            4)
                cat "$log_file"
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Function to validate the crawler's access to the darknet
validate_darknet_access() {
    echo "Validating Darknet access..."
    if curl -s --socks5-hostname 127.0.0.1:9050 http://example.com >/dev/null; then
        echo "Darknet access is Active"
    else
        echo "Darknet access is Non-Active. Ensure Tor is running."
    fi
}

# Main script execution
get_user_input
validate_darknet_access
crawl_and_index
admin_ui
