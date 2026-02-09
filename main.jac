"""TaskFlow - A multi-user todo app with AI meal planning and collaboration."""

cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}

import from byllm.lib { Model }
import from collab {
    init_db,
    user_exists,
    get_username_by_root_id,
    ensure_default_list,
    create_list as db_create_list,
    get_user_lists as db_get_user_lists,
    rename_list as db_rename_list,
    delete_list as db_delete_list,
    can_access_list,
    is_list_owner,
    add_todo as db_add_todo,
    get_todos as db_get_todos,
    toggle_todo as db_toggle_todo,
    delete_todo as db_delete_todo,
    update_todo_priority as db_update_todo_priority,
    reorder_todos as db_reorder_todos,
    add_ingredient_todos as db_add_ingredient_todos,
    create_invitation as db_create_invitation,
    get_invitations as db_get_invitations,
    respond_to_invitation as db_respond_to_invitation,
    get_list_members as db_get_list_members,
    remove_member as db_remove_member
}

glob llm = Model(model_name="claude-sonnet-4-20250514");

# --- AI Types ---

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, CLOVE, BUNCH }

obj Ingredient {
    has name: str;
    has quantity: float;
    has unit: Unit;
    has cost: float;
    has carby: bool;
}

sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient is high in carbohydrates";

"""Categorize a todo based on its title."""
def categorize(title: str) -> Category by llm();

"""Generate a shopping list of ingredients needed for a described meal."""
def generate_ingredients(meal_description: str) -> list[Ingredient] by llm();

# --- Profile Node (stores username in each user's graph for recovery) ---

node Profile {
    has username: str;
}

# --- Meal Ingredient Node (stays in Jac graph - personal data) ---

node MealIngredient {
    has name: str,
        quantity: float,
        unit: str,
        cost: float,
        carby: bool;
}

# --- List Management Walkers ---

walker:priv WhoAmI {
    """Recover the logged-in username from the Profile node."""
    has found_username: str = "";

    can visit_children with Root entry { visit [-->]; }

    can read_profile with Profile entry {
        self.found_username = here.username;
    }

    can finalize with Root exit {
        report {"username": self.found_username};
    }
}

walker:priv SetupUser {
    """Create Profile node if missing; ensure default list exists."""
    has username: str;
    has found: bool = False;

    can visit_children with Root entry { visit [-->]; }

    can check_profile with Profile entry {
        self.found = True;
    }

    can finalize with Root exit {
        if not self.found {
            here ++> Profile(username=self.username);
        }
        list_id = ensure_default_list(self.username);
        report {"default_list_id": list_id, "username": self.username};
    }
}

walker:priv CreateTodoList {
    has title: str;
    has username: str;

    can create with Root entry {
        result = db_create_list(self.title, self.username);
        report result;
    }
}

walker:priv ListTodoLists {
    has username: str;

    can list_all with Root entry {
        result = db_get_user_lists(self.username);
        report result;
    }
}

walker:priv RenameTodoList {
    has list_id: str;
    has title: str;
    has username: str;

    can rename with Root entry {
        result = db_rename_list(self.list_id, self.title, self.username);
        report result;
    }
}

walker:priv DeleteTodoList {
    has list_id: str;
    has username: str;

    can delete with Root entry {
        result = db_delete_list(self.list_id, self.username);
        report result;
    }
}

# --- Todo Walkers (now using SQLite via collab.py) ---

walker:priv AddTodo {
    has title: str;
    has list_id: str;
    has username: str;
    has priority: str = "medium";

    can create with Root entry {
        if not can_access_list(self.username, self.list_id) {
            report {"error": "Not authorized"};
            return;
        }
        category = "other";
        try {
            category = str(categorize(self.title)).split(".")[-1].lower();
        } except Exception as e {
            category = "other";
        }
        result = db_add_todo(self.list_id, self.title, category, self.priority);
        report result;
    }
}

walker:priv ListTodos {
    has list_id: str;
    has username: str;

    can list_all with Root entry {
        if not can_access_list(self.username, self.list_id) {
            report [];
            return;
        }
        result = db_get_todos(self.list_id);
        report result;
    }
}

walker:priv ToggleTodo {
    has todo_id: str;
    has username: str;

    can toggle with Root entry {
        result = db_toggle_todo(self.todo_id, self.username);
        report result;
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can delete with Root entry {
        result = db_delete_todo(self.todo_id);
        report result;
    }
}

walker:priv UpdateTodoPriority {
    has todo_id: str;
    has priority: str;

    can update with Root entry {
        result = db_update_todo_priority(self.todo_id, self.priority);
        report result;
    }
}

walker:priv ReorderTodos {
    has updates: list = [];

    can reorder with Root entry {
        result = db_reorder_todos(self.updates);
        report result;
    }
}

walker:priv AddIngredientsAsTodos {
    has list_id: str;
    has username: str;
    has ingredients: list = [];
    has priority: str = "medium";

    can create with Root entry {
        if not can_access_list(self.username, self.list_id) {
            report [];
            return;
        }
        result = db_add_ingredient_todos(self.list_id, self.ingredients, self.priority);
        report result;
    }
}

# --- Collaboration Walkers ---

walker:priv ShareList {
    has list_id: str;
    has target_username: str;
    has username: str;

    can share with Root entry {
        result = db_create_invitation(self.username, self.target_username, self.list_id);
        report result;
    }
}

walker:priv ListInvitations {
    has username: str;

    can list_all with Root entry {
        result = db_get_invitations(self.username);
        report result;
    }
}

walker:priv RespondToInvitation {
    has invitation_id: str;
    has accept: bool;
    has username: str;

    can respond with Root entry {
        result = db_respond_to_invitation(self.invitation_id, self.username, self.accept);
        report result;
    }
}

walker:priv GetListMembers {
    has list_id: str;

    can get_members with Root entry {
        result = db_get_list_members(self.list_id);
        report result;
    }
}

walker:priv RemoveListMember {
    has list_id: str;
    has target_username: str;
    has username: str;

    can remove with Root entry {
        result = db_remove_member(self.list_id, self.target_username, self.username);
        report result;
    }
}

# --- Meal Planner Walkers (still use Jac graph) ---

walker:priv GenerateShoppingList {
    has meal_description: str;

    can generate with Root entry {
        # First clear old ingredients
        visit [-->];
        # Then generate new ones
        result: list = [];
        try {
            ingredients = generate_ingredients(self.meal_description);
            for ing in ingredients {
                ing_data = {
                    "name": ing.name,
                    "quantity": ing.quantity,
                    "unit": str(ing.unit).split(".")[-1].lower(),
                    "cost": ing.cost,
                    "carby": ing.carby
                };
                here ++> MealIngredient(
                    name=ing_data["name"],
                    quantity=ing_data["quantity"],
                    unit=ing_data["unit"],
                    cost=ing_data["cost"],
                    carby=ing_data["carby"]
                );
                result.append(ing_data);
            }
        } except Exception as e {
            result = [];
        }
        report result;
    }

    can clear_old with MealIngredient entry {
        del here;
    }
}

walker:priv ListMealPlan {
    has ingredients: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with MealIngredient entry {
        self.ingredients.append({
            "name": here.name,
            "quantity": here.quantity,
            "unit": here.unit,
            "cost": here.cost,
            "carby": here.carby
        });
    }

    can report_all with Root exit {
        report self.ingredients;
    }
}

walker:priv ClearMealPlan {
    can collect with Root entry {
        visit [-->];
    }

    can clear with MealIngredient entry {
        del here;
        report {"cleared": True};
    }
}
