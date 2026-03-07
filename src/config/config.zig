const std = @import("std");
const zon = std.zon;

const CONF_PATH_ENV_KEY: []const u8 = "CONF_PATH";
const CONF_PATH_DEFAULT: []const u8 = "ztlb.conf";

pub const Config = struct {
    bind: []const Bind,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.bind) |bind_item| {
            allocator.free(bind_item.address);

            switch (bind_item.forward) {
                .round_robin => |rule| free_nested_slice(allocator, u8, rule),
                .weighted_round_robin => |rule| free_ForwardWeighted_slice(allocator, rule),
                .ip_hash => |rule| free_nested_slice(allocator, u8, rule),
                .least_connections => |rule| free_nested_slice(allocator, u8, rule),
                .weighted_least_connections => |rule| free_ForwardWeighted_slice(allocator, rule),
                .least_response_time => |rule| free_nested_slice(allocator, u8, rule),
                .random => |rule| free_nested_slice(allocator, u8, rule),
            }
        }
        allocator.free(self.bind);
    }

    fn vaildate_config(self: Config, allocator: std.mem.Allocator) !void {
        var bind_address_map: std.StringHashMap(bool) = .init(allocator);
        defer bind_address_map.deinit();
        var target_address_map: std.StringHashMap(bool) = .init(allocator);
        defer target_address_map.deinit();

        for (self.bind) |item| {
            if (bind_address_map.contains(item.address)) {
                std.log.err("bind address: {s} duplicate", .{item.address});
                return error.BindAddressDuplicate;
            }
            try bind_address_map.put(item.address, true);

            switch (item.forward) {
                .round_robin => |rule| try check_duplicate_nested_slice(&target_address_map, rule),
                .weighted_round_robin => |rule| try check_duplicate_ForwardWeighted_slice(&target_address_map, rule),
                .ip_hash => |rule| try check_duplicate_nested_slice(&target_address_map, rule),
                .least_connections => |rule| try check_duplicate_nested_slice(&target_address_map, rule),
                .weighted_least_connections => |rule| try check_duplicate_ForwardWeighted_slice(&target_address_map, rule),
                .least_response_time => |rule| try check_duplicate_nested_slice(&target_address_map, rule),
                .random => |rule| try check_duplicate_nested_slice(&target_address_map, rule),
            }
        }
    }

    fn free_nested_slice(allocator: std.mem.Allocator, T: type, s: []const []const T) void {
        for (s) |item| {
            allocator.free(item);
        }
        allocator.free(s);
    }

    fn free_ForwardWeighted_slice(allocator: std.mem.Allocator, s: []const ForwardWeighted) void {
        for (s) |item| {
            allocator.free(item.target);
        }
        allocator.free(s);
    }

    fn check_duplicate_nested_slice(map: *std.StringHashMap(bool), s: []const []const u8) !void {
        map.clearAndFree();
        for (s) |target| {
            if (map.contains(target)) {
                std.log.err("target address: {s} duplicate", .{target});
                return error.TargetAddressDuplicate;
            }
            try map.put(target, true);
        }
    }

    fn check_duplicate_ForwardWeighted_slice(map: *std.StringHashMap(bool), s: []const ForwardWeighted) !void {
        map.clearAndFree();
        for (s) |item| {
            if (map.contains(item.target)) {
                std.log.err("target address: {s} duplicate", .{item.target});
                return error.TargetAddressDuplicate;
            }
            try map.put(item.target, true);
        }
    }
};

const Bind = struct {
    address: []const u8,
    protocol: Protocol,
    forward: Forward,
};

const Protocol = enum {
    tcp,
    udp,
};

const Forward = union(enum) {
    round_robin: []const []const u8,
    weighted_round_robin: []const ForwardWeighted,
    ip_hash: []const []const u8,
    least_connections: []const []const u8,
    weighted_least_connections: []const ForwardWeighted,
    least_response_time: []const []const u8,
    random: []const []const u8,
};

const ForwardWeighted = struct {
    target: []const u8,
    weight: u16,
};

pub fn get_config(allocator: std.mem.Allocator) !Config {
    var conf_path = CONF_PATH_DEFAULT;

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    if (env_map.get(CONF_PATH_ENV_KEY)) |v| {
        if (v.len == 0) {
            return error.InvalidConfigPath;
        }

        conf_path = v;
    }

    var conf_file: std.fs.File = undefined;
    if (conf_path[0] == '/') {
        conf_file = try std.fs.openFileAbsolute(conf_path, .{
            .mode = .read_only,
        });
    } else {
        conf_file = try std.fs.cwd().openFile(conf_path, .{
            .mode = .read_only,
        });
    }
    defer conf_file.close();

    const conf_file_stat = try conf_file.stat();
    const conf_data = try conf_file.readToEndAlloc(allocator, conf_file_stat.size);
    const conf_data_null_terminated = try std.mem.Allocator.dupeZ(allocator, u8, conf_data);
    allocator.free(conf_data);
    defer allocator.free(conf_data_null_terminated);

    // parse
    var diag = zon.parse.Diagnostics{};
    defer diag.deinit(allocator);

    const config = zon.parse.fromSlice(
        Config,
        allocator,
        conf_data_null_terminated,
        &diag,
        .{
            .free_on_error = true,
            .ignore_unknown_fields = false,
        },
    ) catch |err| {
        std.log.err("parse config file error: {}", .{err});
        return error.ConfigParseError;
    };

    try config.vaildate_config(allocator);

    return config;
}
