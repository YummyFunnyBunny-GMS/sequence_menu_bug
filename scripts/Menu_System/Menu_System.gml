enum MENU_STATE {
    CREATE,
    SET_ITEMS,
    UPDATE,
    DELETE,
}

enum MENU_ITEM_STATE {
    APPEAR,
    IDLE,
    HOVER,
    SELECTED,
    DISABLED,
    DELETE,
}

enum MENU_ITEM {
    BTN,
}

function Menu_System(options = {}) constructor {
    menu_obj    = get_object_value(options, "owner", obj_menu);
    menu_data   = [];
    active_menu = undefined;
    
    // selection
    selection_coords = [0,0];
    selected_index = 0;
    
    // depth
    menu_depth  = get_object_value(options, "menu_depth", -1000);
    menu_item_depth = get_object_value(options, "menu_item_depth", -2000);
    
    // menu surface
    surface = undefined;
    surface_dimensions = get_object_value(options, "surface_dimensions", [1152,648]);
    ui_layer = layer_get_id("ui");
    
    init = function(options = {}) {
        // set menu controller depth
        menu_obj.depth = menu_depth;
        
        // import menu data
        var _data = get_object_value(options, "data", []);
        if (array_length(_data) > 0) {
            for (var i = 0; i < array_length(_data); i++) {
                var _menu = new Menu(_data[i]);
                array_push(menu_data, _menu);
            }
        }
    }
    
    room_start = function() {
        // set menu for the main menu room
        if (room == rm_main_menu) {
            set_active_menu("main_menu_main");
        }
    }
    
    room_end = function() {
        active_menu = undefined;
    }
    
    set_active_menu = function(name) {
        var _menu = get_menu(name);
        if (is_undefined(_menu)) return;
            
        // reset active menu if its currently set
        if (!is_undefined(active_menu)) {
            
            // destroy sequence and reset active_menu
            layer_sequence_destroy(active_menu.sequence_el);    
            active_menu.sequence_el = undefined;
            active_menu.sequence_inst = undefined;
            active_menu.sequence_items = [];
            active_menu.state = MENU_STATE.CREATE;
            
            // reset selection
            selection_coords = [0,0];
            selected_index = 0;
        }
        
        
        active_menu = _menu;
    }
    
    clear_active_menu = function() {
        if (!is_undefined(active_menu)) return;
        active_menu = undefined;
    }
    
    get_menu = function(name) {
        for (var i = 0; i < array_length(menu_data); i++) {
            if (menu_data[i].name == name) {
                return menu_data[i];
            }
        }
        return undefined;
    }
    
    update = function() {
        if (is_undefined(active_menu)) return;
            
        // run active menu state
        switch(active_menu.state) {
            case MENU_STATE.CREATE: menu_state_create(); break;
            case MENU_STATE.SET_ITEMS: menu_state_set(); break;
            case MENU_STATE.UPDATE: menu_state_update(); break;
            case MENU_STATE.DELETE: menu_state_delete(); break;
        }
        
        // input checks
        if (keyboard_check_pressed(vk_up))    key_selection(-1, 0);
        if (keyboard_check_pressed(vk_down))  key_selection(1, 0);
        if (keyboard_check_pressed(vk_left))  key_selection(0, -1);
        if (keyboard_check_pressed(vk_right)) key_selection(0, 1);
        if (keyboard_check_pressed(vk_enter)) activate_selection();
    }
    
    #region - Button Selection
    
    key_selection = function(drow, dcol) {
        // calculate new coordinates with wrapping
        var new_row = selection_coords[0] + drow;
        var new_col = selection_coords[1] + dcol;
    
        // wrap around rows
        var max_row = -1;
        for (var i = 0; i < array_length(active_menu.items_data); i++) {
            max_row = max(max_row, active_menu.items_data[i].select_coords[0]);
        }
        new_row = (new_row + (max_row + 1)) mod (max_row + 1);
    
        // wrap around columns (if multi-column)
        var max_col = -1;
        for (var i = 0; i < array_length(active_menu.items_data); i++) {
            max_col = max(max_col, active_menu.items_data[i].select_coords[1]);
        }
        new_col = (new_col + (max_col + 1)) mod (max_col + 1);
    
        // find item matching new coordinates
        var _found_index = set_selection(new_row, new_col);
        if (_found_index == undefined) return;
    
        // update current selection
        selection_coords[0] = new_row;
        selection_coords[1] = new_col;
        selected_index = _found_index;
    
        // update visual hover state
        hover_selection();
    }
    
    mouse_selection = function(coords) {
        // find item matching new coordinates
        var _found_index = set_selection(coords[0], coords[1]);
        if (_found_index == undefined) return;
            
        selection_coords = coords;
        selected_index = _found_index;
        
        hover_selection();
    }
    
    set_selection = function(row, col) {
        var found_index = undefined;
        for (var i = 0; i < array_length(active_menu.items_data); i++) {
            var item = active_menu.items_data[i];
            if (item.select_coords[0] == row && item.select_coords[1] == col) {
                found_index = i;
                break;
            }
        }
        
        return found_index;
    }
    
    hover_selection = function() {
        if (is_undefined(active_menu)) return;
        if (!is_undefined(selected_index)) {
            for (var i = 0; i < array_length(active_menu.sequence_items); i++) {
                var obj_id = active_menu.sequence_items[i];
                
                // Update hover flag for this item
                obj_id.item_data.hovered = (i == selected_index);
    
                // Let the item decide how to render its hover effect
                obj_id.item_data.set_hover();
            }
        }
        
    }
    
    activate_selection = function() {
        if (selected_index == undefined) return;
    
        var item = active_menu.items_data[selected_index];
        if (is_callable(item.callback)) {
            item.callback();
        }
    }
    
    #endregion
    
    #region - Menu States
    
    menu_state_create = function() {
        if (is_undefined(active_menu)) return;
        if (active_menu.state != MENU_STATE.CREATE) return;

        // create the menu sequence
        var _x = (display_get_gui_width() / 2);
        var _y = (display_get_gui_height() / 2);

        active_menu.sequence_el = layer_sequence_create("ui", _x, _y, active_menu.sequence);
        active_menu.sequence_inst = layer_sequence_get_instance(active_menu.sequence_el);

        // proceed to next state
        active_menu.state = MENU_STATE.SET_ITEMS;
    }
    
    menu_state_set = function() {
        if (is_undefined(active_menu)) return;
        if (active_menu.state != MENU_STATE.SET_ITEMS) return;

        // store appropriate item_data inside each menu item object created by the parent sequence        
        for (var i = 0; i < array_length(active_menu.sequence_inst.activeTracks); i++) {
            var _track = active_menu.sequence_inst.activeTracks[i];
            var _track_name = _track.track.name;
            var _inst_id = _track.instanceID;
            for (var j = 0; j < array_length(active_menu.items_data); j++) {
                var _item = active_menu.items_data[j];
                var _item_name = _item.name;
                if (_track_name == _item_name) {
                    
                    // store the menu item's id in the correct item_data index
                    _item.item_obj = _inst_id;
                    
                    // store the item_data inside the menu item
                    variable_instance_set(_inst_id, "item_data", _item);
                    
                    // init the menu item
                    _inst_id.item_data.init();
                }
            }
        }
        
        // proceed to next state
        active_menu.state = MENU_STATE.UPDATE;
    }
    
    menu_state_update = function() {

    }
    
    menu_state_delete = function() {
        
    }
    #endregion
}

