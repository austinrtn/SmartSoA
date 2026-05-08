const std = @import("std");
const Allocator = std.mem.Allocator;
const Attribute = std.builtin.Type.StructField.Attributes;

pub fn SmartSoa(comptime StructT: type) type {
    const Inner = GetInner(StructT);
    return struct {
        const Self = @This();
        const InnerFields = std.meta.fields(Inner);
    
        len: usize = 0, 
        cap: usize = 0,
        inner: Inner = undefined,
    
        pub fn init() Self {
            return Self{};
        }
    
        pub fn deinit(self: *Self, allocator: Allocator) void {
            if(self.cap > 0) self.freeInner(allocator);
        }

        fn freeInner(self: *Self, allocator: Allocator) void {
            inline for(InnerFields) |field| {
                allocator.free(@field(self.inner, field.name));
            }
        }
    
        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, cap: usize) !void {
            const allocated: bool = (self.cap > 0);
            const new_cap = @max(self.cap, cap);
            
            inline for(InnerFields) |field| {
                const data = &@field(self.inner, field.name);
                if(allocated) data.* = try allocator.realloc(data.*, new_cap)
                    else data.* = try allocator.alloc(@FieldType(StructT, field.name), new_cap);
            }
            
            self.cap = new_cap;
        }
    
        pub fn append(self: *Self, allocator: Allocator, T: StructT) !void {
            if(self.cap == 0)
                try self.ensureTotalCapacity(allocator, 1);
            if(self.len + 1 > self.cap) 
                try self.ensureTotalCapacity(allocator, self.cap * 2);
                
            inline for(InnerFields) |field| {
                @field(self.inner, field.name)[self.len] = @field(T, field.name);
            }
    
            self.len += 1;
        }

        pub fn items(self: *Self, comptime field: std.meta.FieldEnum(Inner)) @FieldType(Inner, @tagName(field)) {
            return @field(self.inner, @tagName(field))[0..self.len];
        }
    
        pub fn manyItems(self: *Self, comptime fields: []const std.meta.FieldEnum(Inner)) GetStructOfArrays(Inner, fields){
            var t: GetStructOfArrays(Inner, fields) = undefined;
    
            inline for(InnerFields) |field| {
                if(@hasField(@TypeOf(t), field.name)) 
                    @field(t, field.name) = @field(self.inner, field.name)[0..self.len];
            }
    
            return t;
        }

        pub fn get(self: *Self, index: usize) StructT {
            var T: StructT = undefined;
            inline for(InnerFields) |field| {
                @field(T, field.name) = @field(self.inner, field.name)[index];
            }
            return T;
        }

        pub fn insert(self: *Self, T: StructT, index: usize) void {
            inline for(InnerFields) |field| {
                @field(self.inner, field.name)[index] = @field(T, field.name);
            }
        }

        pub fn clearRetainingCapacity(self: *Self) void {
           self.len = 0; 
        }

        pub fn clearAndFree(self: *Self, allocator: Allocator) void {
            if(self.cap > 0) self.freeInner(allocator);
            self.len = 0; 
            self.cap = 0;
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
