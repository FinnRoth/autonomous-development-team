"""
ADT Board API — dependency-aware task board for the Autonomous Development Team.
FastAPI + SQLite (WAL mode). Single worker REQUIRED for write safety.

DB_PATH: /data/board.db (Docker named volume, never a host path)
Port: 3000
"""

from __future__ import annotations

import json
import sqlite3
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional

import aiosqlite
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

DB_PATH = "/data/board.db"

VALID_STATUSES = {"backlog", "ready", "in_progress", "in_review", "qa", "done", "blocked"}
VALID_TYPES = {"epic", "story", "task", "bug"}
VALID_PRIORITIES = {"P0", "P1", "P2", "P3"}
VALID_ESTIMATES = {"S", "M", "L", "XL"}
VALID_AGENTS = {"project-lead", "architect", "backend", "frontend", "uiux", "reviewer", "qa", "unassigned"}

# Allowed transitions per agent role
TRANSITIONS = {
    "project-lead": {
        "backlog": ["ready", "blocked"],
        "ready": ["backlog", "blocked"],
        "in_progress": ["blocked"],
        "in_review": ["blocked"],
        "qa": ["done", "blocked"],
        "blocked": ["ready", "backlog"],
        "done": [],
    },
    "backend": {
        "in_progress": ["in_review", "blocked"],
        "blocked": ["in_progress"],
    },
    "frontend": {
        "in_progress": ["in_review", "blocked"],
        "blocked": ["in_progress"],
    },
    "architect": {
        "in_progress": ["in_review", "blocked"],
        "blocked": ["in_progress"],
    },
    "uiux": {
        "in_progress": ["in_review", "blocked"],
        "blocked": ["in_progress"],
    },
    "reviewer": {
        "in_review": ["qa", "in_progress"],
    },
    "qa": {
        "qa": ["done", "blocked"],
        "blocked": ["qa"],
    },
}

