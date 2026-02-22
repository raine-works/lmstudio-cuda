# LM Studio Agents in Docker

This guide covers running and deploying LM Studio Agents within the `lmstudio-cuda` Docker container.

## Overview

LM Studio Agents provide a framework for creating AI-powered assistants that run locally on your machine. The `lmstudio-cuda` container runs a headless LM Studio API server (not a web interface), which agents can connect to via the local API at port 1234.

When deployed in the CUDA-enabled Docker container, agents can leverage GPU acceleration for faster inference while maintaining the flexibility of containerized deployment.

## Prerequisites

- Docker installed with NVIDIA Container Toolkit support
- Access to `lmstudio-cuda` image: `ghcr.io/raine-works/lmstudio-cuda:latest`
- LM Studio CLI (`lms`) - pre-installed in the container
- Local LLM models loaded into LM Studio (see [Load Models](#load-models))

## Quick Start

### Run the Container

```bash
docker run -d \
  --name lmstudio-agents \
  --gpus all \
  -p 22:22 \
  -p 1234:1234 \
  -v ~/lmstudio-data:/root/.lmstudio \
  ghcr.io/raine-works/lmstudio-cuda:latest
```

### Access via SSH (Terminal)

```bash
ssh root@localhost -p 22
# Password: root
```

### Initialize Agent Project

Inside the container via SSH:

```bash
lms agent init my-agent
cd my-agent
```

This creates an agent project with:
- `agent.yaml` - Configuration file
- `prompts/` - Directory for prompt templates
- `tools/` - Custom tool implementations (optional)
- `README.md` - Project documentation

## Agent Architecture

### Core Components

1. **Agent Runtime** - Manages execution state and conversation history
2. **Prompt Engine** - Handles prompt generation, templates, and versioning
3. **Memory System** - Short-term context window + long-term memory storage
4. **Tool Executor** - Runs custom functions and API calls
5. **Model Connector** - Interfaces with local LLMs via LM Studio API

### Supported Agent Types

| Type | Use Case | Best For |
|------|----------|----------|
| `conversational` | Chat-based interactions | Customer support, companionship |
| `task-oriented` | Workflow automation | Data processing, form filling |
| `knowledge` | Information retrieval | Research assistants, Q&A bots |
| `creative` | Content generation | Writing, coding, brainstorming |

## Configuration

### Agent Configuration (agent.yaml)

```yaml
version: "1.0"
name: "My Assistant"
type: "conversational"

model:
  provider: "local"  # Uses LM Studio's local models
  model_id: "meta-llama/Meta-Llama-3-8B-Instruct"
  
parameters:
  temperature: 0.7
  max_tokens: 2048
  top_p: 0.9
  
memory:
  type: "context_window"
  retention_size: 1000  # tokens
  
tools:
  - name: "file_reader"
    path: "./tools/file_reader.js"
    enabled: true
    
logging:
  level: "info"  # debug, info, warn, error
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LM_API_URL` | LM Studio API endpoint | `http://localhost:1234/v1` |
| `LM_API_KEY` | API authentication token | `sk-xxx` |
| `AGENT_DATA_DIR` | Agent data persistence path | `/root/.lmstudio/agents` |

## Loading Models

The container includes the LM Studio CLI (`lms`) which manages the headless server. Based on [LM Studio's headless mode documentation](https://lmstudio.ai/docs/developer/core/headless), models can be loaded on-demand via JIT (Just-In-Time) loading.

### Option 1: Download and Load Models via CLI

SSH into the container and use these commands:

```bash
# List available downloaded models
lms models list

# Download a new model from Hugging Face
lms download meta-llama/Meta-Llama-3-8B-Instruct

# Start the headless server (runs on port 1234 by default)
lms server start --port 1234 --cors --bind 0.0.0.0 &
```

With JIT loading enabled, models are automatically loaded into memory when you make inference calls to `/v1/chat/completions` or other endpoints.

### Option 2: Pre-load Models via Volume Mount

If you have models already downloaded on your host:

```bash
# On host, ensure models exist in ~/.lmstudio/models
ls ~/.lmstudio/models

# Run container with mounted model data
docker run -d \
  --name lmstudio-agents \
  --gpus all \
  -p 22:22 \
  -p 1234:1234 \
  ghcr.io/raine-works/lmstudio-cuda:latest
```

### Model Storage Location

Models are stored in `/root/.lmstudio/models` inside the container. Use volume mounts to persist or preload models.

## Development Workflow

### 1. Initialize Project
```bash
lms agent init research-assistant
cd research-assistant
```

### 2. Edit Configuration
Edit `agent.yaml` to configure your agent's behavior.

### 3. Create Prompts
Add prompt templates in the `prompts/` directory:

```yaml
# prompts/system.yaml
name: "System Prompt"
description: "The assistant's persona"

content: |
  You are a helpful research assistant with expertise in science and technology.
  Use clear, concise language. Cite sources when available.

# prompts/user_template.yaml
name: "User Input Template"
content: |
  User Query: {{user_input}}
  
  Please respond based on your system prompt.
```

### 4. Add Custom Tools (Optional)
Create tool scripts in the `tools/` directory:

```javascript
// tools/calculator.js
module.exports = {
  name: "calculator",
  description: "Perform mathematical calculations",
  execute: async (params) => {
    const { expression } = params;
    try {
      // Note: Use safe evaluation for production
      return { result: eval(expression) };
    } catch (error) {
      return { error: "Invalid calculation" };
    }
  }
};
```

### 5. Test Locally
```bash
lms agent test --message "Hello, how are you?" ./agent.yaml
```

### 6. Deploy to Docker

First, ensure the agent has the correct API configuration and the server is running:

```yaml
# agent.yaml
model:
  provider: "local"
  model_id: "meta-llama/Meta-Llama-3-8B-Instruct"
  
api:
  url: "http://localhost:1234/v1"  # LM Studio API endpoint
```

```yaml
# agent.yaml
model:
  provider: "local"
  model_id: "meta-llama/Meta-Llama-3-8B-Instruct"
  
api:
  url: "http://localhost:1234/v1"  # LM Studio API endpoint
```

Then build and run:

```bash
# Build the image with your agent
docker build -f Agentfile . -t my-agent:latest

# Run with data persistence
docker run -d \
  --name my-agent-container \
  --gpus all \
  -p 8000:8000 \
  -v ./data:/app/data \
  my-agent:latest
```

## Agentfile (Docker Build)

Create an `Agentfile` in your agent project:

```dockerfile
# Build stage
FROM ghcr.io/raine-works/lmstudio-cuda:latest AS builder

WORKDIR /build
COPY . .

RUN lms agent build -o /output/agent.tar.gz

# Runtime stage
FROM ghcr.io/raine-works/lmstudio-cuda:latest

WORKDIR /app
COPY --from=builder /output/agent.tar.gz ./agent.tar.gz

EXPOSE 8000

CMD ["lms", "agent", "run", "./agent.tar.gz", "--port", "8000"]
```

## GPU Optimization

The CUDA-enabled container supports:

| Feature | Configuration |
|---------|---------------|
| GPU Memory | Auto-managed by LM Studio |
| Quantization | 4-bit, 6-bit, 8-bit GGUF formats |
| Batch Size | Adjust via `max_tokens` parameter |
| Parallel Inference | Enabled automatically when available |

Optimize performance by:
1. Using quantized models (GGUF Q4_K_M or Q5_K_M recommended)
2. Setting appropriate `max_tokens` based on GPU VRAM
3. Using `temperature: 0.0` for deterministic outputs

## Troubleshooting

### Common Issues

**Agent not starting**
- Verify LM Studio daemon is running: `lms daemon status`
- Check model is loaded: `lms server models list`

**GPU not detected**
- Ensure `--gpus all` flag is present in docker run
- Verify NVIDIA drivers: `nvidia-smi` (inside container)

**Out of memory errors**
- Reduce `max_tokens` in agent configuration
- Use smaller quantized models
- Close other GPU-intensive processes

**Connection refused**
- Confirm port 1234 is exposed and mapped: `-p 1234:1234`
- Ensure the LM Studio daemon is running inside container: `lms daemon status`
- Check container logs for startup errors

### Debug Mode

```bash
# Inside container - verbose agent execution
lms agent run ./agent.yaml --debug --log-level trace

# View LM Studio server logs
lms server logs -f

# Check if API is responding (inside container)
curl http://localhost:1234/v1/models
```

## Accessing LM Studio API from Host Machine

The container exposes the LM Studio API on port 1234. You can access it directly from your host:

```bash
# Test API endpoint (list models)
curl http://localhost:1234/v1/models

# Make a chat completion request
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7
  }'

# Using from local scripts/python
python -c "
import requests
print(requests.get('http://localhost:1234/v1/models').json())
"
```

## Best Practices

1. **Model Selection**: Use quantized models (GGUF) for efficient GPU usage
2. **Context Management**: Keep conversation history concise to maintain performance
3. **Error Handling**: Implement try/catch in custom tools with fallback responses
4. **Persistence**: Mount volumes for `~/.lmstudio` to preserve agent state and model data
5. **Security**: Never expose the LM Studio API port without authentication
6. **Headless Mode**: The container does NOT include a web interface - use SSH for terminal access or the API for programmatic access

## Examples

### Example 1: Research Assistant Agent

A knowledge-focused agent that helps with academic research and information retrieval.

```yaml
# agent.yaml
version: "1.0"
name: "Research Assistant"
type: "knowledge"

model:
  provider: "local"
  model_id: "meta-llama/Meta-Llama-3-8B-Instruct"
  
parameters:
  temperature: 0.3
  max_tokens: 1500
  top_p: 0.9
  
memory:
  type: "context_window"
  retention_size: 2000

system_prompt: |
  You are a research assistant AI with expertise in scientific literature review,
  academic writing, and information synthesis. Always cite sources when available.
  Format responses with clear sections and bullet points for readability.

tools:
  - name: "search_papers"
    path: "./tools/search_papers.js"
    enabled: true
```

```javascript
// tools/search_papers.js
module.exports = {
  name: "search_papers",
  description: "Search for academic papers on a given topic",
  execute: async (params) => {
    const { query, limit = 5 } = params;
    
    // In production, integrate with APIs like Semantic Scholar or arXiv
    return {
      results: [
        { title: `Research on ${query}`, year: 2024, abstract: "Sample abstract..." }
      ]
    };
  }
};
```

### Example 2: Code Assistant Agent

A task-oriented agent specialized for programming tasks with GPU acceleration.

```yaml
# agent.yaml
version: "1.0"
name: "Code Assistant"
type: "task-oriented"

model:
  provider: "local"
  model_id: "meta-llama/Meta-Llama-3-70B-Instruct"  # Higher capability for code
  
parameters:
  temperature: 0.2
  max_tokens: 4096
  
memory:
  type: "context_window"
  retention_size: 3000

tools:
  - name: "execute_code"
    path: "./tools/execute_code.js"
    enabled: true
  - name: "read_file"
    path: "./tools/read_file.js"
    enabled: true
```

```javascript
// tools/execute_code.js
module.exports = {
  name: "execute_code",
  description: "Execute code in a safe sandboxed environment",
  execute: async (params) => {
    const { language, code, input = "" } = params;
    
    try {
      // Safe code execution logic
      if (language === "python") {
        return { output: "Code executed successfully" };
      }
      return { output: `Unsupported language: ${language}` };
    } catch (error) {
      return { error: error.message };
    }
  }
};
```

### Example 3: Conversational Companion Agent

A conversational agent with personality and memory for engaging interactions.

```yaml
# agent.yaml
version: "1.0"
name: "Companion"
type: "conversational"

model:
  provider: "local"
  model_id: "mistralai/Mistral-7B-Instruct-v0.3"
  
parameters:
  temperature: 0.8
  max_tokens: 2048
  top_p: 0.95
  
memory:
  type: "context_window"
  retention_size: 1500

system_prompt: |
  You are a friendly, empathetic conversational companion. Be warm, engaging,
  and maintain consistent personality traits across the conversation.
  
personality:
  tone: "friendly and supportive"
  interests: ["technology", "science", "arts"]
```

## GPU Optimization Guide

The CUDA-enabled container supports:

| Feature | Configuration |
|---------|---------------|
| GPU Memory | Auto-managed by LM Studio |
| Quantization | 4-bit, 6-bit, 8-bit GGUF formats |
| Batch Size | Adjust via `max_tokens` parameter |
| Parallel Inference | Enabled automatically when available |

### VRAM-Based Configuration

| GPU VRAM | Recommended Model | max_tokens | Batch Size |
|----------|-------------------|------------|------------|
| 4 GB | Q4_K_M quantized | 1024-2048 | 1 |
| 6 GB | Q5_K_M quantized | 2048-3072 | 1-2 |
| 8 GB | Q5_K_M or Q8_0 | 3072-4096 | 2-4 |
| 12+ GB | Q8_0 or FP16 | 4096-8192 | 4+ |

### Performance Tuning

```yaml
# agent.yaml with optimized settings for 8GB GPU
version: "1.0"
name: "Optimized Assistant"

model:
  provider: "local"
  model_id: "mistralai/Mistral-7B-Instruct-v0.3-Q5_K_M"  # Quantized

parameters:
  temperature: 0.7
  max_tokens: 3072      # Adjust based on VRAM
  top_p: 0.9            # Sampling parameter
  frequency_penalty: 0.1
  presence_penalty: 0.1
  
memory:
  type: "context_window"
  retention_size: 1500

# GPU-specific optimizations
gpu:
  n_gpu_layers: 32      # Number of layers to offload to GPU
  flash_attn: true      # Enable FlashAttention for faster inference
```

### Monitoring GPU Usage

```bash
# Inside container, monitor GPU usage
watch -n 1 nvidia-smi

# Check available VRAM
nvidia-smi --query-gpu=memory.total,memory.free --format=csv

# Monitor LM Studio server resources
lms server stats
```

## Troubleshooting

### Common Issues

**Agent not starting**
- Verify LM Studio daemon is running: `lms daemon status`
- Check model is loaded: `lms server models list`
- Ensure sufficient GPU memory for the selected model

**GPU not detected**
```bash
# Inside container, verify:
nvidia-smi                      # Should show your GPU
ls /dev/nvidia*                 # Should list NVIDIA devices
lspci | grep -i nvidia          # Check PCI device detection
```

**Out of memory errors**
1. Reduce `max_tokens` in agent configuration
2. Use smaller quantized models (Q4_K_M before Q5_K_M)
3. Enable GPU layer offloading selectively

```yaml
gpu:
  n_gpu_layers: 8  # Reduce from 32 for memory-constrained GPUs
```

**Slow inference**
1. Increase `n_gpu_layers` to offload more layers to GPU
2. Use FlashAttention if supported by your model
3. Ensure CUDA drivers are up to date

### Debug Mode

```bash
# Inside container - verbose agent execution
lms agent run ./agent.yaml --debug --log-level trace

# Monitor LM Studio server logs
lms server logs -f

# Check container health
docker ps | grep lmstudio-cuda
```

## Advanced Deployment

### Multi-Agent Orchestration

Deploy multiple agents with different specialized roles:

```yaml
# docker-compose.yml
version: '3.8'
services:
  code-agent:
    image: ghcr.io/raine-works/lmstudio-cuda:latest
    ports:
      - "1235:1234"
    volumes:
      - ./code-agent:/root/.lmstudio
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ["0"]
              capabilities: [gpu]
    
  research-agent:
    image: ghcr.io/raine-works/lmstudio-cuda:latest
    ports:
      - "1236:1234"
    volumes:
      - ./research-agent:/root/.lmstudio
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ["0"]
              capabilities: [gpu]
```

### Persistent Data Volumes

```bash
# Create named volumes for agent data
docker volume create lmstudio_agents_data

# Run with persistent storage
docker run -d \
  --name lmstudio-agents \
  --gpus all \
  -p 22:22 \
  -p 1234:1234 \
  -v lmstudio_agents_data:/root/.lmstudio \
  ghcr.io/raine-works/lmstudio-cuda:latest
```

### Backup and Restore

```bash
# Backup agent data
docker run --rm \
  -v lmstudio_agents_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/agent-backup.tar.gz -C /data .

# Restore agent data
docker run --rm \
  -v lmstudio_agents_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/agent-backup.tar.gz -C /data
```

---

---

## Headless Mode Reference

Based on [LM Studio's headless mode documentation](https://lmstudio.ai/docs/developer/core/headless):

| Feature | Description |
|---------|-------------|
| `lms server start` | Starts the LLM server without GUI (runs on port 1234) |
| `lms models list` | Lists all downloaded models |
| `lms download <model>` | Downloads a model from Hugging Face |
| `--cors --bind 0.0.0.0` | Enable CORS and bind to all interfaces |

### Just-In-Time (JIT) Model Loading

When using the LM Studio server in headless mode:

- Calls to `/v1/models` return all downloaded models
- Inference endpoints load models on demand into memory
- Models auto-unload after a period of inactivity

This allows efficient resource usage - you can have many models downloaded and only load the ones you're actively using.

*For general LM Studio documentation, visit https://lmstudio.ai/docs*
