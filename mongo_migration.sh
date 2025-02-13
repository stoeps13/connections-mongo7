#!/usr/bin/env bash

#Copyright 2025 HCLTech
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

LOG_FILE="migration_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

NFS_ROOT=${NFS_ROOT:-/mnt}
REPL_SET=${REPL_SET:-"rs0"}
NETWORK_NAME=${NETWORK_NAME:-"mongo5-network"}
HOST_PORT_BASE=${HOST_PORT_BASE:-27010}
CONTAINER_PORT=${CONTAINER_PORT:-27017}

declare -A FCV_VERSIONS=(["6.0"]="docker.io/bitnami/mongodb:6.0" ["7.0"]="docker.io/bitnami/mongodb:7.0")
declare -A container_map

log_info() { echo "[INFO] $1"; }

# Ensure the Docker network exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    log_info "Creating Docker network: $NETWORK_NAME"
    docker network create "$NETWORK_NAME"
fi

start_container() {
    log_info "Starting MongoDB container (Image: $5): $1 on $2"
    docker run -dt --name "$1" --hostname "$2" --network $NETWORK_NAME \
        -p "$3:$CONTAINER_PORT" -v "$4:/bitnami/mongodb/data/db:Z" \
        -e MONGODB_EXTRA_FLAGS="--replSet=$REPL_SET" "$5"
}

wait_for_mongo() {
    log_info "Waiting for MongoDB in $1 to be ready..."
    until docker exec "$1" mongosh --host 127.0.0.1 --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; do
        sleep 5
    done
    log_info "MongoDB in $1 is ready."
}

stop_and_remove_container() {
    local container_name="$1"
    local timeout="${2:-30}"  # Default timeout is 30 seconds
    
    # Print MongoDB logs before shutting down the container
    log_info "Fetching logs for container: $container_name before stopping"
    docker logs "$container_name" --tail 5  # Display last 5 lines of logs

    # Wait for MongoDB to complete its shutdown and replication
    log_info "Stopping container: $container_name with timeout: $timeout seconds"
    docker stop --time "$timeout" "$container_name"
    
    # Display final logs after the stop command (optional)
    log_info "Fetching final logs after stopping container: $container_name"
    docker logs "$container_name" --tail 5  # Display last 5 lines of logs

    # Removing the container
    log_info "Removing container: $container_name"
    docker rm "$container_name"
}

update_fcv() {
    fcv_command="db.adminCommand({ setFeatureCompatibilityVersion: '$1'$( [ "$1" == "7.0" ] && echo ', confirm: true') })"
    log_info "Setting FCV to $1 on the primary node ($primary_container)"
    docker exec "$primary_container" mongosh --quiet --eval "$fcv_command"
    sleep 10
    log_info "FCV updated to $1."
}

remove_replica_set_config() {
    log_info "Removing ReplicaSet configuration for MongoDB 7.0..."
    for hostname in "${hostname_array[@]}"; do
        container_name="${container_map[${hostname%%:*}]}"
        until docker exec "$container_name" mongosh local --retryWrites=false --quiet --eval 'db.system.replset.deleteOne({"_id":"rs0"});'; do
            sleep 10
        done
    done
}

detect_primary() {
    for cname in "${container_map[@]}"; do
        is_primary=$(docker exec "$cname" mongosh --quiet --eval 'db.isMaster().ismaster')
        if [ "$is_primary" == "true" ]; then
            primary_container="$cname"
            primary_hostname=$(docker exec "$cname" mongosh --quiet --eval 'db.isMaster().primary')
            return
        fi
    done
}

print_replica_set_info() {
    log_info "Replica set status for container: $primary_container"
    docker exec "$1" mongosh --quiet --eval 'rs.status()'
}

construct_hostname() {
    new_host_name=$(echo "$1" | sed 's/mongo[0-9]/mongo7/g')
    echo $new_host_name
}

wait_for_all_members_ready() {
    local primary_container="$1"
    local expected_members="$2"
    local ready=false

    log_info "Waiting for all replica set members to be ready..."
    while [ "$ready" = false ]; do
        sleep 10
        ready=true
        rs_status=$(docker exec "$primary_container" mongosh --quiet --eval 'JSON.stringify(rs.status())')
        for ((i=0; i<expected_members; i++)); do
            state=$(echo "$rs_status" | grep -oP '"stateStr"\s*:\s*"\K[^"]+' | sed -n "$((i+1))p")
            log_info "Member $i state: $state"
            if [ "$state" != "SECONDARY" ] && [ "$state" != "PRIMARY" ]; then
                ready=false
                break
            fi
        done
    done
    log_info "All replica set members are ready."
}

