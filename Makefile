# Makefile for compiling and running UVM testbench with VCS

# Define the UVM and VCS directories
UVM_HOME ?= $(UVM_HOME)    # UVM installation path (adjust if necessary)
VCS = vcs

# Build directory for all generated files
BUILD_DIR = build

# Coverage options - can be overridden: COVERAGE=all for maximum coverage
# Default: line+cond+fsm+branch+tgl+assert (includes assertion coverage)
# Use COVERAGE=all for all available coverage types
COVERAGE ?= line+cond+fsm+branch+tgl+assert

# PLI library for FSDB support (Novas/Verdi)
# Try to find Verdi PLI library automatically, or set VERDI_HOME manually
VERDI_HOME ?= $(shell echo $$VERDI_HOME)
# Function to find PLI tab file
find_pli_tab = $(shell if [ -n "$(VERDI_HOME)" ]; then find $(VERDI_HOME) -name "novas.tab" -o -name "verdi.tab" 2>/dev/null | head -1; elif [ -d /opt/synopsys ]; then find /opt/synopsys/verdi* -name "novas.tab" -o -name "verdi.tab" 2>/dev/null | head -1; fi)

VCS_OPTIONS = -timescale=1ns/1ns +vcs+flush+all +v2k +warn=all -kdb -sverilog \
              +incdir+src +incdir+tests +incdir+seq +incdir+tb +incdir+agent \
              +incdir+env +incdir+subscribers +incdir+include \
              -debug_all -full64 -cm $(COVERAGE) $(WAVEFORM_DEFINE)

# UVM options - remove +UVM_NO_DPI if using C memory model (requires DPI)
ifeq ($(USE_C_MEMORY_MODEL),1)
  UVM_OPTIONS = -ntb_opts uvm-1.2 +define+UVM_NO_DEPRECATED +define+USE_DPI_MODEL
else
  UVM_OPTIONS = -ntb_opts uvm-1.2 +UVM_NO_DPI +define+UVM_NO_DEPRECATED
endif

# Test selection - default to basic test, can be overridden
TESTNAME ?= axi_basic_test

# C memory model option - set USE_C_MEMORY_MODEL=1 to use C implementation
USE_C_MEMORY_MODEL ?= 0
C_MEMORY_MODEL_SRC = subscribers/axi_memory_model.c

# Waveform generation - set WAVEFORM=1 to enable waveform dumping
# WAVEFORM_FORMAT can be: vpd (DVE), vcd (Verdi/GTKWave), or fsdb (Verdi)
# WAVEFORM_FILE can be customized (default: waveform.vpd/vcd/fsdb)
# All waveform files go to $(BUILD_DIR)/
WAVEFORM ?= 0
WAVEFORM_FORMAT ?= vcd
WAVEFORM_FILE ?= $(BUILD_DIR)/waveform.$(WAVEFORM_FORMAT)
ifeq ($(WAVEFORM),1)
  ifeq ($(WAVEFORM_FORMAT),vpd)
    WAVEFORM_OPTIONS = +vcd+$(WAVEFORM_FILE)
    WAVEFORM_DEFINE = +define+VPD_DUMP
  else ifeq ($(WAVEFORM_FORMAT),vcd)
    WAVEFORM_OPTIONS = 
    WAVEFORM_DEFINE = +define+VCD_DUMP +define+VCD_FILE=\"$(WAVEFORM_FILE)\"
  else ifeq ($(WAVEFORM_FORMAT),fsdb)
    WAVEFORM_OPTIONS = 
    WAVEFORM_DEFINE = +define+FSDB_DUMP +define+FSDB_FILE=\"$(WAVEFORM_FILE)\"
  else
    $(error Invalid WAVEFORM_FORMAT: $(WAVEFORM_FORMAT). Use vpd, vcd, or fsdb)
  endif
