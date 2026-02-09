"""Filter popover component for filtering todos."""

def:pub FilterPopover(
    filterPriority: list,
    filterCompletion: list,
    filterTag: list,
    onTogglePriority: any,
    onToggleCompletion: any,
    onToggleTag: any,
    onClose: any
) -> any {
    return
        <div className="filter-popover">
            <div className="filter-header">
                <span className="filter-header-title">Filters</span>
                <button onClick={onClose} className="filter-close-btn">×</button>
            </div>
            <div className="filter-section">
                <div className="filter-section-title">Priority</div>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterPriority.includes("high")}
                        onChange={lambda -> None { onTogglePriority("high"); }}
                    /> High
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterPriority.includes("medium")}
                        onChange={lambda -> None { onTogglePriority("medium"); }}
                    /> Medium
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterPriority.includes("low")}
                        onChange={lambda -> None { onTogglePriority("low"); }}
                    /> Low
                </label>
            </div>
            <div className="filter-section">
                <div className="filter-section-title">Completion</div>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterCompletion.includes("todo")}
                        onChange={lambda -> None { onToggleCompletion("todo"); }}
                    /> Todo
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterCompletion.includes("completed")}
                        onChange={lambda -> None { onToggleCompletion("completed"); }}
                    /> Completed
                </label>
            </div>
            <div className="filter-section">
                <div className="filter-section-title">Tag</div>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterTag.includes("work")}
                        onChange={lambda -> None { onToggleTag("work"); }}
                    /> Work
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterTag.includes("personal")}
                        onChange={lambda -> None { onToggleTag("personal"); }}
                    /> Personal
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterTag.includes("shopping")}
                        onChange={lambda -> None { onToggleTag("shopping"); }}
                    /> Shopping
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterTag.includes("health")}
                        onChange={lambda -> None { onToggleTag("health"); }}
                    /> Health
                </label>
                <label className="filter-checkbox-label">
                    <input type="checkbox"
                        checked={filterTag.includes("other")}
                        onChange={lambda -> None { onToggleTag("other"); }}
                    /> Other
                </label>
            </div>
        </div>;
}
