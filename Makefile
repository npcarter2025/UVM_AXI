# Makefile for compiling and running UVM testbench with VCS

# Define the UVM and VCS directories
UVM_HOME ?= $(UVM_HOME)    # UVM installation path (adjust if necessary)
VCS = vcs

# Coverage options - can be overridden: COVERAGE=all for maximum coverage
# Default: line+cond+fsm+branch+tgl+assert (includes assertion coverage)
# Use COVERAGE=all for all available coverage types
COVERAGE ?= line+cond+fsm+branch+tgl+assert

VCS_OPTIONS = -timescale=1ns/1ns +vcs+flush+all +v2k +warn=all -kdb -sverilog \
              +incdir+src +incdir+tests +incdir+seq +incdir+tb +incdir+agent \
              +incdir+env +incdir+subscribers +incdir+include \
              -debug_all -full64 -cm $(COVERAGE)

UVM_OPTIONS = -ntb_opts uvm-1.2 +UVM_NO_DPI +define+UVM_NO_DEPRECATED

# Test selection - default to basic test, can be overridden
TESTNAME ?= axi_basic_test

# Waveform generation - set WAVEFORM=1 to enable VPD waveform dumping
# Note: VPD format requires DVE (commercial Synopsys tool) to view
# WAVEFORM_FILE can be customized (default: waveform.vpd)
WAVEFORM ?= 0
WAVEFORM_FILE ?= waveform.vpd
ifeq ($(WAVEFORM),1)
  WAVEFORM_OPTIONS = +vcd+$(WAVEFORM_FILE)
else
  WAVEFORM_OPTIONS =
endif

# GUI mode - set GUI=1 to enable DVE GUI
GUI ?= 0
ifeq ($(GUI),1)
  GUI_OPTIONS = -gui
else
  GUI_OPTIONS =
endif

VCS_SIM_OPTIONS = +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=$(TESTNAME) $(WAVEFORM_OPTIONS) $(GUI_OPTIONS)

# Testbench and source files
DUT_TOP = src/axi_memory.sv        # Top-level DUT file
TB_TOP = tb/testbench.sv       # Top-level testbench file
SV_FILES = tests/test_pkg.sv

# Compilation target
compile: $(SV_FILES)
	$(VCS) $(VCS_OPTIONS) $(UVM_OPTIONS) -l compile.log \
	       src/axi_if.sv src/mem_pkg.sv $(DUT_TOP) $(SV_FILES) $(TB_TOP) -o simv

# Simulation target
# LOGFILE can be overridden to specify a custom log file name
LOGFILE ?= run.log
run: compile
	./simv $(VCS_SIM_OPTIONS) -cm $(COVERAGE) -l $(LOGFILE)

# Run specific test
run_basic:
	$(MAKE) run TESTNAME=axi_basic_test

run_stress:
	$(MAKE) run TESTNAME=axi_stress_test

run_write_read:
	$(MAKE) run TESTNAME=axi_write_read_test

run_corner:
	$(MAKE) run TESTNAME=axi_corner_case_test

# Run with waveform generation enabled
run_waveform:
	$(MAKE) run WAVEFORM=1

# Run specific test with waveforms
run_basic_wave:
	$(MAKE) run TESTNAME=axi_basic_test WAVEFORM=1

run_stress_wave:
	$(MAKE) run TESTNAME=axi_stress_test WAVEFORM=1

run_write_read_wave:
	$(MAKE) run TESTNAME=axi_write_read_test WAVEFORM=1

run_corner_wave:
	$(MAKE) run TESTNAME=axi_corner_case_test WAVEFORM=1

# Run with GUI (DVE) - enables waveform viewing
run_gui:
	$(MAKE) run GUI=1

# Check if X11 forwarding is working (for viewing waveforms over SSH)
check_x11:
	@echo "Checking X11 forwarding status..."
	@if [ -n "$$TERM_PROGRAM" ] && [ "$$TERM_PROGRAM" = "vscode" ]; then \
		echo "⚠ VSCode Remote SSH detected (X11 forwarding typically not available)"; \
		echo ""; \
		echo "Best options for VSCode users:"; \
		echo "  1. Copy waveform file locally and view with local DVE:"; \
		echo "     - Generate: make run_basic_wave"; \
		echo "     - Copy to local: scp user@host:$$PWD/waveform.vpd ."; \
		echo "     - View locally: dve -vpd waveform.vpd (if DVE installed locally)"; \
		echo ""; \
		echo "  2. Use NoMachine/VNC for remote desktop access (if DVE license available)"; \
		echo ""; \
		echo "  3. Use free waveform viewer GTKWave (requires VCD format, not VPD)"; \
		echo ""; \
		echo "  4. Enable X11 in VSCode SSH config (advanced):"; \
		echo "     Add to ~/.ssh/config:"; \
		echo "       Host your-host"; \
		echo "         ForwardX11 yes"; \
		echo "         ForwardX11Trusted yes"; \
	elif [ -z "$$DISPLAY" ]; then \
		echo "ERROR: DISPLAY not set. X11 forwarding is not enabled."; \
		echo "       Reconnect with: ssh -X username@hostname"; \
		echo "       Or use trusted forwarding: ssh -Y username@hostname"; \
		exit 1; \
	else \
		echo "✓ DISPLAY is set to: $$DISPLAY"; \
		echo "✓ X11 forwarding appears to be working"; \
		echo "  You can view waveforms with: dve -vpd waveform.vpd"; \
	fi