init_replica_set() {
    log_info "Initializing the replica set..."
    # Start the primary container for MongoDB 7.0
    primary_cname="mongo-0"
    MONGO_HOST=$(construct_hostname "${hostname_array[0]%:*}")
    log_info "converted host for new primary:  $MONGO_HOST"
    start_container "$primary_cname" "${MONGO_HOST}" "27010" "$NFS_ROOT/mongo7-node-0/data/db" "docker.io/bitnami/mongodb:7.0"
    wait_for_mongo "$primary_cname"

    # Initialize the replica set with only the primary node
    log_info "Initializing the replica set with the primary node..."
    docker exec "$primary_cname" mongosh --quiet --eval "rs.initiate({ _id: 'rs0', members: [{ _id: 0, host: '${MONGO_HOST}:27017' }], protocolVersion: 1 })"
    log_info "Primary node initialized."

    # Wait for the primary node to be fully ready
    log_info "Waiting for the primary node to be fully ready..."
    until docker exec "$primary_cname" mongosh --quiet --eval 'rs.isMaster().ismaster' | grep -q 'true'; do
        sleep 10
    done
    log_info "Primary node is fully ready."

    # Start the secondary containers for MongoDB 7.0
    for i in $(seq 1 $((${#hostname_array[@]} - 1))); do
        cname="mongo-$i"
        MONGO_HOST=$(construct_hostname "${hostname_array[$i]%:*}")
        start_container "$cname" "${MONGO_HOST}" "$((HOST_PORT_BASE + i))" "$NFS_ROOT/mongo7-node-$i/data/db" "docker.io/bitnami/mongodb:7.0"
        wait_for_mongo "$cname"
    done

   for i in $(seq 1 $((${#hostname_array[@]} - 1))); do
         # Add the secondary nodes to the replica set
        log_info "Adding secondary node to the replica set..."
        MONGO_HOST=$(construct_hostname "${hostname_array[$i]%:*}")
        cname="mongo-$i"
        docker exec "$primary_cname" mongosh --quiet --eval "rs.add('${MONGO_HOST}:27017')"
        log_info "Secondary node added to the replica set."
    done
    

    # Wait for all members to be ready
    wait_for_all_members_ready "$primary_cname" "${#hostname_array[@]}"

    # Step 8: Print replica set information
    print_replica_set_info "$primary_cname"

    # Step 9: Stop and remove all the containers
    for i in "${!hostname_array[@]}"; do
        cname="mongo-$i"
        [[ "$cname" != "$primary_cname" ]] && stop_and_remove_container "$cname"
        sleep 5
    done

    stop_and_remove_container "$primary_cname"
}


# Step 1: Start a temporary container to get replica set info
log_info "Starting temporary MongoDB container to retrieve replica set info (MongoDB 5.0)"
docker run -dt --name "mongo-get-host-name" -p 27020:$CONTAINER_PORT \
    -v "$NFS_ROOT/mongo7-node-0/data/db:/bitnami/mongodb/data/db:Z" \
    -e MONGODB_EXTRA_FLAGS="--replSet=$REPL_SET" docker.io/bitnami/mongodb:5.0

wait_for_mongo "mongo-get-host-name"
hostname_array=($(docker exec "mongo-get-host-name" mongosh --quiet --eval "rs.conf();" | sed -n "s/.*host: '\([^']*\)'.*/\1/p"))
hostname_array=($(printf "%s\n" "${hostname_array[@]}" | sort))
log_info "Detected hostnames: ${hostname_array[@]}"

# Use the stop_and_remove_container function to stop and remove the temporary container
stop_and_remove_container "mongo-get-host-name"

# Step 2: Start MongoDB containers and map hostnames to container names
for i in "${!hostname_array[@]}"; do
    cname="mongo-$i"
    start_container "$cname" "${hostname_array[$i]%%:*}" "$((HOST_PORT_BASE + i))" "$NFS_ROOT/mongo7-node-$i/data/db" "docker.io/bitnami/mongodb:5.0"
    container_map["${hostname_array[$i]%%:*}"]="$cname"
    wait_for_mongo "$cname"
done

# print the container_map
log_info "Container map:"
for key in "${!container_map[@]}"; do
    echo "$key: ${container_map[$key]}"
done

# Step 3: Detect the primary node and its hostname
detect_primary
log_info "Primary node detected: $primary_container with hostname: $primary_hostname"
# Print replica set information
print_replica_set_info "$primary_container"

# Step 4: Incrementally update MongoDB version and FCV
for fcv in $(echo "${!FCV_VERSIONS[@]}" | tr ' ' '\n' | sort -V); do
    log_info "Upgrading containers to MongoDB version ${FCV_VERSIONS[$fcv]} and setting FCV to $fcv"
    for i in "${!hostname_array[@]}"; do
        cname="mongo-$i"
        stop_and_remove_container "$cname"
        start_container "$cname" "${hostname_array[$i]%:*}" "$((HOST_PORT_BASE + i))" "$NFS_ROOT/mongo7-node-$i/data/db" "${FCV_VERSIONS[$fcv]}"
        wait_for_mongo "$cname"
    done

    # Re-detect the primary node and its hostname after restarting containers
    detect_primary
    log_info "Primary node re-detected: $primary_container with hostname: $primary_hostname"
    print_replica_set_info "$primary_container"

    update_fcv "$fcv"

    if [ "$fcv" == "7.0" ]; then
        # Step 5: Remove replica set and transactions
        remove_replica_set_config
        # Step 6: Stop and remove all the containers
        for i in "${!hostname_array[@]}"; do
            cname="mongo-$i"
            [[ "$cname" != "$primary_container" ]] && stop_and_remove_container "$cname"
        done
        stop_and_remove_container "$primary_container"
    fi
done

init_replica_set
log_info "FCV upgrade complete."
