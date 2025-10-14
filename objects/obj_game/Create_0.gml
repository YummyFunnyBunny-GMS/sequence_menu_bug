// load menu data
var _menu_db = db_menus();

// create the menu system
global.menu = new Menu_System();

// create the menu controller object
instance_create_depth(0,0,0,obj_menu);

// initialize the menu system with included data
global.menu.init({ data: _menu_db });

// go to main menu
room_goto(rm_main_menu);


