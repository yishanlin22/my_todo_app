"""Todo item component with priority badge, drag support, and completed-by display."""

def:pub TodoItem(
    todo: dict,
    onToggle: any,
    onDelete: any,
    onDragStart: any,
    onDragOver: any,
    onDrop: any
) -> any {
    priorityClass = "priority-badge-" + todo.priority;
    return
        <div
            className={("todo-item todo-item-completed" if todo.completed else "todo-item")}
            draggable={True}
            onDragStart={lambda e: any -> None { onDragStart(todo.id, e); }}
            onDragOver={lambda e: any -> None { e.preventDefault(); onDragOver(todo.id, e); }}
            onDrop={lambda e: any -> None { e.preventDefault(); onDrop(todo.id, e); }}
        >
            <input
                type="checkbox"
                checked={todo.completed}
                onChange={lambda -> None { onToggle(todo.id); }}
                className="todo-checkbox"
            />
            <div className="todo-content">
                <span className={("todo-title-completed" if todo.completed else "todo-title")}>
                    {todo.title}
                </span>
                {(
                    <span className="completed-by">completed by {todo.completed_by}</span>
                ) if todo.completed and todo.completed_by else None}
            </div>
            {(
                <span className="category-badge">{todo.category}</span>
            ) if todo.category and todo.category != "other" else None}
            <span className={priorityClass}>{todo.priority}</span>
            <button
                onClick={lambda -> None { onDelete(todo.id); }}
                className="todo-delete-btn"
            >
                x
            </button>
        </div>;
}
