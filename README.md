# Time Blocks CLI
 - This is a CLI application intended to be used for a productivity strategy called "Time Blocking"
 - In this system, different activities / subjects are given specific amounts of time dedicated to them.
 - When a time block is finished, the next time block is started or a small break period is introduced before the next block
 - This approach is intended to reduce context switching by focusing individual tasks to receive individual attention rather than jumping between tasks

## How to use
> Available Commands:
 - time-blocks {time/topic} {time/topic} ... --break={time}
    - Set and start a schedule of time blocks, where each pair of arguments contains a topic and a formatted duration
        - Duration format is as follows: HH:MM:SS for hours, minutes, and seconds.
    - When the schedule finishes, the program ends.
    --break={time}: Set a break time between each time-block, ex. --break=5:00
 - time-blocks set {time/topic} {time/topic} ... --break={time}
    - Set a new schedule and await a further command
    --break={time}: Set a break time between each time-block, ex. --break=5:00
 - time-blocks start --break={time}
    - Use the most recently set schedule and exit when it finishes
    --break={time}: Set a break time between each time-block, ex. --break=5:00
 - time-blocks audio {file_path}
    - Set a path to a valid audio file to be played at the end of each time block
    - Valid audio file formats are:
        mp3, wav, and ogg
