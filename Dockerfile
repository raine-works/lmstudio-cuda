# 1. Use NVIDIA CUDA 12.4 base (compatible with most RunPod hosts in 2026)
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# 2. Install system dependencies + SSH for RunPod terminal
RUN apt-get update && apt-get install -y \
    curl \
    libfuse2 \
    libnss3 \
    libasound2 \
    libgomp1 \
    openssh-server \
    sudo \
    bash \
    && rm -rf /var/lib/apt/lists/*

# 3. Configure SSH (Ensures the Web Terminal stays connected)
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 4. Install LM Studio CLI (lms)
RUN curl -fsSL https://lmstudio.ai/install.sh | bash

# 5. Set Environment Variables
# Ensures the 'lms' command is available in all shells
ENV PATH="/root/.lmstudio/bin:${PATH}"
ENV APPIMAGE_EXTRACT_AND_RUN=1

# 6. Bootstrap the binary
RUN lms bootstrap

# 7. Expose ports (22 for Terminal/SSH, 1234 for LM Studio API)
EXPOSE 22 1234

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use the script as the entry point
ENTRYPOINT ["/entrypoint.sh"]

# Label for easier identification in GHCR
LABEL org.opencontainers.image.source="https://github.com/raine-works/lmstudio-cuda"
