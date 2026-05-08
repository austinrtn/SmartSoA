const std = @import("std");
const Io = std.Io;
const SmartSoa = @import("SmartSoa.zig").SmartSoa;

const Point = struct {x: f32, y: f32};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const writer = &stdout.interface;

    var mal_timestamp: Timestamps = .init(io);
    var smart_timestamp: Timestamps = .init(io);

    const P_Count = 1_000_000;
    const frame_count = 10_000;
    const max_x = 100_000.0;
    const max_y = 100_000.0;
    const max_vel = 100; 
    
    const Particle = struct {
        x: f32,
        y: f32, 
        x_vel: f32,
        y_vel: f32,
    };

    try writer.writeAll("Generating Particles...\n");
    try writer.flush();
    const base_particles = try allocator.alloc(Particle, P_Count);
    defer allocator.free(base_particles);

    const src = std.Random.IoSource{.io = io};
    const rand = src.interface();
    
    for(base_particles) |*p| {
        p.* = .{
            .x = rand.float(f32) * max_x,
            .y = rand.float(f32) * max_y,
            .x_vel = rand.float(f32) * max_vel,
            .y_vel = rand.float(f32) * max_vel,
        };
    }

    const mal_particles = try allocator.dupe(Particle, base_particles);
    defer allocator.free(mal_particles);
    const smart_particles = try allocator.dupe(Particle, base_particles);
    defer allocator.free(smart_particles);

    var mal_list: std.MultiArrayList(Particle) = .empty;
    defer mal_list.deinit(allocator);

    var smart_list: SmartSoa(Particle) = .init();
    defer smart_list.deinit(allocator);

    try writer.writeAll("Particles generated, Testing MultiArraylist\n");
    try writer.writeAll("Appending Particles...\n");
    try writer.flush();
    
    mal_timestamp.append.start();
    
    try mal_list.ensureTotalCapacity(allocator, P_Count);
    for(mal_particles) |p| {
        try mal_list.append(allocator, p);
    }
    
    mal_timestamp.append.end();

    try writer.writeAll("Getting Slices...\n");
    try writer.flush();
    
    mal_timestamp.get_slices.start();
    
    const xs = mal_list.items(.x);
    const ys = mal_list.items(.y);
    const x_vels = mal_list.items(.x_vel);
    const y_vels = mal_list.items(.y_vel);

    mal_timestamp.get_slices.end();

    try writer.writeAll("Manipulating data...\n");
    try writer.flush();

    mal_timestamp.manipulate.start();
    for (0..frame_count) |_| {
        for(xs, ys, x_vels, y_vels) |*x, *y, x_vel, y_vel| {
            x.* += x_vel;
            y.* += y_vel;
        }
    }
    mal_timestamp.manipulate.end();
    
    try writer.writeAll("\nTesting SmartSoa...\n");
    try writer.writeAll("Appending Particles...\n");
    try writer.flush();

    smart_timestamp.append.start();

    try smart_list.ensureTotalCapacity(allocator, P_Count);
    for(smart_particles) |p| {
        try smart_list.append(allocator, p);
    }

    smart_timestamp.append.end();

    try writer.writeAll("Getting slices via manyItems...\n");
    try writer.flush();

    smart_timestamp.get_slices.start();

    const smart_items = smart_list.manyItems(&.{ .x, .y, .x_vel, .y_vel });

    smart_timestamp.get_slices.end();

    try writer.writeAll("Manipulating data...\n");
    try writer.flush();

    smart_timestamp.manipulate.start();
    for (0..frame_count) |_| {
        for(smart_items.x, smart_items.y, smart_items.x_vel, smart_items.y_vel) |*x, *y, x_vel, y_vel| {
            x.* += x_vel;
            y.* += y_vel;
        }
    }
    smart_timestamp.manipulate.end();

    for (xs, ys, smart_items.x, smart_items.y) |mal_x, mal_y, smart_x, smart_y| {
        try std.testing.expectEqual(mal_x, smart_x);
        try std.testing.expectEqual(mal_y, smart_y);
    }

    try writer.writeAll("\nComparison\n");
    try printTiming(writer, "MultiArrayList", mal_timestamp);
    try printTiming(writer, "SmartSoa", smart_timestamp);
    try writer.writeAll("\nRatios (SmartSoa / MultiArrayList)\n");
    try printRatio(writer, "append", smart_timestamp.append.end_time, mal_timestamp.append.end_time);
    try printRatio(writer, "get slices", smart_timestamp.get_slices.end_time, mal_timestamp.get_slices.end_time);
    try printRatio(writer, "manipulate", smart_timestamp.manipulate.end_time, mal_timestamp.manipulate.end_time);
    try writer.flush();
}

