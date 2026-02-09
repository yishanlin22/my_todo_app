"""Implementations for the Todo App frontend component."""

# --- Initialization ---

impl app.initAfterLogin -> None {
    currentUser = loggedInUser;
    if not currentUser {
        # Page reload - recover username from Profile node
        try {
            whoResult = root spawn WhoAmI();
            recovered = whoResult.reports[0].username if whoResult.reports else "";
            if recovered {
                loggedInUser = recovered;
                currentUser = recovered;
            }
        } except Exception as e {
            # ignore
        }
    }
    if currentUser {
        fetchLists(currentUser);
        fetchMealPlan();
    }
}

# --- Auth ---

impl app.handleLogin -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    loading = True;
    uname = username;
    success = await jacLogin(uname, password);
    loading = False;
    if success {
        loggedInUser = uname;
        # Setup profile and default list
        try {
            root spawn SetupUser(username=uname);
        } except Exception as e {
            # ignore setup errors
        }
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = "Invalid username or password";
    }
}

impl app.handleSignup -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    if password.length < 4 {
        error = "Password must be at least 4 characters";
        return;
    }
    loading = True;
    uname = username;
    result = await jacSignup(uname, password);
    loading = False;
    if result["success"] {
        loggedInUser = uname;
        # Setup profile and default list
        try {
            root spawn SetupUser(username=uname);
        } except Exception as e {
            # ignore setup errors
        }
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        errData = result["error"];
        if errData and errData.message {
            error = errData.message;
        } elif errData {
            error = "" + errData;
        } else {
            error = "Signup failed";
        }
    }
}

impl app.handleLogout -> None {
    jacLogout();
    isLoggedIn = False;
    loggedInUser = "";
    todos = [];
    lists = [];
    activeListId = "";
    ingredients = [];
    excludedIngredients = [];
    mealInput = "";
    filterOpen = False;
    filterPriority = [];
    filterCompletion = [];
    filterTag = [];
    invitations = [];
    invitationsOpen = False;
    shareDialogOpen = False;
    listMembers = [];
}

impl app.handleSubmit(e: any) -> None {
    e.preventDefault();
    if isSignup {
        await handleSignup();
    } else {
        await handleLogin();
    }
}

# --- List Management ---

impl app.fetchLists(user: str) -> None {
    if not user { return; }
    try {
        result = root spawn ListTodoLists(username=user);
        # Use local var - state var 'lists' is stale after setLists()
        newLists = result.reports[0] if result.reports else [];
        lists = newLists;
        # Auto-select first list if no active list
        selectedId = activeListId;
        if not selectedId and newLists.length > 0 {
            selectedId = newLists[0].id;
            activeListId = selectedId;
        }
        # Inline ListTodos call to avoid cross-function state issues
        if selectedId {
            todosLoading = True;
            todoResult = root spawn ListTodos(list_id=selectedId, username=user);
            todos = todoResult.reports[0] if todoResult.reports else [];
            todosLoading = False;
        }
    } except Exception as e {
        lists = [];
    }
    # Also fetch invitations inline
    try {
        invResult = root spawn ListInvitations(username=user);
        invitations = invResult.reports[0] if invResult.reports else [];
    } except Exception as e {
        invitations = [];
    }
}

impl app.createList -> None {
    if not newListTitle.trim() { creatingList = False; return; }
    try {
        result = root spawn CreateTodoList(title=newListTitle, username=loggedInUser);
        newList = result.reports[0] if result.reports else {};
        if newList and newList.id {
            lists = lists.concat([newList]);
            activeListId = newList.id;
            fetchTodos(newList.id, loggedInUser);
        }
    } except Exception as e {
        # ignore
    }
    newListTitle = "";
    creatingList = False;
}

impl app.renameList(listId: str, title: str) -> None {
    if not title.trim() { return; }
    try {
        root spawn RenameTodoList(list_id=listId, title=title, username=loggedInUser);
        lists = lists.map(
            lambda l: any -> any {
                if l.id == listId {
                    return {
                        "id": l.id, "title": title, "owner": l.owner,
                        "shared_with": l.shared_with, "todo_count": l.todo_count
                    };
                }
                return l;
            }
        );
    } except Exception as e {
        # ignore
    }
}

impl app.deleteList(listId: str) -> None {
    try {
        root spawn DeleteTodoList(list_id=listId, username=loggedInUser);
        lists = lists.filter(lambda l: any -> bool { return l.id != listId; });
        if activeListId == listId {
            newActiveId = lists[0].id if lists.length > 0 else "";
            activeListId = newActiveId;
            if newActiveId { fetchTodos(newActiveId, loggedInUser); }
            else { todos = []; }
        }
    } except Exception as e {
        # ignore
    }
}

