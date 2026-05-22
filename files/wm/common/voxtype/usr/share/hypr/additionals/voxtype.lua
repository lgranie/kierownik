local exec = hl.dsp.exec_cmd

hl.bind("SUPER + D", exec("voxtype record start"), { description = "Start Voxtype record" })
hl.bind("SUPER + SHIFT + D", exec("voxtype record stop"), { description = "Stop Voxtype record" })
