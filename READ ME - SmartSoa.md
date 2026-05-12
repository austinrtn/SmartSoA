# What is SmartSoA? 
SmartSoa is a library that allows user to create and manipulate a **Struct-of-Arrays** data container.  It is similar to Zig's `std.MultiArraylist` with one key difference: the user can retrieve multiple fields at once using the `SmartSoa.manyItems` function.  This function returns a struct that is generated using the `comptime fields` parameter.  This struct returns a slice of each specified field from the main data structure.  While there is no meaningful difference in performance between Zig's MultiArraylist and the SmartSoA data structure,  the difference in ergonomics are quiet substantial and make for a much less frustrating experience. 


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
var list = MultiArraylist(Particle); 
defer list.deinit(allocator);

// First we need to convert to a slice (ewe)
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
var soa = SmartSoA(Particle); 
defer soa.deinit(allocator);

// No need to call slice, we can just call soa.allItems() to
// get the relevant data via field access. 
const = soa.allItems();

// Let's move the particles
for(soa.x, soa.y, soa.xvel, soa.yvel) |*x, *y, xvel, yvel| {
	x.* += xvel;
	y.* += yvel;
}

// Now let's draw the particles.
for(soa.x, soa.y, soa.r, soa.color) |x, y, r, color| {
	drawCircle(x, y, r, color);
}
```