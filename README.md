# LM Studio CUDA

This project provides a complete Dockerized environment for running LM Studio with NVIDIA CUDA support. The container includes all necessary components to run LM Studio with GPU acceleration, SSH access, and pre-configured CLI tools.

## Features
- Run LM Studio in headless mode (GUI-less) with full NVIDIA CUDA GPU support
- Access the LM Studio API via SSH terminal or directly from host machine
- Built-in SSH server for remote access and debugging
- Pre-configured with LM Studio CLI tools and dependencies
- Multi-architecture support (AMD64, ARM64)
- Automated CI/CD pipeline with GitHub Actions
- Semantic versioning for Docker images

## Prerequisites

- Docker installed on your system
- NVIDIA GPU with drivers installed (for GPU support)
- Docker Compose (optional, but recommended)

## Quick Start

### Using Docker Run

```bash
docker run -d \
  --name lmstudio-cuda \
  --gpus all \
  -p 22:22 \
  -p 1234:1234 \
  ghcr.io/raine-works/lmstudio-cuda:latest
```

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'
services:
  lmstudio:
    image: ghcr.io/raine-works/lmstudio-cuda:latest
    container_name: lmstudio-cuda
    ports:
      - "22:22"   # SSH access
      - "1234:1234" # LM Studio API
    volumes:
      - ./data:/root/.lmstudio  # Persist data
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

Then run:
```bash
docker-compose up -d
```

## Access Methods

### SSH Access

Connect via SSH to get terminal access:
```bash
ssh root@localhost -p 22
# Default password is 'root'
```

### Accessing the LM Studio API

The container runs a headless LM Studio API server on port 1234. You can interact with it via:

**From inside the container (via SSH):**
```bash
ssh root@localhost -p 22
# Then use lms commands:
lms ls                # List downloaded models
lms get <model-id>        # Download a model
lms server start --port 1234   # Start the headless server
```

**From your host machine (after running container):**
```bash
# Test API endpoint (list models)
curl http://localhost:1234/v1/models

# Make a chat completion request
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Meta-Llama-3-8B-Instruct","messages":[{"role":"user","content":"Hello!"}]}'
```

## Environment Variables

The container can be configured using environment variables:

- `LM_API_TOKEN` - API token for LM Studio (optional)

## Ports

- `22` - SSH access
- `1234` - LM Studio API server (headless, no web interface)

## Building Locally

### Prerequisites

Make sure you have the following installed:
- Docker
- Buildx support enabled

### Build Commands

```bash
# Build locally
npm run build:local

# Push to registry (requires authentication)
npm run auth:docker
npm run build
```

## GitHub Actions

This project includes a GitHub Actions workflow that automatically builds and publishes the Docker image when pushing to the main branch or creating a new tag.

### Workflow Details

The workflow:
1. Triggers on pushes to `master` branch or tags matching `v*`
2. Builds the Docker image for both AMD64 and ARM64 architectures
3. Pushes the image to GitHub Container Registry (GHCR)
4. Creates version tags based on semantic versioning

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Troubleshooting

### GitHub Actions Deployment Issues

If you encounter a 403 Forbidden error when pushing to GHCR, check the following:

1. **Repository Permissions**: Ensure your repository allows package publishing
2. **Token Permissions**: Verify that `GITHUB_TOKEN` has `packages: write` permission
3. **Repository Visibility**: Make sure the repository settings allow package publishing
4. **Owner/Repository Name**: Confirm the repository name matches `raine-works/lmstudio-cuda`

### Common Solutions

- Navigate to **Settings** → **Packages** in your GitHub repository and ensure package publishing is enabled
- Check that you have write access to the repository
- If using a private repository, verify organization-level package permissions
- Try re-running the workflow after a few minutes (sometimes temporary auth issues resolve)

## Headless Mode

This container runs LM Studio in headless mode (GUI-less operation) as documented on the [LM Studio docs](https://lmstudio.ai/docs/developer/core/headless). Key features:

- Server starts automatically via entrypoint script with `lms server start`
- Models can be loaded on-demand via JIT (Just-In-Time) loading
- No web interface - use SSH for terminal access or the REST API for programmatic access

## License

This project is licensed under the MIT License - see the LICENSE file for details.
```
