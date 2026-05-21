local exec = hl.dsp.exec_cmd

hl.bind("SUPER + V", exec("voxtype record start"), { description = "Start Voxtype record" })
hl.bindr("SUPER + V", exec("voxtype record stop"), { description = "Stop Voxtype record" })
