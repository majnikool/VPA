# Start with a base image that has bash
FROM alpine:latest

# Install dependencies
RUN apk update && apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    dialog

# Install kubectl
RUN KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Set the working directory in the Docker image
WORKDIR /app

# Copy the entire project directory into the Docker image
COPY . .

# Make the script executable
RUN chmod +x tui.sh

# Set the entrypoint to be your script
ENTRYPOINT ["/app/tui.sh"]
