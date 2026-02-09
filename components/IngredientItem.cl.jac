"""Ingredient item component with cross-off support."""

def:pub IngredientItem(ingredient: dict, excluded: bool, onExclude: any) -> any {
    return
        <div className={("ingredient-item ingredient-excluded" if excluded else "ingredient-item")}>
            <div className="ingredient-info">
                <span className={("ingredient-name ingredient-name-excluded" if excluded else "ingredient-name")}>
                    {ingredient.name}
                </span>
                <span className="ingredient-qty">
                    {ingredient.quantity} {ingredient.unit}
                </span>
            </div>
            <div className="ingredient-meta">
                {(
                    <span className="carb-badge">Carbs</span>
                ) if ingredient.carby else None}
                <span className="cost-label">${ingredient.cost.toFixed(2)}</span>
                <button
                    onClick={onExclude}
                    className={("ingredient-exclude-btn ingredient-exclude-btn-active" if excluded else "ingredient-exclude-btn")}
                >
                    {("Undo" if excluded else "×")}
                </button>
            </div>
        </div>;
}
