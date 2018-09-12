/*
 * Author: mharis001
 * Creates a context group with rows of actions.
 *
 * Arguments:
 * 0: Actions <ARRAY>
 * 1: Context level <NUMBER>
 * 2: Parent row <CONTROL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [] call zen_context_menu_fnc_createContextGroup
 *
 * Public: No
 */
#include "script_component.hpp"

params [["_contextActions", []], ["_contextLevel", 0], ["_parentRow", controlNull]];

// Exit if no context actions provided
if (_contextActions isEqualTo []) exitWith {};

// Check action conditions
private _params = [call FUNC(getContextPos)];
_params append GVAR(selected);
_contextActions = _contextActions select {
    _params call (_x select 4);
};

// Create context group control
private _display = findDisplay IDD_RSCDISPLAYCURATOR;
private _ctrlContextGroup = _display ctrlCreate [QGVAR(group), IDC_CONTEXT_GROUP];

// Assign context level and store context group
_ctrlContextGroup setVariable [QGVAR(level), _contextLevel];
GVAR(contextGroups) set [_contextLevel, _ctrlContextGroup];

// Create context action rows
private _numberOfRows = 0;

{
    _x params ["_actionName", "_displayName", "_picture", "_statement", "_condition", "", "_children"];

    // Create context row control
    private _ctrlContextRow = _display ctrlCreate [QGVAR(row), IDC_CONTEXT_ROW, _ctrlContextGroup];

    // Set action name and picture
    private _ctrlName = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_NAME;
    _ctrlName ctrlSetText _displayName;

    private _ctrlPicture = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_PICTURE;
    _ctrlPicture ctrlSetText _picture;

    // Hide expandable icon if no children actions
    if (_children isEqualTo []) then {
        private _ctrlExpandable = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_EXPANDABLE;
        _ctrlExpandable ctrlShow false;
    };

    // Add mouse area EHs
    private _ctrlMouse = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_MOUSE;
    _ctrlMouse ctrlAddEventHandler ["MouseEnter", {
        params ["_ctrlMouse"];

        private _ctrlContextRow = ctrlParentControlsGroup _ctrlMouse;
        private _ctrlContextGroup = ctrlParentControlsGroup _ctrlContextRow;

        // Update highlight color
        private _ctrlHighlight = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_HIGHLIGHT;
        _ctrlHighlight ctrlSetBackgroundColor [0, 0, 0, 1];

        // Close previously opened child context groups
        private _contextLevel = _ctrlContextGroup getVariable QGVAR(level);
        for "_i" from (_contextLevel + 1) to (count GVAR(contextGroups) -1) do {
            ctrlDelete (GVAR(contextGroups) select _i);
        };

        // Create child context group if action has children
        private _children = _ctrlContextRow getVariable QGVAR(children);
        if !(_children isEqualTo []) then {
            [_children, _contextLevel + 1, _ctrlContextRow] call FUNC(createContextGroup);
        };
    }];
    _ctrlMouse ctrlAddEventHandler ["MouseExit", {
        params ["_ctrlMouse"];

        private _ctrlContextRow = ctrlParentControlsGroup _ctrlMouse;

        // Update highlight color
        private _ctrlHighlight = _ctrlContextRow controlsGroupCtrl IDC_CONTEXT_HIGHLIGHT;
        _ctrlHighlight ctrlSetBackgroundColor [0, 0, 0, 0];
    }];
    _ctrlMouse ctrlAddEventHandler ["MouseButtonDown", {
        params ["_ctrlMouse", "_button"];

        if (_button isEqualTo 0) then {
            private _ctrlContextRow = ctrlParentControlsGroup _ctrlMouse;
            private _statement = _ctrlContextRow getVariable QGVAR(statement);
            private _params = [call FUNC(getContextPos)];
            _params append GVAR(selected);
            _params call _statement;
            {call FUNC(closeMenu)} call CBA_fnc_execNextFrame;
        };
    }];

    _ctrlContextRow setVariable [QGVAR(statement), _statement];
    _ctrlContextRow setVariable [QGVAR(children), _children];

    // Update row position in group
    _ctrlContextRow ctrlSetPosition [0, _numberOfRows * GUI_GRID_H];
    _ctrlContextRow ctrlCommit 0;

    _numberOfRows = _numberOfRows + 1;
} forEach _contextActions;

// Determine width and height of context group
private _wPos = 8 * GUI_GRID_W;
private _hPos = _numberOfRows * GUI_GRID_H;

// Update context background position
private _ctrlBackground = _ctrlContextGroup controlsGroupCtrl IDC_CONTEXT_BACKGROUND;
_ctrlBackground ctrlSetPosition [0, 0, _wPos, _hPos];
_ctrlBackground ctrlCommit 0;

// Update context group position
private _groupPosition = if (isNull _parentRow) then {
    // No parent row, position based on mouse position when opened
    GVAR(mousePos) params ["_xPos", "_yPos"];

    _xPos = safeZoneX + SPACING_W max (_xPos min (safeZoneX + safeZoneW - _wPos - SPACING_W));
    _yPos = safeZoneY + SPACING_H max (_yPos min (safeZoneY + safezoneH - _hPos - SPACING_H));

    [_xPos, _yPos, _wPos, _hPos]
} else {
    // Has parent row, position based on parent group position
    ctrlPosition ctrlParentControlsGroup _parentRow params ["_xPos", "_yPos"];

    // Add y position of row relative to group
    _yPos = _yPos + (ctrlPosition _parentRow select 1);

    // Determine position of children context groups (left or right of main)
    // This follows logic of BI's context menu (ctrlMenu)
    // If menu is opened more than half way across screen, expand to the left
    _xPos = if (GVAR(mousePos) select 0 > 0.5) then {
        _xPos - _wPos - SPACING_W;
    } else {
        _xPos + _wPos + SPACING_W;
    };

    _yPos = safeZoneY + SPACING_H max (_yPos min (safeZoneY + safezoneH - _hPos - SPACING_H));

    [_xPos, _yPos, _wPos, _hPos]
};

_ctrlContextGroup ctrlSetPosition _groupPosition;
_ctrlContextGroup ctrlCommit 0;