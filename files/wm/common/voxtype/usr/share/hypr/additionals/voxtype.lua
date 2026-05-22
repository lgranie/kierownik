local exec = hl.dsp.exec_cmd

hl.bind("SUPER + D", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0; voxtype record start"), { description = "Start Voxtype record" })
hl.bind("SUPER + SHIFT + D", exec("voxtype record stop; wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1"), { description = "Stop Voxtype record" })
