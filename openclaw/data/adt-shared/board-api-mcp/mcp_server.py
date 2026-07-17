"""
ADT Board API MCP stdio bridge.
Runs inside the openclaw container; calls http://board-api:3000 via HTTP.
Exposes board-api endpoints as MCP tools for all 7 ADT agents.
"""

import asyncio
import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

BOARD_API_BASE = "http://board-api:3000"

server = Server("board-api")


def http_get(path: str) -> Any:
    url = BOARD_API_BASE + path
    with urllib.request.urlopen(url, timeout=10) as resp:
        return json.loads(resp.read())


def http_post(path: str, body: dict) -> tuple[int, Any]:
    url = BOARD_API_BASE + path
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def http_patch(path: str, body: dict) -> tuple[int, Any]:
    url = BOARD_API_BASE + path
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="PATCH")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


TOOLS = [
    Tool(
        name="board_get_ready_tickets",
        description="Get all tickets that are ready to be claimed by a specific agent role. Returns only tickets where all dependencies are done.",
        inputSchema={
            "type": "object",
            "properties": {"owner": {"type": "string", "description": "Agent role id (e.g. 'backend', 'frontend', 'uiux')"}},
            "required": ["owner"],
        },
    ),
    Tool(
        name="board_claim_ticket",
        description="Atomically claim a ready ticket. Returns 409 if already claimed or dependencies not met.",
        inputSchema={
            "type": "object",
            "properties": {
                "ticket_id": {"type": "string"},
                "agent": {"type": "string", "description": "Your agent role id"},
            },
            "required": ["ticket_id", "agent"],
        },
    ),
    Tool(
        name="board_get_ticket",
        description="Get full details of a ticket including comments.",
        inputSchema={
            "type": "object",
            "properties": {"ticket_id": {"type": "string"}},
            "required": ["ticket_id"],
        },
    ),
    Tool(
        name="board_list_tickets",
        description="List tickets with optional filters.",
        inputSchema={
            "type": "object",
            "properties": {
                "status": {"type": "string"},
                "owner": {"type": "string"},
                "type": {"type": "string"},
            },
        },
    ),
    Tool(
        name="board_transition_ticket",
        description="Transition a ticket to a new status. The transition must be valid for your agent role.",
        inputSchema={
            "type": "object",
            "properties": {
                "ticket_id": {"type": "string"},
                "agent": {"type": "string"},
                "to": {"type": "string", "description": "Target status"},
            },
            "required": ["ticket_id", "agent", "to"],
        },
    ),
    Tool(
        name="board_create_ticket",
        description="Create a new ticket (project-lead use only).",
        inputSchema={
            "type": "object",
            "properties": {
                "id": {"type": "string"},
                "type": {"type": "string"},
                "title": {"type": "string"},
                "parent": {"type": "string"},
                "owner": {"type": "string"},
                "status": {"type": "string"},
                "priority": {"type": "string"},
                "estimate": {"type": "string"},
                "created": {"type": "string"},
                "acceptance": {"type": "array", "items": {"type": "string"}},
                "depends_on": {"type": "array", "items": {"type": "string"}},
                "blocks": {"type": "array", "items": {"type": "string"}},
                "body": {"type": "string"},
            },
            "required": ["id", "type", "title"],
        },
    ),
    Tool(
        name="board_update_ticket",
        description="Update ticket fields (project-lead use only).",
        inputSchema={
            "type": "object",
            "properties": {
                "ticket_id": {"type": "string"},
                "title": {"type": "string"},
                "parent": {"type": "string"},
                "owner": {"type": "string"},
                "status": {"type": "string"},
                "priority": {"type": "string"},
                "estimate": {"type": "string"},
                "acceptance": {"type": "array", "items": {"type": "string"}},
                "depends_on": {"type": "array", "items": {"type": "string"}},
                "blocks": {"type": "array", "items": {"type": "string"}},
                "body": {"type": "string"},
            },
            "required": ["ticket_id"],
        },
    ),
    Tool(
        name="board_get_board",
        description="Get full board snapshot grouped by status column.",
        inputSchema={"type": "object", "properties": {}},
    ),
    Tool(
        name="board_add_comment",
        description=(
            "Post a comment on a ticket. This is the agent-to-agent messaging channel. "
            "Types: 'handoff', 'question', 'escalation' are actionable "
            "and REQUIRE a 'to' recipient; 'info'/'comment' are non-actionable notes. Set 'notify' "
            "to also flag additional agents. Set 'from_ticket' on a handoff to reference the source ticket."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "ticket_id": {"type": "string", "description": "Ticket the comment is posted on (the destination ticket for a handoff)"},
                "author": {"type": "string", "description": "Your agent role id"},
                "type": {
                    "type": "string",
                    "enum": ["handoff", "question", "escalation", "info", "comment", "status_change"],
                },
                "body": {"type": "string"},
                "to": {"type": "string", "description": "Recipient agent role id — required for handoff/question/escalation"},
                "notify": {"type": "array", "items": {"type": "string"}, "description": "Additional agent role ids to notify"},
                "from_ticket": {"type": "string", "description": "Source ticket id for a cross-ticket handoff (optional)"},
            },
            "required": ["ticket_id", "author", "body"],
        },
    ),
    Tool(
        name="board_get_unread",
        description=(
            "Get comments addressed to you (via 'to' or 'notify') that you have not yet acked. "
            "This is the heartbeat notification poll agents run to find comments addressed to them. "
            "Each result carries its parent ticket's id, title, and status. After handling a comment, "
            "call board_ack_comment."
        ),
        inputSchema={
            "type": "object",
            "properties": {"agent": {"type": "string", "description": "Your agent role id"}},
            "required": ["agent"],
        },
    ),
    Tool(
        name="board_ack_comment",
        description="Mark a comment as read/handled by you. Idempotent. Removes it from your board_get_unread results.",
        inputSchema={
            "type": "object",
            "properties": {
                "comment_id": {"type": "integer"},
                "agent": {"type": "string", "description": "Your agent role id"},
            },
            "required": ["comment_id", "agent"],
        },
    ),
    Tool(
        name="board_get_deps",
        description="Get dependency status for a ticket — which deps are done, which are blocking.",
        inputSchema={
            "type": "object",
            "properties": {"ticket_id": {"type": "string"}},
            "required": ["ticket_id"],
        },
    ),
]