# View existing waveform file with DVE
view_waveform:
	@if [ -z "$$DISPLAY" ]; then \
		echo "ERROR: X11 forwarding not enabled."; \
		echo ""; \
		echo "For VSCode users:"; \
		echo "  Run: make show_copy_instructions"; \
		echo ""; \
		echo "For NoMachine users:"; \
		echo "  Connect via NoMachine, then run: make view_waveform"; \
		echo "  Or use Verdi (often better): make view_verdi"; \
		exit 1; \
	fi
	@if [ ! -f "$(WAVEFORM_FILE)" ]; then \
		echo "ERROR: Waveform file '$(WAVEFORM_FILE)' not found."; \
		echo "       Generate it first with: make run_basic_wave"; \
		exit 1; \
	else \
		echo "Opening waveform file $(WAVEFORM_FILE) with DVE..."; \
		dve -vpd $(WAVEFORM_FILE); \
	fi

# View waveform with Verdi (Synopsys Verdi - often better than DVE)
view_verdi:
	@if [ -z "$$DISPLAY" ]; then \
		echo "ERROR: X11 forwarding not enabled."; \
		echo ""; \
		echo "For NoMachine users:"; \
		echo "  Connect via NoMachine, then run: make view_verdi"; \
		exit 1; \
	fi
	@if [ ! -f "$(WAVEFORM_FILE)" ]; then \
		echo "ERROR: Waveform file '$(WAVEFORM_FILE)' not found."; \
		echo "       Generate it first with: make run_basic_wave"; \
		exit 1; \
	else \
		echo "Opening waveform file $(WAVEFORM_FILE) with Verdi..."; \
		verdi -vpd $(WAVEFORM_FILE) & \
		echo "Verdi launched in background. Check NoMachine window."; \
	fi

# Show instructions for copying waveform files (useful for VSCode users)
show_copy_instructions:
	@echo "Instructions for viewing waveforms from VSCode Remote SSH:"
	@echo ""
	@echo "Step 1: Generate waveform file"
	@echo "  make run_basic_wave"
	@echo ""
	@echo "Step 2: Copy waveform file to local machine"
	@echo "  From your LOCAL terminal (not in VSCode), run:"
	@echo "  scp $$USER@$$(hostname -f):$$PWD/$(WAVEFORM_FILE) ."
	@echo ""
	@echo "Step 3: View waveform locally"
	@echo "  Option A: DVE (requires Synopsys VCS license - commercial software)"
	@echo "    If you have DVE installed locally:"
	@echo "      dve -vpd $(WAVEFORM_FILE)"
	@echo ""
	@echo "  Option B: GTKWave (FREE, open-source alternative)"
	@echo "    Note: VPD format is proprietary to VCS. You may need to:"
	@echo "    1. Check if VCS includes vcd2vpd converter"
	@echo "    2. Or modify testbench to generate VCD directly (use \$dumpfile/\$dumpvars)"
	@echo "    3. Then view with: gtkwave waveform.vcd"
	@echo ""
  @echo "  Option C: Use NoMachine to access the server (RECOMMENDED if available)"
	@echo "    1. Connect to server via NoMachine"
	@echo "    2. Open terminal in NoMachine session"
	@echo "    3. cd to project directory"
	@echo "    4. Run: make view_verdi    (uses Verdi - better than DVE)"
	@echo "       Or:  make view_waveform (uses DVE)"
	@echo ""
	@echo "Current waveform file location:"
	@echo "  Remote: $$PWD/$(WAVEFORM_FILE)"

