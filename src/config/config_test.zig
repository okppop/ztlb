const std = @import("std");
const conf = @import("config.zig");

test "test get_config" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leaks");
    const allocator = gpa.allocator();

    var config = try conf.get_config(allocator);
    defer config.deinit(allocator);

    std.debug.print("config: {}\n", .{config});
}