DDL = """
CREATE TABLE IF NOT EXISTS tickets (
    id          TEXT PRIMARY KEY,
    type        TEXT NOT NULL,
    title       TEXT NOT NULL,
    parent      TEXT REFERENCES tickets(id),
    owner       TEXT NOT NULL DEFAULT 'unassigned',
    status      TEXT NOT NULL DEFAULT 'backlog',
    priority    TEXT NOT NULL DEFAULT 'P2',
    estimate    TEXT,
    created     TEXT NOT NULL,
    acceptance  TEXT NOT NULL DEFAULT '[]',
    depends_on  TEXT NOT NULL DEFAULT '[]',
    blocks      TEXT NOT NULL DEFAULT '[]',
    claimed_by  TEXT,
    claimed_at  TEXT,
    updated_at  TEXT NOT NULL,
    body        TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS comments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id   TEXT NOT NULL REFERENCES tickets(id),
    author      TEXT NOT NULL,
    type        TEXT NOT NULL,
    body        TEXT NOT NULL,
    created_at  TEXT NOT NULL
);
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def row_to_ticket(row: sqlite3.Row) -> dict:
    d = dict(row)
    for f in ("acceptance", "depends_on", "blocks"):
        try:
            d[f] = json.loads(d[f]) if d[f] else []
        except (json.JSONDecodeError, TypeError):
            d[f] = []
    return d


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("PRAGMA journal_mode=WAL")
        await db.execute("PRAGMA foreign_keys=ON")
        await db.executescript(DDL)
        await db.commit()
    yield


app = FastAPI(title="ADT Board API", version="1.0.0", lifespan=lifespan)


# ── Pydantic models ────────────────────────────────────────────────────────────

class TicketCreate(BaseModel):
    id: str
    type: str
    title: str
    parent: Optional[str] = None
    owner: str = "unassigned"
    status: str = "backlog"
    priority: str = "P2"
    estimate: Optional[str] = None
    created: Optional[str] = None
    acceptance: list[str] = []
    depends_on: list[str] = []
    blocks: list[str] = []
    body: str = ""


class TicketUpdate(BaseModel):
    type: Optional[str] = None
    title: Optional[str] = None
    parent: Optional[str] = None
    owner: Optional[str] = None
    status: Optional[str] = None
    priority: Optional[str] = None
    estimate: Optional[str] = None
    acceptance: Optional[list[str]] = None
    depends_on: Optional[list[str]] = None
    blocks: Optional[list[str]] = None
    body: Optional[str] = None


class ClaimRequest(BaseModel):
    agent: str


class TransitionRequest(BaseModel):
    agent: str
    to: str


class CommentCreate(BaseModel):
    author: str
    type: str = "comment"
    body: str


# ── Health ─────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    try:
        async with aiosqlite.connect(DB_PATH) as db:
            async with db.execute("SELECT COUNT(*) FROM tickets") as cur:
                row = await cur.fetchone()
                count = row[0] if row else 0
        return {"status": "ok", "sqlite": "ok", "tickets": count}
    except Exception as e:
        raise HTTPException(status_code=503, detail={"status": "error", "sqlite": str(e)})


# ── Tickets CRUD ───────────────────────────────────────────────────────────────

@app.post("/tickets", status_code=201)
async def create_ticket(t: TicketCreate):
    if not t.id or not t.id.replace("-", "").replace("_", "").isalnum():
        raise HTTPException(400, "id must be alphanumeric with hyphens/underscores")
    if t.type not in VALID_TYPES:
        raise HTTPException(400, f"type must be one of {VALID_TYPES}")
    if t.status not in VALID_STATUSES:
        raise HTTPException(400, f"status must be one of {VALID_STATUSES}")
    if t.priority not in VALID_PRIORITIES:
        raise HTTPException(400, f"priority must be one of {VALID_PRIORITIES}")
    if t.estimate and t.estimate not in VALID_ESTIMATES:
        raise HTTPException(400, f"estimate must be one of {VALID_ESTIMATES}")
    created = t.created or now_iso()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("PRAGMA foreign_keys=ON")
        try:
            await db.execute(
                """INSERT INTO tickets
                   (id, type, title, parent, owner, status, priority, estimate,
                    created, acceptance, depends_on, blocks, updated_at, body)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (t.id, t.type, t.title, t.parent, t.owner, t.status, t.priority,
                 t.estimate, created, json.dumps(t.acceptance),
                 json.dumps(t.depends_on), json.dumps(t.blocks), now_iso(), t.body),
            )
            await db.commit()
        except aiosqlite.IntegrityError as e:
            raise HTTPException(409, f"Ticket {t.id} already exists: {e}")
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute("SELECT * FROM tickets WHERE id=?", (t.id,)) as cur:
            row = await cur.fetchone()
    return row_to_ticket(row)


@app.get("/tickets")
async def list_tickets(
    status: Optional[str] = Query(None),
    owner: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
):
    conditions = []
    params = []
    if status:
        conditions.append("status=?")
        params.append(status)
    if owner:
        conditions.append("owner=?")
        params.append(owner)
    if type:
        conditions.append("type=?")
        params.append(type)
    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute(f"SELECT * FROM tickets {where} ORDER BY created ASC", params) as cur:
            rows = await cur.fetchall()
    return [row_to_ticket(r) for r in rows]


@app.get("/tickets/ready")
async def get_ready_tickets(owner: str = Query(...)):
    sql = """
        SELECT t.* FROM tickets t
        WHERE t.owner = ?
          AND t.status = 'ready'
          AND t.claimed_by IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM json_each(t.depends_on) dep
            JOIN tickets dep_t ON dep_t.id = dep.value
            WHERE dep_t.status != 'done'
          )
        ORDER BY
          CASE t.priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 WHEN 'P3' THEN 3 END,
          t.created ASC
    """
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute(sql, (owner,)) as cur:
            rows = await cur.fetchall()
    return [row_to_ticket(r) for r in rows]


@app.get("/tickets/{ticket_id}")
async def get_ticket(ticket_id: str):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            row = await cur.fetchone()
        if not row:
            raise HTTPException(404, f"Ticket {ticket_id} not found")
        async with db.execute(
            "SELECT * FROM comments WHERE ticket_id=? ORDER BY created_at ASC", (ticket_id,)
        ) as cur:
            comments = [dict(r) for r in await cur.fetchall()]
    result = row_to_ticket(row)
    result["comments"] = comments
    return result


