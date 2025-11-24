// lib/core/constants/course_structure.dart
import 'unit_catalog.dart';

class CourseStructure {
  /// Map of courseKey -> year -> semester -> list of unitCodes
  /// Fill in as you verify official unit lists. This contains core programs for initial seed.
  static final Map<String, Map<String, Map<String, List<String>>>> curriculum = {
    // BBIT (example fill from JKUAT pages)
    'BBIT': {
      '1': {
        '1': [
          'HRD2101',
          'SZL2111',
          'COMM1101',
          'PSI2101',
          'ICS2101',
          'HBC2102',
          'HBC2103',
        ],
        '2': [
          'DBS2101',
          'SWE2101',
          'HBT2102',
          'ICS2106',
          'ENT2401',
        ],
      },
      '2': {
        '1': [
          'ICS2201',
          'CSS2101',
          'AI3101',
        ],
        '2': [
          'SMA2104',
          'PROJ4001',
        ],
      },
    },

    // COMPUTER SCIENCE (BSc.)
    'COMPUTER_SCIENCE': {
      '1': {
        '1': [
          'PSI2101',
          'SMA2104',
          'COMM1101',
          'ICS2101',
        ],
        '2': [
          'DBS2101',
          'SWE2101',
          'ICS2201',
        ],
      },
      '2': {
        '1': [
          'AI3101',
          'CSS2101',
        ],
        '2': [
          'PROJ4001',
        ],
      },
    },

    // BIT (Information Technology)
    'BIT': {
      '1': {
        '1': ['COMM1101', 'PSI2101', 'ICS2101'],
        '2': ['DBS2101', 'SWE2101'],
      },
    },

    // BCOM (Commerce)
    'BCOM': {
      '1': {
        '1': ['HBC2102', 'HBC2103', 'HCB0101'],
        '2': ['HCB0102', 'HCB0104'],
      },
    },

    // AGRICULTURE (sample)
    'BSC_AGRIC': {
      '1': {
        '1': ['AHS2001', 'SBC2001', 'COMM1101'],
        '2': ['AHS2002', 'AHS2005'],
      },
    },

    // MBChB placeholder (medicine) — use real official list if available
    'MBCHB': {
      '1': {
        '1': ['ANAT2101', 'BIO2101', 'MIC2101'],
        '2': ['PHYS2101'],
      },
    },

    // Add rest of courses similarly
  };

  static List<String> getUnitCodes(String courseKey, String year, String semester) {
    return curriculum[courseKey]?[year]?[semester] ?? [];
  }

  static List<String> getUnitNamesFromCodes(List<String> codes) {
    return codes.map((c) => UnitCatalog.units[c] ?? c).toList();
  }
}
