"""Collaboration module - SQLite storage for todo lists, todos, and invitations.

Uses a shared SQLite database because Jac's walker:priv model isolates each
user's graph, making cross-user collaboration impossible within the graph alone.
"""

import os;
import sqlite3;
import from uuid { uuid4 }

glob AUTH_DB: str = os.path.join(".jac", "data", "main.db");
glob COLLAB_DB: str = os.path.join(".jac", "data", "collab.db");


"""Get a connection to the collaboration database."""
def _conn -> sqlite3.Connection {
    os.makedirs(os.path.dirname(COLLAB_DB), exist_ok=True);
    conn = sqlite3.connect(COLLAB_DB);
    conn.row_factory = sqlite3.Row;
    conn.execute("PRAGMA journal_mode=WAL");
    conn.execute("PRAGMA foreign_keys=ON");
    return conn;
}


"""Create tables if they don't exist."""
def init_db -> None {
    conn = _conn();
    c = conn.cursor();
    c.execute("""CREATE TABLE IF NOT EXISTS todo_lists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        owner TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""");
    c.execute("""CREATE TABLE IF NOT EXISTS list_members (
        list_id TEXT NOT NULL,
        username TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        PRIMARY KEY (list_id, username),
        FOREIGN KEY (list_id) REFERENCES todo_lists(id) ON DELETE CASCADE
    )""");
    c.execute("""CREATE TABLE IF NOT EXISTS todos (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        category TEXT DEFAULT 'other',
        priority TEXT DEFAULT 'medium',
        order_num INTEGER DEFAULT 0,
        completed_by TEXT DEFAULT '',
        FOREIGN KEY (list_id) REFERENCES todo_lists(id) ON DELETE CASCADE
    )""");
    c.execute("""CREATE TABLE IF NOT EXISTS invitations (
        id TEXT PRIMARY KEY,
        from_user TEXT NOT NULL,
        to_user TEXT NOT NULL,
        list_id TEXT NOT NULL,
        list_title TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""");
    conn.commit();
    conn.close();
}


# ---- User helpers ----

"""Check if a username exists in the Jac auth DB."""
def user_exists(username: str) -> bool {
    if not os.path.exists(AUTH_DB) {
        return False;
    }
    conn = sqlite3.connect(AUTH_DB);
    row = conn.execute(
        "SELECT 1 FROM users WHERE username = ? AND username != '__guest__'",
        (username,)
    ).fetchone();
    conn.close();
    return row is not None;
}


"""Look up username from root_id in the Jac auth DB."""
def get_username_by_root_id(root_id: str) -> str {
    if not os.path.exists(AUTH_DB) {
        return "";
    }
    conn = sqlite3.connect(AUTH_DB);
    row = conn.execute(
        "SELECT username FROM users WHERE root_id = ?", (root_id,)
    ).fetchone();
    conn.close();
    return row[0] if row else "";
}


# ---- List CRUD ----

"""Create a new todo list and add owner as member."""
def create_list(title: str, owner: str) -> dict {
    list_id = str(uuid4());
    conn = _conn();
    conn.execute(
        "INSERT INTO todo_lists (id, title, owner) VALUES (?, ?, ?)",
        (list_id, title, owner)
    );
    conn.execute(
        "INSERT INTO list_members (list_id, username, role) VALUES (?, ?, 'owner')",
        (list_id, owner)
    );
    conn.commit();
    conn.close();
    return {"id": list_id, "title": title, "owner": owner, "shared_with": []};
}


