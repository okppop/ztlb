const std = @import("std");
const zon = std.zon;

const CONF_PATH_ENV_KEY: []const u8 = "CONF_PATH";
const CONF_PATH_DEFAULT: []const u8 = "ztlb.conf";

const Config = struct {
    bind: []const Bind,

    fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.bind) |bind_item| {
            allocator.free(bind_item.address);

            switch (bind_item.forward) {
                .round_robin => |item| free_nested_slice(allocator, u8, item),
                .weighted_round_robin => |item| {
                    for (item) |fw| {
                        allocator.free(fw.target);
                    }
                    allocator.free(item);
                },
                .ip_hash => |item| free_nested_slice(allocator, u8, item),
                .least_connections => |item| free_nested_slice(allocator, u8, item),
                .weighted_least_connections => |item| {
                    for (item) |fw| {
                        allocator.free(fw.target);
                    }
                    allocator.free(item);
                },
                .least_response_time => |item| free_nested_slice(allocator, u8, item),
                .random => |item| free_nested_slice(allocator, u8, item),
            }
        }
        allocator.free(self.bind);
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

    return config;
}

fn free_nested_slice(allocator: std.mem.Allocator, T: type, s: []const []const T) void {
    for (s) |item| {
        allocator.free(item);
    }
    allocator.free(s);
}
