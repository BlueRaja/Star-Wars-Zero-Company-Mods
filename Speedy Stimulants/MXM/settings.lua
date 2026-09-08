return {
    id      = "SpeedyStimulants",
    name    = "Speedy Stimulants",
    author  = "BlueRaja",
    version = "1.1.0",
    description = "Speeds up stim and medpack animations.",

    settings = {
        {
            key     = "anim_speed_multiplier",
            type    = "number",
            name    = "Animation speed",
            default = 1.3,
            min     = 1,
            max     = 5,
            step    = 0.1,
            desc    = "How much faster stim and medpack animations play. Higher is faster. Anything over 1.3 screws up the injection animation.",
        },
        {
            key     = "thrown_item_speed_multiplier",
            type    = "number",
            name    = "Thrown item speed",
            default = 3,
            min     = 1,
            max     = 5,
            step    = 0.5,
            desc    = "How much faster thrown stims and medpacs fly. Higher is faster.",
        },
    },
}
