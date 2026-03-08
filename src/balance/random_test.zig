const std = @import("std");
const t = std.testing;
const RandomBalancer = @import("random.zig").RandomBalancer;

test "RandomBalancer" {
    var targets: std.ArrayList(u8) = .empty;
    defer targets.deinit(t.allocator);

    for (0..100) |i| {
        try targets.append(t.allocator, @intCast(i));

        var balancer: RandomBalancer(u8) = try .init(t.allocator, targets.items);
        defer balancer.deinit();

        for (0..100) |_| {
            const selected = balancer.select();
            try t.expect(std.mem.containsAtLeast(
                u8,
                targets.items,
                1,
                std.mem.asBytes(&selected),
            ));
        }
    }
}