"""Get all lists a user owns or is a member of."""
def get_user_lists(username: str) -> list {
    conn = _conn();
    rows = conn.execute(
        """SELECT DISTINCT tl.id, tl.title, tl.owner
           FROM todo_lists tl
           JOIN list_members lm ON tl.id = lm.list_id
           WHERE lm.username = ?
           ORDER BY tl.created_at""",
        (username,)
    ).fetchall();
    result: list = [];
    for r in rows {
        members = conn.execute(
            "SELECT username, role FROM list_members WHERE list_id = ?",
            (r["id"],)
        ).fetchall();
        shared = [m["username"] for m in members if m["username"] != r["owner"]];
        todo_count = conn.execute(
            "SELECT COUNT(*) as cnt FROM todos WHERE list_id = ? AND completed = 0",
            (r["id"],)
        ).fetchone()["cnt"];
        result.append({
            "id": r["id"],
            "title": r["title"],
            "owner": r["owner"],
            "shared_with": shared,
            "todo_count": todo_count
        });
    }
    conn.close();
    return result;
}


"""Rename a list. Only owner can rename."""
def rename_list(list_id: str, title: str, username: str) -> dict {
    conn = _conn();
    row = conn.execute(
        "SELECT owner FROM todo_lists WHERE id = ?", (list_id,)
    ).fetchone();
    if not row or row["owner"] != username {
        conn.close();
        return {"error": "Not authorized"};
    }
    conn.execute("UPDATE todo_lists SET title = ? WHERE id = ?", (title, list_id));
    conn.commit();
    conn.close();
    return {"id": list_id, "title": title};
}


"""Delete a list. Only owner can delete."""
def delete_list(list_id: str, username: str) -> dict {
    conn = _conn();
    row = conn.execute(
        "SELECT owner FROM todo_lists WHERE id = ?", (list_id,)
    ).fetchone();
    if not row or row["owner"] != username {
        conn.close();
        return {"error": "Not authorized"};
    }
    conn.execute("DELETE FROM todos WHERE list_id = ?", (list_id,));
    conn.execute("DELETE FROM list_members WHERE list_id = ?", (list_id,));
    conn.execute("DELETE FROM invitations WHERE list_id = ?", (list_id,));
    conn.execute("DELETE FROM todo_lists WHERE id = ?", (list_id,));
    conn.commit();
    conn.close();
    return {"deleted": list_id};
}


"""Check if a user can access a list."""
def can_access_list(username: str, list_id: str) -> bool {
    conn = _conn();
    row = conn.execute(
        "SELECT 1 FROM list_members WHERE list_id = ? AND username = ?",
        (list_id, username)
    ).fetchone();
    conn.close();
    return row is not None;
}


"""Check if a user is the owner of a list."""
def is_list_owner(username: str, list_id: str) -> bool {
    conn = _conn();
    row = conn.execute(
        "SELECT 1 FROM todo_lists WHERE id = ? AND owner = ?",
        (list_id, username)
    ).fetchone();
    conn.close();
    return row is not None;
}


# ---- Todo CRUD ----

"""Add a todo to a list."""
def add_todo(list_id: str, title: str, category: str, priority: str) -> dict {
    conn = _conn();
    max_order = conn.execute(
        "SELECT COALESCE(MAX(order_num), -1) + 1 FROM todos WHERE list_id = ? AND priority = ?",
        (list_id, priority)
    ).fetchone()[0];
    todo_id = str(uuid4());
    conn.execute(
        """INSERT INTO todos (id, list_id, title, completed, category, priority, order_num, completed_by)
           VALUES (?, ?, ?, 0, ?, ?, ?, '')""",
        (todo_id, list_id, title, category, priority, max_order)
    );
    conn.commit();
    conn.close();
    return {
        "id": todo_id,
        "title": title,
        "completed": False,
        "category": category,
        "priority": priority,
        "order": max_order,
        "completed_by": ""
    };
}


"""Get all todos for a list."""
def get_todos(list_id: str) -> list {
    conn = _conn();
    rows = conn.execute(
        "SELECT * FROM todos WHERE list_id = ? ORDER BY priority, order_num",
        (list_id,)
    ).fetchall();
    conn.close();
    return [
        {
            "id": r["id"],
            "title": r["title"],
            "completed": bool(r["completed"]),
            "category": r["category"],
            "priority": r["priority"],
            "order": r["order_num"],
            "completed_by": r["completed_by"]
        }
        for r in rows
    ];
}


