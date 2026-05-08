const std = @import("std");
const Io = std.Io;
const Attribute = std.builtin.Type.StructField.Attributes;

const Point = struct {x: f32, y: f32};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var list = try SmartSoa(Point).init(allocator);
    defer list.deinit();

    const point: Point = .{.x = 1.5, .y = 0}; 
    
    try list.ensureTotalCapacity(20);
    try list.append(point);
    
    const items = list.getMany(&.{.x, .y});
    std.debug.print("data: {any}\n", .{items});

    for(items.x, items.y) |*x, *y| {
        x.* += 1;
        y.* += 1;
    }
    
    std.debug.print("data: {any}\n", .{items});

    const point2: Point = .{.x = 21, .y = 69.69};
    try list.append(point2);

    const xs = list.get(.x);
    std.debug.print("data: {any}\n", .{xs});
}

pub fn SmartSoa(comptime StructT: type) type {
    const Inner = GetInner(StructT);
    return struct {
        const Self = @This();
        const InnerFields = std.meta.fields(Inner);
    
        allocator: std.mem.Allocator,
        len: usize = 0, 
        cap: usize = 0,
        inner: Inner = undefined,
    
        pub fn init(allocator: std.mem.Allocator) !Self {
            var self: Self = .{.allocator = allocator};
            
            inline for(InnerFields) |field| {
                @field(self.inner, field.name) = try allocator.alloc(f32, 0);
            }
            
            return self;
        }
    
        pub fn deinit(self: *Self) void {
            inline for(InnerFields) |field| {
                self.allocator.free(@field(self.inner, field.name));
            }
        }
    
        pub fn ensureTotalCapacity(self: *Self, cap: usize) !void {
            const new_cap = @max(self.cap, cap);
            
            inline for(InnerFields) |field| {
                const data = &@field(self.inner, field.name);
                data.* = try self.allocator.realloc(data.*, new_cap);
            }
            
            self.cap = new_cap;
        }
    
        pub fn append(self: *Self, T: StructT) !void {
            if(self.cap == 0)
                try self.ensureTotalCapacity(2);
            if(self.len + 1 > self.cap) 
                try self.ensureTotalCapacity(self.cap * 2);
                
            inline for(InnerFields) |field| {
                @field(self.inner, field.name)[self.len] = @field(T, field.name);
            }
    
            self.len += 1;
        }

        pub fn get(self: *Self, comptime field: std.meta.FieldEnum(Inner)) @FieldType(Inner, @tagName(field)) {
            return @field(self.inner, @tagName(field))[0..self.len];
        }
    
        pub fn getMany(self: *Self, comptime fields: []const std.meta.FieldEnum(Inner)) GetStructOfArrays(Inner, fields){
            var t: GetStructOfArrays(Inner, fields) = undefined;
    
            inline for(InnerFields) |field| {
                if(@hasField(@TypeOf(t), field.name)) 
                    @field(t, field.name) = @field(self.inner, field.name)[0..self.len];
            }
    
            return t;
        }
    };
}

fn GetInner(comptime T: type) type {
    const field_names = std.meta.fieldNames(T); 
    
    const field_types = blk: {
        var types: [field_names.len]type = undefined;
        inline for(field_names, 0..) |name, i| types[i] = []@FieldType(T, name);
        break :blk types;
    };
    
    const field_attrs = blk: {
        var attrs: [field_names.len]Attribute = undefined;
        for(0..field_names.len) |i| attrs[i] = .{};
        break :blk attrs;
    };

    return @Struct(
        .auto,
        null,
        field_names,
        &field_types,
        &field_attrs,
    );
}

fn GetStructOfArrays(comptime T: type, comptime fields: []const std.meta.FieldEnum(T)) type {
    const field_names = blk: {
        var names: [fields.len][]const u8 = undefined;
        for(0..fields.len) |i| {
            names[i] = @tagName(fields[i]);
        }
        break :blk names;
    };

    const field_types = blk: {
        var types: [fields.len]type = undefined;
        for(0..fields.len) |i| {
            types[i] = @FieldType(T, @tagName(fields[i]));
        }

        break :blk types;
    };

    const field_attrs = blk: {
        var attrs: [fields.len]Attribute = undefined;
        for(0..fields.len) |i| {
            attrs[i] = .{};
        }
        
        break :blk attrs;
    };
    
    return @Struct(
        .auto,
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );
}