else
  WAVEFORM_OPTIONS =
  WAVEFORM_DEFINE =
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
# All build artifacts go to $(BUILD_DIR)/
compile: $(SV_FILES)
	@mkdir -p $(BUILD_DIR)
	@if [ "$(USE_C_MEMORY_MODEL)" = "1" ]; then \
		echo "Using C memory model (DPI enabled)"; \
	fi
	@PLI_TAB=""; \
	if [ "$(WAVEFORM_FORMAT)" = "fsdb" ]; then \
		PLI_TAB="$(call find_pli_tab)"; \
		if [ -n "$$PLI_TAB" ] && [ -f "$$PLI_TAB" ]; then \
			echo "Using PLI library: $$PLI_TAB"; \
			PLI_OPT="-P $$PLI_TAB"; \
		else \
			echo "Warning: FSDB format requires Novas PLI library."; \
			echo "  Set VERDI_HOME or use VCD/VPD format instead."; \
			echo "  Attempting compilation without PLI (may fail)..."; \
			PLI_OPT=""; \
		fi; \
	else \
		PLI_OPT=""; \
	fi; \
	DPI_SRC=""; \
	if [ "$(USE_C_MEMORY_MODEL)" = "1" ]; then \
		DPI_SRC="$(C_MEMORY_MODEL_SRC)"; \
	fi; \
	$(VCS) $(VCS_OPTIONS) $$PLI_OPT $(UVM_OPTIONS) -l $(BUILD_DIR)/compile.log \
	       src/axi_if.sv src/mem_pkg.sv $(DUT_TOP) $(SV_FILES) $(TB_TOP) $$DPI_SRC -o $(BUILD_DIR)/simv
	@if [ -d csrc ]; then mv csrc $(BUILD_DIR)/ 2>/dev/null || true; fi
	@if [ -d simv.daidir ]; then mv simv.daidir $(BUILD_DIR)/ 2>/dev/null || true; fi
	@if [ -f ucli.key ]; then mv ucli.key $(BUILD_DIR)/ 2>/dev/null || true; fi
	@if [ -f vc_hdrs.h ]; then mv vc_hdrs.h $(BUILD_DIR)/ 2>/dev/null || true; fi

# Simulation target
# LOGFILE can be overridden to specify a custom log file name
# All log files go to $(BUILD_DIR)/
LOGFILE ?= $(BUILD_DIR)/run.log
run: compile
	@mkdir -p $(BUILD_DIR)
	$(BUILD_DIR)/simv $(VCS_SIM_OPTIONS) -cm $(COVERAGE) -l $(LOGFILE)
	@if [ -d simv.vdb ]; then mv simv.vdb $(BUILD_DIR)/ 2>/dev/null || true; fi
	@if [ -d DVEfiles ]; then mv DVEfiles $(BUILD_DIR)/ 2>/dev/null || true; fi
	@if [ -f inter.vpd ]; then mv inter.vpd $(BUILD_DIR)/ 2>/dev/null || true; fi

# Run specific test
run_basic:
	$(MAKE) run TESTNAME=axi_basic_test

run_stress:
	$(MAKE) run TESTNAME=axi_stress_test

run_write_read:
	$(MAKE) run TESTNAME=axi_write_read_test

run_corner:
	$(MAKE) run TESTNAME=axi_corner_case_test

# Run with waveform generation enabled (default: VCD format)
run_waveform:
	$(MAKE) run WAVEFORM=1 WAVEFORM_FORMAT=vcd

