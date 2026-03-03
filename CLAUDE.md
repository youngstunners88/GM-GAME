# Claude Code Configuration for Zo Computer

## Project Context

This is your Zo Computer workspace. You have full access to all files, tools, and skills.

## Environment

- Working directory: `/home/workspace`
- Skills directory: `/home/workspace/Skills`
- Secrets stored in: `/home/.z/secrets.json`

## Available Skills (50+ agents and tools)

### Orchestration & Multi-Agent
- **agent-orchestra**: Master orchestrator coordinating ShieldGuard, BugHunter, DocMaster, and Obsidian agents
- **antfarm**: Multi-agent workflow orchestration with battle-tested patterns
- **agent-lightning**: RL-based learning system that improves with every task
- **commander**: Master command agent that launches and coordinates other agents

### iHhashi Delivery Platform
- **ihhashi-orchestrator**: Master orchestrator for iHhashi agent team
- **ihhashi-sync**: Syncs all iHhashi agents with latest app information
- **sa-brand-agent**: South African brand enforcement for iHhashi
- **quality-agent**: QA agent for iHhashi standards validation

### Trading & Crypto
- **bankr**: AI-powered crypto trading via natural language
- **trading-bot**: Autonomous crypto trading with technical analysis
- **crypto-trading-bot**: Memecoin detection, copy trading, arbitrage
- **solana-trader**: Solana wallet management and Jupiter DEX trading
- **token-scout**: Token scouting and scam detection
- **token-discovery**: Discover and analyze new tokens across chains
- **clawrouter-leadership**: Command Clawrouter and Antfarm for decentralized trading

### Code & Development
- **free-claude-code**: Run Claude Code for FREE using local Ollama models
- **ollama-coder**: Free local code generation using Ollama
- **claude-code-capabilities**: Full orchestration with TodoWrite and Task tool
- **claude-code-essentials**: Essential configuration for Claude Code
- **claude-code-skills-pack**: Complete skills pack with Antfarm integration
- **bug-hunter**: Testing and bug detection agent

### Creative & Marketing
- **creativeforge**: Comprehensive creative generation for images, videos, content
- **cinematic-video**: Create cinematic narrative videos
- **cinematic-director**: Master-level cinematic video creation
- **marketing-expert**: Marketing strategist and creative powerhouse
- **larry**: Automate TikTok slideshow marketing
- **portfolio-builder**: Build professional portfolio websites

### Automation & Integration
- **openfang-apis**: Gateway to 1400+ public APIs
- **tinyfish-web-agent**: Autonomous web automation
- **tinyfish-competitor-monitor**: Monitor competitor prices
- **agenticseek-integration**: Fully local autonomous AI agent

### Knowledge & Memory
- **vault-commands**: AI-powered slash commands for notes vault
- **zo-memory**: Persistent conversation memory system
- **obsidian-sync**: Obsidian vault management agent
- **agentskill-retriever**: Retrieve skills from 90,000+ agent skills

### Operations
- **shield-guard**: Security agent for API key management
- **doc-master**: Documentation and GitHub management
- **outreach-engine**: Automated lead outreach system
- **pain-point-hunter**: Discover client pain points and build solutions
- **smart-solver**: Intelligent problem-solving with fallback chains
- **digital-citadel**: Identity preservation for AI agents
- **prd-creator**: Create Product Requirements Documents

### Project-Specific
- **boober-strengthener**: Strengthens Boober taxi safety app
- **conway-agent**: Interact with Conway Research AI agent ecosystem
- **ihhashi-sync**: Sync iHhashi agents with app updates

## Key Projects

### iHhashi (Delivery Platform)
- Location: `/home/workspace/iHhashi`
- Type: Delivery platform for groceries, food, courier services
- NOT a taxi app, NOT related to Boober

### Boober (Taxi Safety App)
- Location: `/home/workspace/Boober`
- Type: Taxi safety application

### Clawrouter/ClawWork
- Location: `/home/workspace/ClawWork`
- Type: AI coding assistant evaluation framework

## How to Use Skills

Skills are located in `/home/workspace/Skills/<skill-name>/`. Each skill has:
- `SKILL.md` - Instructions and metadata
- `scripts/` - Executable scripts (run with `bun script.ts`)
- `references/` - Detailed documentation
- `assets/` - Static resources

To use a skill:
1. Read the SKILL.md file
2. Run scripts as directed
3. Follow the instructions in the skill

## Preferences

- Use South African English for iHhashi-related content
- Always run vault-commands for context on conversation start
- Log important exchanges to zo-memory
- Follow the Smart Solver Protocol when tools fail
