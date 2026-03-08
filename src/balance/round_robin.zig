const std = @import("std");
const Atomic = std.atomic.Value;

pub fn RoundRobinBalancer(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        index: Atomic(usize),
        targets: []const T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, targets: []const T) !Self {
            return .{
                .allocator = allocator,
                .targets = try allocator.dupe(T, targets),
                .index = .init(0),
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.targets);
        }

        pub fn select(self: *Self) T {
            return self.targets[self.index.fetchAdd(1, .monotonic) % self.targets.len];
        }
    };
}
