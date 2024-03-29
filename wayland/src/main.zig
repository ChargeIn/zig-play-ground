const std = @import("std");
const messages = @import("messages.zig");

// Based on the tutorial from https://zig.news/leroycep/wayland-from-the-wire-part-1-12a1
// Thanks to LeRoyce Pearson
// And the official documentation https://wayland.freedesktop.org/docs/html/ch04.html#sect-Protocol-Wire-Format

// The version of the wl_shm protocol we will be targeting.
const WL_SHM_VERSION = 1;
// The version of the wl_compositor protocol we will be targeting.
const WL_COMPOSITOR_VERSION = 5;
// The version of the xdg_wm_base protocol we will be targeting.
const XDG_WM_BASE_VERSION = 2;

/// https://wayland.app/protocols/xdg-shell#xdg_surface:request:ack_configure
const XDG_SURFACE_REQUEST_ACK_CONFIGURE = 4;

// https://wayland.app/protocols/wayland#wl_registry:event:global
const WL_REGISTRY_EVENT_GLOBAL = 0;

pub fn main() !void {
    std.log.debug("Starting wayland connection...", .{});

    var general_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_allocator.deinit();

    const gpa = general_allocator.allocator();

    const display_path = getDisplayPath(gpa) catch |err| switch (err) {
    error.EnvironmentVariableNotFound => {
        std.log.err("Error: Wayland is not avalidable on your system.", .{});
        return;
    },
    error.OutOfMemory => {
        std.log.err("Running out of memory.\n", .{});
        return;
    },
    else => {
        std.log.err("Error: An unexpected error occured: {any}.", .{err});
        return;
    },
    };
    defer gpa.free(display_path);

    std.log.debug("wayland path: {}", .{std.zig.fmtEscapes(display_path)});

    const socket = try std.net.connectUnixSocket(display_path);
    defer socket.close();

    const display_id = 1;
    var next_id: u32 = 2;

    const registry_id = next_id;
    next_id += 1;

    try socket.writeAll(std.mem.sliceAsBytes(&[_]u32{
    // id of the object; in this case the default wl_display object at 1,
    display_id,

    // The size (in bytes) of the message and the opcode, which is object specific.
    // In this case we are using opcode 1, which corresponds to `wl_display::get_registry`.
    // First 16 bit for size of the message including header and the second for the code
    (0x000C << 16) | (0x0001),

    // argument of the get_registry function is the new id
    registry_id,
    }));

    // sync callback wit the registry object
    const registry_done_callback_id = next_id;
    next_id += 1;

    // same as above for `wl_display:sync` (opcode 0)
    try socket.writeAll(std.mem.sliceAsBytes(&[_]u32{
    display_id,
    (0x000C << 16) | (0x0000),
    registry_done_callback_id,
    }));

    var message_bytes = std.ArrayList(u8).init(gpa);
    defer message_bytes.deinit();

    var shm_id_opt: ?u32 = null;
    var compositor_id_opt: ?u32 = null;
    var xdg_wm_base_id_opt: ?u32 = null;

    // How do we know that the opcode for WL_REGISTRY_REQUEST is 0? Because it is the first `request` in the protocol for `wl_registry`.
    const WL_REGISTRY_REQUEST_BIND = 0;

    while(true) {
        const event = try messages.Event.read(socket, &message_bytes);

        if(event.header.object_id == registry_done_callback_id) {
            // No need to parse the message since it can only have one opcode
            break;
        }

        if(event.header.object_id == registry_id and event.header.opcode == WL_REGISTRY_EVENT_GLOBAL) {
            // Parse out the fields of the global event;
            const name: u32 = @bitCast(event.body[0..4].*);

            const interface_str_len: u32 = @bitCast(event.body[4..8].*);
            // the interface_str is `interface_str_len - 1` because `interface_str_len` includes the null pointer
            const interface_str: [:0]const u8 = event.body[8..][0 .. interface_str_len-1 :0];

            const interface_str_len_u32_align = std.mem.alignForward(u32, interface_str_len, @alignOf(u32));
            const version: u32 = @bitCast(event.body[8 + interface_str_len_u32_align ..][0..4].*);

            if(std.mem.eql(u8, interface_str, "wl_shm")) {
                if(version < WL_SHM_VERSION) {
                    std.log.err("Compositor supports only {s} version {}, client expected version >= {}", .{ interface_str, version, WL_SHM_VERSION });
                    return error.WaylandInterfaceOutOfDate;
                }
                shm_id_opt = next_id;
                next_id += 1;

                try messages.Event.write(socket, registry_id, WL_REGISTRY_REQUEST_BIND, &[_]u32{
                    // The numeric name of the global we want to bind.
                    name,

                    // `new_id` arguments have three parts when the sub-type is not specified by the protocol:
                    //   1. A string specifying the textual name of the interface
                    "wl_shm".len + 1, // length of "wl_shm" plus one for the required null byte
                    @bitCast(@as([4]u8, "wl_s".*)),
                    @bitCast(@as([4]u8, "hm\x00\x00".*)), // we have two 0x00 bytes to align the string with u32

                    //   2. The version you are using, affects which functions you can access
                    WL_SHM_VERSION,

                    //   3. And the `new_id` part, where we tell it which client id we are giving it
                    shm_id_opt.?,
                });
            } else if (std.mem.eql(u8, interface_str, "wl_compositor")) {
                if (version < WL_COMPOSITOR_VERSION) {
                    std.log.err("compositor supports only {s} version {}, client expected version >= {}", .{ interface_str, version, WL_COMPOSITOR_VERSION });
                    return error.WaylandInterfaceOutOfDate;
                }
                compositor_id_opt = next_id;
                next_id += 1;

                try messages.Event.write(socket, registry_id, WL_REGISTRY_REQUEST_BIND, &[_]u32{
                name,
                "wl_compositor".len + 1, // add one for the required null byte
                @bitCast(@as([4]u8, "wl_c".*)),
                @bitCast(@as([4]u8, "ompo".*)),
                @bitCast(@as([4]u8, "sito".*)),
                @bitCast(@as([4]u8, "r\x00\x00\x00".*)),
                WL_COMPOSITOR_VERSION,
                compositor_id_opt.?,
                });
            } else if (std.mem.eql(u8, interface_str, "xdg_wm_base")) {
                if (version < XDG_WM_BASE_VERSION) {
                    std.log.err("compositor supports only {s} version {}, client expected version >= {}", .{ interface_str, version, XDG_WM_BASE_VERSION });
                    return error.WaylandInterfaceOutOfDate;
                }
                xdg_wm_base_id_opt = next_id;
                next_id += 1;

                try messages.Event.write(socket, registry_id, WL_REGISTRY_REQUEST_BIND, &[_]u32{
                name,
                "xdg_wm_base".len + 1,
                @bitCast(@as([4]u8, "xdg_".*)),
                @bitCast(@as([4]u8, "wm_b".*)),
                @bitCast(@as([4]u8, "ase\x00".*)),
                XDG_WM_BASE_VERSION,
                xdg_wm_base_id_opt.?,
                });
            }
            continue;
        }
    }

    const shm_id = shm_id_opt orelse return error.NeccessaryWaylandExtensionMissing;
    const compositor_id = compositor_id_opt orelse return error.NeccessaryWaylandExtensionMissing;
    const xdg_wm_base_id = xdg_wm_base_id_opt orelse return error.NeccessaryWaylandExtensionMissing;

    std.log.debug("wl_shm client id = {}; wl_compositor client id = {}; xdg_wm_base client id = {}", .{ shm_id, compositor_id, xdg_wm_base_id });

    // Create a surface using wl_compositor::create_surface
    const surface_id = next_id;
    next_id += 1;

    // https://wayland.app/protocols/wayland#wl_compositor:request:create_surface
    const WL_COMPOSITOR_REQUEST_CREATE_SURFACE = 0;
    try messages.Event.write(socket, compositor_id, WL_COMPOSITOR_REQUEST_CREATE_SURFACE, &[_]u32{
        // id: new_id<wl_surface>
        surface_id,
    });

    // Create an xdg_surface
    const xdg_surface_id = next_id;
    next_id += 1;

    // https://wayland.app/protocols/xdg-shell#xdg_wm_base:request:get_xdg_surface
    const XDG_WM_BASE_REQUEST_GET_XDG_SURFACE = 2;
    try messages.Event.write(socket, xdg_wm_base_id, XDG_WM_BASE_REQUEST_GET_XDG_SURFACE, &[_]u32{
        // id: new_id<xdg_surface>
        xdg_surface_id,
        // surface: object<wl_surface>
        surface_id,
    });

    // Get the xdg_surface as an xdg_toplevel object
    const xdg_toplevel_id = next_id;
    next_id += 1;

    // https://wayland.app/protocols/xdg-shell#xdg_surface:request:get_toplevel
    const XDG_SURFACE_REQUEST_GET_TOPLEVEL = 1;
    try messages.Event.write(socket, xdg_surface_id, XDG_SURFACE_REQUEST_GET_TOPLEVEL, &[_]u32{
    // id: new_id<xdg_surface>
    xdg_toplevel_id,
    });

    // Commit the surface. This tells the compositor that the current batch of
    // changes is ready, and they can now be applied.

    // https://wayland.app/protocols/wayland#wl_surface:request:commit
    const WL_SURFACE_REQUEST_COMMIT = 6;
    try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_COMMIT, &[_]u32{});

    // Wait for the surface to be configured before moving on
    while (true) {
        const event = try messages.Event.read(socket, &message_bytes);

        if (event.header.object_id == xdg_surface_id) {
            switch (event.header.opcode) {
                // https://wayland.app/protocols/xdg-shell#xdg_surface:event:configure
                0 => {
                    // The configure event acts as a heartbeat. Every once in a while the compositor will send us
                    // a `configure` event, and if our application doesn't respond with an `ack_configure` response
                    // it will assume our program has died and destroy the window.
                    const serial: u32 = @bitCast(event.body[0..4].*);

                    try messages.Event.write(socket, xdg_surface_id, XDG_SURFACE_REQUEST_ACK_CONFIGURE, &[_]u32{
                        // We respond with the number it sent us, so it knows which configure we are responding to.
                        serial,
                    });

                    try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_COMMIT, &[_]u32{});

                    // The surface has been configured! We can move on
                    break;
                },
                else => return error.InvalidOpcode,
                }
        } else {
            std.log.warn("unknown event {{ .object_id = {}, .opcode = {x}, .message = \"{}\" }}", .{ event.header.object_id, event.header.opcode, std.zig.fmtEscapes(std.mem.sliceAsBytes(event.body)) });
        }
    }

    // allocate a shared memory file, which we will use as a framebuffer to write pixels into
    const Pixel = [4]u8;
    const framebuffer_size = [2]usize{ 128, 128 };
    const shared_memory_pool_len = framebuffer_size[0] * framebuffer_size[1] * @sizeOf(Pixel);

    const shared_memory_pool_fd = try std.os.memfd_create("my-wayland-framebuffer", 0);
    try std.os.ftruncate(shared_memory_pool_fd, shared_memory_pool_len);

    // Create a wl_shm_pool (wayland shared memory pool). This will be used to create framebuffers,
    // though in this article we only plan on creating one.
    const wl_shm_pool_id = try messages.writeWlShmRequestCreatePool(
    socket,
    shm_id,
    &next_id,
    shared_memory_pool_fd,
    @intCast(shared_memory_pool_len),
    );

    // Now we allocate a framebuffer from the shared memory pool
    const wl_buffer_id = next_id;
    next_id += 1;

    // https://wayland.app/protocols/wayland#wl_shm_pool:request:create_buffer
    const WL_SHM_POOL_REQUEST_CREATE_BUFFER = 0;
    // https://wayland.app/protocols/wayland#wl_shm:enum:format
    const WL_SHM_POOL_ENUM_FORMAT_ARGB8888 = 0;
    try messages.Event.write(socket, wl_shm_pool_id, WL_SHM_POOL_REQUEST_CREATE_BUFFER, &[_]u32{
        // id: new_id<wl_buffer>,
        wl_buffer_id,
        // Byte offset of the framebuffer in the pool. In this case we allocate it at the very start of the file.
        0,
        // Width of the framebuffer.
        framebuffer_size[0],
        // Height of the framebuffer.
        framebuffer_size[1],
        // Stride of the framebuffer, or rather, how many bytes are in a single row of pixels.
        framebuffer_size[0] * @sizeOf(Pixel),
        // The format of the framebuffer. In this case we choose argb8888.
        WL_SHM_POOL_ENUM_FORMAT_ARGB8888,
    });

    // Now we turn the shared memory pool and the framebuffer we just allocated into slices on our side for ease of use.
    const shared_memory_pool_bytes = try std.os.mmap(null, shared_memory_pool_len, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, shared_memory_pool_fd, 0);
    const framebuffer = @as([*]Pixel, @ptrCast(shared_memory_pool_bytes.ptr))[0 .. shared_memory_pool_bytes.len / @sizeOf(Pixel)];

    // put some interesting colors into the framebuffer
    for (0..framebuffer_size[1]) |y| {
        const row = framebuffer[y * framebuffer_size[0] .. (y + 1) * framebuffer_size[0]];
        for (row, 0..framebuffer_size[0]) |*pixel, x| {
            pixel.* = .{
            @truncate(x),
            @truncate(y),
            0x00,
            0xFF,
            };
        }
    }

    // Now we attach the framebuffer to the surface at <0, 0>. The x and y MUST be <0, 0> since version 5 of WL_SURFACE,
    // which we are using.

    // https://wayland.app/protocols/wayland#wl_surface:request:attach
    const WL_SURFACE_REQUEST_ATTACH = 1;
    try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_ATTACH, &[_]u32{
        // buffer: object<wl_buffer>,
        wl_buffer_id,
        // The x offset of the buffer.
        0,
        // The y offset of the buffer.
        0,
    });

    // We mark the surface as damaged, meaning that the compositor should update what is rendered on the window.
    // You can specify specific damage regions; but in this case we just damage the entire surface.

    // https://wayland.app/protocols/wayland#wl_surface:request:damage
    const WL_SURFACE_REQUEST_DAMAGE = 2;
    try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_DAMAGE, &[_]u32{
        // The x offset of the damage region.
        0,
        // The y offset of the damage region.
        0,
        // The width of the damage region.
        @bitCast(@as(i32, std.math.maxInt(i32))),
        // The height of the damage region.
        @bitCast(@as(i32, std.math.maxInt(i32))),
    });

    // Commit the surface. This tells wayland that we are done making changes, and it can display all the changes that have been
    // made so far.
    // const WL_SURFACE_REQUEST_COMMIT = 6;
    try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_COMMIT, &[_]u32{});

    // Now we finally, finally, get to the main loop of the program.
    var running = true;
    while (running) {
        const event = try messages.Event.read(socket, &message_bytes);

        if (event.header.object_id == xdg_surface_id) {
            switch (event.header.opcode) {
            // https://wayland.app/protocols/xdg-shell#xdg_surface:event:configure
            0 => {
                // The configure event acts as a heartbeat. Every once in a while the compositor will send us
                // a `configure` event, and if our application doesn't respond with an `ack_configure` response
                // it will assume our program has died and destroy the window.
                const serial: u32 = @bitCast(event.body[0..4].*);

                try messages.Event.write(socket, xdg_surface_id, XDG_SURFACE_REQUEST_ACK_CONFIGURE, &[_]u32{
                    // We respond with the number it sent us, so it knows which configure we are responding to.
                    serial,
                });
                try messages.Event.write(socket, surface_id, WL_SURFACE_REQUEST_COMMIT, &[_]u32{});
            },
            else => return error.InvalidOpcode,
            }
        } else if (event.header.object_id == xdg_toplevel_id) {
            switch (event.header.opcode) {
            // https://wayland.app/protocols/xdg-shell#xdg_toplevel:event:configure
            0 => {
            // The xdg_toplevel:configure event asks us to resize the window. For now, we will ignore it expect to
            // log it.
                const width: u32 = @bitCast(event.body[0..4].*);
                const height: u32 = @bitCast(event.body[4..8].*);
                const states_len: u32 = @bitCast(event.body[8..12].*);
                const states = @as([*]const u32, @ptrCast(@alignCast(event.body[12..].ptr)))[0..states_len];

                std.log.debug("xdg_toplevel:configure({}, {}, {any})", .{ width, height, states });
            },
            // https://wayland.app/protocols/xdg-shell#xdg_toplevel:event:close
            1 => {
            // The compositor asked us to close the window.
                running = false;
                std.log.debug("xdg_toplevel:close()", .{});
            },
            // https://wayland.app/protocols/xdg-shell#xdg_toplevel:event:configure_bounds
            2 => std.log.debug("xdg_toplevel:configure_bounds()", .{}),
            // https://wayland.app/protocols/xdg-shell#xdg_toplevel:event:wm_capabilities
            3 => std.log.debug("xdg_toplevel:wm_capabilities()", .{}),
            else => return error.InvalidOpcode,
            }
        } else if (event.header.object_id == wl_buffer_id) {
            switch (event.header.opcode) {
            // https://wayland.app/protocols/wayland#wl_buffer:event:release
            0 => {
            // The xdg_toplevel:release event let's us know that it is safe to reuse the buffer now.
                std.log.debug("wl_buffer:release()", .{});
            },
            else => return error.InvalidOpcode,
            }
        } else if (event.header.object_id == display_id) {
            switch (event.header.opcode) {
            // https://wayland.app/protocols/wayland#wl_display:event:error
            0 => {
                const object_id: u32 = @bitCast(event.body[0..4].*);
                const error_code: u32 = @bitCast(event.body[4..8].*);
                const error_message_len: u32 = @bitCast(event.body[8..12].*);
                const error_message = event.body[12 .. error_message_len - 1 :0];
                std.log.warn("wl_display:error({}, {}, \"{}\")", .{ object_id, error_code, std.zig.fmtEscapes(error_message) });
            },
            // https://wayland.app/protocols/wayland#wl_display:event:delete_id
            1 => {
            // wl_display:delete_id tells us that we can reuse an id. In this article we log it, but
            // otherwise ignore it.
                const name: u32 = @bitCast(event.body[0..4].*);
                std.log.debug("wl_display:delete_id({})", .{name});
            },
            else => return error.InvalidOpcode,
            }
        } else {
            std.log.warn("unknown event {{ .object_id = {}, .opcode = {x}, .message = \"{}\" }}", .{ event.header.object_id, event.header.opcode, std.zig.fmtEscapes(std.mem.sliceAsBytes(event.body)) });
        }
    }
}

pub fn getDisplayPath(gpa: std.mem.Allocator) ![]u8 {
    const xdg_runtime_dir_path = try std.process.getEnvVarOwned(gpa, "XDG_RUNTIME_DIR");
    defer gpa.free(xdg_runtime_dir_path);

    const display_name = try std.process.getEnvVarOwned(gpa, "WAYLAND_DISPLAY");
    defer gpa.free(display_name);

    return try std.fs.path.join(gpa, &.{ xdg_runtime_dir_path, display_name });
}
