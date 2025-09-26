function get_object_value(object, key, default_value) {
    /// @desc search an object for a key and return the value of that key
    /// @param {struct} object     The struct to pull the value from
    /// @param {string} key        The key name to look up in the struct
    /// @param {*} default_value   The fallback value to return if the key is not found
    /// @returns {*} The value from the struct, or the default value if not found
    
    if (is_struct(object) && variable_struct_exists(object, key)) {
        var val = variable_instance_get(object, key);
        return val;
    } else {
        return default_value;
    }
}

function print() {
    ///@desc wrapper function for easily printing messages to the log
	var _output_string = "";
	for (var _i = 0; _i < argument_count; _i++) {
	    _output_string += string(argument[_i]) + " ";
	}
	show_debug_message(_output_string);
}