# What is SmartSoA? 
SmartSoA is a library that allows user to create and manipulate a **Struct-of-Arrays** data container.  It is similar to Zig's `std.MultiArraylist` with one key difference: the user can retrieve multiple fields at once using the `SmartSoA.manyItems` function.  This function returns a struct that is generated using the `comptime fields` parameter.  This struct returns a slice of each specified field from the main data structure.  While there is no meaningful difference in performance between Zig's MultiArraylist and the SmartSoA data structure,  the difference in ergonomics are quiet substantial and make for a much less frustrating experience. 
# Ergonomic Examples: 
##### The struct we will be using : 
```zig
const Particle = struct {
	x: f32, 
	y: f32, 
	xvel: f32, 
	yvel: f32,
	r: f32, 
	color: Color 
}
```
##### std.MultiArraylist:  
```c
var list: MultiArraylist(Particle) = .empty;
defer list.deinit(allocator);

// First we need to convert to a slice (ew)
const s = list.slice();

// Then everytime we want to use the fields within the slice, we need to call items (also ewe)

// Let's move the particles
for(s.items(.x), s.items(.y), s.items(.xvel), s.items(.yvel)) 
	|*x, *y, xvel, yvel| {
	x.* += xvel;
	y.* += yvel;
}

// Now let's draw the particles.  Again, we need to call .items for each field
for(s.items(.x), s.items(.y), s.items(.r), s.items.color) |x, y, r, color| {
	drawCircle(x, y, r, color);
}
```
##### SmartSoA:  
```c
// Similar init
var soa: SmartSoA(Particle) = .init(); 
defer soa.deinit(allocator);

// No need to call slice, we can just call soa.allItems() to
// get the relevant data via field access. 
const soa = soa.allItems();

// You can also use the soa.manyItems() function to spefify which fields you 
// want returned by passing an array of FieldEnum values 
const selected_items = manyItems(&.{.x, .y, .xvel, .yvel});

// But we'll just stick with our soa variable for this example
_ = selected_items; 

// First let's capture the data necessary to move the particles 
for(soa.x, soa.y, soa.xvel, soa.yvel) |*x, *y, xvel, yvel| {
	x.* += xvel;
	y.* += yvel;
}

// Then we use that same struct to capture the necessary
// data to draw the particles using the same struct.
for(soa.x, soa.y, soa.r, soa.color) |x, y, r, color| {
	drawCircle(x, y, r, color);
}

// If we wanted to get structs of the SmartSoA container
// with specified fields, we can use the soa.manyItems instead.
// It should be noted that there is not a significant performance 
// difference between manyItems and allItems methods.

const move_items = soa.manyItems(&.{.x, .y, .xvel, .yvel});
const draw_items = soa.manyItems(&.{.x, .y, .r, .color});
```

# Other Fields