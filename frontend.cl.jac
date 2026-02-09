"""Todo App - Client-Side UI with priority lanes, filters, DnD, and meal integration."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.TodoItem { TodoItem }
import from .components.AuthForm { AuthForm }
import from .components.IngredientItem { IngredientItem }
import from .components.FilterPopover { FilterPopover }

sv import from main {
    AddTodo, ListTodos, ToggleTodo, DeleteTodo,
    UpdateTodoPriority, ReorderTodos, AddIngredientsAsTodos,
    GenerateShoppingList, ListMealPlan, ClearMealPlan
}

def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        todos: list = [],
        newTodoText: str = "",
        newTodoPriority: str = "medium",
        todosLoading: bool = True,
        mealInput: str = "",
        ingredients: list = [],
        ingredientsLoading: bool = False,
        excludedIngredients: list = [],
        ingredientsPriority: str = "medium",
        filterOpen: bool = False,
        filterPriority: list = [],
        filterCompletion: list = [],
        filterTag: list = [],
        dragTodoId: str = "";

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchTodos();
            fetchMealPlan();
        }
    }

    # Method declarations (implementations in frontend.impl.jac)
    async def fetchTodos -> None;
    async def addTodo -> None;
    async def toggleTodo(todoId: str) -> None;
    async def deleteTodo(todoId: str) -> None;
    async def updateTodoPriority(todoId: str, newPriority: str) -> None;
    async def reorderTodos(updates: list) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;
    def handleTodoKeyPress(e: any) -> None;
    async def fetchMealPlan -> None;
    async def generateIngredients -> None;
    async def clearIngredients -> None;
    async def addIngredientsAsTodos -> None;
    def handleMealKeyPress(e: any) -> None;
    def getIngredientsTotal -> float;
    def getFilteredTodos(priority: str) -> list;
    def toggleFilterPriority(p: str) -> None;
    def toggleFilterCompletion(c: str) -> None;
    def toggleFilterTag(t: str) -> None;
    def onDragStart(todoId: str, e: any) -> None;
    def onDragOverTodo(todoId: str, e: any) -> None;
    def onDropOnTodo(todoId: str, e: any) -> None;
    def onDropOnLane(priority: str, e: any) -> None;
    def toggleIngredientExclude(idx: int) -> None;

    if checkingAuth {
        return
            <div style={{"display": "flex", "justifyContent": "center",
                         "alignItems": "center", "minHeight": "100vh",
                         "color": "rgba(255,255,255,0.6)", "fontFamily": "system-ui"}}>
                Loading...
            </div>;
    }

    if isLoggedIn {
        totalCost = getIngredientsTotal();
        highTodos = getFilteredTodos("high");
        mediumTodos = getFilteredTodos("medium");
        lowTodos = getFilteredTodos("low");
        activeFilterCount = filterPriority.length + filterCompletion.length + filterTag.length;
        return
            <div className="app-container">
                <div className="app-content">
                    <div className="card">
                        <div className="card-header">
                            <div>
                                <h1 className="app-title">TaskFlow</h1>
                                <p className="app-subtitle">
                                    Todo list with AI meal planning
                                </p>
                            </div>
                            <button onClick={handleLogout} className="btn-signout">
                                Sign Out
                            </button>
                        </div>
                    </div>
                    <div className="two-column-layout">
                        <div className="column-left">
                            <div className="card">
                                <div className="add-row">
                                    <input
                                        type="text"
                                        value={newTodoText}
                                        onChange={lambda e: any -> None { newTodoText = e.target.value; }}
                                        onKeyPress={handleTodoKeyPress}
                                        placeholder="What needs to be done?"
                                        className="todo-input"
                                    />
                                    <select
                                        value={newTodoPriority}
                                        onChange={lambda e: any -> None { newTodoPriority = e.target.value; }}
                                        className="priority-select"
                                    >
                                        <option value="high">High</option>
                                        <option value="medium">Medium</option>
                                        <option value="low">Low</option>
                                    </select>
                                    <button
                                        onClick={lambda -> None { addTodo(); }}
                                        className="btn-add"
                                    >
                                        Add
                                    </button>
                                </div>
                                <div className="filter-bar">
                                    <button
                                        onClick={lambda -> None { filterOpen = not filterOpen; }}
                                        className={("filter-icon-btn filter-icon-btn-active" if activeFilterCount > 0 else "filter-icon-btn")}
                                    >
                                        {"Filter" + ((" (" + activeFilterCount + ")") if activeFilterCount > 0 else "")}
                                    </button>
                                    {(
                                        <FilterPopover
                                            filterPriority={filterPriority}
                                            filterCompletion={filterCompletion}
                                            filterTag={filterTag}
                                            onTogglePriority={toggleFilterPriority}
                                            onToggleCompletion={toggleFilterCompletion}
                                            onToggleTag={toggleFilterTag}
                                            onClose={lambda -> None { filterOpen = False; }}
                                        />
                                    ) if filterOpen else None}
                                </div>
                            </div>
                            {(
                                <div className="loading-message">Loading tasks...</div>
                            ) if todosLoading else (
                                <div className="priority-lanes">
                                    <div
                                        className="priority-lane"
                                        onDragOver={lambda e: any -> None { e.preventDefault(); }}
                                        onDrop={lambda e: any -> None { e.preventDefault(); onDropOnLane("high", e); }}
                                    >
                                        <div className="lane-header lane-header-high">
                                            <span className="lane-dot lane-dot-high"></span>
                                            High
                                            <span className="lane-count">{highTodos.length}</span>
                                        </div>
                                        {(
                                            <div className="lane-empty">No high priority tasks</div>
                                        ) if highTodos.length == 0 else (
                                            <div>
                                                {[
                                                    <TodoItem
                                                        key={todo.id}
                                                        todo={todo}
                                                        onToggle={toggleTodo}
                                                        onDelete={deleteTodo}
                                                        onDragStart={onDragStart}
                                                        onDragOver={onDragOverTodo}
                                                        onDrop={onDropOnTodo}
                                                    /> for todo in highTodos
                                                ]}
                                            </div>
                                        )}
                                    </div>
                                    <div
                                        className="priority-lane"
                                        onDragOver={lambda e: any -> None { e.preventDefault(); }}
                                        onDrop={lambda e: any -> None { e.preventDefault(); onDropOnLane("medium", e); }}
                                    >
                                        <div className="lane-header lane-header-medium">
                                            <span className="lane-dot lane-dot-medium"></span>
                                            Medium
                                            <span className="lane-count">{mediumTodos.length}</span>
                                        </div>
                                        {(
                                            <div className="lane-empty">No medium priority tasks</div>
                                        ) if mediumTodos.length == 0 else (
                                            <div>
                                                {[
                                                    <TodoItem
                                                        key={todo.id}
                                                        todo={todo}
                                                        onToggle={toggleTodo}
                                                        onDelete={deleteTodo}
                                                        onDragStart={onDragStart}
                                                        onDragOver={onDragOverTodo}
                                                        onDrop={onDropOnTodo}
                                                    /> for todo in mediumTodos
                                                ]}
                                            </div>
                                        )}
                                    </div>
                                    <div
                                        className="priority-lane"
                                        onDragOver={lambda e: any -> None { e.preventDefault(); }}
                                        onDrop={lambda e: any -> None { e.preventDefault(); onDropOnLane("low", e); }}
                                    >
                                        <div className="lane-header lane-header-low">
                                            <span className="lane-dot lane-dot-low"></span>
                                            Low
                                            <span className="lane-count">{lowTodos.length}</span>
                                        </div>
                                        {(
                                            <div className="lane-empty">No low priority tasks</div>
                                        ) if lowTodos.length == 0 else (
                                            <div>
                                                {[
                                                    <TodoItem
                                                        key={todo.id}
                                                        todo={todo}
                                                        onToggle={toggleTodo}
                                                        onDelete={deleteTodo}
                                                        onDragStart={onDragStart}
                                                        onDragOver={onDragOverTodo}
                                                        onDrop={onDropOnTodo}
                                                    /> for todo in lowTodos
                                                ]}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}
                            <div className="remaining-count">
                                {todos.filter(
                                    lambda t: any -> bool { return not t.completed; }
                                ).length} items remaining
                            </div>
                        </div>
                        <div className="column-right">
                            <div className="card">
                                <h2 className="panel-title">Meal Planner</h2>
                                <p className="panel-subtitle">
                                    Describe a meal to generate a shopping list
                                </p>
                                <div className="add-row">
                                    <input
                                        type="text"
                                        value={mealInput}
                                        onChange={lambda e: any -> None { mealInput = e.target.value; }}
                                        onKeyPress={handleMealKeyPress}
                                        placeholder="e.g. spaghetti bolognese for 4"
                                        className="todo-input"
                                    />
                                    <button
                                        onClick={lambda -> None { generateIngredients(); }}
                                        disabled={ingredientsLoading}
                                        className="btn-generate"
                                    >
                                        {("Generating..." if ingredientsLoading else "Generate")}
                                    </button>
                                </div>
                            </div>
                            <div className="card">
                                {(
                                    <div className="loading-message">
                                        <div className="generating-spinner"></div>
                                        Generating shopping list with AI...
                                    </div>
                                ) if ingredientsLoading else (
                                    <div>
                                        {(
                                            <div className="empty-message">
                                                Enter a meal above to generate ingredients.
                                            </div>
                                        ) if ingredients.length == 0 else (
                                            <div>
                                                {ingredients.map(
                                                    lambda ing: any, idx: any -> any {
                                                        return <IngredientItem
                                                            key={ing.name}
                                                            ingredient={ing}
                                                            excluded={excludedIngredients.includes(idx)}
                                                            onExclude={lambda -> None { toggleIngredientExclude(idx); }}
                                                        />;
                                                    }
                                                )}
                                                <div className="ingredients-footer">
                                                    <div className="ingredients-total">
                                                        Total: ${totalCost.toFixed(2)}
                                                    </div>
                                                    <div className="ingredients-actions">
                                                        <button
                                                            onClick={lambda -> None { clearIngredients(); }}
                                                            className="btn-clear"
                                                        >
                                                            Clear
                                                        </button>
                                                        <select
                                                            value={ingredientsPriority}
                                                            onChange={lambda e: any -> None { ingredientsPriority = e.target.value; }}
                                                            className="priority-select priority-select-small"
                                                        >
                                                            <option value="high">High</option>
                                                            <option value="medium">Medium</option>
                                                            <option value="low">Low</option>
                                                        </select>
                                                        <button
                                                            onClick={lambda -> None { addIngredientsAsTodos(); }}
                                                            className="btn-add-as-todos"
                                                        >
                                                            Add as Todos
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }

    return
        <AuthForm
            isSignup={isSignup}
            username={username}
            password={password}
            error={error}
            loading={loading}
            onUsernameChange={lambda e: any -> None { username = e.target.value; }}
            onPasswordChange={lambda e: any -> None { password = e.target.value; }}
            onSubmit={handleSubmit}
            onToggleMode={lambda -> None { isSignup = not isSignup; error = ""; }}
        />;
}
