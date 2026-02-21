# Use CUDA 12.4 runtime on Ubuntu 22.04
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# 1. Install system dependencies for LM Studio (headless requirements)
RUN apt-get update && apt-get install -y \
    curl \
    libfuse2 \
    libnss3 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install LM Studio CLI (lms) using the official script
RUN curl -fsSL https://lmstudio.ai/install.sh | bash

# 3. Create a symbolic link and bootstrap the lms binary
# The script installs to ~/.lmstudio/bin/lms. We move/link it to make it global.
RUN ln -s /root/.lmstudio/bin/lms /usr/local/bin/lms && \
    /usr/local/bin/lms bootstrap

# 4. Set Environment Variables
# Ensures the container knows where the LM Studio binaries live
ENV PATH="/root/.lmstudio/bin:${PATH}"
# Prevents some 'sandboxing' errors common in containerized GPU environments
ENV APPIMAGE_EXTRACT_AND_RUN=1

# 5. Expose the default LM Studio port
EXPOSE 1234

# 6. Startup Command: Initialize the daemon and start the server
# --cors=true allows your Zed editor to talk to the RunPod IP
# --bind 0.0.0.0 ensures it listens on the network interface, not just localhost
CMD ["/bin/bash", "-c", "lms daemon up && lms server start --port 1234 --cors=true --bind 0.0.0.0"]
LABEL org.opencontainers.image.source="https://github.com/raine-works/lmstudio-docker"
