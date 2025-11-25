package robingui

//import "shared:rlgl_ex/rlgl_ex"
//import "vendor:raylib/rlgl"
import rl "vendor:raylib"
import "base:runtime" // Needed to give contextless elements context
import "core:mem" // Needed to store the allocator
import "core:mem/virtual" // Needed for the memory arena (TODO: Add alternate system for WASM builds (use `when`!))
import "core:strings" 
import "core:fmt"
import os "core:os/os2"

ElementState :: enum {
	None = 0, // Check if not zero to see if button is pressed
	Hover,
	Pressed,
	Down,
	Released,
}

ElementStateColors :: struct {
	fill_color: rl.Color,
	outline_color: rl.Color,
	text_color: rl.Color,
}

ThemeColors :: struct {
	none: ElementStateColors,
	hover: ElementStateColors,
	down: ElementStateColors,
}

Theme :: struct {
	colors: ThemeColors,
	line_thickness: f32,
	font: rl.Font
}

@(private)
State :: struct {
	theme: Theme,
	// This arena is largely used for converting text from odin strings to cstrings. It is cleared at the end of the frame.
	temp_arena: virtual.Arena, // Basically context.temp_allocator, but our own version so we avoid accidentally deleting user data; This is technically the base structure though
	temp_allocator: mem.Allocator, // The actual allocator we use for dynamic memory allocation calls
}

// Universal state
@(private)
gui_state: State

// This is where a lot of the bullshit happens lol. Stuff that sets up the base state and sets up reasonable defaults for everything, as well as taking care of memory allocation preperations for the user.
// Is this super neccessary? Nah, but I like it :)
@(private)
@(init)
init :: proc "contextless" () {
	context = runtime.default_context()

	// Initialize arena
	err := virtual.arena_init_growing(&gui_state.temp_arena)
	if err != .None {
		fmt.println("Something went wrong while trying to set up the arena for robingui:", err)
		os.exit(int(err))
	}

	// Get the allocator for our arena
	allocator := virtual.arena_allocator(&gui_state.temp_arena)

	theme_colors := ThemeColors {
		none = {
			{201, 201, 201, 255}, {131, 131, 131, 255}, {104, 104, 104, 255},
		},
		hover = {
			{201, 239, 254, 255}, {91, 178, 217, 255}, {108, 155, 188, 255},
		},
		down = {
			{151, 232, 255, 255}, {4, 146, 199, 255}, {54, 139, 175, 255},
		},
	}

	// Define default theme
	theme := Theme {
		colors = theme_colors,
		line_thickness = 2,
	}

	// Set up state
	gui_state.theme = theme
	gui_state.temp_allocator = allocator
}

@(private)
@(fini)
fini :: proc "contextless" () {
	context = runtime.default_context()

	// Clean up our arena
	virtual.arena_destroy(&gui_state.temp_arena)
}

@(private)
get_state_from_rectangle :: proc(rectangle: rl.Rectangle, button: rl.MouseButton = .LEFT) -> (element_state: ElementState) {
	if rl.CheckCollisionPointRec(rl.GetMousePosition(), rectangle) {
		if rl.IsMouseButtonPressed(button) do return .Pressed
		else if rl.IsMouseButtonReleased(button) do return .Released
		else if rl.IsMouseButtonDown(button) do return .Down
		else do return .Hover
	}

	return
}

@(private)
get_colors_from_state :: proc(element_state: ElementState) -> (colors: ElementStateColors) {
	// This is the most efficient way I could figure out how to do this
	#partial switch element_state {
		case .Released:
			fallthrough
		case .Hover:
			return gui_state.theme.colors.hover
		case .Pressed:
			fallthrough
		case .Down:
			return gui_state.theme.colors.down
	}

	return gui_state.theme.colors.none
}

set_theme :: proc(theme: Theme) {
	gui_state.theme = theme
}

get_theme :: proc() -> (theme: Theme) {
	return gui_state.theme
}

button :: proc(rectangle: rl.Rectangle, down: ^bool, text: string = "") -> (element_state: ElementState) {
	element_state = get_state_from_rectangle(rectangle)

	if element_state == .Pressed || element_state == .Down do down^ = true
	else do down^ = false

	colors := get_colors_from_state(element_state)
	rl.DrawRectangleRec(rectangle, colors.fill_color)
	rl.DrawRectangleLinesEx(rectangle, gui_state.theme.line_thickness, colors.outline_color)

	if text != "" {
		c_text := strings.clone_to_cstring(text, gui_state.temp_allocator)

		font := rl.GetFontDefault()
		text_size := rl.MeasureTextEx(font, c_text, f32(font.baseSize), f32(font.glyphPadding + 1) /*ough*/)

		text_position := rl.Vector2 {rectangle.x, rectangle.y} + {rectangle.width / 2, rectangle.height / 2} - (text_size / 2)

		rl.DrawTextEx(font, c_text, text_position, f32(font.baseSize) * 1.001 /*ugh*/, f32(font.glyphPadding + 1) /*UGH*/, colors.text_color)
	}

	return
}

end_gui :: proc() {
	// Deallocate everything in the arena
	free_all(gui_state.temp_allocator)
}