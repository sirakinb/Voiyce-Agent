"""
Voiyce Agent Backend — FastAPI server using Claude Agent SDK + Composio.

Runs locally, auto-launched by the Swift app. Uses the Claude Agent SDK
with Composio's MCP provider for productivity tool integrations.
"""

import json
import asyncio
import logging
import os
from typing import AsyncGenerator

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("voiyce")

app = FastAPI(title="Voiyce Agent Backend")

DEFAULT_PORT = 8435

SYSTEM_PROMPT = (
    "You are Voiyce, an AI assistant for knowledge work. You help users "
    "manage emails, calendars, tasks, documents, and other productivity "
    "tools through natural conversation. When you need to interact with "
    "external services, use the tools provided. Always explain what "
    "you're doing in plain language. Keep responses concise and actionable."
)


# ---------------------------------------------------------------------------
# Claude Agent SDK + Composio MCP
# ---------------------------------------------------------------------------

async def run_agent_sdk(
    message: str,
    claude_key: str,
    composio_key: str,
    session_id: str | None = None,
) -> AsyncGenerator[dict, None]:
    """Run Claude Agent SDK with Composio tools via in-process MCP server."""
    from claude_agent_sdk import (
        ClaudeSDKClient,
        ClaudeAgentOptions,
        AssistantMessage,
        ResultMessage,
        SystemMessage,
        TextBlock,
        create_sdk_mcp_server,
    )

    yield _evt("status", "Starting agent...")

    mcp_servers = {}

    # Set up Composio tools as an in-process MCP server
    if composio_key:
        try:
            from composio import Composio
            from composio_claude_agent_sdk import ClaudeAgentSDKProvider

            yield _evt("status", "Setting up Composio tools...")

            os.environ["COMPOSIO_API_KEY"] = composio_key
            composio = Composio(provider=ClaudeAgentSDKProvider())
            session = composio.create(user_id="voiyce-user")
            tools = session.tools()

            if tools:
                tool_server = create_sdk_mcp_server(
                    name="composio",
                    version="1.0.0",
                    tools=tools,
                )
                mcp_servers["composio"] = tool_server
                logger.info(f"Composio MCP ready with {len(tools)} tools")
                yield _evt("status", f"Loaded {len(tools)} tools")
            else:
                logger.warning("Composio returned no tools")
                yield _evt("status", "No tools available")

        except Exception as e:
            logger.warning(f"Composio setup failed: {e}")
            yield _evt("status", f"Tools unavailable: {e}")

    # Set API key for Agent SDK
    os.environ["ANTHROPIC_API_KEY"] = claude_key

    options = ClaudeAgentOptions(
        system_prompt=SYSTEM_PROMPT,
        model="claude-sonnet-4-6",
        max_turns=10,
        max_budget_usd=2.0,
        permission_mode="bypassPermissions",
        mcp_servers=mcp_servers if mcp_servers else None,
        resume=session_id if session_id else None,
        continue_conversation=True if session_id else False,
    )

    try:
        async with ClaudeSDKClient(options=options) as client:
            await client.query(message)

            last_text = None  # Track last emitted text to deduplicate

            async for msg in client.receive_response():
                if isinstance(msg, AssistantMessage):
                    for block in msg.content:
                        if isinstance(block, TextBlock):
                            if block.text and block.text != last_text:
                                last_text = block.text
                                yield _evt("text", block.text)
                        elif hasattr(block, "name"):
                            yield _evt("status", f"Running {block.name}...")

                elif isinstance(msg, ResultMessage):
                    # Emit session_id so the client can resume this conversation
                    if hasattr(msg, "session_id") and msg.session_id:
                        yield _evt("session_id", msg.session_id)

                    # Only emit if it has new text not already sent
                    if msg.result and msg.result != last_text:
                        last_text = msg.result
                        yield _evt("text", msg.result)

                elif isinstance(msg, SystemMessage):
                    if getattr(msg, "subtype", "") == "init":
                        yield _evt("status", "Agent initialized")

    except Exception as e:
        logger.exception("Agent SDK error")
        yield _evt("error", str(e))

    yield _evt("done", "")


# ---------------------------------------------------------------------------
# Fallback: direct Anthropic SDK (if CLI not available)
# ---------------------------------------------------------------------------

async def run_direct(
    message: str,
    claude_key: str,
    composio_key: str,
) -> AsyncGenerator[dict, None]:
    """Fallback agent loop using Anthropic SDK directly."""
    import anthropic

    client = anthropic.Anthropic(api_key=claude_key)
    messages = [{"role": "user", "content": message}]

    yield _evt("status", "Processing...")

    try:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            messages=messages,
        )
        for block in response.content:
            if block.type == "text":
                yield _evt("text", block.text)
    except Exception as e:
        yield _evt("error", str(e))

    yield _evt("done", "")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _evt(event_type: str, content: str) -> dict:
    return {
        "event": "message",
        "data": json.dumps({"type": event_type, "content": content}),
    }


_cli_available: bool | None = None

async def is_cli_available() -> bool:
    global _cli_available
    if _cli_available is not None:
        return _cli_available
    try:
        proc = await asyncio.create_subprocess_exec(
            "claude", "--version",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.wait()
        _cli_available = proc.returncode == 0
    except FileNotFoundError:
        _cli_available = False
    logger.info(f"Claude CLI available: {_cli_available}")
    return _cli_available


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/chat/sync")
async def chat_sync(request: Request):
    """Non-streaming chat. Returns all events as JSON array.

    Body: {"message": "..."}
    Headers: X-Claude-API-Key (required), X-Composio-API-Key (optional)
    """
    claude_key = request.headers.get("X-Claude-API-Key", "")
    composio_key = request.headers.get("X-Composio-API-Key", "")

    if not claude_key:
        return JSONResponse(status_code=400, content={"error": "X-Claude-API-Key header required"})

    try:
        body = await request.json()
    except Exception:
        return JSONResponse(status_code=400, content={"error": "Invalid JSON"})

    message = body.get("message", "").strip()
    if not message:
        return JSONResponse(status_code=400, content={"error": "message is required"})

    session_id = body.get("session_id")

    events = []

    # Prefer Agent SDK; fall back to direct API if CLI unavailable
    if await is_cli_available():
        logger.info("Using Claude Agent SDK + Composio MCP")
        generator = run_agent_sdk(message, claude_key, composio_key, session_id=session_id)
    else:
        logger.info("Using direct Anthropic SDK (fallback)")
        generator = run_direct(message, claude_key, composio_key)

    async for sse_event in generator:
        data = json.loads(sse_event["data"])
        events.append(data)
        if data.get("type") == "done":
            break

    return JSONResponse(content={"events": events})


@app.get("/health")
async def health():
    cli = await is_cli_available()
    return {"status": "ok", "mode": "agent-sdk" if cli else "direct"}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", DEFAULT_PORT))
    uvicorn.run(app, host="127.0.0.1", port=port)