# Generate all waveform formats (VCD, VPD, FSDB) for the current test
# Note: FSDB requires Novas PLI library - may skip if not available
run_all_formats:
	@echo "Generating all waveform formats (VCD, VPD, FSDB)..."
	@echo "Note: This will run the simulation 3 times."
	@echo "      FSDB requires Novas PLI library - will skip if compilation fails."
	@echo ""
	@echo "1/3: Generating VCD format..."
	$(MAKE) run WAVEFORM=1 WAVEFORM_FORMAT=vcd WAVEFORM_FILE=$(BUILD_DIR)/waveform.vcd || true
	@echo ""
	@echo "2/3: Generating VPD format..."
	$(MAKE) run WAVEFORM=1 WAVEFORM_FORMAT=vpd WAVEFORM_FILE=$(BUILD_DIR)/waveform.vpd || true
	@echo ""
	@echo "3/3: Generating FSDB format (may fail if PLI not available)..."
	@if $(MAKE) run WAVEFORM=1 WAVEFORM_FORMAT=fsdb WAVEFORM_FILE=$(BUILD_DIR)/waveform.fsdb 2>/dev/null; then \
		echo "  ✓ FSDB generated successfully"; \
	else \
		echo "  ✗ FSDB generation skipped (PLI library not available)"; \
		echo "    To enable FSDB, set VERDI_HOME or NOVAS_PLI_TAB environment variable"; \
	fi
	@echo ""
	@echo "Waveform formats generated in $(BUILD_DIR)/:"
	@echo "  - $(BUILD_DIR)/waveform.vcd  (for Verdi/GTKWave)"
	@echo "  - $(BUILD_DIR)/waveform.vpd  (for DVE)"
	@if [ -f $(BUILD_DIR)/waveform.fsdb ]; then \
		echo "  - $(BUILD_DIR)/waveform.fsdb (for Verdi)"; \
	else \
		echo "  - $(BUILD_DIR)/waveform.fsdb (skipped - PLI not available)"; \
	fi

# Run specific test with waveforms (VCD format for Verdi)
run_basic_wave:
	$(MAKE) run TESTNAME=axi_basic_test WAVEFORM=1 WAVEFORM_FORMAT=vcd

run_stress_wave:
	$(MAKE) run TESTNAME=axi_stress_test WAVEFORM=1 WAVEFORM_FORMAT=vcd

run_write_read_wave:
	$(MAKE) run TESTNAME=axi_write_read_test WAVEFORM=1 WAVEFORM_FORMAT=vcd

run_corner_wave:
	$(MAKE) run TESTNAME=axi_corner_case_test WAVEFORM=1 WAVEFORM_FORMAT=vcd

# Generate all waveform formats for specific tests
run_basic_all_formats:
	$(MAKE) run_all_formats TESTNAME=axi_basic_test

run_stress_all_formats:
	$(MAKE) run_all_formats TESTNAME=axi_stress_test

run_write_read_all_formats:
	$(MAKE) run_all_formats TESTNAME=axi_write_read_test

run_corner_all_formats:
	$(MAKE) run_all_formats TESTNAME=axi_corner_case_test

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

# View waveform with Verdi (Synopsys Verdi - works with VCD, FSDB, and VPD)
view_verdi:
	@if [ -z "$$DISPLAY" ]; then \
		echo "ERROR: X11 forwarding not enabled."; \
		echo ""; \
		echo "For Apache Guacamole/NoMachine users:"; \
		echo "  Connect via Guacamole/NoMachine, then run: make view_verdi"; \
		exit 1; \
	fi
	@if [ ! -f "$(WAVEFORM_FILE)" ]; then \
		echo "ERROR: Waveform file '$(WAVEFORM_FILE)' not found."; \
		echo "       Generate it first with: make run_basic_wave"; \
		exit 1; \
	else \
		echo "Opening waveform file $(WAVEFORM_FILE) with Verdi..."; \
		if echo "$(WAVEFORM_FILE)" | grep -q "\.vcd$$"; then \
			verdi -vcd $(WAVEFORM_FILE) & \
		elif echo "$(WAVEFORM_FILE)" | grep -q "\.fsdb$$"; then \
			verdi -ssf $(WAVEFORM_FILE) & \
		else \
			verdi -vpd $(WAVEFORM_FILE) & \
		fi; \
		echo "Verdi launched in background. Check your GUI window."; \
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
	$(BUILD_DIR)/simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_basic_test -cm $(COVERAGE) -l $(BUILD_DIR)/axi_basic_test.log & \
	$(BUILD_DIR)/simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_stress_test -cm $(COVERAGE) -l $(BUILD_DIR)/axi_stress_test.log & \
	$(BUILD_DIR)/simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_write_read_test -cm $(COVERAGE) -l $(BUILD_DIR)/axi_write_read_test.log & \
	$(BUILD_DIR)/simv +ntb_random_seed_automatic +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=axi_corner_case_test -cm $(COVERAGE) -l $(BUILD_DIR)/axi_corner_case_test.log & \
	wait
	@echo "All tests completed. Check individual log files in $(BUILD_DIR)/:"
	@echo "  - $(BUILD_DIR)/axi_basic_test.log"
	@echo "  - $(BUILD_DIR)/axi_stress_test.log"
	@echo "  - $(BUILD_DIR)/axi_write_read_test.log"
	@echo "  - $(BUILD_DIR)/axi_corner_case_test.log"