@app.patch("/tickets/{ticket_id}")
async def update_ticket(ticket_id: str, u: TicketUpdate):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            existing = await cur.fetchone()
        if not existing:
            raise HTTPException(404, f"Ticket {ticket_id} not found")
        fields = {}
        if u.type is not None:
            fields["type"] = u.type
        if u.title is not None:
            fields["title"] = u.title
        if u.parent is not None:
            fields["parent"] = u.parent
        if u.owner is not None:
            fields["owner"] = u.owner
        if u.status is not None:
            fields["status"] = u.status
        if u.priority is not None:
            fields["priority"] = u.priority
        if u.estimate is not None:
            fields["estimate"] = u.estimate
        if u.acceptance is not None:
            fields["acceptance"] = json.dumps(u.acceptance)
        if u.depends_on is not None:
            fields["depends_on"] = json.dumps(u.depends_on)
        if u.blocks is not None:
            fields["blocks"] = json.dumps(u.blocks)
        if u.body is not None:
            fields["body"] = u.body
        if not fields:
            return row_to_ticket(existing)
        fields["updated_at"] = now_iso()
        set_clause = ", ".join(f"{k}=?" for k in fields)
        await db.execute(
            f"UPDATE tickets SET {set_clause} WHERE id=?",
            list(fields.values()) + [ticket_id],
        )
        await db.commit()
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            row = await cur.fetchone()
    return row_to_ticket(row)


# ── Claim (atomic, race-condition-safe) ────────────────────────────────────────

@app.post("/tickets/{ticket_id}/claim")
async def claim_ticket(ticket_id: str, req: ClaimRequest):
    """
    Atomically claim a ticket. Uses BEGIN IMMEDIATE to prevent two agents
    from claiming the same ticket simultaneously.
    """
    conn = await aiosqlite.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        await conn.execute("PRAGMA foreign_keys=ON")
        await conn.execute("BEGIN IMMEDIATE")
        async with conn.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            row = await cur.fetchone()
        if not row:
            await conn.execute("ROLLBACK")
            raise HTTPException(404, f"Ticket {ticket_id} not found")
        ticket = dict(row)
        if ticket["status"] != "ready":
            await conn.execute("ROLLBACK")
            raise HTTPException(409, {
                "error": "not_claimable",
                "reason": f"ticket status is '{ticket['status']}', not 'ready'",
                "current_status": ticket["status"],
                "claimed_by": ticket.get("claimed_by"),
            })
        if ticket["claimed_by"] is not None:
            await conn.execute("ROLLBACK")
            raise HTTPException(409, {
                "error": "not_claimable",
                "reason": f"ticket already claimed by {ticket['claimed_by']}",
                "current_status": ticket["status"],
                "claimed_by": ticket["claimed_by"],
            })
        # Check all depends_on are done
        deps = json.loads(ticket["depends_on"]) if ticket["depends_on"] else []
        for dep_id in deps:
            async with conn.execute("SELECT status FROM tickets WHERE id=?", (dep_id,)) as cur:
                dep_row = await cur.fetchone()
            if dep_row is None or dep_row["status"] != "done":
                dep_status = dep_row["status"] if dep_row else "not_found"
                await conn.execute("ROLLBACK")
                raise HTTPException(409, {
                    "error": "not_claimable",
                    "reason": f"dependency {dep_id} has status '{dep_status}', not 'done'",
                    "current_status": ticket["status"],
                    "claimed_by": None,
                    "blocking_dep": dep_id,
                    "blocking_dep_status": dep_status,
                })
        ts = now_iso()
        await conn.execute(
            "UPDATE tickets SET status='in_progress', claimed_by=?, claimed_at=?, updated_at=? WHERE id=?",
            (req.agent, ts, ts, ticket_id),
        )
        await conn.commit()
        async with conn.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            updated = await cur.fetchone()
        return row_to_ticket(updated)
    finally:
        await conn.close()


# ── Transition ──────────────────────────────────────────────────────────────────

