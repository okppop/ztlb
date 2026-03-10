const std = @import("std");
const t = std.testing;
const IPHashBalancer = @import("ip_hash.zig").IPHashBalancer;

test "IPHashBalancer" {
    var targets = [_][]const u8{
        "1.1.1.1",
        "2.2.2.2",
        "8.8.8.8",
        "123.321.123.321",
    };

    var targetsMap: std.StringHashMap([]const u8) = .init(t.allocator);
    defer targetsMap.deinit();

    var balancer: IPHashBalancer([]const u8) = try .init(t.allocator, &targets);
    defer balancer.deinit();

    for (targets) |client_ip| {
        try targetsMap.put(client_ip, balancer.select(client_ip));
    }

    for (0..100) |_| {
        for (targets) |client_ip| {
            try t.expectEqualStrings(
                balancer.select(client_ip),
                targetsMap.get(client_ip).?,
            );
        }
    }
}
