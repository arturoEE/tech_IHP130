######################################################################
##        Copyright (c) 2022 Carsten Wulff Software, Norway
## ###################################################################
## Created       : wulff at 2022-4-27
## ###################################################################
##  The MIT License (MIT)
##
##  Permission is hereby granted, free of charge, to any person obtaining a copy
##  of this software and associated documentation files (the "Software"), to deal
##  in the Software without restriction, including without limitation the rights
##  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
##  copies of the Software, and to permit persons to whom the Software is
##  furnished to do so, subject to the following conditions:
##
##  The above copyright notice and this permission notice shall be included in all
##  copies or substantial portions of the Software.
##
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
##  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
##  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
##  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
##  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
##  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
##  SOFTWARE.
##
######################################################################


PRCELL = ${PREFIX}${CELL}

PDKPATH=${PDK_ROOT}/sky130B



.PHONY: drc lvs lpe gds cdl xsch


#----------------------------------------------------------------------------
# Figure out what where running on
#----------------------------------------------------------------------------
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
ECHO=echo
endif

ifeq ($(UNAME_S),Linux)

#- Seems to be a difference between centos and ubuntu here. Ubuntu does not like echo -e
ifeq ($(shell lsb_release -si),Ubuntu)
ECHO=echo
else
ECHO=echo -e
endif
endif

#----------------------------------------------------------------------------
# VERIFICATION
#----------------------------------------------------------------------------
LMAG=../design/${LIB}
NCELL=${LMAG}/${PRCELL}
MCELL=${NCELL}.mag

SUB=BULKN

BUILD=../design/


CICEXCLUDE?=""

#- Cicpy
CICPY=cicpy

#- Ciccreator
CICDIR=../../ciccreator
ifneq "$(wildcard $(CICDIR) )" ""
CIC=${CICDIR}/bin/cic
CICGUI=${CICDIR}/bin/cic-gui
else
CIC=cic
CICGUI=cic-gui
endif

CICVIEWS =  --spice --verilog --xschem --magic

RDIR=2>&1


define TECH_HELP
*****************************************************************
                 Technology make system
******************************************************************
I know I will forget, so I write everything down in a Makefile

The command 'make' reads a Makefile, and runs the first command.

You can specify the commands by adding them after 'make'
, for example 'make help' prints this text

Most commands in this Makefile use two parameters, LIB, and CELL.
For example:

	make xsch LIB=RPLY_EX0_SKY130NM CELL=RPLY_EX0

generates a netlist from schematic in xsch/RPLY_EX0.spice

To see what a make command does, add a '-n' option
For example:
	make xsch LIB=RPLY_EX0_SKY130NM CELL=RPLY_EX0 -n

Outputs:
	test -d xsch || mkdir xsch
	xschem -q -x -b -s -n ../design/RPLY_EX0_SKY130NM/RPLY_EX0.sch

Commands:
   gds    Generate GDSII from layout
   xsch   Generate netlist from schematic
   xlvs   Run Layout Versus Schematic
   drc    Run Design Rule Checks
   doc    Use pandoc to convert README.md into README.html
   xview  Start Xschem
endef

export TECH_HELP

help:
	@echo "$${TECH_HELP}"


ip:
	cd ${BUILD};${CIC}  --I ../cic ../cic/ip.json  ../cic/sky130.tech ${LIB} ${CICOPT}
	cd ${BUILD}; ${CICPY}  transpile ${LIB}.cic ../cic/sky130.tech ${LIB}  ${CICVIEWS} --smash "(P|N)CHIOA" --exclude ${CICEXCLUDE}

view:
	@cd ${BUILD}; ${CICGUI} ${LIB}.cic ../cic/sky130.tech

gds:
	test -d gds || mkdir gds
	${ECHO} "load ${NCELL}.mag\ncalma write gds/${PRCELL}.gds \nquit" > gds/${PRCELL}.tcl
	magic -noconsole -dnull gds/${PRCELL}.tcl > gds/${PRCELL}.log  ${RDIR}


xsch:
	@test -d xsch || mkdir xsch
	xschem -q -x -b -s -n ../design/${LIB}/${CELL}.sch

xlvs:
	@test -d lvs || mkdir lvs
	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB ${SUB}\nload ${NCELL}.mag\nextract all\n\next2spice lvs\next2spice -o lvs/${PRCELL}.spi\nquit" > lvs/${PRCELL}_spi.tcl
	magic -noconsole -dnull lvs/${PRCELL}_spi.tcl > lvs/${PRCELL}_spi.log ${RDIR}
	netgen -batch lvs "lvs/${PRCELL}.spi ${PRCELL}"  "xsch/${PRCELL}.spice ${PRCELL}" ${PDKPATH}/libs.tech/netgen/sky130B_setup.tcl lvs/${PRCELL}_lvs.log > lvs/${PRCELL}_netgen_lvs.log
	cat lvs/${PRCELL}_lvs.log | ../tech/script/checklvs ${PRCELL}

