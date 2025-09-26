//==========================
// FEATURES TO ADD

// - add different hovered effects we can choose from
//    - change image index
//    - change x/y coords (ex. raise by 2px if hovered)
//    - change opacity
// - add new item types
//    - checkbox
//    - slider

// BUG FIXES
// - fix bug with selected_index becoming undefined when mixing keyboard and mouse hovering
//==========================

enum MENU_STATE {
    CREATE,
    SET_ITEMS,
    SET_NESTED,
    UPDATE,
    DELETE,
}

enum MENU_ITEM_STATE {
    INIT,
    SET,
    UPDATE,
    DELETE,
}

enum MENU_ITEM_NEST_STATE {
    IDLE,
    HOVERED,
    SELECTED,
    DISABLED,
}

enum MENU_ITEM {
    BTN,
}

enum MENU_ITEM_HOVER {
    NONE,        // nothing happens when you hover over the item
    IMG_IDX,     // the image index of the item changes
    FLOAT,       // the items coordinates change slightly
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
        
        // create the menu surface
        if (!surface_exists(surface)) create_surface();
        
        // import menu data
        print(options);
        var _data = get_object_value(options, "data", []);
        print(_data);
        if (array_length(_data) > 0) {
            print("data!");
            for (var i = 0; i < array_length(_data); i++) {
                var _menu = new Menu(_data[i]);
                //variable_struct_set(_menu, "menu_system", self);
                print("1");
                array_push(menu_data, _menu);
            }
        }
    }
    
    #region - Menu Surface
    
    create_surface = function() {
        // checks if the menu surface exists and is the size we want
        if (!surface_exists(surface) || surface_get_width(surface) != surface_dimensions[0] || surface_get_height(surface) != surface_dimensions[1]) {
                
            // turns off the regular ui layer (we will be manually drawing it to our surface, not the game)
            layer_set_visible(layer_get_id("ui"), false);
                
            // creates surface and stores it
            if (surface_exists(surface)) surface_free(surface);
            surface = surface_create(surface_dimensions[0], surface_dimensions[1]);
        }
    }
    
    // install the scripts on the layer (do this once when the room starts)
    install_layer_surface = function() {
        if (ui_layer == -1) return;
            
        // install layer scripts to the ui_layer (do this once per room)
        layer_script_begin(ui_layer, menu_ui_layer_begin);
        layer_script_end  (ui_layer, menu_ui_layer_end);
    }
    
    // begin script: set target to menu_surface before the layer draws
    menu_ui_layer_begin = function() {
        if (!surface_exists(surface)) return;
        surface_set_target(surface);
        draw_clear_alpha(c_black, 0);
    }
    
    // end script: reset draw target after the layer finishes drawing
    menu_ui_layer_end = function() {
        surface_reset_target();
    }
    
    draw_gui = function() {
        if (!surface_exists(surface)) return;
        draw_surface(surface, 0, 0);
    }
    
    #endregion
    
    
    room_start = function() {
        // set menu for the main menu room
        if (room == rm_main_menu) {
            set_active_menu("main_menu_main");
        }
        
        install_layer_surface();
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
            case MENU_STATE.SET_NESTED: menu_state_nested(); break;
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
            //print($"{item.select_coords[0]}, {item.select_coords[1]} - {row}, {col}");
            if (item.select_coords[0] == row && item.select_coords[1] == col) {
                found_index = i;
                break;
            }
        }
        //print("found index: ", found_index);
        
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
                    //_inst_id.item_data.init();
                }
            }
        }

        //hover_selection();
        
        // proceed to next state
        active_menu.state = MENU_STATE.SET_NESTED;
    }
    
    menu_state_nested = function() {
        if (is_undefined(active_menu)) return;
        if (active_menu.state != MENU_STATE.SET_NESTED) return;

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
    name = get_object_value(options, "name", "menu");
    sequence = get_object_value(options, "sequence", undefined);
    coords = get_object_value(options, "coords", [camera_get_view_width(view_camera[0])/2, camera_get_view_height(view_camera[0])/2]);
    
    state = MENU_STATE.CREATE;          // stores the state of the menu sequence
    sequence_items = [];                // stores the IDs of the menu items created by the sequence
    items_data = [];                    // stores the item data from the database
    sequence_el = undefined;            // stores the element id of the created menu sequence
    sequence_inst = undefined;          // stores the instance struct of the created menu sequence
    
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
    name = get_object_value(options, "name", "menu_item");       // stores the name of this item
    menu = get_object_value(options, "menu", undefined);         // stores the name of the menu controlling this item
    
    type = get_object_value(options, "type", MENU_ITEM.BTN);     // stores the type of the item - controls functionality
    sprite = get_object_value(options, "sprite", undefined);     // stores the sprite used for this item 
    select_coords = get_object_value(options, "select_coords", [0,0]);  // stores the coordinates used in the keyboard selection functionality
    callback = get_object_value(options, "callback", undefined);        // stores the callback function used when this item is used
    hover_type = get_object_value(options, "hover_type", MENU_ITEM_HOVER.FLOAT);
    
    hovered = false;
    
    state = MENU_ITEM_STATE.INIT;
    nest_state = MENU_ITEM_NEST_STATE.IDLE;
    
    item_obj = undefined;
    sequence_el = undefined;                                        // stores the items sequence element id
    sequence_inst = undefined;                                      // stores the items sequence instance struct
    sequence_track_playing = false;
    
    menu_item_state_init = function() {
        sequence_el = layer_sequence_create("ui", item_obj.x, item_obj.y, seq_btn);
        sequence_inst = layer_sequence_get_instance(sequence_el);
        
        //var _replacing_instance = instance_create_layer(item_obj.x, item_obj.y, item_obj.layer, item_obj.object_index);
        //sequence_instance_override_object(sequence_inst, item_obj.object_index, _replacing_instance);
        
        sequence_instance_override_object(sequence_inst, obj_menu_item, item_obj.object_index);
        
        item_obj.sprite_index = sprite;
        item_obj.image_speed = 0;
        
        menu_item_state_set();
        
        layer_sequence_play(sequence_el);
        
        state = MENU_ITEM_STATE.SET;
    }
    
    update = function() {
        switch(state) {
            case MENU_ITEM_STATE.INIT:
                menu_item_state_init();
                state = MENU_ITEM_STATE.SET;
                break;
            case MENU_ITEM_STATE.SET:
                menu_item_state_set();
                state = MENU_ITEM_STATE.UPDATE;
                break;
            case MENU_ITEM_STATE.UPDATE:
                menu_item_state_update();
                break;
            case MENU_ITEM_STATE.DELETE:
                menu_item_state_delete();
                break;
        }
        
        // reset track playing
        if (sequence_track_playing) {
            if (layer_sequence_is_finished(sequence_el)) {
                sequence_track_playing = false;
            }
        }
        
        //print(layer_sequence_is_paused(sequence_el));
        //print(layer_sequence_get_headpos(sequence_el));
    }

    draw_gui = function() {
        with (item_obj) {
            draw_self();
        }
    }
    
    change_state = function(_state) {
        if (nest_state == _state) return;
        nest_state = _state;
        sequence_track_playing = false; // reset so new track can play
    }
    
    menu_item_play_track = function(track_name) {
        if (is_undefined(sequence_inst)) return;
        if (sequence_track_playing == true) return;
        // Loop all tracks and only enable the one we want
        for (var i = 0; i < array_length(sequence_inst.sequence.tracks); i++) {
            var _track = sequence_inst.sequence.tracks[i];
            sequence_inst.sequence.tracks[i].visible = (_track.name == track_name);
        }
        // Reset to beginning of chosen track
        layer_sequence_headpos(sequence_el, 0);
        layer_sequence_play(sequence_el);
        
        sequence_track_playing = true;
    }
    
    menu_item_state_idle = function() {
        //if (layer_sequence_is_paused(sequence_el)) {
            //layer_sequence_pause(sequence_el);
        //}
    }
    
    menu_item_state_set = function() {
        // set the sprite index for this item
        var sprite_id = asset_get_index(sprite);
        for (var i = 0; i < array_length(sequence_inst.activeTracks); i++) {
            var _track = sequence_inst.activeTracks[i];
            for (var j = 0; j < array_length(_track.track.keyframes); j++) {
                var _keyframe = _track.track.keyframes[j];
                for (var k = 0; k < array_length(_keyframe.channels); k++) {
                    sequence_inst.activeTracks[i].track.keyframes[j].channels[k].spriteIndex = sprite_id;
                }
            }
        }
    }
    
    menu_item_state_update = function() { 
        var mx = device_mouse_x_to_gui(0);
        var my = device_mouse_y_to_gui(0);
        
        if (nest_state != MENU_ITEM_NEST_STATE.DISABLED) {
            if (point_in_rectangle(mx, my, item_obj.bbox_left, item_obj.bbox_top, item_obj.bbox_right, item_obj.bbox_bottom)) {
                if (mouse_check_button(mb_left)) {
                    change_state(MENU_ITEM_NEST_STATE.SELECTED);
                } else {
                    change_state(MENU_ITEM_NEST_STATE.HOVERED);
                }
            } else {
                change_state(MENU_ITEM_NEST_STATE.IDLE);
            }
        }
    }
    
    menu_item_state_delete = function() {
        
    }
}

            

#region - ARCHIVED

    
    
    //set_sequence_track = function(track_name) {
        //for (var i = 0; i < array_length(sequence_inst.sequence.tracks); i++) {
            //var _track = sequence_inst.sequence.tracks[i];
            //var _name = _track.name;
            //if (_name == name) {
                //_track.visible = true;
                ////_track.enabled = true;
            //} else {
                //_track.visible = false;
                ////_track.enabled = false;
            //}
        //}
    //}

    //set_hover = function() {
        //switch(hover_type) {
            //case MENU_HOVER.NONE:
                //break;
            //case MENU_HOVER.INDEX:
                //item_obj.image_index = hovered ? 1 : 0;
                //break;
            //case MENU_HOVER.FLOAT:
                //item_obj.x = item_obj.base_x + (hovered ? float_x : 0);
                //item_obj.y = item_obj.base_y + (hovered ? float_y : 0);
                //break;
        //}
    //}

#endregion
