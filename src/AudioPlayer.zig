audio_spec: c.SDL_AudioSpec,
wav_buffer: [*c]u8,
wav_length: u32,
device_id: c.SDL_AudioDeviceID,

pub fn init() !AudioPlayer {
    if (c.SDL_Init(c.SDL_INIT_AUDIO) < 0) {
        std.debug.print("SDL could not initialize! SDL_Error: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    return .{
        .audio_spec = undefined,
        .wav_buffer = undefined,
        .wav_length = undefined,
        .device_id = undefined,
    };
}

pub fn load(self: *AudioPlayer, file_path: []const u8) !void {
    const c_file_path = try std.mem.concatWithSentinel(std.heap.c_allocator, u8, &.{file_path}, 0);
    defer std.heap.c_allocator.free(c_file_path);

    var tmp_buf: [*c]u8 = undefined;

    if (c.SDL_LoadWAV(c_file_path, &self.audio_spec, &tmp_buf, &self.wav_length) == null) {
        std.debug.print("Failed to load WAV file: {s}\n", .{c.SDL_GetError()});
        return error.LoadWAVFailed;
    }
    self.wav_buffer = tmp_buf;
}

pub fn play(self: AudioPlayer, final: bool) void {
    _ = c.SDL_QueueAudio(self.device_id, self.wav_buffer, self.wav_length);
    c.SDL_PauseAudioDevice(self.device_id, 0);

    if (final) {
        while (c.SDL_GetQueuedAudioSize(self.device_id) > 0) {
            c.SDL_Delay(100);
        }
    }
}

pub fn deinit(self: *AudioPlayer) void {
    if (self.wav_buffer != null) {
        c.SDL_FreeWAV(self.wav_buffer);
    }
    if (self.device_id != 0) {
        c.SDL_CloseAudioDevice(self.device_id);
    }
    c.SDL_Quit();
}

const std = @import("std");
const c = @cImport({
    @cDefine("SDL_MAIN_HANDLED", "1");
    @cInclude("SDL2/SDL.h");
});

const AudioPlayer = @This();
