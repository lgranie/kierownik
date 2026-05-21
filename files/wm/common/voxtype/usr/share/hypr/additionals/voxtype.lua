local exec = hl.dsp.exec_cmd

hl.bind("SUPER + V", exec("voxtype record start"), { description = "Start Voxtype record" })
hl.bind("SUPER + SHIFT + V", exec("voxtype record stop"), { description = "Stop Voxtype record" })
