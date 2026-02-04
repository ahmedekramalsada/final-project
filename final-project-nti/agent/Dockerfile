FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    libicu70 \
    libssl3 \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create agent directory and set working directory
WORKDIR /azp/

# Copy the start script first
COPY start.sh ./
RUN chmod +x start.sh

# Run as non-root user for security
RUN useradd -m azpagent && chown -R azpagent:azpagent /azp
USER azpagent

# The start script will download the agent at runtime
ENTRYPOINT ["./start.sh"]
