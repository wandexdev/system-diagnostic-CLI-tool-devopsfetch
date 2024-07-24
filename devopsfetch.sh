#!/bin/bash

# Color codes for columns
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/devopsfetch.log"

# Table formatting function for -t option and log file
format_table() {
    column -t -s $'\t' | sed 's/^/| /' | sed 's/$/ |/' | sed '2s/[^|]/-/g'
}

time_range_date() {
    local start_time="$1"
    local end_time="$2"
    local limit=50 # Set a limit for the number of lines to display

    journalctl --since "$start_time" --until "$end_time" --output=short |
    awk -v limit="$limit" '
    BEGIN {
        print "Timestamp|User|Process|Message"
    }
    NR <= limit {
        timestamp = $1 " " $2 " " $3
        user = $4
        process = $5
        $1=$2=$3=$4=$5=""
        message = substr($0,6)
        print timestamp "|" user "|" process "|" message
    }' | column -t -s '|' | format_table
}

options_ports() {
    if [ -n "$1" ]; then
        echo -e "${GREEN}DETAILS FOR PORT $1${NC}"
        echo -e "${GREEN}-----------------------${NC}"
        echo -e "COMMAND\tPID\tUSER\tFD\tTYPE\tDEVICE\tSIZE/OFF\tNODE\tNAME"
        sudo lsof -i -n -P | grep ":$1 " | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' | column -t
    else
        echo -e "${GREEN}ACTIVE PORTS${NC}"
        echo -e "${GREEN}-----------------${NC}"
        echo -e "COMMAND\tPID\tUSER\tFD\tTYPE\tDEVICE\tSIZE/OFF\tNODE\tNAME"
        sudo lsof -i -n -P | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' | column -t
    fi
    echo ""
}

options_users() {
    if [ -n "$1" ]; then
        echo -e "${YELLOW}DETAILS FOR USER $1${NC}"
        echo -e "${YELLOW}-----------------------${NC}"
        lastlog -u "$1" | awk 'NR==1 {print "USER\tPORT\tFROM\tLATEST\tLOGIN\tTIME\tLAST LOGIN"} NR>1 {print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10}' | column -t
    else
        echo -e "${YELLOW}USER LOGINS${NC}"
        echo -e "${YELLOW}-----------------${NC}"
        getent passwd | awk -F: '{ if ($3 >= 1000 && $3 != 65534) print $1 }' | xargs -I{} lastlog -u {} | awk 'NR==1 {print "USER\tPORT\tFROM\tLATEST\tLOGIN\tTIME\tLAST LOGIN"} NR>1 {print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10}' | column -t
    fi
    echo ""
}