"""Toggle a todo's completed status and record who completed it."""
def toggle_todo(todo_id: str, username: str) -> dict {
    conn = _conn();
    row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone();
    if not row {
        conn.close();
        return {"error": "Not found"};
    }
    new_completed = 0 if row["completed"] else 1;
    completed_by = username if new_completed else "";
    conn.execute(
        "UPDATE todos SET completed = ?, completed_by = ? WHERE id = ?",
        (new_completed, completed_by, todo_id)
    );
    conn.commit();
    conn.close();
    return {"id": todo_id, "completed": bool(new_completed), "completed_by": completed_by};
}


"""Delete a todo."""
def delete_todo(todo_id: str) -> dict {
    conn = _conn();
    conn.execute("DELETE FROM todos WHERE id = ?", (todo_id,));
    conn.commit();
    conn.close();
    return {"deleted": todo_id};
}


"""Update a todo's priority."""
def update_todo_priority(todo_id: str, priority: str) -> dict {
    conn = _conn();
    conn.execute("UPDATE todos SET priority = ? WHERE id = ?", (priority, todo_id));
    conn.commit();
    row = conn.execute("SELECT * FROM todos WHERE id = ?", (todo_id,)).fetchone();
    conn.close();
    if not row {
        return {"error": "Not found"};
    }
    return {"id": todo_id, "priority": priority, "order": row["order_num"]};
}


"""Batch update order and priority for todos."""
def reorder_todos(updates: list) -> dict {
    conn = _conn();
    for upd in updates {
        conn.execute(
            "UPDATE todos SET order_num = ?, priority = ? WHERE id = ?",
            (upd["order"], upd["priority"], upd["id"])
        );
    }
    conn.commit();
    conn.close();
    return {"done": True};
}


"""Add multiple ingredient todos to a list."""
def add_ingredient_todos(list_id: str, ingredients: list, priority: str) -> list {
    conn = _conn();
    max_order = conn.execute(
        "SELECT COALESCE(MAX(order_num), -1) + 1 FROM todos WHERE list_id = ? AND priority = ?",
        (list_id, priority)
    ).fetchone()[0];
    result: list = [];
    for ing in ingredients {
        todo_id = str(uuid4());
        title = f"Buy {ing['quantity']} {ing['unit']} {ing['name']}";
        conn.execute(
            """INSERT INTO todos (id, list_id, title, completed, category, priority, order_num, completed_by)
               VALUES (?, ?, ?, 0, 'shopping', ?, ?, '')""",
            (todo_id, list_id, title, priority, max_order)
        );
        result.append({
            "id": todo_id,
            "title": title,
            "completed": False,
            "category": "shopping",
            "priority": priority,
            "order": max_order,
            "completed_by": ""
        });
        max_order += 1;
    }
    conn.commit();
    conn.close();
    return result;
}


# ---- Invitation CRUD ----

"""Create an invitation to share a list."""
def create_invitation(from_user: str, to_user: str, list_id: str) -> dict {
    if not user_exists(to_user) {
        return {"error": "User not found"};
    }
    if from_user == to_user {
        return {"error": "Cannot share with yourself"};
    }
    conn = _conn();
    # Check list exists and user is owner
    row = conn.execute(
        "SELECT * FROM todo_lists WHERE id = ? AND owner = ?",
        (list_id, from_user)
    ).fetchone();
    if not row {
        conn.close();
        return {"error": "List not found or not owner"};
    }
    # Check not already a member
    existing = conn.execute(
        "SELECT 1 FROM list_members WHERE list_id = ? AND username = ?",
        (list_id, to_user)
    ).fetchone();
    if existing {
        conn.close();
        return {"error": "User is already a member"};
    }
    # Check for pending invitation
    pending = conn.execute(
        "SELECT 1 FROM invitations WHERE list_id = ? AND to_user = ? AND status = 'pending'",
        (list_id, to_user)
    ).fetchone();
    if pending {
        conn.close();
        return {"error": "Invitation already pending"};
    }
    inv_id = str(uuid4());
    conn.execute(
        "INSERT INTO invitations (id, from_user, to_user, list_id, list_title, status) VALUES (?, ?, ?, ?, ?, 'pending')",
        (inv_id, from_user, to_user, list_id, row["title"])
    );
    conn.commit();
    conn.close();
    return {
        "id": inv_id,
        "from_user": from_user,
        "to_user": to_user,
        "list_title": row["title"],
        "status": "pending"
    };
}


