// audio_spec: c.SDL_AudioSpec,
// wav_buffer: [*c]u8,
// wav_length: u32,
// device_id: c.SDL_AudioDeviceID,
//
// pub fn init() !AudioPlayer {
//     if (c.SDL_Init(c.SDL_INIT_AUDIO) < 0) {
//         std.log.err("SDL could not initialize! SDL_Error: {s}\n", .{c.SDL_GetError()});
//         return error.SDLInitFailed;
//     }
//     return .{
//         .audio_spec = undefined,
//         .wav_buffer = undefined,
//         .wav_length = undefined,
//         .device_id = undefined,
//     };
// }
//
// pub fn get_duration_ms(self: AudioPlayer) u64 {
//     if (self.audio_spec.size == 0) {
//         return 1000;
//     }
//     const first = (@as(f64, @floatFromInt(self.wav_length))) * 1000.0;
//     const second = @as(u32, @intCast(self.audio_spec.freq)) * @as(u32, @intCast(self.audio_spec.channels)) * self.audio_spec.size;
//     std.log.debug("{any}\n", .{self.audio_spec});
//
//     const duration_ms = @divTrunc(@as(u32, @intFromFloat(first)), second);
//     return @intCast(duration_ms); // Errs when size is set to 0
// }
//
// pub fn load(self: *AudioPlayer, file_path: []const u8) !void {
//     const c_file_path = try std.mem.concatWithSentinel(std.heap.c_allocator, u8, &.{file_path}, 0);
//     defer std.heap.c_allocator.free(c_file_path);
//
//     var tmp_buf: [*c]u8 = undefined;
//
//     if (c.SDL_LoadWAV(c_file_path, &self.audio_spec, &tmp_buf, &self.wav_length) == null) {
//         std.log.err("Failed to load WAV file: {s}\n", .{c.SDL_GetError()});
//         return error.LoadWAVFailed;
//     }
//     self.wav_buffer = tmp_buf;
//     const device_id = c.SDL_OpenAudioDevice(null, 0, &self.audio_spec, null, 0);
//     if (device_id == 0) {
//         std.log.err("Failed to open audio device: {s}\n", .{c.SDL_GetError()});
//         return error.OpenAudioDeviceFailed;
//     }
//     self.device_id = device_id;
// }
//
// pub fn play(self: AudioPlayer) void {
//     _ = c.SDL_QueueAudio(self.device_id, self.wav_buffer, self.wav_length);
//     c.SDL_PauseAudioDevice(self.device_id, 0);
//
//     // if (final) {
//     //     while (c.SDL_GetQueuedAudioSize(self.device_id) > 0) {
//     //         c.SDL_Delay(100);
//     //     }
//     // }
// }
//
// pub fn deinit(self: *AudioPlayer) void {
//     if (self.wav_buffer != null) {
//         c.SDL_FreeWAV(self.wav_buffer);
//     }
//     if (self.device_id != 0) {
//         c.SDL_CloseAudioDevice(self.device_id);
//     }
//     c.SDL_Quit();
// }
//
// const std = @import("std");
// const c = @cImport({
//     @cDefine("SDL_MAIN_HANDLED", "1");
//     @cInclude("SDL2/SDL.h");
// });
//
// const AudioPlayer = @This();

engine: c.ma_engine,
sound: c.ma_sound,
audio_file_path: [*:0]const u8,

pub fn init(file_path: [*:0]const u8) !AudioPlayer {
    var engine: c.ma_engine = undefined;
    const engine_config = c.ma_engine_config_init();
    if (c.ma_engine_init(&engine_config, &engine) != c.MA_SUCCESS) {
        std.debug.print("Failed to init audio engine!\n", .{});
        return error.AudioInitializationFailed;
    }

    const self = AudioPlayer{
        .engine = engine,
        .sound = undefined,
        .audio_file_path = file_path,
    };
    return self;
}

pub fn deinit(self: *AudioPlayer) void {
    c.ma_engine_uninit(&self.engine);
}

pub fn play(self: *AudioPlayer) void {
    // Load and play WAV file
    if (c.ma_sound_init_from_file(&self.engine, self.audio_file_path, 0, null, null, &self.sound) != c.MA_SUCCESS) {
        std.debug.print("Failed to load WAV file: {s}\n", .{self.audio_file_path});
        return;
    }

    defer c.ma_sound_uninit(&self.sound); // Cleanup

    // Start playback
    if (c.ma_sound_start(&self.sound) != c.MA_SUCCESS) {
        std.debug.print("Failed to play sound!\n", .{});
        return;
    }

    // Wait until sound finishes (or loop forever if needed)
    while (c.ma_sound_is_playing(&self.sound) != 0) {
        std.Thread.sleep(100 * std.time.ns_per_ms); // Check every 100ms
    }
}

const std = @import("std");
const c = @cImport({
    // Enable WAV decoding (minimal config)
    @cInclude("miniaudio.h");
});
const AudioPlayer = @This();
