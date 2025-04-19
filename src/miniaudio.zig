pub fn main() !void {
    var engine: miniaudio.ma_engine = .{};
    const result = miniaudio.ma_engine_init(null, &engine);
    if (result != miniaudio.MA_SUCCESS) {
        std.debug.print("Failed to initialize audio engine\n", .{});
        return error.AudioInitFailed;
    }

    // Play a sound (replace "sound.wav" with your file)
    const play_result = miniaudio.ma_engine_play_sound(&engine, "beep.wav", null);
    if (play_result != miniaudio.MA_SUCCESS) {
        std.debug.print("Failed to play sound\n", .{});
    }

    // Keep the program running while audio plays
    std.debug.print("Playing audio... (Press Enter to quit)\n", .{});
    var stdin = std.io.getStdIn().reader();
    _ = stdin.readByte() catch {};

    // Cleanup
    miniaudio.ma_engine_uninit(&engine);
}

const std = @import("std");
const miniaudio = @cImport({
    @cInclude("miniaudio.h");
});