xflvs:
	@test -d lvs || mkdir lvs
	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB ${SUB}\nload ${NCELL}.mag\nextract all\n\next2spice lvs\next2spice hierarchy off\next2spice subcircuits off\next2spice -o lvs/${PRCELL}.spi\nquit" > lvs/${PRCELL}_spi.tcl
	magic -noconsole -dnull lvs/${PRCELL}_spi.tcl > lvs/${PRCELL}_spi.log ${RDIR}
	netgen -batch lvs "lvs/${PRCELL}.spi ${PRCELL}"  "xsch/${PRCELL}.spice ${PRCELL}" ${PDKPATH}/libs.tech/netgen/sky130B_setup.tcl lvs/${PRCELL}_lvs.log > lvs/${PRCELL}_netgen_lvs.log
	cat lvs/${PRCELL}_lvs.log | ../tech/script/checklvs ${PRCELL}



#cdlh:
#	@test -d cdl || mkdir cdl
#	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB ${SUB}\nload ${NCELL}.mag\nextract all\n\next2spice lvs\next2spice subcircuits off\next2spice -o cdl/${PRCELL}.spi\nquit" > cdl/${PRCELL}.tcl
#	@magic -noconsole -dnull cdl/${PRCELL}.tcl  > cdl/${PRCELL}.log ${RDIR}

#- Run flat LVS
lvs:
	@test -d lvs || mkdir lvs
	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB ${SUB}\nload ${NCELL}.mag\nextract all\n\next2spice lvs\next2spice hierarchy off\next2spice subcircuits off\next2spice -o lvs/${PRCELL}.spi\nquit" > lvs/${PRCELL}_spi.tcl
	@magic -noconsole -dnull lvs/${PRCELL}_spi.tcl > lvs/${PRCELL}_spi.log ${RDIR}
	@netgen -batch lvs "lvs/${PRCELL}.spi ${PRCELL}"  "${BUILD}/${LIB}.spi ${PRCELL}" ${PDKPATH}/libs.tech/netgen/sky130B_setup.tcl lvs/${PRCELL}_lvs.log > lvs/${PRCELL}_netgen_lvs.log
	@grep -e "Circuits match uniquely" -e "Netlists do not match"  lvs/${PRCELL}_lvs.log|uniq|perl -ne "use Term::ANSIColor;print(sprintf(\"%-40s\t[ \",${PRCELL}));if(m/match uniquely/ig){print(color('green').'LVS OK  '.color('reset'));}else{print(color('red').'LVS FAIL'.color('reset'));};print(\" ]\n\");"

#- Run DRC
drc:
	@test -d drc || mkdir drc
	@${ECHO} "load ${NCELL}.mag\nlogcommands drc/${PRCELL}_drc.log\nset b [view bbox]\nbox values [lindex \$$b 0] [lindex \$$b 1] [lindex \$$b 2] [lindex \$$b 3]\ndrc catchup\ndrc why\ndrc count total\nquit\n" > drc/${PRCELL}_drc.tcl
	@magic -noconsole -dnull drc/${PRCELL}_drc.tcl > drc/${PRCELL}_drc.log ${RDIR}
	@tail -n 1 drc/${PRCELL}_drc.log| perl -ne "\$$exit = 0;use Term::ANSIColor;print(sprintf(\"%-40s\t[ \",${PRCELL}));if(m/:\s+0\n/ig){print(color('green').'DRC OK  '.color('reset'));}else{print(color('red').'DRC FAIL'.color('reset'));\$$exit = 1;};print(\" ]\n\");exit \$$exit;" || tail -n 10 drc/${PRCELL}_drc.log

#- Run parasitic extraction
lpe:
	@test -d lpe || mkdir lpe
	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB 0\nload ${NCELL}.mag\nextract all\n\next2spice resistor off\next2spice capacitance on\next2spice cthresh 0.4\next2spice format ngspice	\next2spice hierarchy off\next2spice subcircuits off\next2spice -o lpe/${PRCELL}_lpe.spi\nquit" > lpe/${PRCELL}_lpe.tcl
	@magic -noconsole -dnull lpe/${PRCELL}_lpe.tcl ${RDIR} | tee lpe/${PRCELL}_magic_lpe.log

lpeh:
	@test -d lpe || -mkdir lpe
	@${ECHO} "set VDD AVDD\nset GND AVSS\nset SUB 0\nload ${NCELL}.mag\nextract all\n\next2spice resistor off\next2spice capacitance on\next2spice cthresh 0.4\next2spice format ngspice\next2spice subcircuits off\next2spice -o lpe/${PRCELL}_lpe.spi\nquit" > lpe/${PRCELL}_lpe.tcl
	@magic -noconsole -dnull lpe/${PRCELL}_lpe.tcl ${RDIR} | tee lpe/${PRCELL}_magic_lpe.log

lvsall:
	@${foreach b, ${CELLS}, ${MAKE} -s cdl lvs CELL=$b;}

lpeall:
	@${foreach b, ${CELLS}, ${MAKE} -s lpe CELL=$b;}

drcall:
	@${foreach  b, ${CELLS}, ${MAKE} -s drc CELL=$b;}


doc:
	pandoc -s ../README.md -o ../README.html

clean:
	-rm -rf lvs drc lpe cdl gds

spi:
	test -d xsch || mkdir xsch
	xschem -q -x -b -s -n ../design/${LIB}/${CELL}.sch
	cat xsch/${CELL}.spice| ../tech/script/fixspi > ../cic/${CELL}.spi

xview:
	xschem -b  ../design/${LIB}/${CELL}.sch &