@server.list_tools()
async def list_tools():
    return TOOLS


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    try:
        result = _dispatch(name, arguments)
        return [TextContent(type="text", text=json.dumps(result, indent=2))]
    except Exception as e:
        return [TextContent(type="text", text=json.dumps({"error": str(e)}))]


def _dispatch(name: str, args: dict) -> Any:
    if name == "board_get_ready_tickets":
        owner = args["owner"]
        return http_get(f"/tickets/ready?owner={urllib.parse.quote(owner)}")

    elif name == "board_claim_ticket":
        status, body = http_post(f"/tickets/{args['ticket_id']}/claim", {"agent": args["agent"]})
        return {"status_code": status, "body": body}

    elif name == "board_get_ticket":
        return http_get(f"/tickets/{args['ticket_id']}")

    elif name == "board_list_tickets":
        params = {k: v for k, v in args.items() if v is not None}
        qs = urllib.parse.urlencode(params)
        return http_get(f"/tickets{'?' + qs if qs else ''}")

    elif name == "board_transition_ticket":
        status, body = http_post(
            f"/tickets/{args['ticket_id']}/transition",
            {"agent": args["agent"], "to": args["to"]},
        )
        return {"status_code": status, "body": body}

    elif name == "board_create_ticket":
        ticket_id = args.pop("ticket_id", None) or args.get("id")
        status, body = http_post("/tickets", args)
        return {"status_code": status, "body": body}

    elif name == "board_update_ticket":
        ticket_id = args.pop("ticket_id")
        status, body = http_patch(f"/tickets/{ticket_id}", args)
        return {"status_code": status, "body": body}

    elif name == "board_get_board":
        return http_get("/board")

    elif name == "board_add_comment":
        ticket_id = args.pop("ticket_id")
        status, body = http_post(f"/tickets/{ticket_id}/comments", args)
        return {"status_code": status, "body": body}

    elif name == "board_get_unread":
        agent = args["agent"]
        return http_get(f"/agents/{urllib.parse.quote(agent)}/unread")

    elif name == "board_ack_comment":
        status, body = http_post(f"/comments/{args['comment_id']}/ack", {"agent": args["agent"]})
        return {"status_code": status, "body": body}

    elif name == "board_get_deps":
        return http_get(f"/tickets/{args['ticket_id']}/deps")

    else:
        raise ValueError(f"Unknown tool: {name}")


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
