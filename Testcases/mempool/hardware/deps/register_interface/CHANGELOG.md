# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.3.1 - 2021-06-24
### Fixed
- Align AXI version in ips_list.yml with Bender.yml

## 0.3.0 - 2021-06-09
### Changed
- Rebased register_interface specific change of reggen tool on lowRISC upstream master
- Bump AXI version

## 0.2.2 - 2021-04-20
### Added
- Add `periph_to_reg`.

### Changed
- Bump AXI version

## 0.2.1 - 2021-02-03
### Changed
- Update `axi` to `0.23.0`
- Update `common_cells` to `1.21.0`

### Added
- Add ipapprox description

## 0.2.0 - 2020-12-30
### Fixed
- Fix bug in AXI-Lite to register interface conversion
- Fix minor style problems (`verible-lint`)

## Removed
- Remove `reg_intf_pkg.sv`. Type definitions are provided by `typedef.svh`.

### Added
- Add `reggen` tool from lowrisc.
- Add `typedef` and `assign` macros.
- Add `reg_cdc`.
- Add `reg_demux`.
- Add `reg_mux`.
- Add `reg_to_mem`.
- AXI to reg interface.
- Open source release.

### Changed
- Updated AXI dependency

## 0.1.3 - 2018-06-02
### Fixed
- Add `axi_lite_to_reg.sv` to list of source files.

## 0.1.2 - 2018-03-23
### Fixed
- Remove time unit from test package. Fixes delay annotation issues.

## 0.1.1 - 2018-03-23
### Fixed
- Add a clock port to the `REG_BUS` interface. This fixes the test driver.

## 0.1.0 - 2018-03-23
### Added
- Add register bus interfaces.
- Add uniform register.
- Add AXI-Lite to register bus adapter.
- Add test package with testbench utilities.
