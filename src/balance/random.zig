const std = @import("std");

pub fn RandomBalancer(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        prng: std.Random.DefaultPrng,

        targets: []const T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, targets: []const T) !Self {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));

            return .{
                .allocator = allocator,
                .prng = std.Random.DefaultPrng.init(seed),

                .targets = try allocator.dupe(T, targets),
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.targets);
        }

        pub fn select(self: *Self) T {
            return self.targets[
                self.prng.random().uintLessThan(
                    usize,
                    self.targets.len,
                )
            ];
        }
    };
}