function Menu(options = {}) constructor {
    name              = get_object_value(options, "name", "menu");
    sequence          = get_object_value(options, "sequence", undefined);
    coords            = get_object_value(options, "coords", [camera_get_view_width(view_camera[0])/2, camera_get_view_height(view_camera[0])/2]);
    
    state             = MENU_STATE.CREATE;     // stores the state of the menu sequence
    items_data        = [];                    // stores the item data from the database
    sequence_el       = undefined;             // stores the element id of the created menu sequence
    sequence_inst     = undefined;             // stores the instance struct of the created menu sequence
    
    // create items_data
    var _items = get_object_value(options, "items", []);
    if (array_length(_items) > 0) {
        for (var i = 0; i < array_length(_items); i++) {
            var _data = _items[i];
            
            // add name of menu to store inside the menu item for later referencing if needed (might not need this)
            variable_struct_set(_data, "menu", name);
            
            // create the menu item
            var _item = new Menu_Item(_items[i]);
            
            // store it in the items_data
            array_push(items_data, _item);
        }
    }
}

function Menu_Item(options = {}) constructor {
    name             = get_object_value(options, "name", "menu_item");                   // stores the name of this item
    menu             = get_object_value(options, "menu", undefined);                     // stores the name of the menu controlling this item
    type             = get_object_value(options, "type", MENU_ITEM.BTN);                 // stores the type of the item - controls functionality
    sprite           = get_object_value(options, "sprite", undefined);                   // stores the sprite used for this item 
    select_coords    = get_object_value(options, "select_coords", [0,0]);                // stores the coordinates used in the keyboard selection functionality
    callback         = get_object_value(options, "callback", undefined);                 // stores the callback function used when this item is used
    
    state            = MENU_ITEM_STATE.APPEAR;
    item_obj         = undefined;
    nested_obj       = undefined;
    sequence_el      = undefined;                                      // stores the items sequence element id
    sequence_inst    = undefined;                                      // stores the items sequence instance struct
    
    init = function() {
        
        // set placeholder sprite
        item_obj.sprite_index = sprite;
        item_obj.image_speed = 0;
        item_obj.image_index = 0;
        
        // hide placeholders
        toggle_placeholder_visible(false);
        
        // set sequence to idle
        set_sequence("seq_btn_appear");
    }
    
    update = function() {
        if (state == MENU_ITEM_STATE.DISABLED) return;
        
        // set gui mouse coords
        var mx = device_mouse_x_to_gui(0);
        var my = device_mouse_y_to_gui(0);
        
        // update nest state with mouse
        if (state != MENU_ITEM_STATE.APPEAR && state != MENU_ITEM_STATE.DELETE) {
            if (point_in_rectangle(mx, my, item_obj.bbox_left, item_obj.bbox_top, item_obj.bbox_right, item_obj.bbox_bottom)) {
                if (mouse_check_button_pressed(mb_left)) {
                    change_state(MENU_ITEM_STATE.SELECTED);
                    set_sequence("seq_btn_selected");
                } else if (state != MENU_ITEM_STATE.SELECTED) {
                    change_state(MENU_ITEM_STATE.HOVER);
                    set_sequence("seq_btn_hover");
                }
            } else if (state != MENU_ITEM_STATE.SELECTED) {
                change_state(MENU_ITEM_STATE.IDLE);
                set_sequence("seq_btn_idle");
            }
        }
        
        // run nest state
        switch(state) {
            case MENU_ITEM_STATE.APPEAR:
                if (layer_sequence_is_finished(sequence_el)) {
                    state = MENU_ITEM_STATE.IDLE;
                }
                break;
            case MENU_ITEM_STATE.IDLE:
                
                break;
            case MENU_ITEM_STATE.HOVER:
                
                break;
            case MENU_ITEM_STATE.SELECTED:

                if (is_callable(callback)) {
                    callback();
                }
            
                for (var i = 0; i < instance_number(obj_menu_item); i++) {
                    var _item = instance_find(obj_menu_item, i);
                    // skip items not belonging to this menu and skip this item
                    if (_item.item_data.menu != menu) continue;
                    if (_item.id == item_obj.id) continue;
                    
                    // set state and sequence
                    _item.item_data.change_state(MENU_ITEM_STATE.DELETE);
                    _item.item_data.set_sequence("seq_btn_delete");
                }
                break;
        }
    }
    
    #region - Helpers
    
    set_sequence = function(sequence) {
        if (!is_undefined(sequence_inst) && sequence_inst.sequence.name == sequence) return;
        
        // destroy existing sequence
        if (layer_sequence_exists(item_obj.layer, sequence_el)) {
            layer_sequence_destroy(sequence_el);
        }
        
        // create new sequence
        var _sequence = asset_get_index(sequence);
        sequence_el = layer_sequence_create("ui", item_obj.x, item_obj.y, _sequence);
        sequence_inst = layer_sequence_get_instance(sequence_el);
        
        // override menu item
        sequence_instance_override_object(sequence_inst, obj_menu_item_nested, item_obj);
    }
    
    set_sprite = function() {
        if (is_undefined(sequence_inst)) return;
        
        // set nested menu item object sprite_index
        for (var i = 0; i < array_length(sequence_inst.activeTracks); i++) {
            nested_obj = sequence_inst.activeTracks[i].instanceID;
            nested_obj.sprite_index = sprite;
        }
    }
    
    change_state = function(_state) {
        if (state == _state) return;
        state = _state;
    }
    
    toggle_placeholder_visible = function(visible) {
        for (var i = 0; i < array_length(item_obj.sequence_instance.activeTracks); i++) {
            item_obj.sequence_instance.activeTracks[i].track.visible = visible;
        }
    }
    
    #endregion
}