# Run all tests with all waveform formats (VCD, VPD, FSDB) for each test
run_all_tests_all_formats: compile
	@echo "=========================================="
	@echo "Running all tests with all waveform formats"
	@echo "This will run 12 simulations (4 tests × 3 formats)"
	@echo "=========================================="
	@echo ""
	@echo "Test 1/4: axi_basic_test"
	@echo "  Format 1/3: VCD..."
	$(MAKE) run TESTNAME=axi_basic_test WAVEFORM=1 WAVEFORM_FORMAT=vcd WAVEFORM_FILE=$(BUILD_DIR)/axi_basic_test.vcd LOGFILE=$(BUILD_DIR)/axi_basic_test_vcd.log
	@echo "  Format 2/3: VPD..."
	$(MAKE) run TESTNAME=axi_basic_test WAVEFORM=1 WAVEFORM_FORMAT=vpd WAVEFORM_FILE=$(BUILD_DIR)/axi_basic_test.vpd LOGFILE=$(BUILD_DIR)/axi_basic_test_vpd.log
	@echo "  Format 3/3: FSDB (may skip if PLI not available)..."
	@$(MAKE) run TESTNAME=axi_basic_test WAVEFORM=1 WAVEFORM_FORMAT=fsdb WAVEFORM_FILE=$(BUILD_DIR)/axi_basic_test.fsdb LOGFILE=$(BUILD_DIR)/axi_basic_test_fsdb.log 2>&1 || echo "    ✗ FSDB skipped (PLI library not available or compilation failed)"
	@echo ""
	@echo "Test 2/4: axi_stress_test"
	@echo "  Format 1/3: VCD..."
	$(MAKE) run TESTNAME=axi_stress_test WAVEFORM=1 WAVEFORM_FORMAT=vcd WAVEFORM_FILE=$(BUILD_DIR)/axi_stress_test.vcd LOGFILE=$(BUILD_DIR)/axi_stress_test_vcd.log
	@echo "  Format 2/3: VPD..."
	$(MAKE) run TESTNAME=axi_stress_test WAVEFORM=1 WAVEFORM_FORMAT=vpd WAVEFORM_FILE=$(BUILD_DIR)/axi_stress_test.vpd LOGFILE=$(BUILD_DIR)/axi_stress_test_vpd.log
	@echo "  Format 3/3: FSDB (may skip if PLI not available)..."
	@$(MAKE) run TESTNAME=axi_stress_test WAVEFORM=1 WAVEFORM_FORMAT=fsdb WAVEFORM_FILE=$(BUILD_DIR)/axi_stress_test.fsdb LOGFILE=$(BUILD_DIR)/axi_stress_test_fsdb.log 2>&1 || echo "    ✗ FSDB skipped (PLI library not available or compilation failed)"
	@echo ""
	@echo "Test 3/4: axi_write_read_test"
	@echo "  Format 1/3: VCD..."
	$(MAKE) run TESTNAME=axi_write_read_test WAVEFORM=1 WAVEFORM_FORMAT=vcd WAVEFORM_FILE=$(BUILD_DIR)/axi_write_read_test.vcd LOGFILE=$(BUILD_DIR)/axi_write_read_test_vcd.log
	@echo "  Format 2/3: VPD..."
	$(MAKE) run TESTNAME=axi_write_read_test WAVEFORM=1 WAVEFORM_FORMAT=vpd WAVEFORM_FILE=$(BUILD_DIR)/axi_write_read_test.vpd LOGFILE=$(BUILD_DIR)/axi_write_read_test_vpd.log
	@echo "  Format 3/3: FSDB (may skip if PLI not available)..."
	@$(MAKE) run TESTNAME=axi_write_read_test WAVEFORM=1 WAVEFORM_FORMAT=fsdb WAVEFORM_FILE=$(BUILD_DIR)/axi_write_read_test.fsdb LOGFILE=$(BUILD_DIR)/axi_write_read_test_fsdb.log 2>&1 || echo "    ✗ FSDB skipped (PLI library not available or compilation failed)"
	@echo ""
	@echo "Test 4/4: axi_corner_case_test"
	@echo "  Format 1/3: VCD..."
	$(MAKE) run TESTNAME=axi_corner_case_test WAVEFORM=1 WAVEFORM_FORMAT=vcd WAVEFORM_FILE=$(BUILD_DIR)/axi_corner_case_test.vcd LOGFILE=$(BUILD_DIR)/axi_corner_case_test_vcd.log
	@echo "  Format 2/3: VPD..."
	$(MAKE) run TESTNAME=axi_corner_case_test WAVEFORM=1 WAVEFORM_FORMAT=vpd WAVEFORM_FILE=$(BUILD_DIR)/axi_corner_case_test.vpd LOGFILE=$(BUILD_DIR)/axi_corner_case_test_vpd.log
	@echo "  Format 3/3: FSDB (may skip if PLI not available)..."
	@$(MAKE) run TESTNAME=axi_corner_case_test WAVEFORM=1 WAVEFORM_FORMAT=fsdb WAVEFORM_FILE=$(BUILD_DIR)/axi_corner_case_test.fsdb LOGFILE=$(BUILD_DIR)/axi_corner_case_test_fsdb.log 2>&1 || echo "    ✗ FSDB skipped (PLI library not available or compilation failed)"
	@echo ""
	@echo "=========================================="
	@echo "All tests and waveforms completed!"
	@echo "=========================================="
	@echo ""
	@echo "Generated waveform files in $(BUILD_DIR)/:"
	@echo "  VCD files (for Verdi/GTKWave):"
	@echo "    - $(BUILD_DIR)/axi_basic_test.vcd"
	@echo "    - $(BUILD_DIR)/axi_stress_test.vcd"
	@echo "    - $(BUILD_DIR)/axi_write_read_test.vcd"
	@echo "    - $(BUILD_DIR)/axi_corner_case_test.vcd"
	@echo "  VPD files (for DVE):"
	@echo "    - $(BUILD_DIR)/axi_basic_test.vpd"
	@echo "    - $(BUILD_DIR)/axi_stress_test.vpd"
	@echo "    - $(BUILD_DIR)/axi_write_read_test.vpd"
	@echo "    - $(BUILD_DIR)/axi_corner_case_test.vpd"
	@echo "  FSDB files (for Verdi):"
	@echo "    - $(BUILD_DIR)/axi_basic_test.fsdb"
	@echo "    - $(BUILD_DIR)/axi_stress_test.fsdb"
	@echo "    - $(BUILD_DIR)/axi_write_read_test.fsdb"
	@echo "    - $(BUILD_DIR)/axi_corner_case_test.fsdb"
	@echo ""
	@echo "Note: Coverage databases are created as simv.vdb for each test run"

