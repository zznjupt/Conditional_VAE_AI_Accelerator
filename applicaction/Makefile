DEBUG = 3

SIM_SRC = rtl.f

BAK = *.bak
LOG = *.log *.history *.key *.fsdb out_log.txt novas.rc novas.conf *.sdf.X
INCA_libs = csrc simv.daidir simv
cad_dir = spyglass-* nWaveLog* BSSLib.lib*

all: COM SIM

COM:
	vcs -full64 -sverilog -debug_all -timescale=1ns/1ps -f ${SIM_SRC}  -l com.log -fsdb +define+fsdb

SIM:
	./simv -l sim.log
	
verdi:
	verdi -sv -f ${SIM_SRC} -ssf *.fsdb -nologo
	
clean:
	-rm -f ${BAK} ${LOG}
	-rm -rf ${INCA_libs} ${cad_dir}