impl app.selectList(listId: str) -> None {
    if activeListId == listId { return; }
    todosLoading = True;
    activeListId = listId;
    fetchTodos(listId, loggedInUser);
}

impl app.startRenaming(listId: str, currentTitle: str) -> None {
    renamingListId = listId;
    renameTitle = currentTitle;
}

impl app.finishRenaming -> None {
    if renamingListId and renameTitle.trim() {
        renameList(renamingListId, renameTitle);
    }
    renamingListId = "";
    renameTitle = "";
}

impl app.handleNewListKeyPress(e: any) -> None {
    if e.key == "Enter" { createList(); }
    if e.key == "Escape" { creatingList = False; newListTitle = ""; }
}

impl app.handleRenameKeyPress(e: any) -> None {
    if e.key == "Enter" { finishRenaming(); }
    if e.key == "Escape" { renamingListId = ""; renameTitle = ""; }
}

# --- Todos ---

impl app.fetchTodos(listId: str, user: str) -> None {
    if not listId or not user { todosLoading = False; return; }
    todosLoading = True;
    try {
        result = root spawn ListTodos(list_id=listId, username=user);
        todos = result.reports[0] if result.reports else [];
    } except Exception as e {
        todos = [];
    }
    todosLoading = False;
}

impl app.addTodo -> None {
    if not newTodoText.trim() or not activeListId { return; }
    try {
        response = root spawn AddTodo(
            title=newTodoText,
            priority=newTodoPriority,
            list_id=activeListId,
            username=loggedInUser
        );
        newTodo = response.reports[0];
        if newTodo and not newTodo.error {
            todos = todos.concat([{
                "id": newTodo.id,
                "title": newTodo.title,
                "completed": newTodo.completed,
                "category": newTodo.category,
                "priority": newTodo.priority,
                "order": newTodo.order,
                "completed_by": ""
            }]);
        }
        newTodoText = "";
    } except Exception as e {
        newTodoText = "";
    }
    # Update list counts
    fetchLists(loggedInUser);
}

impl app.toggleTodo(todoId: str) -> None {
    root spawn ToggleTodo(todo_id=todoId, username=loggedInUser);
    todos = todos.map(
        lambda t: any -> any {
            if t.id == todoId {
                return {
                    "id": t.id, "title": t.title,
                    "completed": not t.completed, "category": t.category,
                    "priority": t.priority, "order": t.order,
                    "completed_by": (loggedInUser if not t.completed else "")
                };
            }
            return t;
        }
    );
}

impl app.deleteTodo(todoId: str) -> None {
    root spawn DeleteTodo(todo_id=todoId);
    todos = todos.filter(
        lambda t: any -> bool { return t.id != todoId; }
    );
    # Update list counts
    fetchLists(loggedInUser);
}

impl app.updateTodoPriority(todoId: str, newPriority: str) -> None {
    root spawn UpdateTodoPriority(todo_id=todoId, priority=newPriority);
    todos = todos.map(
        lambda t: any -> any {
            if t.id == todoId {
                return {
                    "id": t.id, "title": t.title,
                    "completed": t.completed, "category": t.category,
                    "priority": newPriority, "order": t.order,
                    "completed_by": t.completed_by
                };
            }
            return t;
        }
    );
}

impl app.reorderTodos(updates: list) -> None {
    root spawn ReorderTodos(updates=updates);
    todos = todos.map(
        lambda t: any -> any {
            matched = updates.find(lambda u: any -> bool { return u.id == t.id; });
            if matched {
                return {
                    "id": t.id, "title": t.title,
                    "completed": t.completed, "category": t.category,
                    "priority": matched.priority, "order": matched.order,
                    "completed_by": t.completed_by
                };
            }
            return t;
        }
    );
}

impl app.handleTodoKeyPress(e: any) -> None {
    if e.key == "Enter" { addTodo(); }
}

impl app.getFilteredTodos(priority: str) -> list {
    # Filter by priority lane first
    if filterPriority.length > 0 and not filterPriority.includes(priority) {
        return [];
    }
    laneTodos = todos.filter(
        lambda t: any -> bool { return t.priority == priority; }
    );
    # Apply completion filter
    if filterCompletion.length > 0 {
        laneTodos = laneTodos.filter(
            lambda t: any -> bool {
                if filterCompletion.includes("completed") and t.completed { return True; }
                if filterCompletion.includes("todo") and not t.completed { return True; }
                return False;
            }
        );
    }
    # Apply tag filter
    if filterTag.length > 0 {
        laneTodos = laneTodos.filter(
            lambda t: any -> bool {
                return filterTag.includes(t.category);
            }
        );
    }
    # Sort by order
    laneTodos = laneTodos.slice().sort(
        lambda a: any, b: any -> int { return a.order - b.order; }
    );
    return laneTodos;
}

