const std = @import("std");
const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
const Slic = struct {
    const Self = @This();
    left: []u8,
    pub fn take(self: *Self, n: anytype) !@TypeOf(self.left[0..n]) {
        if (self.left.len < n) return error.EOF;
        defer self.left = self.left[n..];
        return self.left[0..n];
    }
};
fn sysErr(e: anytype) !@TypeOf(e catch unreachable) {
    return e catch return error.SysErr;
}
fn shouldDecrypt(name: []const u8) bool {
    if (std.mem.endsWith(u8, name, ".mp4")) return false;
    if (std.mem.endsWith(u8, name, ".flv")) return false;
    return true;
}
fn decrypt(data: []u8, key: []const u8) void {
    for (data, 0..) |*b, i| b.* ^= key[i % key.len];
}
pub fn main() u8 {
    realMain() catch |e| {
        std.debug.print("{s}\n", .{switch (e) {
            error.EOF => "eof error",
            error.Usage => "usage: zpfs pfsfile [outdir(empty for listing)]",
            error.SysErr => "syscall error",
            error.NotPFS => "not a pfs (pf8)",
        }});
        return 255;
    };
    return 0;
}
fn realMain() !void {
    // 0. get arg, open file
    var argv = std.process.args();
    _ = argv.skip(); // skip self
    const fd = try sysErr(std.posix.openZ(argv.next() orelse return error.Usage, .{}, 0));
    const map = try sysErr(std.posix.mmap(null, @intCast((try sysErr(std.posix.fstat(fd))).size), prot, .{ .TYPE = .PRIVATE }, fd, 0));
    const dir = if (argv.next()) |path| try sysErr(std.fs.cwd().makeOpenPath(path, .{})) else null;
    var slice = Slic{ .left = map };

    // 1. read header, make key
    if (!std.mem.eql(u8, "pf8", try slice.take(3))) return error.NotPFS;
    const index_size = std.mem.readInt(u32, try slice.take(4), .little);
    const index_data = try slice.take(index_size);
    slice.left = index_data;
    var index_h_sha1: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    std.crypto.hash.Sha1.hash(index_data, &index_h_sha1, .{});

    // 2. read entries, extract
    const entry_count = std.mem.readInt(u32, try slice.take(4), .little);
    for (0..entry_count) |i| {
        const plen = std.mem.readInt(u32, try slice.take(4), .little);
        const path = (try slice.take(plen + 4))[0..plen];
        std.mem.replaceScalar(u8, path, '\\', '/');
        const offs = std.mem.readInt(u32, try slice.take(4), .little);
        const size = std.mem.readInt(u32, try slice.take(4), .little);
        std.debug.print("[{}] {s} {} {}\n", .{ i, path, offs, size });
        if (dir) |d| {
            const data = map[offs..][0..size];
            if (std.mem.lastIndexOfScalar(u8, path, '/')) |j| try sysErr(d.makePath(path[0..j]));
            if (shouldDecrypt(path)) decrypt(data, &index_h_sha1);
            try sysErr(d.writeFile(.{ .sub_path = path, .data = data }));
        }
    }
}
