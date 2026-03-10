const std = @import("std");
const Md5 = std.crypto.hash.Md5;

pub fn IPHashBalancer(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        targets: []const T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, targets: []const T) !Self {
            return .{
                .allocator = allocator,
                .targets = try allocator.dupe(T, targets),
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.targets);
        }

        pub fn select(self: *Self, ip: []const u8) T {
            const hashed = Md5.hashResult(ip);
            var sum: usize = 0;
            inline for (hashed) |byte| sum += byte;

            return self.targets[sum % self.targets.len];
        }
    };
}