impl app.toggleFilterPriority(p: str) -> None {
    if filterPriority.includes(p) {
        filterPriority = filterPriority.filter(
            lambda x: any -> bool { return x != p; }
        );
    } else {
        filterPriority = filterPriority.concat([p]);
    }
}

impl app.toggleFilterCompletion(c: str) -> None {
    if filterCompletion.includes(c) {
        filterCompletion = filterCompletion.filter(
            lambda x: any -> bool { return x != c; }
        );
    } else {
        filterCompletion = filterCompletion.concat([c]);
    }
}

impl app.toggleFilterTag(t: str) -> None {
    if filterTag.includes(t) {
        filterTag = filterTag.filter(
            lambda x: any -> bool { return x != t; }
        );
    } else {
        filterTag = filterTag.concat([t]);
    }
}

impl app.onDragStart(todoId: str, e: any) -> None {
    dragTodoId = todoId;
    e.dataTransfer.effectAllowed = "move";
}

impl app.onDragOverTodo(todoId: str, e: any) -> None {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
}

impl app.onDropOnTodo(todoId: str, e: any) -> None {
    e.preventDefault();
    if not dragTodoId or dragTodoId == todoId { dragTodoId = ""; return; }
    draggedTodo = todos.find(lambda t: any -> bool { return t.id == dragTodoId; });
    targetTodo = todos.find(lambda t: any -> bool { return t.id == todoId; });
    if not draggedTodo or not targetTodo { dragTodoId = ""; return; }
    targetPriority = targetTodo.priority;
    laneTodos = todos.filter(
        lambda t: any -> bool { return t.priority == targetPriority and t.id != dragTodoId; }
    ).sort(
        lambda a: any, b: any -> int { return a.order - b.order; }
    );
    reordered: list = [];
    inserted = False;
    for t in laneTodos {
        if t.id == todoId and not inserted {
            reordered = reordered.concat([{"id": dragTodoId, "order": 0, "priority": targetPriority}]);
            inserted = True;
        }
        reordered = reordered.concat([{"id": t.id, "order": 0, "priority": targetPriority}]);
    }
    if not inserted {
        reordered = reordered.concat([{"id": dragTodoId, "order": 0, "priority": targetPriority}]);
    }
    updates = reordered.map(
        lambda item: any, idx: any -> any {
            return {"id": item.id, "order": idx, "priority": item.priority};
        }
    );
    reorderTodos(updates);
    dragTodoId = "";
}

impl app.onDropOnLane(priority: str, e: any) -> None {
    e.preventDefault();
    if not dragTodoId { return; }
    draggedTodo = todos.find(lambda t: any -> bool { return t.id == dragTodoId; });
    if not draggedTodo { dragTodoId = ""; return; }
    if draggedTodo.priority == priority { dragTodoId = ""; return; }
    laneTodos = todos.filter(
        lambda t: any -> bool { return t.priority == priority; }
    );
    maxOrder = 0;
    for t in laneTodos {
        if t.order >= maxOrder { maxOrder = t.order + 1; }
    }
    updates = [{"id": dragTodoId, "order": maxOrder, "priority": priority}];
    reorderTodos(updates);
    dragTodoId = "";
}

# --- Meal Planner ---

impl app.fetchMealPlan -> None {
    result = root spawn ListMealPlan();
    ingredients = result.reports[0] if result.reports else [];
    excludedIngredients = [];
}

impl app.generateIngredients -> None {
    if not mealInput.trim() { return; }
    ingredientsLoading = True;
    try {
        result = root spawn GenerateShoppingList(meal_description=mealInput);
        ingredients = result.reports[0] if result.reports else [];
        excludedIngredients = [];
    } except Exception as e {
        ingredients = [];
        excludedIngredients = [];
    }
    ingredientsLoading = False;
}

impl app.clearIngredients -> None {
    root spawn ClearMealPlan();
    ingredients = [];
    excludedIngredients = [];
    mealInput = "";
}

