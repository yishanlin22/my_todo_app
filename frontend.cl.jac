"""Todo App - Client-Side UI with lists, collaboration, priority lanes, filters, DnD, and meal integration."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.TodoItem { TodoItem }
import from .components.AuthForm { AuthForm }
import from .components.IngredientItem { IngredientItem }
import from .components.FilterPopover { FilterPopover }

sv import from main {
    WhoAmI, SetupUser,
    CreateTodoList, ListTodoLists, RenameTodoList, DeleteTodoList,
    AddTodo, ListTodos, ToggleTodo, DeleteTodo,
    UpdateTodoPriority, ReorderTodos, AddIngredientsAsTodos,
    ShareList, ListInvitations, RespondToInvitation, GetListMembers, RemoveListMember,
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
        loggedInUser: str = "",
        # Lists
        lists: list = [],
        activeListId: str = "",
        newListTitle: str = "",
        creatingList: bool = False,
        renamingListId: str = "",
        renameTitle: str = "",
        # Todos
        todos: list = [],
        newTodoText: str = "",
        newTodoPriority: str = "medium",
        todosLoading: bool = True,
        # Meal planner
        mealInput: str = "",
        ingredients: list = [],
        ingredientsLoading: bool = False,
        excludedIngredients: list = [],
        ingredientsPriority: str = "medium",
        # Filters
        filterOpen: bool = False,
        filterPriority: list = [],
        filterCompletion: list = [],
        filterTag: list = [],
        dragTodoId: str = "",
        # Collaboration
        invitations: list = [],
        invitationsOpen: bool = False,
        shareDialogOpen: bool = False,
        shareUsername: str = "",
        shareError: str = "",
        listMembers: list = [],
        # Theme
        theme: str = "default";

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            initAfterLogin();
        }
    }

    # Method declarations (implementations in frontend.impl.jac)
    # Initialization
    async def initAfterLogin -> None;
    # Auth
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;
    # List management
    async def fetchLists(user: str) -> None;
    async def createList -> None;
    async def renameList(listId: str, title: str) -> None;
    async def deleteList(listId: str) -> None;
    async def selectList(listId: str) -> None;
    def startRenaming(listId: str, currentTitle: str) -> None;
    async def finishRenaming -> None;
    def handleNewListKeyPress(e: any) -> None;
    def handleRenameKeyPress(e: any) -> None;
    # Todos
    async def fetchTodos(listId: str, user: str) -> None;
    async def addTodo -> None;
    async def toggleTodo(todoId: str) -> None;
    async def deleteTodo(todoId: str) -> None;
    async def updateTodoPriority(todoId: str, newPriority: str) -> None;
    async def reorderTodos(updates: list) -> None;
    def handleTodoKeyPress(e: any) -> None;
    def getFilteredTodos(priority: str) -> list;
    def toggleFilterPriority(p: str) -> None;
    def toggleFilterCompletion(c: str) -> None;
    def toggleFilterTag(t: str) -> None;
    def onDragStart(todoId: str, e: any) -> None;
    def onDragOverTodo(todoId: str, e: any) -> None;
    def onDropOnTodo(todoId: str, e: any) -> None;
    def onDropOnLane(priority: str, e: any) -> None;
    # Meal planner
    async def fetchMealPlan -> None;
    async def generateIngredients -> None;
    async def clearIngredients -> None;
    async def addIngredientsAsTodos -> None;
    def handleMealKeyPress(e: any) -> None;
    def getIngredientsTotal -> float;
    def toggleIngredientExclude(idx: int) -> None;
    # Collaboration
    async def fetchInvitations -> None;
    async def respondToInvitation(invId: str, accept: bool) -> None;
    async def shareList -> None;
    async def fetchListMembers -> None;
    async def removeListMember(uname: str) -> None;
    def openShareDialog -> None;
    def closeShareDialog -> None;
    def handleShareKeyPress(e: any) -> None;

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
        myLists = lists.filter(lambda l: any -> bool { return l.owner == loggedInUser; });
        sharedLists = lists.filter(lambda l: any -> bool { return l.owner != loggedInUser; });
        activeList = lists.find(lambda l: any -> bool { return l.id == activeListId; });
        isOwner = activeList and activeList.owner == loggedInUser;
        themeClass = ("app-container" if theme == "default" else "app-container theme-" + theme);
        return
            <div className={themeClass}>
                <div className="app-content">
                    <div className="card">
                        <div className="card-header">
                            <div>
                                <h1 className="app-title">TaskFlow</h1>
                                <p className="app-subtitle">
                                    Signed in as <strong>{loggedInUser}</strong>
                                </p>
                            </div>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem"}}>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "0.35rem"}}>
                                    <span style={{"fontSize": "0.8rem", "color": "var(--text-muted)", "whiteSpace": "nowrap"}}>Theme:</span>
                                    <select
                                        value={theme}
                                        onChange={lambda e: any -> None { theme = e.target.value; }}
                                        className="theme-select"
                                        title="Switch theme"
                                    >
                                        <option value="default">Dark</option>
                                        <option value="light">Light</option>
                                        <option value="valentine">Valentine</option>
                                        <option value="cny">New Year</option>
                                    </select>
                                </div>
                                <div style={{"position": "relative"}}>
                                    <button
                                        onClick={lambda -> None { invitationsOpen = not invitationsOpen; }}
                                        className="invite-bell"
                                        title="Invitations"
                                    >
                                        Inbox
                                        {(
                                            <span className="invite-bell-badge">{invitations.length}</span>
                                        ) if invitations.length > 0 else None}
                                    </button>
                                    {(
                                        <div className="invite-dropdown">
                                            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "0.75rem"}}>
                                                <span style={{"color": "white", "fontWeight": "600", "fontSize": "0.9rem"}}>Invitations</span>
                                                <button onClick={lambda -> None { invitationsOpen = False; }} className="filter-close-btn">x</button>
                                            </div>
                                            {(
                                                <div className="invite-empty">No pending invitations</div>
                                            ) if invitations.length == 0 else (
                                                <div>
                                                    {[
                                                        <div key={inv.id} className="invite-item">
                                                            <div className="invite-info">
                                                                <div className="invite-from">{inv.from_user}</div>
                                                                <div className="invite-list-title">invites you to "{inv.list_title}"</div>
                                                            </div>
                                                            <div className="invite-actions">
                                                                <button
                                                                    onClick={lambda -> None { respondToInvitation(inv.id, True); }}
                                                                    className="invite-accept-btn"
                                                                >Accept</button>
                                                                <button
                                                                    onClick={lambda -> None { respondToInvitation(inv.id, False); }}
                                                                    className="invite-decline-btn"
                                                                >Decline</button>
                                                            </div>
                                                        </div>
                                                    for inv in invitations]}
                                                </div>
                                            )}
                                        </div>
                                    ) if invitationsOpen else None}
                                </div>
                                <button onClick={handleLogout} className="btn-signout">
                                    Sign Out
                                </button>
                            </div>
                        </div>
                    </div>
                    <div className="three-column-layout">
                        <div className="column-sidebar">
                            <div className="list-sidebar">
                                <div className="list-sidebar-title">My Lists</div>
                                {[
                                    <div
                                        key={lst.id}
                                        className={("list-item list-item-active" if lst.id == activeListId else "list-item")}
                                        onClick={lambda -> None { selectList(lst.id); }}
                                    >
                                        <span className="list-item-title">
                                            {lst.title}
                                        </span>
                                        {(
                                            <span className="shared-badge">shared</span>
                                        ) if lst.shared_with.length > 0 else None}
                                        <span className="list-item-count">{lst.todo_count}</span>
                                    </div>
                                for lst in myLists]}
                                {(
                                    <div>
                                        <div className="list-sidebar-title" style={{"marginTop": "1rem"}}>Shared with Me</div>
                                        {[
                                            <div
                                                key={slst.id}
                                                className={("list-item list-item-active" if slst.id == activeListId else "list-item")}
                                                onClick={lambda -> None { selectList(slst.id); }}
                                            >
                                                <span className="list-item-title">{slst.title}</span>
                                                <span className="shared-badge">{slst.owner}</span>
                                                <span className="list-item-count">{slst.todo_count}</span>
                                            </div>
                                        for slst in sharedLists]}
                                    </div>
                                ) if sharedLists.length > 0 else None}
                                {(
                                    <div>
                                        <input
                                            type="text"
                                            value={newListTitle}
                                            onChange={lambda e: any -> None { newListTitle = e.target.value; }}
                                            onKeyPress={handleNewListKeyPress}
                                            placeholder="List name..."
                                            className="list-create-input"
                                            autoFocus={True}
                                        />
                                    </div>
                                ) if creatingList else (
                                    <button
                                        onClick={lambda -> None { creatingList = True; }}
                                        className="list-add-btn"
                                    >
                                        + New List
                                    </button>
                                )}
                            </div>
                        </div>
                        <div className="column-left">
                            {(
                                <div className="card">
                                    <div className="list-header-bar">
                                        <div>
                                            <h2 className="panel-title">{activeList.title if activeList else "Select a list"}</h2>
                                            {(
                                                <div className="shared-users">
                                                    <span className="shared-user-chip shared-user-owner">{activeList.owner}</span>
                                                    {[
                                                        <span key={su} className="shared-user-chip">{su}</span>
                                                    for su in activeList.shared_with]}
                                                </div>
                                            ) if activeList and activeList.shared_with.length > 0 else None}
                                        </div>
                                        {(
                                            <div className="list-actions-bar">
                                                <button
                                                    onClick={lambda -> None { openShareDialog(); }}
                                                    className="btn-share"
                                                    title="Share this list"
                                                >Share</button>
                                                <button
                                                    onClick={lambda -> None { startRenaming(activeListId, activeList.title); }}
                                                    className="btn-list-action"
                                                    title="Rename list"
                                                >Rename</button>
                                                {(
                                                    <button
                                                        onClick={lambda -> None { deleteList(activeListId); }}
                                                        className="btn-list-delete"
                                                        title="Delete list"
                                                    >Delete</button>
                                                ) if myLists.length > 1 else None}
                                            </div>
                                        ) if isOwner else None}
                                    </div>
                                </div>
                            ) if activeList else None}
                            {(
                                <div className="card rename-card">
                                    <div className="add-row">
                                        <input
                                            type="text"
                                            value={renameTitle}
                                            onChange={lambda e: any -> None { renameTitle = e.target.value; }}
                                            onKeyPress={handleRenameKeyPress}
                                            className="todo-input"
                                            autoFocus={True}
                                        />
                                        <button onClick={lambda -> None { finishRenaming(); }} className="btn-add">Save</button>
                                        <button onClick={lambda -> None { renamingListId = ""; }} className="btn-clear">Cancel</button>
                                    </div>
                                </div>
                            ) if renamingListId else None}
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
                {(
                    <div className="share-dialog-overlay" onClick={lambda -> None { closeShareDialog(); }}>
                        <div className="share-dialog" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                            <div className="share-dialog-title">
                                Share "{activeList.title if activeList else ""}"
                            </div>
                            {(
                                <div className="share-error">{shareError}</div>
                            ) if shareError else None}
                            <div className="share-input-row">
                                <input
                                    type="text"
                                    value={shareUsername}
                                    onChange={lambda e: any -> None { shareUsername = e.target.value; shareError = ""; }}
                                    onKeyPress={handleShareKeyPress}
                                    placeholder="Enter username to invite..."
                                    className="share-input"
                                    autoFocus={True}
                                />
                                <button onClick={lambda -> None { shareList(); }} className="share-btn">
                                    Invite
                                </button>
                            </div>
                            <div className="share-member-list">
                                <div className="list-sidebar-title">Members</div>
                                {[
                                    <div key={mem.username} className="share-member">
                                        <span>{mem.username}</span>
                                        {(
                                            <span className="share-member-owner">owner</span>
                                        ) if mem.role == "owner" else (
                                            <button
                                                onClick={lambda -> None { removeListMember(mem.username); }}
                                                className="share-remove-btn"
                                                title="Remove member"
                                            >x</button>
                                        ) if isOwner else (
                                            <span className="shared-badge">{mem.role}</span>
                                        )}
                                    </div>
                                for mem in listMembers]}
                            </div>
                            <div style={{"marginTop": "1rem", "textAlign": "right"}}>
                                <button onClick={lambda -> None { closeShareDialog(); }} className="share-close-btn">
                                    Close
                                </button>
                            </div>
                        </div>
                    </div>
                ) if shareDialogOpen else None}
                {(
                    <span className="horse-runner">🐎🐎🐎🧧🧧🧧🏮🏮🏮🥟🥟🥟🎇🎇🎇🧨🧨🧨🐎🐎🐎</span>
                ) if theme == "cny" else None}
                {(
                    <div>
                        <span className="float-emoji" style={{"left": "5%", "animationDelay": "0s", "fontSize": "1.4rem"}}>❤️</span>
                        <span className="float-emoji" style={{"left": "15%", "animationDelay": "1.2s", "fontSize": "1.1rem"}}>🌸</span>
                        <span className="float-emoji" style={{"left": "28%", "animationDelay": "2.8s", "fontSize": "1.6rem"}}>💕</span>
                        <span className="float-emoji" style={{"left": "40%", "animationDelay": "0.5s", "fontSize": "1.2rem"}}>🌹</span>
                        <span className="float-emoji" style={{"left": "55%", "animationDelay": "3.5s", "fontSize": "1.5rem"}}>💗</span>
                        <span className="float-emoji" style={{"left": "65%", "animationDelay": "1.8s", "fontSize": "1.1rem"}}>🌺</span>
                        <span className="float-emoji" style={{"left": "78%", "animationDelay": "4.2s", "fontSize": "1.4rem"}}>💖</span>
                        <span className="float-emoji" style={{"left": "90%", "animationDelay": "2.2s", "fontSize": "1.3rem"}}>🌷</span>
                    </div>
                ) if theme == "valentine" else None}
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
            theme={theme}
            onThemeChange={lambda e: any -> None { theme = e.target.value; }}
        />;
}