options_nginx() {
    if [ -n "$1" ]; then
        echo -e "${BLUE}NGINX CONFIGURATION FOR DOMAIN $1${NC}"
        echo -e "${BLUE}------------------------------------${NC}"
        config_file=$(grep -rl "server_name $1" /etc/nginx/sites-available)
        if [ -z "$config_file" ]; then
            echo -e "${RED}No configuration file found for domain $1${NC}"
            return
        fi
        proxy=$(grep "proxy_pass" "$config_file" | awk '{print $2}')
        port=$(grep "listen" "$config_file" | awk '{print $2}')
        echo -e "CONFIG FILE:\t$config_file"
        echo -e "PROXY:\t\t$proxy"
        echo -e "PORT:\t\t$port"
        echo ""
        echo -e "${BLUE}SERVER BLOCK DETAILS${NC}"
        echo -e "${BLUE}-----------------------${NC}"
        cat "$config_file"
    else
        echo -e "${BLUE}NGINX CONFIGURATIONS${NC}"
        echo -e "${BLUE}-----------------${NC}"
        for file in /etc/nginx/sites-available/*; do
            server_name=$(grep "server_name" "$file" | awk '{print $2}')
            proxy=$(grep "proxy_pass" "$file" | awk '{print $2}')
            port=$(grep "listen" "$file" | awk '{print $2}')
            if [ -n "$server_name" ]; then
                echo -e "DOMAIN:\t$server_name\nPROXY:\t$proxy\nCONFIG FILE:\t$file\nPORT:\t$port\n"
            fi
        done | column -t
    fi
    echo ""
}

options_docker() {
    check_docker_permission
    local container=$1
    log_activity "Displaying Docker information. Container/Image: $container"
    
    if [ -z "$container" ]; then
        echo -e "${CYAN}DOCKER IMAGES${NC}"
        echo -e "${CYAN}-----------------${NC}"
        # Filter out lines with <none> in repository or tag
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | grep -vE '\<none\>' | format_table
        
        echo -e "\n${CYAN}ALL DOCKER CONTAINERS (INCLUDING EXITED)${NC}"
        echo -e "${CYAN}-------------------------------------------${NC}"
        docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" | format_table
    else
        echo -e "${CYAN}INFORMATION FOR CONTAINER/IMAGE: $container${NC}"
        echo -e "${CYAN}------------------------------------------${NC}"
        
        # Fetch container information
        container_info=$(docker ps -a --filter "name=$container" --format "{{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}")
        
        # Fetch image information
        image_info=$(docker images --filter "reference=$container" --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | grep -vE '\<none\>')

        if [ -n "$container_info" ]; then
            echo -e "${GREEN}Container Details:${NC}"
            echo -e "ID\tIMAGE\tCOMMAND\tCREATED\tSTATUS\tPORTS\tNAME"
            echo -e "$container_info" | format_table
        fi
        
        if [ -n "$image_info" ]; then
            echo -e "${GREEN}Image Details:${NC}"
            echo -e "REPOSITORY\tTAG\tID\tSIZE\tCREATED"
            echo -e "$image_info" | format_table
        fi

        if [ -z "$container_info" ] && [ -z "$image_info" ]; then
            echo -e "${RED}No container or image found with the name or ID: $container${NC}"
        fi
    fi
}

options_time_range() {
    if [ -n "$1" ] && [ -n "$2" ]; then
        echo -e "${CYAN}ACTIVITIES${NC}"
        echo -e "${CYAN}-----------------${NC}"
        time_range_date "$1" "$2"
    else
        # Use default time range if no arguments are provided
        echo "No date range specified. Using default time range for today."
        local default_range
        default_range=$(get_default_time_range)
        local start_time
        local end_time
        start_time=$(echo "$default_range" | awk '{print $1}')
        end_time=$(echo "$default_range" | awk '{print $2}')
        echo -e "${CYAN}ACTIVITIES${NC}"
        echo -e "${CYAN}-----------------${NC}"
        time_range_date "$start_time" "$end_time"
    fi
    echo ""
}

log_activities() {
    while true; do
        {
            echo "-------------------------------"
            echo "Timestamp: $(date)"
            echo "-------------------------------"
            echo -e "${CYAN}DEVOPSFETCH SERVICE OUTPUT${NC}"
            echo -e "${CYAN}----------------------------${NC}"
            # Log the output of the devopsfetch service
            journalctl -u devopsfetch.service --since "5 minutes ago" | format_table
        } >> "$LOG_FILE"
        sleep 300
    done
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--port) options_ports "$2"; shift ;;
        -d|--docker) options_docker "$2"; shift ;;
        -n|--nginx) options_nginx "$2"; shift ;;
        -u|--users) options_users "$2"; shift ;;
        -t|--time)
            if [ "$#" -ne 3 ]; then
                echo "Error! Wrong format, input a date range."
                echo "Format: $0 -t|--time <start> <end>"
                exit 1
            fi
            options_time_range "$2" "$3"
            shift 2
            ;;
        -h|--help) 
            echo -e "${RED}Usage: devopsfetch [options]${NC}"
            echo -e "${RED}Options:${NC}"
            echo -e "-p|--port <port>         Show active ports or details for a specific port."
            echo -e "-u|--users <username>    Show user login details or details for a specific user."
            echo -e "-n|--nginx <domain>      Show Nginx configurations for a specific domain."
            echo -e "-d|--docker <container>  Show Docker container statuses or details for a specific container."
            echo -e "-t|--time <start> <end>  Show activities for a specified time range."
            echo -e "-h|--help                Show this help message."
            exit 0
            ;;
        *) 
            echo "Error! wrong options/format: $1"
            echo "Run -h or -- help to show usage"
            exit 1
            ;;
    esac
    shift
done