test "items" {
    const allocator = std.testing.allocator;
    var list = SmartSoa(Point).init();
    defer list.deinit(allocator);

    const point: Point = .{.x = 1.5, .y = 0}; 
    
    try list.append(allocator, point);
    const items = list.manyItems(&.{.x, .y});

    for(items.x, items.y) |*x, *y| {
        x.* += 1;
        y.* += 1;
    }

    for(items.x, items.y) |x, y| {
        try std.testing.expectEqual(point.x, x - 1);
        try std.testing.expectEqual(point.y, y - 1);
    }
}

test "many_appends" {
    const point_count = 1_000_000;
    const allocator = std.testing.allocator;

    var prng = std.Random.DefaultPrng.init(@intCast(std.testing.random_seed));
    const random = prng.random();
    
    var list = SmartSoa(Point).init();
    defer list.deinit(allocator);

    for(0..point_count) |_| {
        const x: f32 = random.float(f32) * 100_000;
        const y: f32 = random.float(f32) * 100_000;
        try list.append(allocator, .{.x = x, .y = y});
    }

    try std.testing.expectEqual(list.len, point_count);
}

test "insert" {
    const allocator = std.testing.allocator;
    
    var list = SmartSoa(struct{int: usize}).init();
    defer list.deinit(allocator);

    for(0..5) |i| {
        try list.append(allocator, .{.int = i});
    }

    for(5..10) |i| {
        list.insert(.{.int = i}, i - 5);
    }

    for(0..5) |i| {
        const T = list.get(i);
        try std.testing.expectEqual(i + 5, T.int);
    }
}

test "clear" {
    const allocator = std.testing.allocator;
    
    var list: SmartSoa(struct{int: usize}) = .init();
    defer list.deinit(allocator);
    
    try list.append(allocator, .{.int = 5});
    try std.testing.expectEqual(list.len, 1); 
    try std.testing.expect(list.cap > 0); 

    list.clearRetainingCapacity();
    try std.testing.expectEqual(list.len, 0); 
    try std.testing.expect(list.cap > 0); 
    
    list.clearAndFree(allocator);
    try std.testing.expectEqual(list.len, 0); 
    try std.testing.expectEqual(list.cap, 0); 
}

test "remove" {
    const allocator = std.testing.allocator;
    
    var list: SmartSoa(struct{int: usize}) = .init();
    defer list.deinit(allocator);

    for(0..10) |i| {
        try list.append(allocator, .{.int = i});
    }

    const swapped = list.swapAndPop(0);
    try std.testing.expectEqual(swapped.?.int, 9);
    try std.testing.expectEqual(list.len, 9);

    const popped = list.pop();
    
    try std.testing.expectEqual(popped.?.int, 9);
    try std.testing.expectEqual(list.len, 8);

    std.debug.print("{any}\n", .{list.items(.int)});
    list.orderedRemove(5);
    std.debug.print("{any}\n", .{list.items(.int)});
}

const Time = struct {
    const Self = @This();
    const Timestamp = std.Io.Clock.Timestamp;

    io: std.Io = undefined,
    start_time: Timestamp = undefined, 
    end_time: i64 = 0,
    
    fn start(self: *Self) void {
        self.start_time = .now(self.io, .awake);
    }

    fn end(self: *Self) void {
        self.end_time = self.start_time.durationTo(.now(self.io, .awake)).raw.toMicroseconds();
    }
};

const Timestamps = struct {
    append: Time = .{},
    get_slices: Time = .{},
    manipulate: Time = .{},

    fn init(io: std.Io) Timestamps {
        var ts: Timestamps = .{};
        inline for(std.meta.fields(@This())) |field| {
            const time = &@field(ts, field.name);
            time.io = io;
        }
        
        return ts;
    }
};

fn printTiming(writer: *std.Io.Writer, label: []const u8, ts: Timestamps) !void {
    try writer.print(
        "{s}: append={}us, get_slices={}us, manipulate={}us\n",
        .{ label, ts.append.end_time, ts.get_slices.end_time, ts.manipulate.end_time },
    );
}

fn printRatio(writer: *std.Io.Writer, label: []const u8, lhs: i64, rhs: i64) !void {
    const ratio = if (rhs == 0) 0.0 else @as(f64, @floatFromInt(lhs)) / @as(f64, @floatFromInt(rhs));
    try writer.print("{s}: {d:.3}x\n", .{ label, ratio });
}
