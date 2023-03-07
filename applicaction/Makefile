DEBUG = 3

SIM_SRC = rtl.f

BAK = *.bak
LOG = *.log *.history *.key *.fsdb out_log.txt novas.rc novas.conf *.sdf.X
INCA_libs = csrc simv.daidir simv
cad_dir = spyglass-* nWaveLog* BSSLib.lib*

all: COM SIM

COM:
	vcs -f ${SIM_SRC}

SIM:
	./simv -l sim.log
	
syn:
	
clean:
	-rm -f ${BAK} ${LOG}
	-rm -rf ${INCA_libs} ${cad_dir}