@app.post("/tickets/{ticket_id}/transition")
async def transition_ticket(ticket_id: str, req: TransitionRequest):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            row = await cur.fetchone()
        if not row:
            raise HTTPException(404, f"Ticket {ticket_id} not found")
        current_status = row["status"]
        agent_transitions = TRANSITIONS.get(req.agent, {})
        allowed = agent_transitions.get(current_status, [])
        if req.to not in allowed:
            # project-lead can always transition to blocked from any state
            if not (req.agent == "project-lead" and req.to == "blocked"):
                raise HTTPException(409, {
                    "error": "invalid_transition",
                    "from": current_status,
                    "to": req.to,
                    "agent": req.agent,
                    "allowed": allowed,
                })
        await db.execute(
            "UPDATE tickets SET status=?, updated_at=? WHERE id=?",
            (req.to, now_iso(), ticket_id),
        )
        await db.commit()
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            updated = await cur.fetchone()
    return row_to_ticket(updated)


# ── Comments ───────────────────────────────────────────────────────────────────

@app.post("/tickets/{ticket_id}/comments", status_code=201)
async def add_comment(ticket_id: str, c: CommentCreate):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT id FROM tickets WHERE id=?", (ticket_id,)) as cur:
            if not await cur.fetchone():
                raise HTTPException(404, f"Ticket {ticket_id} not found")
        await db.execute(
            "INSERT INTO comments (ticket_id, author, type, body, created_at) VALUES (?,?,?,?,?)",
            (ticket_id, c.author, c.type, c.body, now_iso()),
        )
        await db.commit()
        async with db.execute(
            "SELECT * FROM comments WHERE ticket_id=? ORDER BY created_at ASC", (ticket_id,)
        ) as cur:
            rows = await cur.fetchall()
    return [dict(r) for r in rows]


@app.get("/tickets/{ticket_id}/comments")
async def get_comments(ticket_id: str):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT id FROM tickets WHERE id=?", (ticket_id,)) as cur:
            if not await cur.fetchone():
                raise HTTPException(404, f"Ticket {ticket_id} not found")
        db.row_factory = sqlite3.Row
        async with db.execute(
            "SELECT * FROM comments WHERE ticket_id=? ORDER BY created_at ASC", (ticket_id,)
        ) as cur:
            rows = await cur.fetchall()
    return [dict(r) for r in rows]


# ── Dependency graph ───────────────────────────────────────────────────────────

@app.get("/tickets/{ticket_id}/deps")
async def get_deps(ticket_id: str):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute("SELECT * FROM tickets WHERE id=?", (ticket_id,)) as cur:
            row = await cur.fetchone()
        if not row:
            raise HTTPException(404, f"Ticket {ticket_id} not found")
        deps_ids = json.loads(row["depends_on"]) if row["depends_on"] else []
        deps = []
        for dep_id in deps_ids:
            async with db.execute("SELECT id, title, status, owner FROM tickets WHERE id=?", (dep_id,)) as cur:
                dep_row = await cur.fetchone()
            deps.append({
                "id": dep_id,
                "found": dep_row is not None,
                "status": dep_row["status"] if dep_row else None,
                "title": dep_row["title"] if dep_row else None,
                "owner": dep_row["owner"] if dep_row else None,
                "blocking": dep_row is None or dep_row["status"] != "done",
            })
    return {
        "ticket_id": ticket_id,
        "depends_on": deps,
        "all_done": all(d["status"] == "done" for d in deps) if deps else True,
        "blocking_deps": [d["id"] for d in deps if d["blocking"]],
    }


# ── Board snapshot ─────────────────────────────────────────────────────────────

@app.get("/board")
async def get_board():
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        async with db.execute(
            "SELECT * FROM tickets ORDER BY "
            "CASE priority WHEN 'P0' THEN 0 WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 WHEN 'P3' THEN 3 END, "
            "created ASC"
        ) as cur:
            rows = await cur.fetchall()
    tickets = [row_to_ticket(r) for r in rows]
    grouped: dict[str, list] = {s: [] for s in ["backlog", "ready", "in_progress", "in_review", "qa", "done", "blocked"]}
    for t in tickets:
        grouped.setdefault(t["status"], []).append(t)
    return {"columns": grouped, "total": len(tickets)}
