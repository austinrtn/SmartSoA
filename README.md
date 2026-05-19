# What is SmartSoA?
SmartSoA is a library that allows user to create and manipulate a **Struct-of-Arrays** data container.  It is similar to Zig's `std.MultiArraylist` with one key difference: the user can retrieve multiple fields at once using the `SmartSoA.allItems` or `SmartSoA.manyItems` methods.  This function returns a struct that is generated using the `comptime fields` parameter.  This struct returns a slice of each specified field from the main data structure.  While there is no meaningful difference in performance between Zig's MultiArraylist and the SmartSoA data structure,  the difference in ergonomics are quiet substantial and make for a much less frustrating experience.

# How to Install
First run this command in your terminal:

```zig fetch --save=smart_soa git+https://github.com/austinrtn/SmartSoA.git```

Then add this code to your `build.zig` file:
```zig
const smart_soa = b.dependency("smart_soa", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("SmartSoA", smart_soa.module("SmartSoA"));
```

Finally, use the library in your project as such:
`const SmartSoA = @import("SmartSoA").SmartSoA;`

# Ergonomic Examples
##### The struct we will be using:
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

# All Fields / Methods

##### `len`
Number of valid elements stored in the SmartSoA.

##### `capacity`
Number of allocated elements available within each field array.

##### `inner`
Contains slices for all field data.
Not for API use.

##### `init`
Creates a new SmartSoA instance.

##### `ensureTotalCapacity`
Increases the capacity of the arrays to store more items.
Allows for arrays to grow without allocation up to set capacity.
Will invalidate element pointers if additional memory is needed.

##### `items`
Returns a slice of values for a specified field.

##### `manyItems`
Returns a struct of slices for each specified field.
For example, if you pass fields `.x` and `.y`, then
`soa.manyItems(&.{.x, .y});`
will return a struct with fields `x` and `y`, both being slices of
their respective type.

##### `get`
Returns a copy of the child struct at a specified index.

##### `set`
Sets the element at a specified index.

##### `append`
Adds an element to the end of the SmartSoA.
Will invalidate element pointers if additional memory is needed.

##### `insert`
Inserts a new element at a specified index, shifting all following elements over one.
Will invalidate element pointers if additional memory is needed.

##### `clearRetainingCapacity`
Clears all data within the field arrays but keeps capacity at its current value.

##### `clearAndFree`
Clears all data and frees all field array data, setting capacity to 0.

##### `swapAndPop`
Removes and returns an element at a specified index and replaces it with the last element in the array.
Returns null if the SmartSoA is empty.
Fast, but does not retain array order.

##### `swapAndPopIdx`
Removes the element at a specified index and replaces it with the last element in the array.
Returns the removed index.
Returns null if the SmartSoA is empty.
Fast, but does not retain array order.

##### `pop`
Returns the last element in the SmartSoA, or returns null if the SmartSoA is empty.

##### `orderedRemove`
Removes the element at a specified index.
Retains the order of the array but is slower than `swapAndPop`.

##### `orderedRemoveMany`
Removes the elements from `from_idx` through `to_idx`, including both indexes.

*More functions may be added in the future*
