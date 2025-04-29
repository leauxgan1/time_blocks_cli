engine: c.ma_engine,
sound: c.ma_sound,
audio_file_path: [*:0]const u8,

pub fn init(file_path: [*:0]const u8) error{ AudioInitializationFailed, AudioFileLoadFailed }!AudioPlayer {
    var engine: c.ma_engine = undefined;
    var sound: c.ma_sound = undefined;

    const engine_config = c.ma_engine_config_init();
    if (c.ma_engine_init(&engine_config, &engine) != c.MA_SUCCESS) {
        std.debug.print("Failed to init audio engine!\n", .{});
        return error.AudioInitializationFailed;
    }
    if (c.ma_sound_init_from_file(&engine, file_path, 0, null, null, &sound) != c.MA_SUCCESS) {
        std.debug.panic("Failed to load audio file file: {s}\n", .{file_path});
        return error.AudioFileLoadFailed;
    }

    return .{
        .engine = engine,
        .sound = sound,
        .audio_file_path = file_path,
    };
}
pub fn change_audio_file(self: *AudioPlayer, new_audio_file: [*:0]const u8) !void {
    self.audio_file_path = new_audio_file;
}

pub fn deinit(self: *AudioPlayer) void {
    c.ma_engine_uninit(&self.engine);
}

pub fn play(self: *AudioPlayer) void {
    // Load from file
    if (c.ma_sound_init_from_file(&self.engine, self.audio_file_path, 0, null, null, &self.sound) != c.MA_SUCCESS) {
        std.debug.panic("Failed to load WAV file: {s}\n", .{self.audio_file_path});
    }
    defer c.ma_sound_uninit(&self.sound);
    // Start playback
    if (c.ma_sound_start(&self.sound) != c.MA_SUCCESS) {
        std.debug.panic("Failed to play sound!\n", .{});
    }
    // Wait until sound finishes (or loop forever if needed)
    while (c.ma_sound_is_playing(&self.sound) != 0) {
        std.Thread.sleep(100 * std.time.ns_per_ms); // Check every 100ms
    }
}

const std = @import("std");
const c = @cImport({
    @cInclude("miniaudio.h");
});
const AudioPlayer = @This();
