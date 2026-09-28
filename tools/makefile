.PHONY: all clean energy_collector comp_energy_tester

all: energy_collector comp_energy_tester

energy_collector:
	$(MAKE) -C energy_collector

comp_energy_tester: energy_collector
	$(MAKE) -C comp_energy_tester

clean:
	$(MAKE) -C energy_collector clean
	$(MAKE) -C comp_energy_tester clean