impl app.addIngredientsAsTodos -> None {
    if not activeListId { return; }
    selected = ingredients.filter(
        lambda ing: any, idx: any -> bool { return not excludedIngredients.includes(idx); }
    );
    if selected.length == 0 { return; }
    try {
        response = root spawn AddIngredientsAsTodos(
            ingredients=selected,
            priority=ingredientsPriority,
            list_id=activeListId,
            username=loggedInUser
        );
        newTodos = response.reports[0] if response.reports else [];
        todos = todos.concat(newTodos);
        root spawn ClearMealPlan();
        ingredients = [];
        excludedIngredients = [];
        ingredientsPriority = "medium";
        mealInput = "";
    } except Exception as e {
        fetchTodos(activeListId, loggedInUser);
    }
    # Update list counts
    fetchLists(loggedInUser);
}

impl app.handleMealKeyPress(e: any) -> None {
    if e.key == "Enter" { generateIngredients(); }
}

impl app.getIngredientsTotal -> float {
    selected = ingredients.filter(
        lambda ing: any, idx: any -> bool { return not excludedIngredients.includes(idx); }
    );
    total = 0.0;
    for ing in selected {
        total = total + ing.cost;
    }
    return total;
}

impl app.toggleIngredientExclude(idx: int) -> None {
    if excludedIngredients.includes(idx) {
        excludedIngredients = excludedIngredients.filter(
            lambda x: any -> bool { return x != idx; }
        );
    } else {
        excludedIngredients = excludedIngredients.concat([idx]);
    }
}

# --- Collaboration ---

impl app.fetchInvitations -> None {
    if not loggedInUser { return; }
    try {
        result = root spawn ListInvitations(username=loggedInUser);
        invitations = result.reports[0] if result.reports else [];
    } except Exception as e {
        invitations = [];
    }
}

impl app.respondToInvitation(invId: str, accept: bool) -> None {
    # Find the invitation before removing it so we know which list was accepted
    acceptedListId = "";
    if accept {
        matched = invitations.find(lambda i: any -> bool { return i.id == invId; });
        if matched { acceptedListId = matched.list_id; }
    }
    try {
        root spawn RespondToInvitation(
            invitation_id=invId,
            accept=accept,
            username=loggedInUser
        );
        # Remove from local invitations
        invitations = invitations.filter(
            lambda inv: any -> bool { return inv.id != invId; }
        );
        # Close the dropdown
        invitationsOpen = False;
        if accept {
            # Refresh lists to include the newly accepted list
            result = root spawn ListTodoLists(username=loggedInUser);
            newLists = result.reports[0] if result.reports else [];
            lists = newLists;
            # Auto-select the accepted list so user sees its todos
            if acceptedListId {
                activeListId = acceptedListId;
                todosLoading = True;
                todoResult = root spawn ListTodos(list_id=acceptedListId, username=loggedInUser);
                todos = todoResult.reports[0] if todoResult.reports else [];
                todosLoading = False;
            }
        }
    } except Exception as e {
        # ignore
    }
}

impl app.shareList -> None {
    if not shareUsername.trim() {
        shareError = "Enter a username";
        return;
    }
    if not activeListId {
        shareError = "No list selected";
        return;
    }
    try {
        result = root spawn ShareList(
            list_id=activeListId,
            target_username=shareUsername,
            username=loggedInUser
        );
        response = result.reports[0] if result.reports else {};
        if response.error {
            shareError = response.error;
        } else {
            shareUsername = "";
            shareError = "";
            # Refresh lists and members
            fetchLists(loggedInUser);
            fetchListMembers();
        }
    } except Exception as e {
        shareError = "Failed to send invitation";
    }
}

impl app.fetchListMembers -> None {
    if not activeListId { listMembers = []; return; }
    try {
        result = root spawn GetListMembers(list_id=activeListId);
        listMembers = result.reports[0] if result.reports else [];
    } except Exception as e {
        listMembers = [];
    }
}

impl app.removeListMember(uname: str) -> None {
    try {
        root spawn RemoveListMember(
            list_id=activeListId,
            target_username=uname,
            username=loggedInUser
        );
        listMembers = listMembers.filter(
            lambda m: any -> bool { return m.username != uname; }
        );
        fetchLists(loggedInUser);
    } except Exception as e {
        # ignore
    }
}

impl app.openShareDialog -> None {
    shareDialogOpen = True;
    shareUsername = "";
    shareError = "";
    fetchListMembers();
}

impl app.closeShareDialog -> None {
    shareDialogOpen = False;
    shareUsername = "";
    shareError = "";
}

impl app.handleShareKeyPress(e: any) -> None {
    if e.key == "Enter" { shareList(); }
    if e.key == "Escape" { closeShareDialog(); }
}
