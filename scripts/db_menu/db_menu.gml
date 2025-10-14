function db_menus(){
    return [
        {
            name: "main_menu_main",
            sequence: seq_main_menu,
            items: [
                {
                    name: "btn_play",
                    type: MENU_ITEM.BTN,
                    sprite: spr_menu_btn_play,
                    select_coords: [0,0],
                    callback: function() {
                        print("PLAY!");
                    }
                },
                {
                    name: "btn_load",
                    type: MENU_ITEM.BTN,
                    sprite: spr_menu_btn_load,
                    select_coords: [1,0],
                    callback: function() {
                        print("LOAD!");
                        
                    }
                },
                {
                    name: "btn_options",
                    type: MENU_ITEM.BTN,
                    sprite: spr_menu_btn_options,
                    select_coords: [2,0],
                    callback: function() {
                        print("OPTIONS!");
                    }
                },
                {
                    name: "btn_quit",
                    type: MENU_ITEM.BTN,
                    sprite: spr_menu_btn_quit,
                    select_coords: [3,0],
                    callback: function() {
                        game_end();
                    }
                },
            ]
        },
    ]
}