"""Get pending invitations for a user."""
def get_invitations(username: str) -> list {
    conn = _conn();
    rows = conn.execute(
        "SELECT * FROM invitations WHERE to_user = ? AND status = 'pending' ORDER BY created_at DESC",
        (username,)
    ).fetchall();
    conn.close();
    return [
        {
            "id": r["id"],
            "from_user": r["from_user"],
            "list_id": r["list_id"],
            "list_title": r["list_title"],
            "status": r["status"]
        }
        for r in rows
    ];
}


"""Accept or decline an invitation."""
def respond_to_invitation(invitation_id: str, username: str, accept: bool) -> dict {
    conn = _conn();
    row = conn.execute(
        "SELECT * FROM invitations WHERE id = ? AND to_user = ? AND status = 'pending'",
        (invitation_id, username)
    ).fetchone();
    if not row {
        conn.close();
        return {"error": "Invitation not found"};
    }
    new_status = "accepted" if accept else "declined";
    conn.execute(
        "UPDATE invitations SET status = ? WHERE id = ?",
        (new_status, invitation_id)
    );
    if accept {
        conn.execute(
            "INSERT OR IGNORE INTO list_members (list_id, username, role) VALUES (?, ?, 'member')",
            (row["list_id"], username)
        );
    }
    conn.commit();
    conn.close();
    return {"id": invitation_id, "status": new_status, "list_id": row["list_id"]};
}


"""Get all members of a list."""
def get_list_members(list_id: str) -> list {
    conn = _conn();
    rows = conn.execute(
        "SELECT username, role FROM list_members WHERE list_id = ? ORDER BY role DESC, username",
        (list_id,)
    ).fetchall();
    conn.close();
    return [{"username": r["username"], "role": r["role"]} for r in rows];
}


"""Remove a member from a list. Only owner can remove."""
def remove_member(list_id: str, username: str, requester: str) -> dict {
    conn = _conn();
    row = conn.execute(
        "SELECT owner FROM todo_lists WHERE id = ?", (list_id,)
    ).fetchone();
    if not row or row["owner"] != requester {
        conn.close();
        return {"error": "Not authorized"};
    }
    if username == requester {
        conn.close();
        return {"error": "Cannot remove yourself"};
    }
    conn.execute(
        "DELETE FROM list_members WHERE list_id = ? AND username = ?",
        (list_id, username)
    );
    conn.commit();
    conn.close();
    return {"removed": username};
}


"""Ensure user has at least one list. Returns the first list ID."""
def ensure_default_list(username: str) -> str {
    conn = _conn();
    row = conn.execute(
        """SELECT tl.id FROM todo_lists tl
           JOIN list_members lm ON tl.id = lm.list_id
           WHERE lm.username = ? ORDER BY tl.created_at LIMIT 1""",
        (username,)
    ).fetchone();
    if row {
        conn.close();
        return row["id"];
    }
    # Create default list
    list_id = str(uuid4());
    conn.execute(
        "INSERT INTO todo_lists (id, title, owner) VALUES (?, 'My Tasks', ?)",
        (list_id, username)
    );
    conn.execute(
        "INSERT INTO list_members (list_id, username, role) VALUES (?, ?, 'owner')",
        (list_id, username)
    );
    conn.commit();
    conn.close();
    return list_id;
}


# Initialize DB on import — use glob assignment to trigger at module load
glob _db_initialized: bool = (lambda: (init_db(), True)[1])();
