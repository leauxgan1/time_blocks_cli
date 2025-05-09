# Time Blocks CLI
 - This is a CLI application intended to be used for a productivity strategy called "Time Blocking"
 - In this system, different activities / subjects are given specific amounts of time dedicated to them.
 - When a time block is finished, the next time block is started or a small break period is introduced before the next block
 - This approach is intended to reduce context switching by focusing individual tasks to receive individual attention rather than jumping between tasks

## How to use
### Available Commands:

tblocks --set [topic,duration]... --break [break_time] --sound [path_to_sound_file]

  --set: Initialize a schedule with a list of pairs of topic and durations (HH:MM:SS) in the order in which they should be prioritized

  --break: Set a break time (HH:MM:SS) between each task

  --sound: Set an alternate sound via a path to play as a notification for the end of each task

        - Supports audio files of the .wav, .mp3, and .ogg format
  --help: Print this menu

## How to build

If you are using nix and nix flakes, you can get a development shell with the proper zig version by running 
> nix develop
This is done most easily using determinate systems's nix installer (https://github.com/DeterminateSystems/nix-installer).

Otherwise, install zig version 0.14 from the https://ziglang.org/download/

Then, run zig build in the directory containing build.zig, and the executable will be populated in zig_out/bin/tblocks
From there, the executable can be symlinked or aliased to be used elsewhere on your machine.

