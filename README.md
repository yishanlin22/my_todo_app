# my-todo-app

A Jac client-side application with React support.

## Project Structure

```
my-todo-app/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.cl.jac     # Example Jac component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac start main.jac
```

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```

## Troubleshooting (Part 3: Walkers, Auth)

### Walker API returns 500

The jac start server expects walker request bodies wrapped in `{"fields": {...}}`. If you see 500 errors when adding todos or using the meal planner:

1. Run the patch script after building: `./patch_client_runtime.sh`
2. Rebuild the client if needed: stop the server, run `jac clean --all`, then `jac start main.jac`
3. Run the patch again: `./patch_client_runtime.sh`

### "Root is not defined" or walkers fail

Use `` `root `` (backtick-root) in walker ability triggers, e.g. `can collect with \`root entry`. The tutorial's `Root` (capital R) may not work in all jac versions.

### API key

Set `ANTHROPIC_API_KEY` before starting for AI features (todo categorization, meal planning):

```bash
export ANTHROPIC_API_KEY="your-key"
jac start main.jac
```
# my_todo_app
