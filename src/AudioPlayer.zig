engine: c.ma_engine,
sound: c.ma_sound,
io: *IOHandle,

pub fn init(io: *IOHandle) !AudioPlayer {
    var engine: c.ma_engine = undefined;

    const engine_config = c.ma_engine_config_init();
    if (c.ma_engine_init(&engine_config, &engine) != c.MA_SUCCESS) {
        io.err.print("Failed to init audio engine!\n", .{});
        return error.AudioInitializationFailed;
    }

    return .{
        .engine = engine,
        .sound = undefined,
        .io = io,
    };
}

pub fn deinit(self: *AudioPlayer) void {
    c.ma_sound_uninit(&self.sound);
    c.ma_engine_uninit(&self.engine);
}

pub fn loadSound(self: *AudioPlayer, file_path: [*:0]const u8) !void {
    // Load from file
    if (c.ma_sound_init_from_file(&self.engine, file_path, 0, null, null, &self.sound) != c.MA_SUCCESS) {
        self.io.err.print("Failed to load WAV file: {s}\n", .{file_path});
        return error.LoadSoundFailed;
    }
}

pub fn play(self: *AudioPlayer) !void {
    // Start playback
    if (c.ma_sound_start(&self.sound) != c.MA_SUCCESS) {
        self.io.err.print("Failed to play sound!\n", .{});
        return error.SoundStartFailed;
    }
    // Wait until sound finishes (or loop forever if needed)
    while (c.ma_sound_is_playing(&self.sound) != 0) {
        std.Thread.sleep(100 * std.time.ns_per_ms); // Check every 100ms
    }
}

test "AudioPlayer init on existing file" {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    const io = IOHandle{ .out = .{ .file = stdout }, .err = .{ .file = stderr } };
    const player = AudioPlayer.init(io);
    player.loadSound("./assets/beep.wav");
}

const std = @import("std");
const c = @cImport({
    @cInclude("miniaudio.h");
});
const AudioPlayer = @This();
const IOHandle = @import("main.zig").IOHandle;