.PHONY: coverage_report

# Coverage report generation
coverage_report:
	@echo "Generating coverage report..."
	@if [ -d $(BUILD_DIR)/simv.vdb ]; then \
		urg -full64 -dir $(BUILD_DIR)/simv.vdb -report $(BUILD_DIR)/coverage_report; \
		echo "Coverage report generated in $(BUILD_DIR)/coverage_report/ directory"; \
		echo "Open $(BUILD_DIR)/coverage_report/dashboard.html in a web browser to view the report"; \
	elif [ -d simv.vdb ]; then \
		echo "Note: Found simv.vdb in root directory, moving to $(BUILD_DIR)/..."; \
		mv simv.vdb $(BUILD_DIR)/ 2>/dev/null || true; \
		urg -full64 -dir $(BUILD_DIR)/simv.vdb -report $(BUILD_DIR)/coverage_report; \
		echo "Coverage report generated in $(BUILD_DIR)/coverage_report/ directory"; \
		echo "Open $(BUILD_DIR)/coverage_report/dashboard.html in a web browser to view the report"; \
	else \
		echo "Error: Coverage database not found. Run tests first to generate coverage data."; \
		echo "Try: make run_basic or make run_all"; \
		exit 1; \
	fi

# Clean up generated files
clean:
	@echo "Cleaning build directory and generated files..."
	rm -rf $(BUILD_DIR)
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h DVEfiles inter.vpd *.log simv.vdb *vpd *.vcd *.fsdb coverage*.vdb coverage_report
	@echo "Clean complete. All build artifacts removed."

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
	@echo "  make run_all_tests_all_formats - Run all tests with all waveform formats (VCD/VPD/FSDB)"
	@echo "  make coverage_report   - Generate coverage report from all test runs"
	@echo "  make clean             - Clean up generated files"
	@echo "  make help              - Display this help message"
	@echo ""
	@echo "Waveform Generation:"
	@echo "  Enable waveform generation (default: VCD format for Verdi):"
	@echo "    make run WAVEFORM=1"
	@echo "    make run WAVEFORM=1 WAVEFORM_FORMAT=vcd    - Generate VCD (Verdi/GTKWave)"
	@echo "    make run WAVEFORM=1 WAVEFORM_FORMAT=vpd    - Generate VPD (DVE)"
	@echo "    make run WAVEFORM=1 WAVEFORM_FORMAT=fsdb   - Generate FSDB (Verdi)"
	@echo "    make run_all_formats  - Generate ALL formats (VCD, VPD, FSDB) for current test"
	@echo "    make run_all_tests_all_formats - Run ALL tests with ALL formats (12 simulations)"
	@echo "    make run_basic_wave    - Run axi_basic_test with waveforms (VCD)"
	@echo "    make run_stress_wave   - Run axi_stress_test with waveforms (VCD)"
	@echo "    make run_write_read_wave - Run axi_write_read_test with waveforms (VCD)"
	@echo "    make run_corner_wave   - Run axi_corner_case_test with waveforms (VCD)"
	@echo "  Custom waveform file:"
	@echo "    make run WAVEFORM=1 WAVEFORM_FILE=my_waveform.vcd"
	@echo "  Viewing waveforms:"
	@echo "    NOTE: DVE/Verdi require Synopsys VCS license (available on this server)"
	@echo "    Option 1: Verdi (works with VCD/FSDB/VPD):"
	@echo "      verdi -vcd waveform.vcd    - View VCD file"
	@echo "      verdi -ssf waveform.fsdb   - View FSDB file"
	@echo "      make view_verdi            - View default waveform file"
	@echo "    Option 2: DVE (works with VPD):"
	@echo "      dve -vpd waveform.vpd     - View VPD file"
	@echo "      make view_waveform        - View default waveform file"
	@echo "    Option 3: GTKWave (FREE, works with VCD):"
	@echo "      gtkwave waveform.vcd      - View VCD file (if installed)"
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
	@echo "C Memory Model (DPI):"
	@echo "  Use C memory model implementation in scoreboard:"
	@echo "    make run USE_C_MEMORY_MODEL=1"
	@echo "    make compile USE_C_MEMORY_MODEL=1"
	@echo "  Note: This enables DPI and compiles subscribers/axi_memory_model.c"
	@echo ""
	@echo "Available tests:"
	@echo "  - axi_basic_test       - Basic functional test"
	@echo "  - axi_stress_test      - Randomized stress test"
	@echo "  - axi_write_read_test  - Write then read test"
	@echo "  - axi_corner_case_test - Corner case tests"
