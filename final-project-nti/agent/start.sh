#!/bin/bash
set -e

# Validate environment variables
if [ -z "${AZP_URL}" ]; then
  echo "error: AZP_URL is not set"
  exit 1
fi

if [ -z "${AZP_TOKEN}" ]; then
  echo "error: AZP_TOKEN is not set"
  exit 1
fi

if [ -z "${AZP_POOL}" ]; then
  echo "error: AZP_POOL is not set"
  exit 1
fi

# Use AZP_AGENT_NAME if set, otherwise use hostname
AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)}"

# Download and extract the agent if not already present
if [ ! -f "./config.sh" ]; then
  echo "Downloading Azure Pipelines agent..."
  
  # Get the latest agent version
  AZP_AGENT_RESPONSE=$(curl -LsS \
    -u user:${AZP_TOKEN} \
    -H 'Accept:application/json;' \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=linux-x64&top=1")
  
  AZP_AGENT_PACKAGE_LATEST_URL=$(echo "$AZP_AGENT_RESPONSE" | jq -r '.value[0].downloadUrl')
  
  if [ -z "$AZP_AGENT_PACKAGE_LATEST_URL" ] || [ "$AZP_AGENT_PACKAGE_LATEST_URL" == "null" ]; then
    echo "error: Could not determine agent download URL. Response: $AZP_AGENT_RESPONSE"
    exit 1
  fi
  
  echo "Using agent package URL: $AZP_AGENT_PACKAGE_LATEST_URL"
  curl -LsS "$AZP_AGENT_PACKAGE_LATEST_URL" | tar -xz
fi

# Configure the agent
./config.sh --unattended \
  --url "${AZP_URL}" \
  --auth pat \
  --token "${AZP_TOKEN}" \
  --pool "${AZP_POOL}" \
  --agent "${AZP_AGENT_NAME}" \
  --replace \
  --acceptTeeEula

# Run the agent
# Use --once to run a single job and exit (ideal for ephemeral agents)
./run.sh "$@"