# Run all tests in parallel with separate log files
run_all: compile
	@echo "Running all tests in parallel..."
	@echo "Coverage mode: $(COVERAGE)"
	@if [ "$(WAVEFORM)" = "1" ]; then \
		echo "Warning: Waveform generation disabled in parallel runs (use individual test runs with WAVEFORM=1)"; \
	fi
	./simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_basic_test -cm $(COVERAGE) -l axi_basic_test.log & \
	./simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_stress_test -cm $(COVERAGE) -l axi_stress_test.log & \
	./simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_write_read_test -cm $(COVERAGE) -l axi_write_read_test.log & \
	./simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_corner_case_test -cm $(COVERAGE) -l axi_corner_case_test.log & \
	wait
	@echo "All tests completed. Check individual log files:"
	@echo "  - axi_basic_test.log"
	@echo "  - axi_stress_test.log"
	@echo "  - axi_write_read_test.log"
	@echo "  - axi_corner_case_test.log"
	@echo ""
	@echo "Note: Coverage databases are created as simv.vdb for each test run"

.PHONY: coverage_report

# Coverage report generation
coverage_report:
	@echo "Generating coverage report..."
	@if [ -d simv.vdb ]; then \
		urg -full64 -dir simv.vdb -report coverage_report; \
		echo "Coverage report generated in coverage_report/ directory"; \
		echo "Open coverage_report/dashboard.html in a web browser to view the report"; \
	else \
		echo "Error: Coverage database not found. Run tests first to generate coverage data."; \
		echo "Try: make run_basic or make run_all"; \
		exit 1; \
	fi

# Clean up generated files
clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h DVEfiles inter.vpd *.log simv.vdb *vpd coverage*.vdb coverage_report

# Help message
help:
	@echo "Makefile for compiling and running UVM testbench with VCS"
	@echo ""
	@echo "Usage:"
	@echo "  make compile           - Compile the UVM testbench"
	@echo "  make run               - Compile and run the UVM testbench (default: axi_basic_test)"
	@echo "  make run TESTNAME=xxx  - Run a specific test (e.g., TESTNAME=axi_stress_test)"
	@echo "  make run_basic         - Run axi_basic_test"
	@echo "  make run_stress        - Run axi_stress_test"
	@echo "  make run_write_read    - Run axi_write_read_test"
	@echo "  make run_corner        - Run axi_corner_case_test"
	@echo "  make run_all           - Run all tests in parallel with separate log files"
	@echo "  make coverage_report   - Generate coverage report from all test runs"
	@echo "  make clean             - Clean up generated files"
	@echo "  make help              - Display this help message"
	@echo ""
	@echo "Waveform Generation:"
	@echo "  Enable VPD waveform generation:"
	@echo "    make run WAVEFORM=1"
	@echo "    make run_basic_wave    - Run axi_basic_test with waveforms"
	@echo "    make run_stress_wave   - Run axi_stress_test with waveforms"
	@echo "    make run_write_read_wave - Run axi_write_read_test with waveforms"
	@echo "    make run_corner_wave   - Run axi_corner_case_test with waveforms"
	@echo "  Custom waveform file:"
	@echo "    make run WAVEFORM=1 WAVEFORM_FILE=my_waveform.vpd"
	@echo "  Viewing waveforms:"
	@echo "    NOTE: DVE/Verdi require Synopsys VCS license (available on this server)"
	@echo "    Option 1: NoMachine (RECOMMENDED - easiest for GUI access)"
	@echo "      Connect via NoMachine, then:"
	@echo "        make view_verdi      - View with Verdi (better than DVE)"
	@echo "        make view_waveform   - View with DVE"
	@echo "    Option 2: If X11 forwarding is enabled:"
	@echo "      make view_waveform     - View waveform.vpd with DVE"
	@echo "      dve -vpd waveform.vpd  - View waveform file directly"
	@echo "      make run_gui           - Run with DVE GUI"
	@echo "    Option 3: FREE alternative: GTKWave (if VPD converted to VCD)"
	@echo "  For VSCode Remote SSH users (X11 forwarding not available):"
	@echo "    make check_x11           - Check X11 status and get VSCode-specific help"
	@echo "    make show_copy_instructions - Get instructions to copy waveform locally"
	@echo "  For regular SSH connections:"
	@echo "    Connect with: ssh -X username@hostname  (enables X11 forwarding)"
	@echo "    Check X11: make check_x11              (verify X11 forwarding works)"
	@echo ""
	@echo "Coverage Options:"
	@echo "  Default coverage: line+cond+fsm+branch+tgl+assert"
	@echo "  Use COVERAGE=all for maximum coverage:"
	@echo "    make run COVERAGE=all"
	@echo "    make run_all COVERAGE=all"
	@echo "  Custom coverage: make run COVERAGE=\"line+cond+branch+tgl\""
	@echo ""
	@echo "Available tests:"
	@echo "  - axi_basic_test       - Basic functional test"
	@echo "  - axi_stress_test      - Randomized stress test"
	@echo "  - axi_write_read_test  - Write then read test"
	@echo "  - axi_corner_case_test - Corner case tests"
