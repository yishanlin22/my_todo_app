# TaskFlow — Multi-User Todo App with AI Meal Planning

**Name:** Yishan Lin
**UMID:** 80379525

## Feature Description

TaskFlow is a collaborative todo application built entirely in Jac. It extends the basic todo app from the tutorial with the following features:

- **Multiple Todo Lists** — Each user can create, rename, and delete multiple todo lists, each with its own set of todos. Different todo lists can be found in navigation bar on the left.
- **Collaboration & Sharing** — Users can share lists with others by username. An invitation system (inbox with accept/decline) manages access. Shared lists display all members alongside the owner, and completed todos show who completed them ("completed by X").
- **AI Todo Categorization** — When a todo is added, an LLM automatically categorizes it (work, shopping, personal, etc.).
- **AI Meal Planner** — Users describe a meal and an LLM generates structured ingredients. These can be added as shopping todos to any list with one click.
- **Priority Levels & Drag-and-Drop Reordering** — Todos have high/medium/low priority and can be reordered via drag-and-drop within or across priority groups.
- **Filtering** — Filter todos by category and completion status.
- **Theme Switching** — Toggle between Dark, Light, Valentine (pink with floating hearts/flowers), and Chinese New Year (red/gold with emoji parade animation) themes.

## Installation & Running

### Prerequisites

- Python 3.12+
- Jac (`pip install jaclang`)
- An Anthropic API key (for AI features)

### Steps

```bash
# 1. Clone the repo and navigate to the app
cd my-todo-app

# 2. Set your API key for AI categorization and meal planning
export ANTHROPIC_API_KEY="your-anthropic-api-key"

# 3. Start the dev server
jac start main.jac
```

The app will be available at **http://localhost:8000**. Register an account to get started.

To test collaboration, open a second browser or incognito window, register a second user, and share a list between them.

## How It Works & Code Location

### Project Structure

```
my-todo-app/
├── main.jac                        # Server entry point — walkers (API endpoints), AI types, graph nodes
├── collab.jac                      # Shared data layer — SQLite CRUD for lists, todos, invitations
├── frontend.cl.jac                 # Frontend UI — component declarations, state, JSX rendering
├── frontend.impl.jac               # Frontend logic — API calls, event handlers, state management
├── styles.css                      # All styles including theme overrides and animations
├── components/
│   ├── AuthForm.cl.jac             # Login/signup form component
│   ├── TodoItem.cl.jac             # Individual todo item component (checkbox, priority, drag-and-drop)
│   ├── FilterPopover.cl.jac        # Category/status filter popover
│   └── IngredientItem.cl.jac       # Meal planner ingredient display
└── jac.toml                        # Jac project configuration
```

### Architecture

The app uses a **hybrid architecture** that leverages Jac's strengths for different data patterns:

- **Personal data (meal planner)** is stored as Jac graph nodes (`MealIngredient`) in each user's private graph. `walker:priv` provides automatic per-user isolation — no user can access another's meal plan.

- **Collaborative data (shared lists, todos, invitations)** is stored in a SQLite database managed by `collab.jac`. This is necessary because `walker:priv` isolates each user's graph — one user's walker cannot traverse another user's nodes. SQLite serves as the shared data store that all users' walkers can read from and write to, with permission checks (`can_access_list`, `is_list_owner`) built into the CRUD functions.

### Key Files

| File | Role |
|---|---|
| `main.jac` | Defines all walkers (`walker:priv`) that serve as API endpoints. Each walker identifies the user via JWT, then delegates to `collab.jac` for list/todo operations or traverses the user's graph for meal planning. |
| `collab.jac` | Pure Jac module that manages the SQLite database — table creation, list CRUD, todo CRUD, invitation flow, member management. Written in Jac syntax using Python's `sqlite3` library. |
| `frontend.cl.jac` | Declares all frontend state variables and renders the full UI in JSX — sidebar with lists, todo panel, meal planner, invitation inbox, theme selector, and emoji animations. |
| `frontend.impl.jac` | Implements all frontend methods — spawning walkers to fetch/create/update/delete data, handling drag-and-drop reorder, managing auth flow. |
| `styles.css` | CSS with custom properties for theming. Theme classes (`.theme-light`, `.theme-valentine`, `.theme-cny`) override color variables. Includes `@keyframes` for Valentine floating emojis and Chinese New Year emoji parade. |
